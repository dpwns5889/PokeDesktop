extends GdUnitTestSuite
## 출현 결정 테스트. (기획서 4.2)


func _entry(dex: int, weight: int, lo: int, hi: int, min_player := 1) -> EncounterEntry:
	var e := EncounterEntry.new()
	e.dex_id = dex
	e.weight = weight
	e.min_level = lo
	e.max_level = hi
	e.min_player_level = min_player
	return e


func _rng(seed := 3) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_pick_respects_weights() -> void:
	var entries: Array[EncounterEntry] = [_entry(16, 90, 2, 5), _entry(25, 10, 2, 5)]
	var counts := {16: 0, 25: 0}
	var rng := _rng()
	for i in 2000:
		counts[EncounterLogic.pick_entry(entries, 1, rng).dex_id] += 1
	assert_int(counts[16]).is_between(1700, 1900)


func test_pick_filters_by_player_level() -> void:
	var entries: Array[EncounterEntry] = [_entry(16, 10, 2, 5), _entry(25, 10, 2, 5, 3)]
	var rng := _rng()
	for i in 200:
		assert_int(EncounterLogic.pick_entry(entries, 2, rng).dex_id).is_equal(16)
	var seen_pikachu := false
	for i in 200:
		if EncounterLogic.pick_entry(entries, 3, rng).dex_id == 25:
			seen_pikachu = true
	assert_bool(seen_pikachu).is_true()


func test_pick_returns_null_when_nothing_available() -> void:
	var entries: Array[EncounterEntry] = [_entry(25, 10, 2, 5, 10)]
	assert_object(EncounterLogic.pick_entry(entries, 1, _rng())).is_null()


func test_wild_level_rises_with_player_level_and_respects_cap() -> void:
	var e := _entry(16, 10, 3, 3)
	var rng := _rng()
	assert_int(Formulas.roll_wild_level(e, 0.2, 8, 1, rng)).is_equal(3)
	assert_int(Formulas.roll_wild_level(e, 0.2, 8, 20, rng)).is_equal(7)     # 3 + 4
	assert_int(Formulas.roll_wild_level(e, 0.2, 8, 40, rng)).is_equal(8)     # 상한
	assert_int(Formulas.roll_wild_level(e, 0.2, 2, 1, rng)).is_equal(3)      # 상한이 최소보다 작으면 최소


func test_gender_follows_ratio() -> void:
	var rng := _rng()
	assert_str(String(EncounterLogic.roll_gender(GameData.get_species(81), rng))).is_equal("none")     # 코일
	assert_str(String(EncounterLogic.roll_gender(GameData.get_species(29), rng))).is_equal("female")   # 니드런♀
	assert_str(String(EncounterLogic.roll_gender(GameData.get_species(32), rng))).is_equal("male")     # 니드런♂


func test_grassland_region_is_valid() -> void:
	var region := GameData.get_region(&"grassland")
	assert_object(region).is_not_null()
	assert_str(region.name_ko).is_equal("초원")
	assert_int(region.encounters.size()).is_greater(0)
	for e in region.encounters:
		assert_bool(GameData.has_species(e.dex_id)).is_true()
		assert_int(e.min_level).is_less_equal(e.max_level)
	var enc := EncounterLogic.roll_encounter(region, 1, _rng())
	assert_int(enc[&"level"]).is_between(2, region.level_cap)
