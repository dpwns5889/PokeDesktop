extends GdUnitTestSuite
## 전투 특성 (엔트리일 때 발동, 기획서 4.6·4.13, v0.28)

const T0 := 1_000_000.0
const Manager := preload("res://assets/scripts/autoload/encounter_manager.gd")

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _add(dex_id: int, level: int, traits: Array = []) -> Dictionary:
	var inst := PlayerState.add_caught({&"dex_id": dex_id, &"level": level, &"gender": &"male", &"region": &"grassland"})
	inst.traits = traits
	return inst


func test_collect_counts_same_trait_once_and_ignores_expedition_traits() -> void:
	var a := _add(16, 10, ["flash_fire", "quick_feet"])
	var b := _add(16, 10, ["flash_fire", "harvest"])
	var fx := BattleTraits.collect([a, b])
	assert_float(fx.type_weights[&"fire"]).is_equal(1.5)     # 같은 특성 2마리 → 1번
	assert_float(fx.type_weights[&"grass"]).is_equal(1.5)
	assert_int(fx.traits.size()).is_equal(2)                 # 속보(원정)는 빠짐
	var none := BattleTraits.collect([])
	assert_dict(none.type_weights).is_empty()
	assert_float(none.interval_mult).is_equal(1.0)
	assert_float(none.fill_mult).is_equal(1.0)


func test_type_weight_raises_encounter_share() -> void:
	var region := GameData.get_region(&"forest")
	var grass_share := func(type_weights: Dictionary) -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var hits := 0
		for i in 4000:
			var e := EncounterLogic.pick_entry(region.encounters, 40, rng, type_weights)
			if GameData.get_species(e.dex_id).types.has(&"grass"):
				hits += 1
		return hits / 4000.0
	var base: float = grass_share.call({})
	var boosted: float = grass_share.call({&"grass": 1.5})
	assert_float(boosted).is_greater(base + 0.04)
	# 기대값: 가중치 비율 w → 1.5w / (1.5w + (1-w))
	assert_float(boosted).is_equal_approx(1.5 * base / (1.5 * base + 1.0 - base), 0.03)


func test_species_weight_mult_any_type() -> void:
	var bulbasaur := GameData.get_species(1)   # 풀·독
	assert_float(BattleTraits.species_weight_mult(bulbasaur, {&"poison": 1.5})).is_equal(1.5)
	assert_float(BattleTraits.species_weight_mult(bulbasaur, {&"fire": 1.5})).is_equal(1.0)


func test_boosted_level_respects_cap() -> void:
	assert_int(BattleTraits.boosted_level(5, 2, 8)).is_equal(7)
	assert_int(BattleTraits.boosted_level(7, 2, 8)).is_equal(8)
	assert_int(BattleTraits.boosted_level(10, 2, 8)).is_equal(10)   # 이미 넘었으면 그대로
	assert_int(BattleTraits.boosted_level(5, 0, 8)).is_equal(5)


## 꿀모으기 = 야생 Lv × 2원, 픽업 = 아이템 인카운터 확률 ×2 (v0.84)
func test_honey_money_and_pickup_mult() -> void:
	var fx := BattleTraits.collect([_add(16, 10, ["pickup", "honey_gather"])])
	assert_int(BattleTraits.after_battle_currency(fx, 20)).is_equal(40)
	assert_float(fx.item_encounter_mult).is_equal(2.0)
	assert_float(BattleTraits.collect([_add(16, 10, [])]).item_encounter_mult).is_equal(1.0)


func test_buff_lines() -> void:
	var fx := BattleTraits.collect([_add(16, 10, ["static", "unnerve", "stench", "vital_spirit"])])
	var texts := BattleTraits.buff_lines(fx).map(func(b): return b.text)
	assert_array(texts).contains(["전기 출현+50%", "야생 Lv+2", "게이지 -10%"])
	var bad := BattleTraits.buff_lines(fx).filter(func(b): return not b.good)
	assert_int(bad.size()).is_equal(2)


