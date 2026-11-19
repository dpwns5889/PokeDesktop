extends Node
## 인카운터 타이머(정지/재개)와 출현 결정, 전투 시작/종료 처리. (기획서 4.2, 4.3)
##
## 상태 흐름
##   WAITING ─타이머 만료→ PREVIEW(풀숲 흔들림, 소리) → APPEARED(90초) ─클릭→ BATTLE → RESULT → WAITING
##                                                      └─90초 초과→ RESULT(도망)
##   WAITING ⇄ PAUSED : 선택한 볼(몬스터볼 제외) 보유량이 0이면 정지, 생기면 남은 시간부터 재개
##   아이템 인카운터 (v0.84): WAITING → PREVIEW(흔들림) → RESULT(아이템을 얻고 ITEM_SHOW_SEC 동안 보여 줌) → WAITING
##     current = {item: id}. 클릭하지 않아도 얻는다.
##
## 시간은 프레임 누적이 아니라 시스템 시각(초)으로 비교한다. 테스트에서는 tick(now)를 직접 호출한다.
## 개발용: 실행 인자 `-- --fast-encounter` 를 주면 간격이 약 12초가 된다. `-- --shiny` 는 모든 야생이 색이 다른 포켓몬(디버그 빌드만, M11).
## `-- --item-encounter` 는 모든 인카운터가 아이템(디버그 빌드만, v0.84).

enum State { WAITING, PAUSED, PREVIEW, APPEARED, BATTLE, RESULT }

const FAST_INTERVAL_SEC := 12.0
const FAST_JITTER_SEC := 4.0
## 아이템 인카운터에서 아이템을 보여 주는 시간
const ITEM_SHOW_SEC := 2.0

var state: State = State.WAITING
## 현재 인카운터 {dex_id, level, gender, shiny, region}. 없으면 빈 Dictionary.
var current: Dictionary = {}
## 마지막 결과: &"caught" / &"fled" / &"item" / &""
var last_result: StringName = &""
## begin_battle()이 거절된 이유: &"storage_full" / &"no_ball" / &""
var block_reason: StringName = &""

var rng := RandomNumberGenerator.new()
var fast_mode := false
var force_shiny := false
var force_item := false

## 이번 전투에 쓴 볼 (볼줍기 특성: 실패하면 돌려준다)
var _battle_ball: StringName = &""
var _deadline: float = 0.0      # 현재 상태가 끝나는 시각 (WAITING이면 다음 인카운터 시각)
var _paused_remaining: float = 0.0
var _started := false


func _ready() -> void:
	rng.randomize()
	fast_mode = OS.get_cmdline_user_args().has("--fast-encounter")
	force_shiny = OS.is_debug_build() and OS.get_cmdline_user_args().has("--shiny")
	force_item = OS.is_debug_build() and OS.get_cmdline_user_args().has("--item-encounter")
	EventBus.current_region_changed.connect(_on_region_changed)
	start(_now())


func _process(_delta: float) -> void:
	tick(_now())


## 타이머 시작(앱 시작 시). 앱이 꺼져 있던 동안의 인카운터는 쌓지 않는다.
func start(now: float) -> void:
	_started = true
	_schedule_next(now)


## 상태 갱신. now = 시스템 시각(초).
func tick(now: float) -> void:
	if not _started:
		return
	match state:
		State.WAITING:
			if not PlayerState.can_use_selected_ball():
				_paused_remaining = maxf(0.0, _deadline - now)
				state = State.PAUSED
				EventBus.ball_shortage_changed.emit(true)
			elif now >= _deadline:
				_begin_encounter(now)
		State.PAUSED:
			if PlayerState.can_use_selected_ball():
				_deadline = now + _paused_remaining
				state = State.WAITING
				EventBus.ball_shortage_changed.emit(false)
		State.PREVIEW:
			if now >= _deadline and current.has(&"item"):
				_found_item(now)
			elif now >= _deadline:
				state = State.APPEARED
				_deadline = now + Formulas.ENCOUNTER_APPEAR_SEC
				PlayerState.mark_seen(current[&"dex_id"])
				EventBus.encounter_appeared.emit(current)
		State.APPEARED:
			if now >= _deadline:
				_finish(now, false)
		State.RESULT:
			if now >= _deadline:
				current = {}
				last_result = &""
				_schedule_next(now)
				EventBus.encounter_ended.emit()


