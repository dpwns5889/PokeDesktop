extends GdUnitTestSuite
## 종 데이터 검증 (기획서 4.5, 4.9, 7장). 데이터를 다시 생성한 뒤 반드시 통과해야 한다.

const VALID_EVO_ITEMS := [&"fire_stone", &"water_stone", &"thunder_stone", &"leaf_stone", &"moon_stone"]


func test_gen1_has_151_contiguous_species() -> void:
	assert_int(GameData.species_count()).is_equal(151)
	for id in range(1, 152):
		assert_bool(GameData.has_species(id)).override_failure_message("도감 %d 없음" % id).is_true()


func test_lookup_pikachu() -> void:
	var s := GameData.get_species(25)
	assert_str(s.name_ko).is_equal("피카츄")
	assert_array(s.types).contains_exactly([&"electric"])
	assert_bool(s.has_gender_sprites).is_true()


func test_fields_in_range() -> void:
	for s in GameData.all_species():
		var where := "%d %s" % [s.dex_id, s.name_ko]
		assert_str(s.name_ko).override_failure_message(where).is_not_empty()
		assert_int(s.catch_rate).override_failure_message(where).is_between(1, 255)
		assert_int(s.base_stats.size()).override_failure_message(where).is_equal(6)
		assert_int(s.types.size()).override_failure_message(where).is_between(1, 2)
		for t in s.types:
			assert_bool(GameData.type_ids().has(t)).override_failure_message("%s: 알 수 없는 타입 %s" % [where, t]).is_true()
		assert_bool(s.gender_ratio == -1.0 or (s.gender_ratio >= 0.0 and s.gender_ratio <= 1.0)) \
			.override_failure_message(where).is_true()


func test_evolutions_are_valid() -> void:
	for s in GameData.all_species():
		for e in s.evolutions:
			var where := "%d %s → %s" % [s.dex_id, s.name_ko, e]
			assert_bool(GameData.has_species(e.to)).override_failure_message(where).is_true()
			match e.method:
				&"level":
					assert_int(e.value).override_failure_message(where).is_between(2, 100)
				&"item":
					assert_bool(VALID_EVO_ITEMS.has(e.item)).override_failure_message(where).is_true()
				_:
					fail("알 수 없는 진화 방식: " + where)


func test_every_evolved_species_is_reachable() -> void:
	var targets := {}
	for s in GameData.all_species():
		for e in s.evolutions:
			targets[e.to] = true
	for s in GameData.all_species():
		if s.evo_stage > 0:
			assert_bool(targets.has(s.dex_id)).override_failure_message("%d %s 로 진화하는 방법 없음" % [s.dex_id, s.name_ko]).is_true()


func test_trade_evolutions_replaced_by_level() -> void:
	# 기획서 4.9: 윤겔라→후딘 36, 근육몬→괴력몬 40, 데구리→딱구리 40, 고우스트→팬텀 38
	var expected := {64: [65, 36], 67: [68, 40], 75: [76, 40], 93: [94, 38]}
	for from in expected:
		var e: Dictionary = GameData.get_species(from).evolutions[0]
		assert_int(e.to).is_equal(expected[from][0])
		assert_str(String(e.method)).is_equal("level")
		assert_int(e.value).is_equal(expected[from][1])


func test_eevee_branches_by_stone() -> void:
	var by_item := {}
	for e in GameData.get_species(133).evolutions:
		by_item[e.item] = e.to
	assert_dict(by_item).is_equal({&"water_stone": 134, &"thunder_stone": 135, &"fire_stone": 136})


func test_legendaries_have_legend_trait() -> void:
	var ids := GameData.legendaries().map(func(s: PokemonSpecies) -> int: return s.dex_id)
	assert_array(ids).contains_exactly([144, 145, 146, 150, 151])
	for s in GameData.legendaries():
		assert_array(s.fixed_trait_ids).contains_exactly([&"legend"])
