extends GdUnitTestSuite
## 지역별 게이지 배율 (기획서 4.3·4.4, v0.63): 후반 지역일수록 과녁 한 번에 덜 찬다

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_fill_decreases_with_region_order() -> void:
	var regions := GameData.all_regions()
	assert_float(regions[0].capture_fill).is_equal(1.0)   # 초원 = 기본
	for i in range(1, regions.size()):
		assert_float(regions[i].capture_fill).override_failure_message(String(regions[i].id)) \
			.is_less(regions[i - 1].capture_fill)
	assert_float(regions[-1].capture_fill).is_equal_approx(0.65, 0.0001)   # 깊은 동굴


func test_encounter_manager_uses_current_region() -> void:
	PlayerState.current_region = &"grassland"
	assert_float(EncounterManager.region_capture_fill()).is_equal(1.0)
	PlayerState.current_region = &"deep_cave"
	assert_float(EncounterManager.region_capture_fill()).is_equal_approx(0.65, 0.0001)
	# 하이퍼볼(×2)을 쓰면 깊은 동굴에서도 초원 몬스터볼보다 많이 찬다
	assert_float(2.0 * EncounterManager.region_capture_fill()).is_greater(1.0)


## v0.92: 발전소부터 뒤로 갈수록 몬스터볼로는 잡기 어렵다 (몬스터볼에만 추가 배율, 슈퍼볼·하이퍼볼은 그대로)
func test_poke_ball_extra_penalty_from_power_plant() -> void:
	var want := {&"grassland": 1.0, &"forest": 1.0, &"waterside": 1.0, &"cave": 1.0,
		&"power_plant": 0.9, &"volcano": 0.8, &"ghost_tower": 0.7, &"snow_mountain": 0.6, &"deep_cave": 0.5}
	for id in want:
		assert_float(GameData.get_region(id).poke_ball_fill).override_failure_message(String(id)) \
			.is_equal_approx(want[id], 0.0001)
	# 몬스터볼의 실제 배율(지역 배율 × 추가 배율)은 발전소부터 계속 내려간다
	var prev := 1.0
	for r in GameData.all_regions():
		var eff := r.capture_fill * r.poke_ball_fill
		assert_float(eff).override_failure_message(String(r.id)).is_less_equal(prev)
		prev = eff
	assert_float(prev).is_equal_approx(0.325, 0.0001)   # 깊은 동굴 몬스터볼


func test_region_capture_fill_by_ball() -> void:
	PlayerState.current_region = &"deep_cave"
	assert_float(EncounterManager.region_capture_fill(&"poke_ball")).is_equal_approx(0.65 * 0.5, 0.0001)
	assert_float(EncounterManager.region_capture_fill(&"great_ball")).is_equal_approx(0.65, 0.0001)   # 슈퍼볼은 추가 감소 없음
	assert_float(EncounterManager.region_capture_fill(&"ultra_ball")).is_equal_approx(0.65, 0.0001)
	assert_float(EncounterManager.region_capture_fill()).is_equal_approx(0.65, 0.0001)
	# 슈퍼볼(×1.5)은 깊은 동굴에서 초원 몬스터볼에 가깝고, 몬스터볼은 초원의 약 1/3
	assert_float(1.5 * EncounterManager.region_capture_fill(&"great_ball")).is_equal_approx(0.975, 0.0001)
	PlayerState.current_region = &"grassland"
	assert_float(EncounterManager.region_capture_fill(&"poke_ball")).is_equal(1.0)   # 초원은 그대로