## 다음 인카운터까지 남은 초 (WAITING/PAUSED에서 의미 있음).
func seconds_until_next() -> float:
	if state == State.PAUSED:
		return _paused_remaining
	if state == State.WAITING:
		return maxf(0.0, _deadline - _now())
	return 0.0


## APPEARED 상태에서 남은 초 (도망까지).
func seconds_until_flee() -> float:
	return maxf(0.0, _deadline - _now()) if state == State.APPEARED else 0.0


## 포켓몬을 클릭했을 때. 볼을 1개 소모하고 전투 파라미터를 돌려준다. 시작할 수 없으면 빈 Dictionary.
func begin_battle() -> Dictionary:
	block_reason = &""
	if state != State.APPEARED:
		return {}
	# 보관함이 가득 차면 인카운터는 일어나지만 전투는 시작하지 않는다 (기획서 4.7.2)
	if PlayerState.is_storage_full():
		block_reason = &"storage_full"
		return {}
	var ball := PlayerState.consume_selected_ball()
	if ball == &"":
		block_reason = &"no_ball"
		return {}
	var species := GameData.get_species(current[&"dex_id"])
	state = State.BATTLE
	_battle_ball = ball
	EventBus.battle_started.emit(current, ball)
	var params := Formulas.capture_params(species.catch_rate, current[&"level"],
		species.is_legendary or species.is_mythical, _ball_modifier(ball),
		entry_bonus(), float(current.get(&"difficulty_bonus", 0.0)))
	params[&"fill"] = float(params[&"fill"]) * float(entry_traits().fill_mult)   # 긴장감 (4.6)
	params[&"fill"] = float(params[&"fill"]) * region_capture_fill(ball)   # 후반 지역일수록 덜 참 (v0.63), 몬스터볼은 더 (v0.92)
	return params


## 지금 지역의 게이지 배율 (RegionData.capture_fill, v0.63). 지역이 없으면 1.0.
## ball 이 몬스터볼이면 그 지역의 몬스터볼 추가 배율(poke_ball_fill, v0.92)도 곱한다 (슈퍼볼·하이퍼볼은 그대로)
func region_capture_fill(ball: StringName = &"") -> float:
	var region := GameData.get_region(PlayerState.current_region)
	if region == null:
		return 1.0
	return region.capture_fill * (region.poke_ball_fill if ball == PlayerState.INFINITE_BALL else 1.0)


## 엔트리의 전투 특성을 합친 효과 (BattleTraits.collect, 기획서 4.6)
func entry_traits() -> Dictionary:
	return BattleTraits.collect(PlayerState.entry_pokemon())


## 엔트리 능력치 보너스 (기획서 4.13). 고정 기준과 비교하므로 상대에 따라 달라지지 않는다 (v0.27)
func entry_bonus() -> Dictionary:
	var stats: Array = []
	for p in PlayerState.entry_pokemon():
		stats.append(PlayerState.stats_of(p))
	return Formulas.entry_battle_bonus(stats, PlayerState.MAX_ENTRIES)


