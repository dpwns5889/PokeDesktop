extends GdUnitTestSuite
## 향로·특이한 향로 (기획서 4.11, v0.41)

const T0 := 2_000_000_000

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_items_exist_and_sold_in_shop() -> void:
	var inc := GameData.get_item(&"incense")
	var shiny := GameData.get_item(&"shiny_incense")
	assert_object(inc).is_not_null()
	assert_object(shiny).is_not_null()
	assert_bool(inc.can_buy()).is_true()
	assert_bool(shiny.can_buy()).is_true()
	assert_object(inc.load_icon()).is_not_null()
	assert_object(shiny.load_icon()).is_not_null()
	# 원정 보상에도 있다
	var found := {}
	for x in GameData.all_expeditions():
		for r in x.reward_table:
			found[String(r.item)] = true
	assert_bool(found.has("incense")).is_true()
	assert_bool(found.has("shiny_incense")).is_true()


func test_use_incense_needs_item_and_type() -> void:
	assert_str(PlayerState.use_incense(&"fire", T0)).contains("없습니다")
	PlayerState.add_item(&"incense", 2)
	assert_str(PlayerState.use_incense(&"", T0)).contains("타입")
	assert_str(PlayerState.use_incense(&"fire", T0)).is_empty()
	assert_int(PlayerState.item_count(&"incense")).is_equal(1)
	assert_str(String(PlayerState.incense_type(T0 + 10))).is_equal("fire")
	assert_int(PlayerState.item_seconds_left("incense", T0)).is_equal(1800)
	assert_dict(PlayerState.incense_type_weights(T0)).is_equal({&"fire": 2.0})
	# 30분 뒤 끝
	assert_str(String(PlayerState.incense_type(T0 + 1800))).is_empty()
	assert_dict(PlayerState.incense_type_weights(T0 + 1800)).is_empty()


func test_same_type_extends_other_type_replaces() -> void:
	PlayerState.add_item(&"incense", 3)
	PlayerState.use_incense(&"water", T0)
	PlayerState.use_incense(&"water", T0 + 600)   # 같은 타입: 이어서 30분
	assert_int(PlayerState.item_seconds_left("incense", T0 + 600)).is_equal(1800 * 2 - 600)
	PlayerState.use_incense(&"grass", T0 + 900)   # 다른 타입: 새로 30분
	assert_str(String(PlayerState.incense_type(T0 + 900))).is_equal("grass")
	assert_int(PlayerState.item_seconds_left("incense", T0 + 900)).is_equal(1800)


func test_shiny_incense_multiplies_rate_and_extends() -> void:
	assert_float(PlayerState.shiny_multiplier(T0)).is_equal(1.0)
	PlayerState.add_item(&"shiny_incense", 2)
	assert_str(PlayerState.use_shiny_incense(T0)).is_empty()
	assert_float(PlayerState.shiny_multiplier(T0 + 60)).is_equal(4.0)
	PlayerState.use_shiny_incense(T0 + 60)   # 연장
	assert_int(PlayerState.item_seconds_left("shiny_incense", T0 + 60)).is_equal(3600 - 60)
	assert_float(PlayerState.shiny_multiplier(T0 + 3600)).is_equal(1.0)
	# 확률: 1/512 × 4 = 1/128
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var n := 0
	for i in 128000:
		if Formulas.roll_shiny(rng, 4.0):
			n += 1
	assert_int(n).is_between(880, 1120)


func test_incense_raises_type_share_in_encounters() -> void:
	var region := GameData.get_region(&"forest")
	var share := func(weights: Dictionary) -> float:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var hit := 0
		for i in 3000:
			var e := EncounterLogic.roll_encounter(region, 40, rng, [], Callable(), weights)
			if GameData.get_species(e[&"dex_id"]).types.has(&"poison"):
				hit += 1
		return hit / 3000.0
	var base: float = share.call({})
	var boosted: float = share.call({&"poison": 2.0})
	assert_float(boosted).is_greater(base + 0.05)


func test_active_items_saved() -> void:
	PlayerState.add_item(&"incense", 1)
	PlayerState.use_incense(&"ghost", T0)
	var d = JSON.parse_string(JSON.stringify(PlayerState.to_save_dict()))
	PlayerState.reset()
	PlayerState.load_save_dict(d)
	assert_str(String(PlayerState.incense_type(T0 + 5))).is_equal("ghost")


func test_buff_line_shows_minutes_left() -> void:
	var now := int(Time.get_unix_time_from_system())
	PlayerState.add_item(&"incense", 1)
	PlayerState.use_incense(&"fire", now)
	var texts := EncounterManager.entry_buffs().map(func(b): return b.text)
	assert_array(texts).contains(["불꽃 향로 30분"])
