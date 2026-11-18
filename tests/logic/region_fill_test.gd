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