## 메인 화면 오른쪽 위에 보여 줄 버프 [{text, good}] (기획서 6.1).
## v0.62: 엔트리 능력치 보너스("게이지 +9%" 등)는 빼고,
## 엔트리의 전투 특성(픽업·꿀모으기·볼줍기·타입 출현 증가 등) + 쓰고 있는 아이템 효과(향로·특이한 향로·행복의 알, 남은 분)
func active_buffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = BattleTraits.buff_lines(entry_traits())
	# 향로 (v0.41): 남은 분
	var now := int(_now())
	var t := PlayerState.incense_type(now)
	if t != &"":
		out.append({"text": "%s 향로 %d분" % [GameData.type_name(t), ceili(PlayerState.item_seconds_left("incense", now) / 60.0)], "good": true})
	var sl := PlayerState.item_seconds_left("shiny_incense", now)
	if sl > 0:
		out.append({"text": "특이한 향로 %d분" % ceili(sl / 60.0), "good": true})
	var el := PlayerState.item_seconds_left("lucky_egg", now)   # 행복의 알 (v0.61)
	if el > 0:
		out.append({"text": "행복의 알 %d분" % ceili(el / 60.0), "good": true})
	var hl := PlayerState.item_seconds_left("sweet_honey", now)   # 향긋한 허브 (v0.87)
	if hl > 0:
		out.append({"text": "향긋한 허브 %d분" % ceili(hl / 60.0), "good": true})
	return out


## 전투 종료 (BattleController가 호출).
func finish_battle(success: bool) -> void:
	if state != State.BATTLE:
		return
	_finish(_now(), success)


## 향긋한 허브 사용 (기획서 4.11, v0.87): 가방이 부른다. 처음 켤 때만 남은 대기 시간을 ×0.5 (연장일 때는 다시 줄이지 않는다).
## 반환: "" = 성공, 아니면 이유
func use_sweet_honey(now: float) -> String:
	var was_active := PlayerState.item_seconds_left("sweet_honey", int(now)) > 0
	var reason := PlayerState.use_sweet_honey(int(now))
	if reason != "" or was_active:
		return reason
	var mult := PlayerState.interval_multiplier(int(now))
	match state:
		State.WAITING:
			_deadline = now + maxf(0.0, _deadline - now) * mult
		State.PAUSED:
			_paused_remaining *= mult
	return ""


## 진행 중인 인카운터를 버리고 대기 상태로 (저장 초기화 등).
func reset_to_waiting() -> void:
	var had_encounter := state != State.WAITING and state != State.PAUSED
	current = {}
	last_result = &""
	block_reason = &""
	_schedule_next(_now())
	if had_encounter:
		EventBus.encounter_ended.emit()


## 개발용: 즉시 인카운터.
func trigger_now() -> void:
	if state == State.WAITING:
		_begin_encounter(_now())


# ---------------------------------------------------------------- 내부

func _ball_modifier(ball: StringName) -> float:
	var item := GameData.get_item(ball)
	return item.catch_modifier() if item else 1.0


func _now() -> float:
	return Time.get_unix_time_from_system()


func _schedule_next(now: float) -> void:
	var interval := Formulas.roll_encounter_interval(rng, GameData.get_region(PlayerState.current_region))
	interval *= float(entry_traits().interval_mult)   # 악취 (4.6)
	interval *= PlayerState.interval_multiplier(int(now))   # 향긋한 허브 (4.11, v0.87)
	if fast_mode:
		interval = FAST_INTERVAL_SEC + rng.randf_range(-FAST_JITTER_SEC, FAST_JITTER_SEC)
	_deadline = now + interval
	state = State.WAITING


## 지역을 바꿨을 때 남은 시간이 새 지역의 최대 간격보다 길면 새 지역 기준으로 다시 뽑는다.
func _on_region_changed(_id: StringName) -> void:
	if not _started or fast_mode:
		return
	var now := _now()
	var limit := Formulas.encounter_interval_range(GameData.get_region(PlayerState.current_region)).y \
		* PlayerState.interval_multiplier(int(now))   # 향긋한 허브 (v0.87)
	match state:
		State.WAITING:
			if _deadline - now > limit:
				_schedule_next(now)
		State.PAUSED:
			_paused_remaining = minf(_paused_remaining, limit)


