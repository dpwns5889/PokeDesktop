extends GdUnitTestSuite
## CaptureGame (과녁 클릭 포획 규칙) 테스트. (기획서 4.3)

const FIELD := Rect2(0, 0, 320, 104)


func _game(params := {}, seed := 1) -> CaptureGame:
	var p := Formulas.capture_params(255, 5, false, 1.0)
	p.merge(params, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return CaptureGame.new(p, FIELD, rng)


## 과녁이 하나 나올 때까지 시간을 진행한다.
func _spawn_one(g: CaptureGame) -> Dictionary:
	for i in 40:
		if not g.targets.is_empty():
			break
		g.update(0.05)
	assert_int(g.targets.size()).is_greater(0)
	return g.targets[0]


func test_difficulty_scales_with_catch_rate_and_level() -> void:
	var easy := Formulas.capture_difficulty(255, 2, false)
	var hard := Formulas.capture_difficulty(3, 50, false)
	assert_float(easy).is_less(0.05)
	assert_float(hard).is_greater(0.8)
	assert_float(Formulas.capture_difficulty(3, 70, true)).is_equal(1.0)


func test_better_ball_fills_more() -> void:
	var poke := Formulas.capture_params(45, 10, false, 1.0)
	var ultra := Formulas.capture_params(45, 10, false, 2.0)
	assert_float(ultra[&"fill"]).is_equal_approx(poke[&"fill"] * 2.0, 0.0001)


func test_target_spawns_inside_playfield() -> void:
	var g := _game()
	for i in 50:
		g.update(0.1)
		for t in g.targets:
			assert_bool(FIELD.has_point(t.pos)).is_true()


func test_targets_never_cover_avoided_area() -> void:
	var pokemon := Rect2(200, 20, 72, 76)
	var avoid: Array[Rect2] = [pokemon]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var g := CaptureGame.new(Formulas.capture_params(255, 5, false, 1.0), FIELD, rng, avoid)
	var spawned := 0
	for i in 400:
		g.update(0.05)
		for t in g.targets:
			spawned += 1
			# 과녁 원 전체가 포켓몬 영역 밖
			assert_bool(pokemon.grow(g.radius()).has_point(t.pos)).is_false()
	assert_int(spawned).is_greater(0)


func test_hard_targets_are_smaller_and_faster() -> void:
	var easy := Formulas.capture_params(255, 3, false, 1.0)
	var hard := Formulas.capture_params(3, 50, true, 1.0)
	assert_float(hard[&"target_radius"]).is_less(easy[&"target_radius"])
	assert_float(hard[&"target_life"]).is_less_equal(0.6)
	assert_float(easy[&"target_life"]).is_greater(1.5)


func test_hit_center_gives_bonus_fill() -> void:
	var g := _game({&"decay_per_sec": 0.0})
	var t := _spawn_one(g)
	assert_int(g.click(t.pos)).is_equal(CaptureGame.HitResult.INNER_HIT)
	assert_float(g.gauge).is_equal_approx(Formulas.CAPTURE_BASE_FILL * Formulas.CAPTURE_INNER_BONUS, 0.0001)


func test_hit_edge_gives_normal_fill() -> void:
	var g := _game({&"decay_per_sec": 0.0})
	var t := _spawn_one(g)
	assert_int(g.click(t.pos + Vector2(g.radius() * 0.9, 0))).is_equal(CaptureGame.HitResult.HIT)
	assert_float(g.gauge).is_equal_approx(Formulas.CAPTURE_BASE_FILL, 0.0001)
	assert_int(g.targets.size()).is_equal(0)


func test_miss_click_applies_penalty() -> void:
	var g := _game({&"decay_per_sec": 0.0})
	g.gauge = 0.5
	assert_int(g.click(Vector2(-100, -100))).is_equal(CaptureGame.HitResult.MISS)
	assert_float(g.gauge).is_equal_approx(0.5 - g._p[&"penalty"], 0.0001)


func test_expired_target_applies_penalty() -> void:
	var g := _game({&"decay_per_sec": 0.0, &"max_targets": 1})
	_spawn_one(g)
	g.gauge = 0.5
	g.update(g.life())   # 수명 끝
	assert_float(g.gauge).is_less(0.5)


func test_gauge_full_means_success() -> void:
	var g := _game({&"fill": 0.5, &"decay_per_sec": 0.0})
	for i in 2:
		var t := _spawn_one(g)
		g.click(t.pos + Vector2(g.radius() * 0.9, 0))
	assert_bool(g.is_finished()).is_true()
	assert_bool(g.is_success()).is_true()


func test_time_out_means_failure() -> void:
	var g := _game()
	for i in 220:
		g.update(0.1)
	assert_bool(g.is_finished()).is_true()
	assert_bool(g.is_success()).is_false()


func test_accurate_player_catches_easy_pokemon() -> void:
	# 중심 근처를 0.3초마다 누르는 플레이어는 쉬운 포켓몬(피죤 Lv3)을 시간 안에 잡는다
	var g := _game({}, 7)
	var t := 0.0
	while not g.is_finished():
		g.update(0.05)
		t += 0.05
		if fmod(t, 0.3) < 0.05 and not g.targets.is_empty():
			g.click(g.targets[0].pos)
	assert_bool(g.is_success()).is_true()
