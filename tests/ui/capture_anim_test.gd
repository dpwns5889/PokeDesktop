extends GdUnitTestSuite
## 포획 연출 (기획서 4.3, v0.50)


func test_ball_frames_exist() -> void:
	for ball in [&"poke_ball", &"great_ball", &"ultra_ball", &"master_ball"]:
		var tex := CaptureAnim.ball_texture(ball)
		assert_object(tex).is_not_null()
		assert_vector(tex.get_size()).is_equal(Vector2(CaptureAnim.CELL.x * 10, CaptureAnim.CELL.y))
	# 모르는 볼은 몬스터볼 그림
	assert_str(CaptureAnim.ball_texture(&"unknown").resource_path).ends_with("poke_ball.png")


func test_plays_throw_absorb_three_shakes_then_finishes() -> void:
	var anim: CaptureAnim = auto_free(CaptureAnim.new())
	add_child(anim)
	var mon: Sprite2D = auto_free(Sprite2D.new())
	mon.position = Vector2(60, 60)
	add_child(mon)
	anim.play(&"great_ball", Vector2(0, 100), Vector2(60, 60), 100.0, mon)
	await assert_signal(anim).wait_until(int(CaptureAnim.total_sec() * 1000) + 3000).is_emitted("finished")
	# 포켓몬은 볼 속으로 사라지고 크기·색은 원래대로 돌려 둔다 (다음 등장 때 그대로 쓰도록)
	assert_bool(mon.visible).is_false()
	assert_vector(mon.scale).is_equal(Vector2.ONE)
	assert_float(mon.modulate.a).is_equal(1.0)
	# 볼은 발판 위(rest_y)에 정면 모습으로 남는다
	assert_float(anim._ball.position.y).is_equal_approx(100.0, 0.01)
	assert_int(anim._ball.frame).is_equal(CaptureAnim.FRONT_FRAME)
	assert_int(CaptureAnim.FRONT_FRAME).is_equal(0)   # 똑바로 선 모습 (8번은 납작해진 모습)
	assert_float(anim._ball.rotation).is_equal_approx(0.0, 0.001)
	anim.clear()
	assert_bool(anim._ball.visible).is_false()


func test_catch_stars_fly_out_from_ball() -> void:
	# 별 3개: 볼 꼭대기(0,0)에서 시작해 왼쪽 위·위·오른쪽 위로 날아간다
	var S := CaptureAnim.CatchStars
	assert_int(S.VELOCITIES.size()).is_equal(3)
	for i in 3:
		assert_vector(S.star_pos(i, 0.0)).is_equal(Vector2.ZERO)
	var t := S.LIFE_SEC * 0.5
	assert_float(S.star_pos(0, t).x).is_less(-5.0)
	assert_float(absf(S.star_pos(1, t).x)).is_less(0.01)
	assert_float(S.star_pos(2, t).x).is_greater(5.0)
	for i in 3:
		assert_float(S.star_pos(i, t).y).is_less(-5.0)
	# 하얀색에 가까운 연노란색
	assert_float(S.COL_FILL.r).is_greater(0.95)
	assert_float(S.COL_FILL.b).is_between(0.6, 0.95)


## v0.73: 별은 무작위 방향으로 돈다. 돌린 모양도 빈틈 없이 원래와 비슷한 칸 수
func test_catch_stars_spin_random_direction() -> void:
	var S := CaptureAnim.CatchStars
	var base := S.rotated_pixels(0.0)
	assert_int(base.size()).is_equal(64)   # SHAPE 의 X 개수 그대로
	for a in [0.4, 1.3, 2.7]:
		var n := S.rotated_pixels(a).size()
		assert_int(n).is_between(54, 76)
	assert_bool(S.rotated_pixels(0.6) == base).is_false()
	# 여러 번 만들면 시계·반시계가 모두 나온다
	var signs := {}
	for k in 20:
		var st = auto_free(S.new())
		add_child(st)
		assert_int(st.spins.size()).is_equal(3)
		for v in st.spins:
			assert_float(absf(v)).is_between(S.SPIN_MIN, S.SPIN_MAX)
			signs[signf(v)] = true
	assert_int(signs.size()).is_equal(2)
