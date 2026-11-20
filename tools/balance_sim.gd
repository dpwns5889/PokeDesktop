extends Node
## 밸런스 시뮬레이터 (기획서 9.4). 실제 게임 로직으로 가상 플레이어의 14일(하루 5시간)을 돌린다.
##
## 실행: <godot> --headless --path . res://tools/balance_sim.tscn -- --seeds 5 --days 14
##   --seeds N      서로 다른 난수로 N번 돌려 평균 (기본 5)
##   --days N       일수 (기본 14)
##   --hours H      하루 실행 시간 (기본 5)
##   --react R      인카운터 반응률 (기본 0.7, 자리 비움이면 도망)
##   --verbose      날마다 자세히
##
## 가상 플레이어의 행동 (사람이 할 법한 단순한 규칙):
## - 인카운터: 반응률만큼 반응해 과녁 전투를 한다. 과녁은 반응 시간 0.3~0.5초, 명중률 85%로 누른다(실제 CaptureGame 사용).
##   어려운 포켓몬(난이도 0.5 이상)에는 가진 가장 좋은 볼을 쓴다.
## - 지역: 아직 못 잡은 종이 가장 많은 해금 지역에서 지낸다.
## - 원정: 빈 자리가 생기면 성공 확률 100%인 원정지 중 가장 요구치가 높은 곳에 보낸다.
##   파티는 게임의 "자동 선택"(전투력 순으로 5마리 이상, 요구치를 넘을 때까지)으로 고르고, 진화 후보 3마리를 더 넣어 경험치를 받게 한다.
##   앱이 꺼져 있는 시간(하루 19시간)에도 원정은 진행된다. 하루 시작에 끝난 원정 보상을 받는다.
## - 엔트리: 하루 끝에 능력치 합(종족값 합 × 레벨)이 가장 큰 3마리로 바꾼다(원정 중인 개체 제외).
## - 박사: 하루 끝과 보관함이 90% 찼을 때 중복 보내기(종마다 가장 좋은 1마리만 남김).
##   받은 사탕은 아직 없는 종으로 진화할 수 있는 포켓몬에게 (필요한 경험치가 적은 순) 먼저 주고, 남으면 주력 10마리에게.
## - 진화: 레벨 진화는 모두 수락, 진화의 돌은 새 종이 나오면 사용(v0.42: 돌은 원정에서만 얻는다).
## - 상점: 슈퍼볼이 10개 미만이면 산다(소지금 3,000원은 남김). 보관함이 90% 차면 (돈이 되는 만큼) 확장.
## - 아이템 인카운터(v0.84): 인카운터가 아이템이면 얻고 끝. 하루 끝에 귀중품을 모두 판다(--verbose 에 "아이템 N개 M원").
## - 골드코롱(v0.87): 플레이어 Lv10부터 하루 시작에 돈이 있으면 --honey 개(기본 2개 = 1시간, 인카운터 간격 ×0.5)를 사서 쓴다. 0이면 안 쓴다.

const DEFAULT_SEEDS := 5
## 기획서 9.3 일차별 목표 [일차, 플레이어 Lv, 포획 종 수]
## (M10에서 중간 목표를 '초반에 빨리 모이고 끝으로 갈수록 느려지는' 수집 곡선에 맞게 고침. 14일차 목표는 그대로)
## [일차, 목표 플레이어 Lv, 목표 종] — v0.25: 빠른 진행 수용 (기획서 9.3)
const TARGETS := [[1, 13, 53], [3, 22, 100], [7, 37, 136], [10, 40, 146], [14, 40, 151]]
const TOLERANCE := 0.15
## 원정에 진화 후보를 몇 마리 더 데려가는지 / 남은 사탕을 나눠 줄 주력 수
const EXTRA_EVOLUTION_MEMBERS := 3
const MAIN_TEAM := 10
## 하루에 쓰는 골드코롱 개수 (--honey 로 바꿈)
const DEFAULT_HONEY_PER_DAY := 2
## 가상 플레이어가 상위 볼을 쓰는 난이도 기준 배율 (v0.92): 기준 = 0.5 × 지역 몬스터볼 추가 배율 × 이 값. 1.0 이면 후반에 막혀 진행이 크게 느려지고(9.3.2), 0.65 부터 목표를 통과한다
const DEFAULT_BALL_SCALE := 0.65
## 슈퍼볼을 이 개수까지 사 둔다 (v0.92: 10 → 30, 후반 지역에서 슈퍼볼을 많이 쓰게 되므로)
const GREAT_BALL_STOCK := 30
## 하이퍼볼 계약 뒤 사 두는 개수와, 하이퍼볼을 먼저 쓰는 난이도 (v0.92)
const ULTRA_BALL_STOCK := 5
const ULTRA_FIRST_DIFFICULTY := 0.7
## 계약·구매 뒤에 남기는 돈 (Q10: 비용 + 3,000원)
const RESERVE := 3000

