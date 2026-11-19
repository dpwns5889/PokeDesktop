extends Node
## 원정: 시작·진행·귀환·보상. 원정은 전투가 아니며 시간만 소모한다. (기획서 4.10)
##
## - 시작 시각과 끝나는 시각을 유닉스 시간으로 저장 → 앱이 꺼져 있어도 진행된다.
## - 시계를 되돌려 남은 시간이 원래보다 길어지면 원래 길이로 자른다(음수 경과 방지).
## - 결과(성공 여부·보상)는 보상을 받을 때 정한다. 전투력·비율·파티 효과는 출발할 때 고정한다.
## 결과는 {ok: bool, reason: String, ...} (화면에 그대로 표시할 수 있는 한국어 문구).

const SLOT_LEVELS := [1, 15, 30]    # 플레이어 레벨에 따라 동시 원정 1 → 2 → 3개

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: check_finished(_now()))
	add_child(timer)
	check_finished.call_deferred(_now())


## 동시에 보낼 수 있는 원정 수
func max_slots() -> int:
	var n := 0
	for lv in SLOT_LEVELS:
		if PlayerState.level >= lv:
			n += 1
	return n


func is_unlocked(x: ExpeditionData) -> bool:
	return UnlockManager.evaluate(x.unlock_conditions)


func is_running(id: StringName) -> bool:
	for x in PlayerState.expeditions:
		if StringName(x.id) == id:
			return true
	return false


## 자동 선택: 원정 중이 아닌 개체 중 요구치를 넘는 최소 파티 (기획서 4.10)
func auto_select(id: StringName) -> Array[String]:
	var x := GameData.get_expedition(id)
	if x == null:
		return []
	var free: Array[Dictionary] = []
	for p in PlayerState.pokemon:
		if not PlayerState.is_busy(p.uid) and not PlayerState.is_entry(p.uid):
			free.append(p)
	return ExpeditionLogic.auto_select(free, x)


## 파티 미리보기 (전투력·성공 확률·시간). uids 는 보관함 개체 uid.
func preview(id: StringName, uids: Array) -> Dictionary:
	var x := GameData.get_expedition(id)
	if x == null:
		return {}
	return ExpeditionLogic.party_summary(_party(uids), x)


func start(id: StringName, uids: Array, now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = _now()
	var x := GameData.get_expedition(id)
	if x == null:
		return _fail("없는 원정지입니다.")
	if not is_unlocked(x):
		return _fail("아직 갈 수 없는 원정지입니다.")
	if is_running(id):
		return _fail("이미 진행 중인 원정지입니다.")
	if PlayerState.expeditions.size() >= max_slots():
		return _fail("동시에 보낼 수 있는 원정은 %d개입니다." % max_slots())
	if uids.size() < x.min_party:
		return _fail("파티는 %d마리 이상이어야 합니다." % x.min_party)
	var seen := {}
	for u in uids:
		if seen.has(u):
			return _fail("같은 포켓몬을 두 번 넣을 수 없습니다.")
		seen[u] = true
		if PlayerState.find_pokemon(u).is_empty():
			return _fail("보관함에 없는 포켓몬입니다.")
		if PlayerState.is_busy(u):
			return _fail("이미 원정 중인 포켓몬이 있습니다.")
		if PlayerState.is_entry(u):
			return _fail("엔트리 포켓몬은 원정에 보낼 수 없습니다.")
	var sum := ExpeditionLogic.party_summary(_party(uids), x)
	if not sum.can_start:
		return _fail("전투력이 부족합니다. (요구치의 70% 이상 필요)")
	var entry := {
		"id": String(id),
		"party": uids.duplicate(),
		"started_at": int(now),
		"end_at": int(now) + int(sum.duration_sec),
		"power": int(sum.power),
		"ratio": float(sum.ratio),
		"mods": sum.mods,
		"notified": false,
	}
	PlayerState.expeditions.append(entry)
	PlayerState.changed.emit()
	return {"ok": true, "reason": "", "entry": entry}


## 남은 초 (끝났으면 0)
func seconds_left(entry: Dictionary, now: float = -1.0) -> int:
	if now < 0.0:
		now = _now()
	var total := int(entry.end_at) - int(entry.started_at)
	return clampi(int(entry.end_at) - int(now), 0, total)


func is_done(entry: Dictionary, now: float = -1.0) -> bool:
	return seconds_left(entry, now) <= 0


## 끝난 원정이 있으면 한 번씩 알림 (expedition_finished). 반환: 보상을 기다리는 원정 수
func check_finished(now: float) -> int:
	var waiting := 0
	for x in PlayerState.expeditions:
		if is_done(x, now):
			waiting += 1
			if not x.notified:
				x.notified = true
				PlayerState.changed.emit()
				EventBus.expedition_finished.emit(StringName(x.id))
	return waiting


func claimable_count() -> int:
	var n := 0
	for x in PlayerState.expeditions:
		if is_done(x):
			n += 1
	return n


## 보상 받기. 반환: {ok, reason, success, currency, items, pokemon_exp: {uid: exp}, levels: {uid: 오른 레벨}, player_exp}
func claim(index: int, now: float = -1.0) -> Dictionary:
	if index < 0 or index >= PlayerState.expeditions.size():
		return _fail("없는 원정입니다.")
	var entry: Dictionary = PlayerState.expeditions[index]
	if not is_done(entry, now):
		return _fail("아직 돌아오지 않았습니다.")
	var x := GameData.get_expedition(StringName(entry.id))
	PlayerState.expeditions.remove_at(index)
	if x == null:
		PlayerState.changed.emit()
		return _fail("원정지 데이터가 없어 보상 없이 돌아왔습니다.")

	var mods: Dictionary = entry.get("mods", {})
	var chance := ExpeditionLogic.success_chance(float(entry.ratio), float(mods.get("success_bonus", 0.0)))
	var success := rng.randf() < chance
	var r := ExpeditionLogic.roll_rewards(x, float(entry.ratio), mods, success, rng)
	PlayerState.add_currency(r.currency)
	for id in r.items:
		PlayerState.add_item(id, r.items[id])
	if not r.items.is_empty():
		EventBus.items_received.emit(r.items, &"expedition")

	var exp_map := {}
	var levels := {}
	for uid in entry.party:
		var inst := PlayerState.find_pokemon(uid)
		if inst.is_empty():
			continue
		var e := ExpeditionLogic.pokemon_exp(inst, x)
		exp_map[uid] = e
		var gained := PlayerState.add_pokemon_exp(inst, e)
		if gained > 0:
			levels[uid] = gained
	PlayerState.add_exp(x.player_exp_reward)
	PlayerState.changed.emit()
	r.merge({"ok": true, "reason": "", "pokemon_exp": exp_map, "levels": levels,
		"player_exp": x.player_exp_reward, "expedition": String(x.id)}, true)
	return r


## 원정 취소: 보상 없이 바로 돌아온다
func cancel(index: int) -> Dictionary:
	if index < 0 or index >= PlayerState.expeditions.size():
		return _fail("없는 원정입니다.")
	PlayerState.expeditions.remove_at(index)
	PlayerState.changed.emit()
	return {"ok": true, "reason": ""}


func _party(uids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in uids:
		var p := PlayerState.find_pokemon(u)
		if not p.is_empty():
			out.append(p)
	return out


func _now() -> float:
	return Time.get_unix_time_from_system()


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
