extends GdUnitTestSuite
## 행복의 알 (기획서 4.11, v0.61): 상점 5,000원, 쓰면 15분 동안 플레이어 경험치 ×1.5

const T0 := 2_000_000_000

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_item_is_shop_only_5000() -> void:
	var egg := GameData.get_item(&"lucky_egg")
	assert_object(egg).is_not_null()
	assert_str(egg.name_ko).is_equal("행복의 알")
	assert_bool(egg.can_buy()).is_true()
	assert_int(egg.buy_price).is_equal(5000)
	assert_array(egg.sources).contains_exactly([&"shop"])
	assert_object(egg.load_icon()).is_not_null()
	# 원정 보상에는 없다
	for x in GameData.all_expeditions():
		for r in x.reward_table:
			assert_str(String(r.item)).is_not_equal("lucky_egg")


func test_use_needs_item_and_lasts_15_min_and_extends() -> void:
	assert_str(PlayerState.use_lucky_egg(T0)).contains("없습니다")
	PlayerState.add_item(&"lucky_egg", 2)
	assert_str(PlayerState.use_lucky_egg(T0)).is_empty()
	assert_int(PlayerState.item_count(&"lucky_egg")).is_equal(1)
	assert_int(PlayerState.item_seconds_left("lucky_egg", T0)).is_equal(15 * 60)
	assert_float(PlayerState.player_exp_multiplier(T0)).is_equal(1.5)
	# 쓰는 중에 또 쓰면 15분 연장
	assert_str(PlayerState.use_lucky_egg(T0 + 60)).is_empty()
	assert_int(PlayerState.item_seconds_left("lucky_egg", T0 + 60)).is_equal(29 * 60)
	assert_float(PlayerState.player_exp_multiplier(T0 + 30 * 60)).is_equal(1.0)


func test_player_exp_is_multiplied_only_while_active() -> void:
	PlayerState.add_exp(10, T0)
	var base := PlayerState.experience
	assert_int(base).is_equal(10)
	PlayerState.add_item(&"lucky_egg", 1)
	PlayerState.use_lucky_egg(T0)
	PlayerState.add_exp(10, T0 + 1)
	assert_int(PlayerState.experience).is_equal(base + 15)
	PlayerState.add_exp(10, T0 + 15 * 60)   # 끝난 뒤
	assert_int(PlayerState.experience).is_equal(base + 25)


func test_saved_and_shown_as_buff() -> void:
	PlayerState.add_item(&"lucky_egg", 1)
	var now := int(Time.get_unix_time_from_system())
	PlayerState.use_lucky_egg(now)
	var d := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.load_save_dict(d)
	assert_int(PlayerState.item_seconds_left("lucky_egg", now)).is_equal(15 * 60)
	var texts := EncounterManager.active_buffs().map(func(b: Dictionary) -> String: return b.text)
	assert_array(texts).contains(["행복의 알 15분"])