var rng := RandomNumberGenerator.new()
var now := 0.0
var days := 14
var hours := 5.0
var react := 0.7
var verbose := false
var honey_per_day := DEFAULT_HONEY_PER_DAY
var no_spend := false   # 지출 없이 모으기만 (--no-spend): 계약 비용 가늠용, v0.92
var ball_scale := DEFAULT_BALL_SCALE   # 상위 볼을 쓰는 난이도 기준 배율 (0 이면 항상 상위 볼, --ball-scale, v0.92)
var stats := {}
var _party_sizes: Array[int] = []    # 자동 선택 인원 (진화 후보 제외), 모든 실행
var _level_log: Array = []   # 실행마다 {레벨: [일, 소지금+귀중품]} (--no-spend 로 계약 비용 가늠, v0.92)
var _level_seen := 1
var _cur_day := 1
var _late_log: Array = []   # 실행마다의 stats (후반 지역 볼 사용 집계, v0.92)
var missing_count := {}   # dex_id -> 못 잡은 실행 수
var _next_send_try := 0.0


func _ready() -> void:
	var seeds := DEFAULT_SEEDS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds": seeds = int(args[i + 1])
			"--days": days = int(args[i + 1])
			"--hours": hours = float(args[i + 1])
			"--react": react = float(args[i + 1])
			"--honey": honey_per_day = int(args[i + 1])
			"--ball-scale": ball_scale = float(args[i + 1])
			"--no-spend": no_spend = true
			"--verbose": verbose = true
	# 시뮬레이터가 실제 매니저의 실시간 처리와 섞이지 않게
	EncounterManager.set_process(false)
	ExpeditionManager.set_process(false)
	for c in ExpeditionManager.get_children():
		if c is Timer:
			c.stop()

	var all_runs: Array = []
	for s in seeds:
		all_runs.append(_run(1000 + s))
	_report(all_runs)
	get_tree().quit()


# ---------------------------------------------------------------- 한 번 돌리기

func _run(seed: int) -> Array:
	rng.seed = seed
	PlayerState.reset()
	PlayerState.rng.seed = seed
	ExpeditionManager.rng.seed = seed
	EvolutionManager.queue.clear()
	now = 2_000_000_000.0
	_next_send_try = 0.0
	stats = {"encounters": 0, "reacted": 0, "caught": 0, "fled": 0, "legend": 0, "expeditions": 0, "transferred": 0,
		"battles": 0, "won": 0, "full": 0, "diff_sum": 0.0, "items": 0, "item_money": 0, "honey": 0,
		"late_battles": 0, "late_poke": 0, "late_won": 0, "late_poke_won": 0}
	var daily: Array = []
	_level_seen = 1
	_level_log.append({})
	for day in range(1, days + 1):
		_cur_day = day
		_claim_expeditions()
		var day_end := now + hours * 3600.0
		_use_honey()
		while true:
			now += Formulas.roll_encounter_interval(rng, GameData.get_region(PlayerState.current_region)) \
				* PlayerState.interval_multiplier(int(now))   # 골드코롱 (v0.87)
			if now >= day_end:
				break
			_encounter()
			_claim_expeditions()
			_send_expedition()
			_handle_evolutions()
			_log_level()
			_buy_contracts()
		stats.item_money += int(ShopManager.sell_all_valuables().get("money", 0))   # v0.84: 귀중품은 하루 끝에 판다
		_end_of_day()
		var snap := _snapshot(day)
		daily.append(snap)
		if verbose:
			print("seed %d day %2d: Lv%d 종%d 지역%d(%s) 돈%d 원정%d 포획%d 전설%d 보관%d/%d 가득%d 전투승률%d%% 평균난이도%.2f 최고Lv%d 아이템%d개 %d원 꿀%d개" % [seed, day, snap.level, snap.species,
				snap.regions, PlayerState.current_region, snap.money, stats.expeditions, stats.caught, stats.legend,
				PlayerState.storage_count(), PlayerState.storage_capacity, stats.full,
				int(100.0 * stats.won / maxi(1, stats.battles)), stats.diff_sum / maxi(1, stats.battles), snap.top_level, stats.items, stats.item_money, stats.honey])
			stats.battles = 0
			stats.won = 0
			stats.full = 0
			stats.diff_sum = 0.0
		now = day_end + (24.0 - hours) * 3600.0   # 앱이 꺼져 있는 시간
	for s in GameData.all_species():
		if not PlayerState.is_caught(s.dex_id):
			missing_count[s.dex_id] = missing_count.get(s.dex_id, 0) + 1
	_late_log.append(stats.duplicate())
	return daily


