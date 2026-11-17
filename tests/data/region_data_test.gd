extends GdUnitTestSuite
## 지역·전설 규칙 데이터 검증 (기획서 4.4, 4.5, 9.4).

const CONDITION_TYPES := ["player_level", "dex_caught_count", "species_caught", "type_caught_count", "region_unlocked"]


func test_nine_regions_in_order() -> void:
	var ids := GameData.region_ids()
	assert_array(ids).contains_exactly([&"grassland", &"forest", &"waterside", &"cave", &"power_plant",
		&"volcano", &"ghost_tower", &"snow_mountain", &"deep_cave"])
	var first := GameData.get_region(&"grassland")
	assert_array(first.unlock_conditions).is_empty()


func test_region_tables_are_valid() -> void:
	for r in GameData.all_regions():
		assert_int(r.encounters.size()).override_failure_message(r.id).is_greater(0)
		for e in r.encounters:
			var where := "%s: %d" % [r.id, e.dex_id]
			assert_bool(GameData.has_species(e.dex_id)).override_failure_message(where).is_true()
			assert_bool(GameData.get_species(e.dex_id).is_legendary).override_failure_message("전설은 일반 표에 넣지 않는다: " + where).is_false()
			assert_int(e.max_level).override_failure_message(where).is_less_equal(r.level_cap)
			assert_int(e.min_level).override_failure_message(where).is_less_equal(e.max_level)
		for c in r.unlock_conditions:
			assert_bool(CONDITION_TYPES.has(c.type)).override_failure_message("%s: %s" % [r.id, c]).is_true()


## 기획서 9.4: 모든 비전설 종은 어떤 지역 표에 있거나 진화로 얻을 수 있어야 한다.
func test_every_non_legendary_species_is_obtainable() -> void:
	var reach := _closure(_table_species(GameData.all_regions()))
	var missing: Array[String] = []
	for s in GameData.all_species():
		if not (s.is_legendary or s.is_mythical) and not reach.has(s.dex_id):
			missing.append("%d %s" % [s.dex_id, s.name_ko])
	assert_array(missing).is_empty()


## 각 지역의 해금 조건은 그보다 앞선 지역(+진화)만으로 달성할 수 있어야 한다 (막힘 방지).
func test_unlock_conditions_are_reachable_from_earlier_regions() -> void:
	var regions := GameData.all_regions()
	for i in regions.size():
		var earlier_tables := _table_species(regions.slice(0, i))
		var reach := _closure(earlier_tables)
		for c in regions[i].unlock_conditions:
			match c.type:
				"dex_caught_count":
					assert_int(reach.size()).override_failure_message("%s: 도감 %d 필요" % [regions[i].id, c.value]).is_greater_equal(c.value)
				"type_caught_count":
					var n := 0
					for id in earlier_tables:
						if GameData.get_species(id).types.has(StringName(c.type_id)):
							n += 1
					assert_int(n).override_failure_message("%s: %s %d 필요" % [regions[i].id, c.type_id, c.value]).is_greater_equal(c.value)


func test_legendary_rules_generated_for_all_legendaries() -> void:
	var rules := GameData.legendary_rules()
	var ids := rules.map(func(r: LegendaryRule) -> int: return r.dex_id)
	assert_array(ids).contains_exactly_in_any_order([144, 145, 146, 150, 151])
	for r in rules:
		assert_float(r.chance).is_equal(0.03)   # M10 밸런스
		for rid in r.region_ids:
			assert_object(GameData.get_region(rid)).override_failure_message("%d: 없는 지역 %s" % [r.dex_id, rid]).is_not_null()
		for c in r.conditions:
			assert_bool(CONDITION_TYPES.has(c.type)).is_true()
		var lv := 0
		for c in r.conditions:
			if c.type == "player_level":
				lv = c.value
		assert_int(lv).override_failure_message("%d: 플레이어 레벨 조건이 최대 레벨(40)을 넘음" % r.dex_id).is_between(1, 40)


func test_legendary_regions_match_main_type() -> void:
	var by_id := {}
	for r in GameData.legendary_rules():
		by_id[r.dex_id] = r
	assert_array(by_id[144].region_ids).contains_exactly([&"snow_mountain"])
	assert_array(by_id[145].region_ids).contains_exactly([&"power_plant"])
	assert_array(by_id[146].region_ids).contains_exactly([&"volcano"])
	assert_array(by_id[150].region_ids).contains_exactly([&"ghost_tower"])


func _table_species(regions: Array) -> Dictionary:
	var out := {}
	for r in regions:
		for e in r.encounters:
			out[e.dex_id] = true
	return out


func _closure(start: Dictionary) -> Dictionary:
	var out := start.duplicate()
	var changed := true
	while changed:
		changed = false
		for id in out.keys():
			for e in GameData.get_species(id).evolutions:
				if not out.has(e.to):
					out[e.to] = true
					changed = true
	return out


func test_battle_ground_index_valid() -> void:
	# 전투 바닥 번호는 시트 칸(0~8) 안 (v0.35). 초원은 풀밭(0), 물가는 물(1)
	for r in GameData.all_regions():
		assert_int(r.battle_ground).override_failure_message(String(r.id)).is_between(0, 8)
	assert_int(GameData.get_region(&"grassland").battle_ground).is_equal(0)
	assert_int(GameData.get_region(&"waterside").battle_ground).is_equal(1)
	assert_bool(ResourceLoader.exists("res://Assets/Generated/ui/ground.png")).is_true()
