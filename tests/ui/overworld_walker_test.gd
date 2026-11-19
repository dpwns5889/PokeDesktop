extends GdUnitTestSuite
## 메인 화면을 걸어다니는 엔트리 (기획서 6.1, M12 v0.45)

const AREA := Rect2(14, 48, 292, 132)


func _species(dex: int) -> PokemonSpecies:
	return GameData.get_species(dex)


func _walker(dex: int = 25, seed_value: int = 1) -> OverworldWalker:
	var w: OverworldWalker = auto_free(OverworldWalker.new())
	w.rng.seed = seed_value
	w.set_process(false)
	add_child(w)
	w.setup(PokemonSprites.overworld_walk_sheet(_species(dex)), null, AREA, AREA.get_center())
	return w


func test_all_species_have_walk_sheets() -> void:
	for dex in range(1, 152):
		var sheet := PokemonSprites.overworld_walk_sheet(_species(dex))
		assert_object(sheet).override_failure_message("걷기 시트 없음: %d" % dex).is_not_null()
		assert_vector(sheet.get_size()).is_equal(Vector2(64, 128))
	# 암컷 모습이 있는 종은 따로, 없는 종은 수컷 그림으로
	assert_str(PokemonSprites.overworld_walk_sheet(_species(25), true).resource_path).ends_with("0025_f.png")
	assert_str(PokemonSprites.overworld_walk_sheet(_species(1), true).resource_path).ends_with("0001.png")


func test_stays_inside_area_for_a_long_time() -> void:
	for seed_value in [1, 2, 3]:
		var w := _walker(143, seed_value)
		var moved := false
		var start := w.foot_position()
		for i in 6000:   # 0.05초 × 6000 = 5분
			w.step(0.05)
			var p := w.foot_position()
			assert_bool(AREA.grow(0.01).has_point(p)).override_failure_message("영역 밖: %s" % p).is_true()
			if p.distance_to(start) > 20:
				moved = true
		assert_bool(moved).is_true()


func test_faces_walking_direction() -> void:
	var w := _walker(1, 7)
	for i in 4000:
		w.step(0.05)
		if w.walking:
			var before := w.foot_position()
			w.step(0.1)
			var v := w.foot_position() - before
			if v.length() > 0.5:
				assert_int(OverworldWalker.dir_toward(v)).is_equal(w.dir)
				# 걷기 시트의 행 = 방향
				assert_int(w.current_frame() / 2).is_equal(w.dir)
				return
	fail("걷기 시작하지 않음")


func test_watching_stops_and_looks_at_point() -> void:
	var w := _walker(4, 3)
	var p := w.foot_position()
	w.set_watching(true, p + Vector2(100, 10))
	assert_int(w.dir).is_equal(OverworldWalker.Dir.RIGHT)
	for i in 400:
		w.step(0.05)
	assert_vector(w.foot_position()).is_equal(p)
	assert_bool(w.walking).is_false()
	w.set_watching(true, p + Vector2(0, -50))
	assert_int(w.dir).is_equal(OverworldWalker.Dir.UP)
	w.set_watching(false)
	var moved := false
	for i in 2000:
		w.step(0.05)
		if not w.foot_position().is_equal_approx(p):
			moved = true
			break
	assert_bool(moved).is_true()


func test_feet_offset_matches_sprite_bottom() -> void:
	var sheet := PokemonSprites.overworld_walk_sheet(_species(25))
	var feet := OverworldWalker.feet_offset(sheet)
	assert_float(feet).is_greater(16.0)
	assert_float(feet).is_less_equal(32.0)


func test_fallback_icon_without_sheet() -> void:
	var w: OverworldWalker = auto_free(OverworldWalker.new())
	add_child(w)
	var icon := UiUtil.pokemon_icon(_species(25))
	w.setup(null, icon, AREA, Vector2(0, 0))
	# 영역 안의 가장 가까운 칸 발 자리로 당겨짐 (v0.67: 칸 x 1 = 16+8, 칸 y 2 = 18+32+13)
	assert_vector(w.foot_position()).is_equal(Vector2(24, 63))
	assert_bool(AREA.has_point(w.foot_position())).is_true()
	w.step(1.0)


## v0.67: 들판 칸(16px)에 맞춰 칸 단위로 걷는다 — 멈춰 있을 때 발은 언제나 칸의 발 자리, 한 번에 칸 크기의 정수배만큼
func test_walks_tile_by_tile() -> void:
	for seed_value in [1, 2, 3]:
		var w := _walker(25, seed_value)
		var stops := 0
		var last_stop := w.foot_position()
		for i in 4000:
			w.step(0.05)
			if w.walking:
				continue
			var off := w.foot_position() - w.grid_origin - OverworldWalker.FOOT_IN_CELL
			assert_float(fposmod(off.x, OverworldWalker.GRID)).override_failure_message("칸에 안 맞음 %s" % off).is_equal(0.0)
			assert_float(fposmod(off.y, OverworldWalker.GRID)).override_failure_message("칸에 안 맞음 %s" % off).is_equal(0.0)
			var moved := w.foot_position() - last_stop
			if moved != Vector2.ZERO:
				assert_bool(moved.x == 0.0 or moved.y == 0.0).is_true()   # 곧게
				assert_float(fposmod(moved.length(), OverworldWalker.GRID)).is_equal(0.0)
				stops += 1
				last_stop = w.foot_position()
		assert_int(stops).is_greater(3)


## v0.91: 저장 초기화(game_reset)하면 엔트리 상자와 걸어다니는 포켓몬도 사라진다 (이전에는 그대로 남았다)
func test_game_reset_clears_walkers_and_entry_icons() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	var a := PlayerState.add_caught({&"dex_id": 25, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	PlayerState.entries = [a.uid] as Array[String]
	var main: Node = auto_free((load("res://assets/scenes/main/companion.tscn") as PackedScene).instantiate())
	add_child(main)
	await get_tree().process_frame
	main._refresh_entry_widgets()
	assert_int(main._walkers.get_child_count()).is_equal(1)
	assert_int(main._entry_icons.get_child_count()).is_equal(1)
	PlayerState.reset()   # SaveManager.reset_save 와 같은 순서: 상태를 비우고 game_reset
	EventBus.game_reset.emit()
	await get_tree().process_frame
	assert_int(main._walkers.get_child_count()).is_equal(0)
	assert_int(main._entry_icons.get_child_count()).is_equal(0)
	PlayerState.load_save_dict(snap)