## 레벨이 처음 오를 때 그 시점의 (일, 소지금 + 팔 수 있는 귀중품)을 기록한다 (v0.92)
func _log_level() -> void:
	while PlayerState.level > _level_seen:
		_level_seen += 1
		_level_log.back()[_level_seen] = [_cur_day, PlayerState.currency + int(ShopManager.valuables().get("total", 0))]


## 계약은 돈(+귀중품을 팔면)이 비용 + RESERVE 이상일 때 바로 맺는다 (v0.92). 처음 맺은 레벨·일을 기록한다
func _buy_contracts() -> void:
	if no_spend:
		return
	for cid in ShopManager.visible_contracts():
		var cost := int(ShopManager.CONTRACTS[cid].cost)
		if PlayerState.currency + int(ShopManager.valuables().get("total", 0)) < cost + RESERVE:
			return
		stats.item_money += int(ShopManager.sell_all_valuables().get("money", 0))
		if ShopManager.buy_contract(cid).ok:
			stats["c_%s_level" % cid] = PlayerState.level
			stats["c_%s_day" % cid] = _cur_day


## 하루 시작에 골드코롱를 사서 쓴다 (v0.87): 실제 상점 규칙(Lv10, 2,000원)을 따른다. 돈이 모자라면 못 산다
func _use_honey() -> void:
	if no_spend:
		return
	for i in honey_per_day:
		if not ShopManager.buy(&"gold_cologne").ok:
			return
		PlayerState.use_gold_cologne(int(now))
		stats.honey += 1


func _snapshot(day: int) -> Dictionary:
	var top := 0
	for p in PlayerState.pokemon:
		top = maxi(top, p.level)
	return {"day": day, "level": PlayerState.level, "species": PlayerState.dex_caught_count(),
		"regions": PlayerState.unlocked_regions.size(), "money": PlayerState.currency, "top_level": top,
		"caught": stats.caught, "expeditions": stats.expeditions, "legend": stats.legend}


# ---------------------------------------------------------------- 인카운터

func _encounter() -> void:
	stats.encounters += 1
	if PlayerState.storage_count() >= PlayerState.storage_capacity * 0.9:
		_tidy_storage()
	_choose_region()
	var region := GameData.get_region(PlayerState.current_region)
	# 아이템 인카운터 (v0.84): 반응과 상관없이 얻는다
	var found := EncounterLogic.roll_item_encounter(region, float(EncounterManager.entry_traits().item_encounter_mult), rng)
	if not found.is_empty():
		PlayerState.add_item(found[&"id"], int(found[&"count"]))
		stats.items += 1
		return
	var enc := EncounterLogic.roll_encounter(region, PlayerState.level, rng, GameData.legendary_rules(), UnlockManager.evaluate)
	if enc.is_empty():
		return
	PlayerState.mark_seen(enc[&"dex_id"])
	if PlayerState.is_storage_full():
		stats.full += 1
	if rng.randf() > react or PlayerState.is_storage_full():
		stats.fled += 1
		return
	stats.reacted += 1
	var species := GameData.get_species(enc[&"dex_id"])
	var legendary: bool = enc.get(&"legendary", false)
	var bonus := float(enc.get(&"difficulty_bonus", 0.0))   # 출현 표의 추가 난이도 (v0.76)
	var difficulty := Formulas.capture_difficulty(species.catch_rate, enc[&"level"], legendary, bonus)
	var ball := _choose_ball(difficulty, region)
	PlayerState.select_ball(ball)
	PlayerState.consume_selected_ball()
	var item := GameData.get_item(ball)
	var params := Formulas.capture_params(species.catch_rate, enc[&"level"], legendary, item.catch_modifier(),
		EncounterManager.entry_bonus(), bonus)
	params[&"fill"] = float(params[&"fill"]) * EncounterManager.region_capture_fill(ball)   # v0.63 지역 배율, v0.92 몬스터볼 추가 배율
	stats.battles += 1
	stats.diff_sum += difficulty
	var late := region != null and region.poke_ball_fill < 1.0   # 발전소부터 (v0.92)
	if late:
		stats.late_battles += 1
		stats.late_poke += 1 if ball == &"poke_ball" else 0
	if _play_capture(params):
		stats.won += 1
		if late:
			stats.late_won += 1
			stats.late_poke_won += 1 if ball == &"poke_ball" else 0
		PlayerState.add_caught(enc)
		stats.caught += 1
		if legendary:
			stats.legend += 1
	else:
		stats.fled += 1
	PlayerState.select_ball(&"poke_ball")