# ---------------------------------------------------------------- 매니저 연동

func _manager() -> Node:
	var m: Node = auto_free(Manager.new())
	m.set_process(false)
	m.rng.seed = 42
	m.start(T0)
	return m


func _to_battle(m: Node) -> void:
	var t := T0 + Formulas.MAX_ENCOUNTER_INTERVAL_SEC * 2.0
	m.tick(t)
	m.tick(t + Formulas.ENCOUNTER_PREVIEW_SEC)


func test_ball_fetch_and_honey_after_failed_battle() -> void:
	PlayerState.add_entry(_add(16, 10, ["ball_fetch", "honey_gather"]).uid)
	PlayerState.add_item(&"great_ball", 1)
	PlayerState.select_ball(&"great_ball")
	var m := _manager()
	_to_battle(m)
	var money := PlayerState.currency
	assert_dict(m.begin_battle()).is_not_empty()
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(0)
	m.finish_battle(false)
	assert_int(PlayerState.currency).is_equal(money + int(m.current[&"level"]) * 2)   # 꿀모으기


## 볼줍기 (v0.56, v0.81 15%): 성공·실패 상관없이 15% 확률로 쓴 볼을 돌려받는다. 몬스터볼은 돌려받지 않는다.
func test_ball_fetch_refunds_about_15_percent_on_any_result() -> void:
	PlayerState.add_entry(_add(16, 10, ["ball_fetch"]).uid)
	var fx := BattleTraits.collect(PlayerState.entry_pokemon())
	assert_bool(fx.refund_ball).is_true()
	assert_float(fx.refund_chance).is_equal_approx(0.15, 0.0001)
	var m := _manager()
	m.rng.seed = 11
	m.current = {&"level": 5}
	var refunds := {true: 0, false: 0}
	for success in [true, false]:
		for i in 300:
			var before := PlayerState.item_count(&"great_ball")
			m._battle_ball = &"great_ball"
			m._apply_after_battle(success)
			refunds[success] += PlayerState.item_count(&"great_ball") - before
	assert_int(refunds[true]).is_between(25, 70)    # 300 × 15% ≈ 45
	assert_int(refunds[false]).is_between(25, 70)
	# 몬스터볼은 돌려받지 않는다
	var pb := PlayerState.item_count(PlayerState.INFINITE_BALL)
	for i in 50:
		m._battle_ball = PlayerState.INFINITE_BALL
		m._apply_after_battle(false)
	assert_int(PlayerState.item_count(PlayerState.INFINITE_BALL)).is_equal(pb)


func test_unnerve_lowers_fill_and_stench_slows_encounters() -> void:
	var m := _manager()
	_to_battle(m)
	var base: float = m.begin_battle()[&"fill"]
	m.finish_battle(true)
	PlayerState.add_entry(_add(16, 10, ["unnerve"]).uid)
	var m2 := _manager()
	_to_battle(m2)
	# 엔트리 능력치 보너스(게이지)도 함께 붙으므로 그것까지 곱한 값과 비교
	var atk := float(m2.entry_bonus()[&"attack"])
	assert_float(m2.begin_battle()[&"fill"]).is_equal_approx(base * (1.0 + atk) * 0.9, 0.0001)
	# 악취: 간격 ×1.15 (같은 rng 로 비교)
	var plain := _manager()
	PlayerState.add_entry(_add(16, 10, ["stench"]).uid)
	var slow := _manager()
	assert_float(slow._deadline - T0).is_equal_approx((plain._deadline - T0) * 1.15, 0.01)


func test_vital_spirit_raises_wild_level() -> void:
	var m := _manager()
	_to_battle(m)
	var base_level: int = m.current[&"level"]
	PlayerState.add_entry(_add(16, 10, ["vital_spirit"]).uid)
	var m2 := _manager()
	_to_battle(m2)
	var cap := GameData.get_region(PlayerState.current_region).level_cap
	assert_int(m2.current[&"level"]).is_equal(mini(base_level + 2, maxi(base_level, cap)))
