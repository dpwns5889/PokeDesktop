extends GdUnitTestSuite
## 지역 바닥 발판 (예전 풀숲 대신, 기획서 6.1, v0.37)


func _ground() -> BattleGround:
	var g: BattleGround = auto_free(BattleGround.new())
	add_child(g)
	return g


func test_sheet_has_nine_cells() -> void:
	var g := _ground()
	assert_bool(g.has_sheet()).is_true()
	assert_int(g.cell_count()).is_equal(9)


func test_region_picks_its_cell() -> void:
	var g := _ground()
	for r in GameData.all_regions():
		g.set_region(r)
		assert_int(g.index).is_equal(r.battle_ground)
		var at := g.texture as AtlasTexture
		assert_vector(at.region.size).is_equal(BattleGround.CELL)
		assert_vector(at.region.position).is_equal(Vector2(r.battle_ground % 3, r.battle_ground / 3) * BattleGround.CELL)
	g.set_region(GameData.get_region(&"waterside"))
	assert_int(g.index).is_equal(1)   # 물
	g.set_index(99)                   # 범위 밖 → 풀밭
	assert_int(g.index).is_equal(0)
	g.set_region(null)
	assert_int(g.index).is_equal(0)


func test_shaking_moves_sideways_and_stops_cleanly() -> void:
	var g := _ground()
	g.shaking = true
	var moved := false
	for i in 20:
		g._process(0.01)
		if g.offset.x != 0.0:
			moved = true
		assert_float(absf(g.offset.x)).is_less_equal(BattleGround.SHAKE_PX)
		assert_float(g.offset.y).is_equal(0.0)
	assert_bool(moved).is_true()
	g.shaking = false
	assert_vector(g.offset).is_equal(Vector2.ZERO)


func test_floating_rule() -> void:
	# 스프라이트가 떠 있는 종만 뜬다 — 비행 타입이어도 서 있으면 안 뜸 (v0.40)
	var Companion := preload("res://assets/scenes/main/companion.gd")
	for pair in [[16, false], [17, false], [21, false], [6, false], [149, false], [83, false], [84, false],
			[18, true], [22, true], [41, true], [12, true], [144, true], [151, true],
			[81, true], [92, true], [109, true], [19, false], [25, false], [94, false]]:
		assert_bool(Companion.is_floating(GameData.get_species(pair[0]))).override_failure_message(str(pair[0])).is_equal(pair[1])