## 난이도가 기준 이상이면 가진 가장 좋은 볼. 기준 = 0.5 × 그 지역의 몬스터볼 추가 배율(poke_ball_fill) × ball_scale:
## 몬스터볼이 덜 찰수록 더 쉬운 상대부터 슈퍼볼을 쓴다 (v0.92, 초원~동굴은 추가 배율이 1.0 이라 기존 0.5 × ball_scale)
func _choose_ball(difficulty: float, region: RegionData = null) -> StringName:
	var poke_fill := region.poke_ball_fill if region else 1.0
	if difficulty >= 0.5 * poke_fill * ball_scale:
		# 아주 어려운 상대(0.7 이상)에는 하이퍼볼을 먼저, 아니면 슈퍼볼을 먼저 (v0.92)
		var order: Array[StringName] = []
		order.assign([&"ultra_ball", &"great_ball"] if difficulty >= ULTRA_FIRST_DIFFICULTY else [&"great_ball", &"ultra_ball"])
		for b in order:
			if PlayerState.item_count(b) > 0:
				return b
	return &"poke_ball"


## 과녁 전투를 가상 플레이어로 진행 (실제 CaptureGame)
func _play_capture(params: Dictionary) -> bool:
	var game := CaptureGame.new(params, Rect2(2, 32, 124, 166), rng)   # v0.46 전투 칸
	var dt := 0.05
	var cooldown := 0.0
	var reaction := rng.randf_range(0.3, 0.5)
	while not game.is_finished():
		game.update(dt)
		cooldown -= dt
		if cooldown <= 0.0 and not game.targets.is_empty() and game.targets[0].age >= reaction:
			var t: Dictionary = game.targets[0]
			if rng.randf() < 0.85:
				# 맞힘: 중심 근처일 확률 약 30%
				var off := Vector2.from_angle(rng.randf() * TAU) * game.radius() * (rng.randf_range(0.0, 0.4) if rng.randf() < 0.3 else rng.randf_range(0.5, 0.95))
				game.click(t.pos + off)
			else:
				game.click(t.pos + Vector2(game.radius() * 1.5, 0))   # 빗나감
			cooldown = rng.randf_range(0.25, 0.4)
			reaction = rng.randf_range(0.3, 0.5)
	return game.is_success()


## 조건을 채웠고 아직 못 잡은 전설이 있으면 그 지역, 아니면 아직 못 잡은 종이 가장 많은 해금 지역
func _choose_region() -> void:
	for rule in GameData.legendary_rules():
		if PlayerState.is_caught(rule.dex_id) or not UnlockManager.evaluate(rule.conditions):
			continue
		for rid in rule.region_ids:
			if PlayerState.unlocked_regions.has(rid):
				PlayerState.set_current_region(rid)
				return
	var best: StringName = PlayerState.current_region
	var best_n := -1
	for r in GameData.all_regions():
		if not PlayerState.unlocked_regions.has(r.id):
			continue
		var n := 0
		for e in r.encounters:
			if e.min_player_level <= PlayerState.level and not PlayerState.is_caught(e.dex_id):
				n += e.weight
		if n >= best_n:
			best_n = n
			best = r.id
	PlayerState.set_current_region(best)


# ---------------------------------------------------------------- 원정

