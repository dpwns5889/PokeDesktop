extends GdUnitTestSuite
## 아이템 데이터, 상점 구매·판매, 보관함 확장, 볼 선택 (기획서 4.2, 4.11, 4.12).

const Manager := preload("res://scripts/autoload/encounter_manager.gd")
const T0 := 1_000_000.0

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_v01_items_and_prices() -> void:
	var ids := GameData.all_items().filter(func(i: ItemData) -> bool: return i.category != GameData.CAPSULE_TEMPLATE) \
		.map(func(i: ItemData) -> String: return String(i.id))   # 특성 캡슐(특성마다 하나, v0.79)은 trait_capsule_test
	assert_array(ids).contains_exactly(["poke_ball", "great_ball", "ultra_ball", "exp_candy_s", "exp_candy_m",
		"fire_stone", "water_stone", "thunder_stone", "leaf_stone", "moon_stone", "incense", "shiny_incense", "lucky_egg",
		"forget_berry", "pretty_feather", "pearl", "stardust", "nugget", "star_piece", "big_nugget"])
	# 금구슬: 판매 전용 (픽업 특성, v0.28)
	var nugget := GameData.get_item(&"nugget")
	assert_bool(nugget.can_buy()).is_false()
	assert_int(nugget.sell_price).is_equal(2000)
	var great := GameData.get_item(&"great_ball")
	assert_int(great.buy_price).is_equal(500)
	assert_int(great.sell_price).is_equal(250)
	assert_float(great.catch_modifier()).is_equal(1.5)
	assert_float(GameData.get_item(&"ultra_ball").catch_modifier()).is_equal(2.0)
	# 경험사탕 S 는 v0.82부터 상점에서 안 팖 (원정·박사에게서만)
	assert_bool(GameData.get_item(&"exp_candy_s").can_buy()).is_false()
	# 원정 전용 = 상점에서 안 팖
	assert_bool(GameData.get_item(&"ultra_ball").can_buy()).is_false()
	assert_bool(GameData.get_item(&"exp_candy_m").can_buy()).is_false()
	assert_bool(GameData.get_item(&"poke_ball").can_sell()).is_false()
	# 진화의 돌: 상점에서 팔지 않고(v0.42) 원정에서 얻는다 — 다섯 가지 모두 어떤 원정 보상에 있다
	var rewards := {}
	for x in GameData.all_expeditions():
		for r in x.reward_table:
			rewards[String(r.item)] = true
	for stone in [&"fire_stone", &"water_stone", &"thunder_stone", &"leaf_stone", &"moon_stone"]:
		assert_bool(GameData.get_item(stone).can_buy()).override_failure_message(String(stone)).is_false()
		assert_bool(GameData.get_item(stone).can_sell()).is_true()
		assert_bool(rewards.has(String(stone))).override_failure_message(String(stone)).is_true()
	# 큰 금구슬: 판매 전용 6,000원, 아이템 인카운터로 얻는다 (v0.84)
	var big := GameData.get_item(&"big_nugget")
	assert_bool(big.can_buy()).is_false()
	assert_int(big.sell_price).is_equal(6000)


## 아이템 인카운터 드롭표 (v0.84): 모든 아이템이 있고 판매 전용, 등급이 높을수록 평균 판매가가 높다
func test_item_encounter_tables() -> void:
	var avg := []
	for tier in [1, 2, 3]:
		var total := 0
		var weight := 0
		for row in Formulas.ITEM_ENCOUNTER_TABLES[tier]:
			var it := GameData.get_item(StringName(row[0]))
			assert_object(it).override_failure_message(String(row[0])).is_not_null()
			assert_bool(it.can_buy()).is_false()
			total += it.sell_price * int(row[1])
			weight += int(row[1])
		avg.append(float(total) / weight)
	assert_bool(avg[0] < avg[1] and avg[1] < avg[2]).is_true()
	for r in GameData.all_regions():
		assert_int(r.item_tier).override_failure_message(String(r.id)).is_between(1, 3)


func test_sell_all_valuables_sells_only_valuables() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.add_item(&"pearl", 2)
	PlayerState.add_item(&"big_nugget", 1)
	PlayerState.add_item(&"great_ball", 3)
	var before := PlayerState.currency
	var r := ShopManager.sell_all_valuables()
	assert_int(r.count).is_equal(3)
	assert_int(PlayerState.currency - before).is_equal(500 * 2 + 6000)
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(3)
	assert_bool(ShopManager.sell_all_valuables().ok).is_false()
	PlayerState.load_save_dict(snap)


func test_evolution_items_in_species_data_exist() -> void:
	for s in GameData.all_species():
		for e in s.evolutions:
			if e.method == &"item":
				assert_object(GameData.get_item(e.item)).override_failure_message("%d: %s" % [s.dex_id, e.item]).is_not_null()


