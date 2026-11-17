extends GdUnitTestSuite
## 왼쪽 들판 타일맵 (기획서 6.1, v0.48)


func test_every_region_has_sheet_and_map() -> void:
	for r in GameData.all_regions():
		var id: StringName = r.id
		var path := FieldMap.SHEET % id
		assert_bool(ResourceLoader.exists(path)).override_failure_message("타일 그림 없음: " + path).is_true()
		var tex: Texture2D = load(path)
		assert_vector(tex.get_size()).is_equal(Vector2(FieldMap.TILE * FieldMap.COLUMNS, FieldMap.TILE))
		assert_bool(FieldMaps.MAPS.has(id)).override_failure_message("배치 없음: %s" % id).is_true()


func test_maps_are_well_formed() -> void:
	for id in FieldMaps.MAPS:
		var rows: Array = FieldMaps.MAPS[id]
		assert_int(rows.size()).is_equal(FieldMaps.ROWS)
		for y in rows.size():
			var row: String = rows[y]
			assert_int(row.length()).override_failure_message("%s %d줄 길이" % [id, y]).is_equal(FieldMaps.COLS)
			for x in row.length():
				assert_str(".*gpwThob").contains(row[x])
				var i := FieldMap.tile_index(rows, x, y)
				assert_int(i).is_between(0, FieldMap.COLUMNS - 1)


func test_nine_slice_and_tree_indices() -> void:
	var rows := [
		"..........",
		".pppp.....",
		".pppp.....",
		".pppp.TTTT",
		"......TTTT",
		"......TTTT",
		"......TTTT",
	]
	assert_int(FieldMap.tile_index(rows, 1, 1)).is_equal(6)        # 길 왼위
	assert_int(FieldMap.tile_index(rows, 2, 2)).is_equal(6 + 4)    # 길 가운데
	assert_int(FieldMap.tile_index(rows, 4, 3)).is_equal(6 + 8)    # 길 오아래
	assert_int(FieldMap.tile_index(rows, 6, 3)).is_equal(35)       # 나무 왼위
	assert_int(FieldMap.tile_index(rows, 9, 3)).is_equal(35 + 3)   # 나무 오위
	assert_int(FieldMap.tile_index(rows, 9, 6)).is_equal(35 + 15)  # 나무 오아래
	# 맵 왼쪽·위 끝에 닿은 나무는 끝에 맞춰 잘린다: 위 3줄 = 나무의 2~4번째 줄, 왼쪽 2칸 = 3~4번째 열
	var edge := [
		"TT....",
		"TT....",
		"TT....",
		"......",
	]
	assert_int(FieldMap.tile_index(edge, 0, 0)).is_equal(35 + 1 * 4 + 2)
	assert_int(FieldMap.tile_index(edge, 1, 2)).is_equal(35 + 3 * 4 + 3)


func test_blocked_cells() -> void:
	var m: FieldMap = auto_free(FieldMap.new())
	add_child(m)
	assert_bool(m.set_region(&"waterside")).is_true()
	assert_bool(m.is_blocked(Vector2(2, 2))).is_true()          # 나무 (0,0)
	assert_bool(m.is_blocked(Vector2(16 * 13 + 4, 16 * 3 + 4))).is_true()   # 물
	assert_bool(m.is_blocked(Vector2(16 * 6 + 4, 16 * 3 + 4))).is_false()   # 땅
	assert_bool(m.is_blocked(Vector2(16 * 8 + 4, 16 * 4 + 4))).is_false()   # 풀숲은 지나감
	assert_bool(m.is_blocked(Vector2(-3, 40))).is_true()        # 맵 밖


func test_walker_never_enters_blocked_cells() -> void:
	var m: FieldMap = auto_free(FieldMap.new())
	add_child(m)
	m.set_region(&"forest")
	var area := Rect2(14, 30, 292, 132)
	for seed_value in [1, 2, 3, 4]:
		var w: OverworldWalker = auto_free(OverworldWalker.new())
		w.rng.seed = seed_value
		w.set_process(false)
		w.blocked = m.is_blocked
		add_child(w)
		w.setup(PokemonSprites.overworld_walk_sheet(GameData.get_species(25)), null, area, area.get_center())
		w.relocate_if_blocked()
		assert_bool(w.is_blocked_at(w.foot_position())).is_false()
		for i in 4000:
			w.step(0.05)
			assert_bool(m.is_blocked(w.foot_position())).override_failure_message("막힌 칸에 들어감: %s" % w.foot_position()).is_false()
