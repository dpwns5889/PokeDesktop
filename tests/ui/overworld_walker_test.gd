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
	assert_vector(w.foot_position()).is_equal(AREA.position)   # 영역 안으로 당겨짐
	w.step(1.0)
