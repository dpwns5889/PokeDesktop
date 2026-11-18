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
				assert_str(".*gpwTYhobv=|fOimcqQ").contains(row[x])
				var i := FieldMap.tile_index(rows, x, y)
				assert_int(i).is_between(0, FieldMap.COLUMNS - 1)


func test_nine_slice_and_tree_indices() -> void:
	var rows := [
		"...........",
		".pppp......",
		".pppp......",
		".pppp.YYYYY",
		"......YYYYY",
		"......YYYYY",
		"......YYYYY",
		"......YYYYY",
	]
	assert_int(FieldMap.tile_index(rows, 1, 1)).is_equal(6)        # 길 왼위
	assert_int(FieldMap.tile_index(rows, 2, 2)).is_equal(6 + 4)    # 길 가운데
	assert_int(FieldMap.tile_index(rows, 4, 3)).is_equal(6 + 8)    # 길 오아래
	# 한 그루 나무 Y = 3×4칸 (v0.64 Object.png). 가로는 3칸씩, 세로는 4칸씩 짝지음
	assert_int(FieldMap.COLUMNS).is_equal(100)   # 땅~덤불 35 + 나무 12 + 큰 바위 4 + 작은 나무 2 + 기계 6 + 상자 1 + 다리 6 + 꽃밭 4 + 물 위 돌 1 + 물 위 큰 바위 4 + 군락 16 + 군락 옆 8 + 풀 덤불 1
	assert_int(FieldMap.tile_index(rows, 6, 3)).is_equal(FieldMap.TREE)            # 나무 왼위
	assert_int(FieldMap.tile_index(rows, 8, 3)).is_equal(FieldMap.TREE + 2)        # 나무 오위
	assert_int(FieldMap.tile_index(rows, 9, 3)).is_equal(FieldMap.TREE)            # 둘째 나무 왼위
	assert_int(FieldMap.tile_index(rows, 7, 6)).is_equal(FieldMap.TREE + 3 * 3 + 1)   # 맨 아랫줄 가운데
	assert_int(FieldMap.tile_index(rows, 6, 7)).is_equal(FieldMap.TREE)            # 다섯째 줄 = 다음 나무 맨 윗줄
	# 맵 왼쪽·위 끝에 닿은 나무는 끝에 맞춰 잘린다: 위 2줄 = 나무의 3~4번째 줄, 왼쪽 1칸 = 3번째 열
	var edge := [
		"Y.....",
		"Y.....",
		"......",
	]
	assert_int(FieldMap.tile_index(edge, 0, 0)).is_equal(FieldMap.TREE + 2 * 3 + 2)
	assert_int(FieldMap.tile_index(edge, 0, 1)).is_equal(FieldMap.TREE + 3 * 3 + 2)


## v0.64: Object.png 의 물체 — 큰 바위 2×2, 작은 나무 1×2, 기계 3×2, 상자 1칸. 모두 못 지나감
func test_object_indices_and_blocking() -> void:
	var rows := [
		"......",
		".OOi..",
		".OOi.c",
		"mmm...",
		"mmm...",
	]
	assert_int(FieldMap.tile_index(rows, 1, 1)).is_equal(FieldMap.BOULDER)
	assert_int(FieldMap.tile_index(rows, 2, 2)).is_equal(FieldMap.BOULDER + 3)
	assert_int(FieldMap.tile_index(rows, 3, 1)).is_equal(FieldMap.SMALL_TREE)
	assert_int(FieldMap.tile_index(rows, 3, 2)).is_equal(FieldMap.SMALL_TREE + 1)
	assert_int(FieldMap.tile_index(rows, 5, 2)).is_equal(FieldMap.CRATE)
	assert_int(FieldMap.tile_index(rows, 1, 3)).is_equal(FieldMap.MACHINE + 1)
	assert_int(FieldMap.tile_index(rows, 2, 4)).is_equal(FieldMap.MACHINE + 3 + 2)
	for ch in ["T", "Y", "O", "i", "m", "c", "o", "b", "q", "Q"]:
		assert_bool(FieldMap.BLOCKED.has(ch)).override_failure_message("지나갈 수 있음: " + ch).is_true()
	var m: FieldMap = auto_free(FieldMap.new())
	add_child(m)
	m.set_region(&"power_plant")
	assert_bool(m.is_blocked(Vector2(16 * 7 + 4, 16 * 2 + 4))).is_true()   # 기계
	assert_bool(m.is_blocked(Vector2(16 * 14 + 4, 16 * 2 + 4))).is_true()  # 상자


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


## v0.64: 나무다리(가로·세로)·꽃밭. 다리 옆 물은 테두리 없이 이어진다
func test_bridge_and_flowers() -> void:
	var rows := [
		"..www.",
		".===w.",
		"..www.",
		".f..|.",
		"....|.",
	]
	assert_int(FieldMap.tile_index(rows, 1, 1)).is_equal(FieldMap.BRIDGE_H)       # 왼끝
	assert_int(FieldMap.tile_index(rows, 2, 1)).is_equal(FieldMap.BRIDGE_H + 1)   # 가운데
	assert_int(FieldMap.tile_index(rows, 3, 1)).is_equal(FieldMap.BRIDGE_H + 2)   # 오른끝
	assert_int(FieldMap.tile_index(rows, 4, 3)).is_equal(FieldMap.BRIDGE_V)       # 위끝
	assert_int(FieldMap.tile_index(rows, 4, 4)).is_equal(FieldMap.BRIDGE_V + 2)   # 아래끝
	assert_int(FieldMap.tile_index(rows, 1, 3)).is_between(FieldMap.FLOWERS, FieldMap.FLOWERS + FieldMap.FLOWER_KINDS - 1)
	# 다리 바로 위 물 (3,0): 아래가 다리라 아래 테두리(15+2*3+1)가 아닌 가운데 칸 (위는 맵 밖 = 이어진 물)
	assert_int(FieldMap.tile_index(rows, 3, 0)).is_equal(15 + 1 * 3 + 1)
	assert_bool(FieldMap.BLOCKED.has("=")).is_false()
	assert_bool(FieldMap.BLOCKED.has("f")).is_false()


