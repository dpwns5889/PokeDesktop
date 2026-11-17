extends GdUnitTestSuite
## Formulas 단위 테스트. 기획서 4.8 표의 값과 일치해야 한다.


func test_exp_to_next() -> void:
	assert_int(Formulas.exp_to_next(1)).is_equal(60)
	assert_int(Formulas.exp_to_next(20)).is_equal(450)
	assert_int(Formulas.exp_to_next(50)).is_equal(1800)


func test_total_exp() -> void:
	assert_int(Formulas.total_exp(1)).is_equal(0)
	assert_int(Formulas.total_exp(2)).is_equal(60)
	assert_int(Formulas.total_exp(50)).is_equal(34900)
	assert_int(Formulas.total_exp(100)).is_equal(218600)


func test_transfer_candies_matches_design_table() -> void:
	assert_dict(Formulas.transfer_candies(5)).is_equal({&"exp_candy_m": 0, &"exp_candy_s": 2})
	assert_dict(Formulas.transfer_candies(20)).is_equal({&"exp_candy_m": 1, &"exp_candy_s": 0})   # M10: 비율 0.18
	assert_dict(Formulas.transfer_candies(50)).is_equal({&"exp_candy_m": 7, &"exp_candy_s": 8})


func test_transfer_candies_always_gives_something() -> void:
	var c := Formulas.transfer_candies(1)
	assert_int(c[&"exp_candy_m"] + c[&"exp_candy_s"]).is_greater(0)


func test_calc_stat() -> void:
	# 피카츄 Lv50: HP 35 → 35+50+10 = 95, 스피드 90 → 90+5 = 95
	assert_int(Formulas.calc_stat(35, 50, true)).is_equal(95)
	assert_int(Formulas.calc_stat(90, 50, false)).is_equal(95)