func _claim_expeditions() -> void:
	ExpeditionManager.check_finished(now)
	var i := 0
	while i < PlayerState.expeditions.size():
		if ExpeditionManager.is_done(PlayerState.expeditions[i], now):
			ExpeditionManager.claim(i, now)
			stats.expeditions += 1
			_handle_evolutions()
		else:
			i += 1


func _send_expedition() -> void:
	# 계산이 무거우므로 30분(게임 시간)에 한 번만 시도
	if now < _next_send_try:
		return
	_next_send_try = now + 1800.0
	while PlayerState.expeditions.size() < ExpeditionManager.max_slots():
		var free: Array[Dictionary] = []
		for p in PlayerState.pokemon:
			if not PlayerState.is_busy(p.uid) and not PlayerState.is_entry(p.uid):
				free.append(p)
		var best_id: StringName = &""
		var best_req := -1
		var best_party: Array = []
		for x in GameData.all_expeditions():
			if ExpeditionManager.is_running(x.id) or not ExpeditionManager.is_unlocked(x) or x.required_power <= best_req:
				continue
			# 자동 선택(게임과 같은 규칙)으로 성공 100%가 되는 가장 어려운 원정지
			var core: Array = ExpeditionLogic.auto_select(free, x)
			if core.size() < x.min_party or ExpeditionManager.preview(x.id, core).success_chance < 1.0:
				continue
			# 진화 후보를 몇 마리 더 데려가 경험치를 준다
			var extra := 0
			for cand in _evolution_candidates():
				if extra >= EXTRA_EVOLUTION_MEMBERS:
					break
				if not core.has(cand.uid) and not PlayerState.is_busy(cand.uid) and not PlayerState.is_entry(cand.uid):
					core.append(cand.uid)
					extra += 1
			best_req = x.required_power
			best_id = x.id
			best_party = core
		if best_id == &"":
			return
		if not ExpeditionManager.start(best_id, best_party, now).ok:
			return   # 출발 실패면 이번엔 그만 (같은 파티로 계속 다시 시도하는 무한 반복 방지)
		_party_sizes.append(best_party.size() - mini(EXTRA_EVOLUTION_MEMBERS, best_party.size()))


## 엔트리: 원정 중이 아닌 개체 중 능력치 합이 큰 3마리 (기획서 4.13)
func _pick_entries() -> void:
	for u in PlayerState.entries.duplicate():
		PlayerState.remove_entry(u)
	var free: Array = PlayerState.pokemon.filter(func(p): return not PlayerState.is_busy(p.uid))
	free.sort_custom(func(a, b):
		return GameData.get_species(a.dex_id).base_stat_total() * a.level > GameData.get_species(b.dex_id).base_stat_total() * b.level)
	for p in free.slice(0, PlayerState.MAX_ENTRIES):
		PlayerState.add_entry(p.uid)


# ---------------------------------------------------------------- 하루 끝: 박사·사탕·진화·상점

## 중복 보내기 + 보관함 확장
func _tidy_storage() -> void:
	var dups := ProfessorManager.duplicate_candidates(false)
	if not dups.is_empty():
		var r := ProfessorManager.transfer(dups)
		stats.transferred += r.get("count", 0)
	while not no_spend and PlayerState.storage_count() >= PlayerState.storage_capacity * 0.9 and ShopManager.can_expand_storage() 			and PlayerState.currency >= ShopManager.next_expansion_cost() + 3000:
		ShopManager.expand_storage()


func _end_of_day() -> void:
	_tidy_storage()
	_pick_entries()
	# 사탕: 진화 후보(필요 경험치가 적은 순)에게 먼저
	for cand in _evolution_candidates():
		if PlayerState.is_busy(cand.uid):
			continue
		var need: int = cand.need
		for candy in [ProfessorManager.CANDY_S, ProfessorManager.CANDY_M]:
			var per := int(GameData.get_item(candy).params.get(&"exp", 100))
			var n := mini(PlayerState.item_count(candy), ceili(float(need) / per))
			if n > 0:
				ProfessorManager.use_candy(cand.uid, candy, n)
				need -= n * per
			if need <= 0:
				break
		_handle_evolutions()
		if PlayerState.item_count(ProfessorManager.CANDY_S) + PlayerState.item_count(ProfessorManager.CANDY_M) == 0:
			break
	# 남은 사탕은 전투력(종족값 합 × 레벨) 상위 MAIN_TEAM 마리에게
	var team: Array = PlayerState.pokemon.filter(func(p): return not PlayerState.is_busy(p.uid))
	team.sort_custom(func(a, b):
		return GameData.get_species(a.dex_id).base_stat_total() * a.level > GameData.get_species(b.dex_id).base_stat_total() * b.level)
	team = team.slice(0, mini(MAIN_TEAM, team.size()))
	for candy in [ProfessorManager.CANDY_M, ProfessorManager.CANDY_S]:
		if team.is_empty():
			break
		var share := ceili(float(PlayerState.item_count(candy)) / team.size())
		for p in team:
			if PlayerState.item_count(candy) <= 0:
				break
			if p.level < Formulas.MAX_POKEMON_LEVEL:
				ProfessorManager.use_candy(p.uid, candy, share)
				_handle_evolutions()
	_use_stones()
	_shop()
	_handle_evolutions()


