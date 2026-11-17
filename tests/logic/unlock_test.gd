extends GdUnitTestSuite
## 해금 조건 평가, 지역 해금, 전설 출현 (기획서 4.4, 4.5).

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _catch(dex_id: int) -> void:
	PlayerState.add_caught({&"dex_id": dex_id, &"level": 5, &"gender": &"male", &"shiny": false, &"region": &"grassland"})


func _rng(seed := 11) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_condition_types() -> void:
	PlayerState.level = 5
	_catch(16)
	_catch(81)
	_catch(25)
	assert_bool(UnlockManager.evaluate([{"type": "player_level", "value": 5}])).is_true()
	assert_bool(UnlockManager.evaluate([{"type": "player_level", "value": 6}])).is_false()
	assert_bool(UnlockManager.evaluate([{"type": "dex_caught_count", "value": 3}])).is_true()
	assert_bool(UnlockManager.evaluate([{"type": "species_caught", "value": 25}])).is_true()
	assert_bool(UnlockManager.evaluate([{"type": "species_caught", "value": 26}])).is_false()
	assert_bool(UnlockManager.evaluate([{"type": "type_caught_count", "type_id": "electric", "value": 2}])).is_true()
	assert_bool(UnlockManager.evaluate([{"type": "type_caught_count", "type_id": "electric", "value": 3}])).is_false()
	assert_bool(UnlockManager.evaluate([{"type": "region_unlocked", "value": "grassland"}])).is_true()
	# AND
	assert_bool(UnlockManager.evaluate([{"type": "player_level", "value": 5}, {"type": "dex_caught_count", "value": 4}])).is_false()


func test_progress_reports_current_and_target() -> void:
	_catch(16)
	var p := UnlockManager.progress({"type": "dex_caught_count", "value": 10})
	assert_int(p.current).is_equal(1)
	assert_int(p.target).is_equal(10)
	assert_str(p.label).contains("10")


func test_forest_unlocks_at_player_level_3() -> void:
	var unlocked: Array = []
	var cb := func(id: StringName) -> void: unlocked.append(id)
	EventBus.region_unlocked.connect(cb)
	PlayerState.level = 2
	assert_array(UnlockManager.check_regions()).is_empty()
	PlayerState.level = 3
	var newly := UnlockManager.check_regions()
	EventBus.region_unlocked.disconnect(cb)
	assert_array(newly).contains_exactly([&"forest"])
	assert_array(unlocked).contains_exactly([&"forest"])
	assert_bool(PlayerState.unlocked_regions.has(&"forest")).is_true()


func test_waterside_needs_level_and_dex() -> void:
	PlayerState.level = 6
	UnlockManager.check_regions()
	assert_bool(PlayerState.unlocked_regions.has(&"waterside")).is_false()
	for id in [10, 11, 13, 14, 16, 19, 21, 29, 32, 39]:
		_catch(id)
	UnlockManager.check_regions()
	assert_bool(PlayerState.unlocked_regions.has(&"waterside")).is_true()


func test_catch_triggers_unlock_automatically() -> void:
	PlayerState.level = 6
	for id in [10, 11, 13, 14, 16, 19, 21, 29, 32]:
		_catch(id)
	assert_bool(PlayerState.unlocked_regions.has(&"waterside")).is_false()
	_catch(39)   # 10번째 → pokemon_caught → 자동 확인
	assert_bool(PlayerState.unlocked_regions.has(&"waterside")).is_true()


func test_cannot_move_to_locked_region() -> void:
	assert_bool(PlayerState.set_current_region(&"deep_cave")).is_false()
	assert_str(String(PlayerState.current_region)).is_equal("grassland")
	PlayerState.unlock_region(&"forest")
	assert_bool(PlayerState.set_current_region(&"forest")).is_true()
	assert_str(String(PlayerState.current_region)).is_equal("forest")


# ---------------------------------------------------------------- 전설

func _rule(dex_id: int, region: StringName, chance := 0.01) -> LegendaryRule:
	var r := LegendaryRule.new()
	r.dex_id = dex_id
	r.chance = chance
	r.level = 50
	r.region_ids = [region] as Array[StringName]
	r.conditions = [{"type": "player_level", "value": 25}] as Array[Dictionary]
	return r


func test_legendary_chance_about_one_percent_when_conditions_met() -> void:
	PlayerState.level = 30
	var region := GameData.get_region(&"snow_mountain")
	var rules: Array[LegendaryRule] = [_rule(144, &"snow_mountain")]
	var rng := _rng()
	var hits := 0
	for i in 20000:
		var enc := EncounterLogic.roll_encounter(region, 30, rng, rules, UnlockManager.evaluate)
		if enc[&"legendary"]:
			hits += 1
			assert_int(enc[&"dex_id"]).is_equal(144)
			assert_int(enc[&"level"]).is_equal(50)
	assert_int(hits).is_between(150, 250)   # 기대 200


func test_no_legendary_when_conditions_not_met() -> void:
	PlayerState.level = 10
	var region := GameData.get_region(&"snow_mountain")
	var rules: Array[LegendaryRule] = [_rule(144, &"snow_mountain", 1.0)]
	assert_bool(EncounterLogic.roll_encounter(region, 10, _rng(), rules, UnlockManager.evaluate)[&"legendary"]).is_false()


func test_no_legendary_in_other_region() -> void:
	PlayerState.level = 30
	var region := GameData.get_region(&"grassland")
	var rules: Array[LegendaryRule] = [_rule(144, &"snow_mountain", 1.0)]
	assert_bool(EncounterLogic.roll_encounter(region, 30, _rng(), rules, UnlockManager.evaluate)[&"legendary"]).is_false()


func test_caught_legendary_gets_legend_trait_and_duplicates_allowed() -> void:
	var a := PlayerState.add_caught({&"dex_id": 150, &"level": 70, &"gender": &"none", &"region": &"ghost_tower"})
	var b := PlayerState.add_caught({&"dex_id": 150, &"level": 70, &"gender": &"none", &"region": &"ghost_tower"})
	assert_array(a.traits).contains(["legend"])   # 고정 특성 + 무작위 특성(M7)
	assert_str(b.uid).is_not_equal(a.uid)
	assert_int(PlayerState.dex[150].caught).is_equal(2)
	_catch(16)
	assert_bool(PlayerState.pokemon.back().traits.has("legend")).is_false()