func _begin_encounter(now: float) -> void:
	var region := GameData.get_region(PlayerState.current_region)
	var fx := entry_traits()
	# 아이템 인카운터 (v0.84): 포켓몬 대신 아이템 (픽업이면 확률 ×2)
	var found := EncounterLogic.roll_item_encounter(region, 1000.0 if force_item else float(fx.item_encounter_mult), rng)
	if not found.is_empty():
		current = {&"item": found[&"id"], &"count": found[&"count"]}
		state = State.PREVIEW
		_deadline = now + Formulas.ENCOUNTER_PREVIEW_SEC
		AudioManager.play(&"encounter")
		EventBus.encounter_started.emit(current)
		return
	# 출현 타입 배율 = 엔트리 특성 × 향로 (v0.41), 색이 다른 확률 = 특이한 향로
	var weights: Dictionary = fx.type_weights.duplicate()
	var inc := PlayerState.incense_type_weights(int(now))
	for t in inc:
		weights[t] = float(weights.get(t, 1.0)) * float(inc[t])
	var enc := {} if region == null else EncounterLogic.roll_encounter(region, PlayerState.level, rng,
		GameData.legendary_rules(), UnlockManager.evaluate, weights, PlayerState.shiny_multiplier(int(now)))
	if not enc.is_empty() and not enc.get(&"legendary", false):
		enc[&"level"] = BattleTraits.boosted_level(enc[&"level"], fx.wild_level_add, region.level_cap)   # 의기양양
	if enc.is_empty():
		push_warning("지역 %s 에서 출현할 포켓몬이 없습니다." % PlayerState.current_region)
		_schedule_next(now)
		return
	if force_shiny:
		enc[&"shiny"] = true
	current = enc
	state = State.PREVIEW
	_deadline = now + Formulas.ENCOUNTER_PREVIEW_SEC
	AudioManager.play(&"encounter")
	EventBus.encounter_started.emit(current)


func _finish(now: float, success: bool) -> void:
	var was_battle := state == State.BATTLE
	state = State.RESULT
	_deadline = now + Formulas.ENCOUNTER_RESULT_SEC
	if was_battle:
		EventBus.battle_finished.emit(success)
	if success:
		last_result = &"caught"
		PlayerState.add_caught(current)
	else:
		last_result = &"fled"
		EventBus.encounter_fled.emit(current)
	if was_battle:
		_apply_after_battle(success)


## 아이템 인카운터: 아이템을 얻고 잠깐 보여 준 뒤 끝 (v0.84)
func _found_item(now: float) -> void:
	var id: StringName = current[&"item"]
	var count := int(current.get(&"count", 1))
	PlayerState.add_item(id, count)
	state = State.RESULT
	last_result = &"item"
	_deadline = now + ITEM_SHOW_SEC
	EventBus.items_received.emit({id: count}, &"encounter")   # 아이템 획득 소리
	EventBus.item_found.emit(id, count)


## 전투가 끝난 뒤 엔트리의 전투 특성: 꿀모으기·볼줍기(15% 확률, v0.81) — 성공·실패 모두 (기획서 4.6)
func _apply_after_battle(_success: bool) -> void:
	var fx := entry_traits()
	var lines := PackedStringArray()
	var money := BattleTraits.after_battle_currency(fx, int(current.get(&"level", 1)))
	if money > 0:
		PlayerState.add_currency(money)
		lines.append("꿀모으기 +%d원" % money)
	if fx.refund_ball and _battle_ball != &"" and _battle_ball != PlayerState.INFINITE_BALL 			and rng.randf() < float(fx.refund_chance):
		PlayerState.add_item(_battle_ball, 1)
		var ball := GameData.get_item(_battle_ball)
		lines.append("볼줍기 +%s" % (ball.name_ko if ball else String(_battle_ball)))   # v0.81: 꿀모으기 "+N원"과 같은 형식
	_battle_ball = &""
	if not lines.is_empty():
		EventBus.battle_traits_triggered.emit(lines)