## 아직 없는 종으로 레벨 진화할 수 있는 개체: [{uid, need(필요 경험치)}], 필요 경험치가 적은 순. 종마다 가장 레벨 높은 1마리.
func _evolution_candidates() -> Array:
	var best := {}   # 진화 후 종 -> {uid, need}
	for p in PlayerState.pokemon:
		var s := GameData.get_species(p.dex_id)
		for e in s.evolutions:
			if e.method != &"level" or PlayerState.is_caught(e.to):
				continue
			var need := maxi(0, Formulas.total_exp(int(e.value)) - Formulas.total_exp(p.level) - int(p.get("exp", 0)))
			if not best.has(e.to) or need < best[e.to].need:
				best[e.to] = {"uid": p.uid, "need": need}
	var out: Array = best.values()
	out.sort_custom(func(a, b): return a.need < b.need)
	return out


func _use_stones() -> void:
	for p in PlayerState.pokemon.duplicate():
		if PlayerState.is_busy(p.uid) or PlayerState.find_pokemon(p.uid).is_empty():
			continue
		var s := GameData.get_species(p.dex_id)
		for e in s.evolutions:
			if e.method != &"item" or PlayerState.is_caught(e.to):
				continue
			var item := StringName(e.item)
			if not no_spend and PlayerState.item_count(item) == 0 and GameData.get_item(item).can_buy() 					and PlayerState.currency >= 3000 + GameData.get_item(item).buy_price:   # v0.42: 돌은 상점에 없음
				ShopManager.buy(item, 1)
			if PlayerState.item_count(item) > 0:
				EvolutionManager.request_item_evolution(p.uid, item)
				_handle_evolutions()
				break


func _shop() -> void:
	if no_spend:
		return
	var great := GameData.get_item(&"great_ball")
	var need := GREAT_BALL_STOCK - PlayerState.item_count(&"great_ball")
	var afford := (PlayerState.currency - RESERVE) / ShopManager.price_of(great)   # v0.92: 계약 뒤에는 싸다
	if need > 0 and afford > 0:
		ShopManager.buy(&"great_ball", mini(need, afford))
	var ultra := GameData.get_item(&"ultra_ball")
	if ShopManager.is_on_sale(ultra):   # 하이퍼볼 취급 계약 뒤 (v0.92)
		var u_need := ULTRA_BALL_STOCK - PlayerState.item_count(&"ultra_ball")
		var u_afford := (PlayerState.currency - RESERVE) / ShopManager.price_of(ultra)
		if u_need > 0 and u_afford > 0:
			ShopManager.buy(&"ultra_ball", mini(u_need, u_afford))


func _handle_evolutions() -> void:
	var guard := 0
	while not EvolutionManager.current().is_empty() and guard < 50:
		EvolutionManager.confirm_current()
		guard += 1


# ---------------------------------------------------------------- 보고