## v0.64: 회색 돌은 물 위에만 (q 1칸, Q 2×2). 물로 보아 둘레 물에 테두리가 생기지 않는다
func test_gray_rocks_only_in_water() -> void:
	var rows := [
		"wwwww",
		"wqwQQ",
		"wwwQQ",
		"wwwww",
	]
	assert_int(FieldMap.tile_index(rows, 1, 1)).is_equal(FieldMap.WATER_ROCK)
	assert_int(FieldMap.tile_index(rows, 3, 1)).is_equal(FieldMap.WATER_BOULDER)
	assert_int(FieldMap.tile_index(rows, 4, 2)).is_equal(FieldMap.WATER_BOULDER + 3)
	assert_int(FieldMap.tile_index(rows, 1, 0)).is_equal(15 + 1 * 3 + 1)   # 돌 위 물 = 가운데 칸 (맵 밖도 물)
	# 실제 지도: q·Q 는 상하좌우가 모두 물(또는 같은 바위·맵 밖)인 칸에만
	for id in FieldMaps.MAPS:
		var m: Array = FieldMaps.MAPS[id]
		for y in m.size():
			for x in String(m[y]).length():
				if String(m[y])[x] in ["q", "Q"]:
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if ny < 0 or ny >= m.size() or nx < 0 or nx >= String(m[ny]).length():
							continue
						assert_str("wqQ=|").override_failure_message("%s (%d,%d) 회색 돌이 물 밖에 닿음" % [id, x, y]).contains(String(m[ny])[nx])


## v0.64: 여러 그루가 붙은 숲(T) = 나무 군락 그림. 두 칸 = 한 그루, 아래 끝이 밑동, 위로 몸통·꼭대기·겹친 부분을 되풀이
func test_tree_cluster_indices() -> void:
	var rows := [
		"TTTTT.",
		"TTTTT.",
		"TTTTT.",
		"TTTTT.",
		"......",
	]
	var at := func(x: int, y: int) -> int: return FieldMap.tile_index(rows, x, y) - FieldMap.CLUSTER
	# 가로: 0, 1, 2, 1, 2 (마지막 그루가 짝이 안 맞아 잘림) / 끝이 홀수 자리면 3
	assert_int(at.call(0, 3) % 4).is_equal(0)
	assert_int(at.call(1, 3) % 4).is_equal(1)
	assert_int(at.call(2, 3) % 4).is_equal(2)
	assert_int(at.call(3, 3) % 4).is_equal(1)
	assert_int(at.call(4, 3) % 4).is_equal(2)
	assert_int(FieldMap.tile_index(["TTTT"], 3, 0) - FieldMap.CLUSTER).is_equal(3 * 4 + 3)
	# 세로: 아래 끝 = 밑동(3), 위로 2, 1, 0, 2 …
	assert_int(at.call(0, 3) / 4).is_equal(3)
	assert_int(at.call(0, 2) / 4).is_equal(2)
	assert_int(at.call(0, 1) / 4).is_equal(1)
	assert_int(at.call(0, 0) / 4).is_equal(0)
	assert_bool(FieldMap.BLOCKED.has("T")).is_true()


## v0.64: 군락 양 끝 바로 옆 땅 칸 = 끝 나무의 잘린 잎 가장자리 (줄은 군락과 같게). 잘린 그루(열 2)로 끝나면 없음
func test_tree_cluster_sides() -> void:
	var rows := [
		".TTTT.",
		".TTTT.",
		"......",
	]
	var side := func(x: int, y: int) -> int: return FieldMap.tile_index(rows, x, y) - FieldMap.CLUSTER_SIDE
	assert_int(side.call(0, 1)).is_equal(3 * 2)       # 왼쪽 옆, 밑동 줄
	assert_int(side.call(5, 1)).is_equal(3 * 2 + 1)   # 오른쪽 옆, 밑동 줄
	assert_int(side.call(0, 0)).is_equal(2 * 2)       # 왼쪽 옆, 몸통 줄
	assert_int(FieldMap.tile_index(rows, 0, 2)).is_less(FieldMap.CLUSTER)   # 군락 옆이 아닌 땅
	# 홀수 폭: 마지막 칸이 잘린 그루(열 2) → 오른쪽 옆 칸 없음
	assert_int(FieldMap.tile_index([".TTT."], 4, 0)).is_less(FieldMap.CLUSTER)
	assert_bool(FieldMap.BLOCKED.has(".")).is_false()


## v0.64: 풀 덤불 v 는 지나갈 수 있고, 덤불 b 는 못 지나감
func test_leaf_bush_passable() -> void:
	assert_int(FieldMap.tile_index(["v"], 0, 0)).is_equal(FieldMap.LEAF_BUSH)
	assert_bool(FieldMap.BLOCKED.has("v")).is_false()
	assert_bool(FieldMap.BLOCKED.has("b")).is_true()