func test_new_game_starting_money() -> void:
	assert_int(PlayerState.currency).is_equal(PlayerState.STARTING_CURRENCY)


func test_buy_spends_money_and_adds_items() -> void:
	PlayerState.currency = 2000
	var r := ShopManager.buy(&"great_ball", 3)
	assert_bool(r.ok).is_true()
	assert_int(PlayerState.currency).is_equal(500)
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(3)


func test_buy_fails_without_money() -> void:
	PlayerState.currency = 400
	var r := ShopManager.buy(&"great_ball", 1)
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("돈이 부족")
	assert_int(PlayerState.currency).is_equal(400)
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(0)


func test_cannot_buy_expedition_only_item() -> void:
	PlayerState.currency = 100000
	assert_bool(ShopManager.buy(&"ultra_ball", 1).ok).is_false()


func test_sell() -> void:
	PlayerState.currency = 0
	PlayerState.add_item(&"exp_candy_m", 2)
	assert_bool(ShopManager.sell(&"exp_candy_m", 2).ok).is_true()
	assert_int(PlayerState.currency).is_equal(1600)
	assert_int(PlayerState.item_count(&"exp_candy_m")).is_equal(0)
	assert_bool(ShopManager.sell(&"exp_candy_m", 1).ok).is_false()
	assert_bool(ShopManager.sell(&"poke_ball", 1).ok).is_false()


func test_storage_expansion_cost_grows_and_caps_at_300() -> void:
	PlayerState.currency = 1_000_000
	var costs: Array[int] = []
	while ShopManager.can_expand_storage():
		costs.append(ShopManager.next_expansion_cost())
		assert_bool(ShopManager.expand_storage().ok).is_true()
	assert_int(PlayerState.storage_capacity).is_equal(300)
	assert_int(costs.size()).is_equal(10)
	assert_int(costs[0]).is_equal(5000)
	assert_int(costs[1]).is_equal(10000)
	assert_int(costs[9]).is_equal(50000)
	assert_bool(ShopManager.expand_storage().ok).is_false()


func test_format_money() -> void:
	assert_str(ShopManager.format_money(0)).is_equal("0원")
	assert_str(ShopManager.format_money(500)).is_equal("500원")
	assert_str(ShopManager.format_money(1234567)).is_equal("1,234,567원")


func test_cycle_ball_goes_through_all_balls() -> void:
	assert_str(String(PlayerState.selected_ball)).is_equal("poke_ball")
	assert_str(String(PlayerState.cycle_ball())).is_equal("great_ball")
	assert_str(String(PlayerState.cycle_ball())).is_equal("ultra_ball")
	assert_str(String(PlayerState.cycle_ball())).is_equal("poke_ball")


## M6 완료 기준: 볼 0개 선택 시 타이머 정지, 구매/변경 시 재개
func test_timer_pauses_with_empty_ball_and_resumes_after_buying() -> void:
	var m: Node = auto_free(Manager.new())
	m.set_process(false)
	m.start(T0)
	PlayerState.select_ball(&"great_ball")
	m.tick(T0 + 1.0)
	assert_int(m.state).is_equal(Manager.State.PAUSED)
	PlayerState.currency = 500
	assert_bool(ShopManager.buy(&"great_ball", 1).ok).is_true()
	m.tick(T0 + 2.0)
	assert_int(m.state).is_equal(Manager.State.WAITING)


func test_using_last_ball_then_timer_pauses() -> void:
	var m: Node = auto_free(Manager.new())
	m.set_process(false)
	m.rng.seed = 1
	# finish_battle()은 실제 시계를 쓰므로 이 테스트는 현재 시각 기준으로 진행한다
	var base := Time.get_unix_time_from_system()
	m.start(base)
	PlayerState.add_item(&"great_ball", 1)
	PlayerState.select_ball(&"great_ball")
	var t := base + Formulas.MAX_ENCOUNTER_INTERVAL_SEC + 1.0
	m.tick(t)
	m.tick(t + Formulas.ENCOUNTER_PREVIEW_SEC)
	var params: Dictionary = m.begin_battle()
	assert_float(params[&"fill"]).is_equal_approx(Formulas.CAPTURE_BASE_FILL * 1.5, 0.0001)
	m.finish_battle(true)
	m.tick(t + 100.0)   # 결과 표시 끝 → 대기
	m.tick(t + 101.0)   # 볼 0개 → 정지
	assert_int(m.state).is_equal(Manager.State.PAUSED)
	PlayerState.select_ball(&"poke_ball")
	m.tick(t + 102.0)
	assert_int(m.state).is_equal(Manager.State.WAITING)