func _report(runs: Array) -> void:
	print("")
	print("=== 밸런스 시뮬레이션: %d회 평균, 하루 %.0f시간 × %d일, 반응률 %d%% ===" % [runs.size(), hours, days, int(react * 100)])
	print("일차 | 플레이어Lv | 포획 종 | 지역 | 소지금 | 최고 포켓몬Lv | 누적 포획 | 원정 | 전설")
	for d in days:
		var avg := {}
		for k in ["level", "species", "regions", "money", "top_level", "caught", "expeditions", "legend"]:
			var sum := 0.0
			for r in runs:
				sum += r[d][k]
			avg[k] = sum / runs.size()
		print("%3d  | %6.1f | %6.1f | %4.1f | %7d | %5.1f | %6.1f | %5.1f | %4.1f" % [d + 1, avg.level, avg.species, avg.regions,
			int(avg.money), avg.top_level, avg.caught, avg.expeditions, avg.legend])
	print("")
	print("목표 비교 (기획서 9.3, 허용 ±%d%%)" % int(TOLERANCE * 100))
	var all_ok := true
	for t in TARGETS:
		if t[0] > days:
			continue
		var lv := 0.0
		var sp := 0.0
		for r in runs:
			lv += r[t[0] - 1].level
			sp += r[t[0] - 1].species
		lv /= runs.size()
		sp /= runs.size()
		var ok_lv: bool = absf(lv - t[1]) <= t[1] * TOLERANCE
		var ok_sp: bool = absf(sp - t[2]) <= t[2] * TOLERANCE
		all_ok = all_ok and ok_lv and ok_sp
		print("  %2d일차  Lv %5.1f / 목표 %2d %s   종 %6.1f / 목표 %3d %s" % [t[0], lv, t[1], "OK" if ok_lv else "벗어남",
			sp, t[2], "OK" if ok_sp else "벗어남"])
	print("결과: %s" % ("통과" if all_ok else "조정 필요"))
	var miss: Array = missing_count.keys()
	miss.sort()
	var names: Array[String] = []
	for id in miss:
		names.append("%s(%d)" % [GameData.get_species(id).name_ko, missing_count[id]])
	if not _party_sizes.is_empty():
		var total := 0
		for n in _party_sizes:
			total += n
		print("원정 자동 선택 인원: 평균 %.1f, 최소 %d, 최대 %d (진화 후보 제외)" % [float(total) / _party_sizes.size(), _party_sizes.min(), _party_sizes.max()])
	# 발전소부터(몬스터볼 추가 배율 < 1) 지역의 전투 (v0.92)
	var lb := 0.0
	var lp := 0.0
	var lw := 0.0
	var lpw := 0.0
	for st in _late_log:
		lb += st.late_battles
		lp += st.late_poke
		lw += st.late_won
		lpw += st.late_poke_won
	if lb > 0.0:
		print("발전소 이후 지역 전투: 실행당 %.0f회, 슈퍼볼 이상 %d%%, 승률 전체 %d%% / 몬스터볼 %d%% / 슈퍼볼 이상 %d%%" % [lb / _late_log.size(), roundi(100.0 * (lb - lp) / lb),
			roundi(100.0 * lw / lb), roundi(100.0 * lpw / maxf(1.0, lp)), roundi(100.0 * (lw - lpw) / maxf(1.0, lb - lp))])
	_report_levels_and_contracts()
	print("마지막 날까지 못 잡은 종 (못 잡은 실행 수): %d종" % miss.size())
	print("  " + ", ".join(names))


## 레벨별 (처음 오른 일, 소지금+귀중품) 평균과, 계약을 맺은 레벨·일 평균 (v0.92)
func _report_levels_and_contracts() -> void:
	var rows: Array[String] = []
	for lv in range(9, 32):
		var n := 0
		var d := 0.0
		var m := 0.0
		for lg in _level_log:
			if lg.has(lv):
				n += 1
				d += lg[lv][0]
				m += lg[lv][1]
		if n > 0:
			rows.append("Lv%d: %.1f일차 %d원" % [lv, d / n, roundi(m / n)])
	print("레벨별 처음 오른 시점의 일차·소지금+귀중품(%s): %s" % ["지출 없음" if no_spend else "보통", " | ".join(rows)])
	for cid in ShopManager.CONTRACTS:
		var n := 0
		var lv := 0.0
		var dy := 0.0
		for st in _late_log:
			if st.has("c_%s_level" % cid):
				n += 1
				lv += st["c_%s_level" % cid]
				dy += st["c_%s_day" % cid]
		if n > 0:
			print("계약 %s(%d원): %d/%d회 맺음, 평균 Lv%.1f(%.1f일차)" % [cid, ShopManager.CONTRACTS[cid].cost, n, _late_log.size(), lv / n, dy / n])
		else:
			print("계약 %s(%d원): 맺지 못함" % [cid, ShopManager.CONTRACTS[cid].cost])
