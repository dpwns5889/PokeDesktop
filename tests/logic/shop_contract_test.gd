extends GdUnitTestSuite
## 상점 계약 (기획서 4.12, v0.92): 슈퍼볼 할인 계약(동굴부터 보임, 맺으면 슈퍼볼 200원),
## 하이퍼볼 취급 계약(슈퍼볼 계약 뒤 보임, 맺으면 하이퍼볼 1,000원). 세이브 v3.

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_great_contract_visible_from_cave() -> void:
	assert_array(ShopManager.visible_contracts()).is_empty()
	PlayerState.unlock_region(&"cave")
	assert_array(ShopManager.visible_contracts()).contains_exactly([&"great_ball_discount"])   # 하이퍼볼 계약은 아직


func test_great_ball_price_drops_after_contract() -> void:
	var great := GameData.get_item(&"great_ball")
	PlayerState.unlock_region(&"cave")
	assert_int(ShopManager.price_of(great)).is_equal(500)
	PlayerState.currency = 100000
	var r := ShopManager.buy_contract(&"great_ball_discount")
	assert_bool(r.ok).is_true()
	assert_int(PlayerState.currency).is_equal(100000 - int(ShopManager.CONTRACTS[&"great_ball_discount"].cost))
	assert_int(ShopManager.price_of(great)).is_equal(200)
	# 실제 구매도 200원, 판매가(150)보다 비싸 차익 거래 없음
	PlayerState.currency = 1000
	assert_bool(ShopManager.buy(&"great_ball", 3).ok).is_true()
	assert_int(PlayerState.currency).is_equal(400)
	assert_int(great.sell_price).is_less(ShopManager.price_of(great))
	# 한 번 맺으면 목록에서 사라지고 다시 못 맺는다
	assert_bool(ShopManager.visible_contracts().has(&"great_ball_discount")).is_false()
	assert_bool(ShopManager.buy_contract(&"great_ball_discount").ok).is_false()


func test_ultra_contract_appears_after_great_contract_and_unlocks_ultra_ball() -> void:
	var ultra := GameData.get_item(&"ultra_ball")
	PlayerState.unlock_region(&"cave")
	PlayerState.currency = 1_000_000
	assert_bool(ShopManager.buy_contract(&"ultra_ball_sale").ok).is_false()   # 슈퍼볼 계약 먼저
	assert_bool(ShopManager.is_on_sale(ultra)).is_false()
	assert_bool(ShopManager.buy(&"ultra_ball").ok).is_false()
	assert_bool(ShopManager.buy_contract(&"great_ball_discount").ok).is_true()
	assert_array(ShopManager.visible_contracts()).contains_exactly([&"ultra_ball_sale"])   # 슈퍼볼 계약 직후부터
	assert_bool(ShopManager.buy_contract(&"ultra_ball_sale").ok).is_true()
	assert_bool(ShopManager.is_on_sale(ultra)).is_true()
	assert_int(ShopManager.price_of(ultra)).is_equal(1000)
	var before := PlayerState.currency
	assert_bool(ShopManager.buy(&"ultra_ball", 2).ok).is_true()
	assert_int(before - PlayerState.currency).is_equal(2000)
	assert_int(ultra.sell_price).is_equal(600)
	assert_array(ShopManager.visible_contracts()).is_empty()


func test_contract_needs_money() -> void:
	PlayerState.unlock_region(&"cave")
	PlayerState.currency = 100
	var r := ShopManager.buy_contract(&"great_ball_discount")
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("돈이 부족")
	assert_int(PlayerState.currency).is_equal(100)
	assert_bool(ShopManager.has_contract(&"great_ball_discount")).is_false()


func test_contract_costs_and_expedition_rewards_unchanged() -> void:
	assert_int(int(ShopManager.CONTRACTS[&"great_ball_discount"].cost)).is_equal(10000)
	assert_int(int(ShopManager.CONTRACTS[&"ultra_ball_sale"].cost)).is_equal(22000)
	# 원정 보상에는 하이퍼볼이 계속 나온다 (계약 없이도 얻는다)
	var found := false
	for x in GameData.all_expeditions():
		for r in x.reward_table:
			if String(r.item) == "ultra_ball":
				found = true
	assert_bool(found).is_true()


func test_contracts_saved_and_loaded() -> void:
	PlayerState.unlock_region(&"cave")
	PlayerState.currency = 1_000_000
	ShopManager.buy_contract(&"great_ball_discount")
	var d := PlayerState.to_save_dict()
	assert_array(d.shop_unlocks).contains_exactly(["great_ball_discount"])
	PlayerState.reset()
	assert_bool(ShopManager.has_contract(&"great_ball_discount")).is_false()
	PlayerState.load_save_dict(d)
	assert_bool(ShopManager.has_contract(&"great_ball_discount")).is_true()
	# 알 수 없는 id·중복은 무시
	d["shop_unlocks"] = ["great_ball_discount", "great_ball_discount", "bogus"]
	PlayerState.load_save_dict(d)
	assert_array(PlayerState.shop_unlocks).contains_exactly(["great_ball_discount"])


func test_save_v2_migrates_to_v3_with_empty_contracts() -> void:
	assert_int(SaveManager.SAVE_VERSION).is_equal(3)
	var old := {"save_version": 2, "player": {"level": 5}, "currency": 10}
	var m := SaveManager.migrate(old)
	assert_int(int(m.save_version)).is_equal(3)
	assert_array(m.shop_unlocks).is_empty()
	PlayerState.load_save_dict(m)
	assert_array(PlayerState.shop_unlocks).is_empty()
	assert_int(PlayerState.level).is_equal(5)
