extends GdUnitTestSuite
## WindowLayout 단위 테스트 (기획서 2.2, 3장).

# 1920×1080, 아래쪽 작업표시줄 48px
const FHD_USABLE := Rect2i(0, 0, 1920, 1032)


func test_auto_scale_by_screen_height() -> void:
	assert_int(WindowLayout.auto_scale(Vector2i(1366, 768))).is_equal(1)
	assert_int(WindowLayout.auto_scale(Vector2i(1920, 1080))).is_equal(2)
	assert_int(WindowLayout.auto_scale(Vector2i(2560, 1440))).is_equal(3)
	assert_int(WindowLayout.auto_scale(Vector2i(3840, 2160))).is_equal(3)


func test_clamp_scale_respects_range_and_screen() -> void:
	assert_int(WindowLayout.clamp_scale(0, FHD_USABLE)).is_equal(1)
	assert_int(WindowLayout.clamp_scale(9, FHD_USABLE)).is_equal(4)
	# 1000×450 화면에는 2배(896×400)까지만 들어간다 (v0.46: 기준 448×200)
	assert_int(WindowLayout.clamp_scale(4, Rect2i(0, 0, 1000, 450))).is_equal(2)
	assert_int(WindowLayout.clamp_scale(4, Rect2i(0, 0, 800, 450))).is_equal(1)


func test_bottom_left_above_bottom_taskbar() -> void:
	assert_vector(WindowLayout.bottom_left(FHD_USABLE, Vector2i(640, 240))).is_equal(Vector2i(0, 792))


func test_bottom_left_with_left_taskbar() -> void:
	# 왼쪽 작업표시줄 60px
	var usable := Rect2i(60, 0, 1860, 1080)
	assert_vector(WindowLayout.bottom_left(usable, Vector2i(640, 240))).is_equal(Vector2i(60, 840))


func test_bottom_left_on_secondary_monitor() -> void:
	var usable := Rect2i(1920, -200, 1280, 1024)
	assert_vector(WindowLayout.bottom_left(usable, Vector2i(320, 120))).is_equal(Vector2i(1920, 704))


func test_clamp_into_pulls_window_back_on_screen() -> void:
	var size := Vector2i(640, 240)
	assert_vector(WindowLayout.clamp_into(Vector2i(1800, 1000), size, FHD_USABLE)).is_equal(Vector2i(1280, 792))
	assert_vector(WindowLayout.clamp_into(Vector2i(-50, -50), size, FHD_USABLE)).is_equal(Vector2i(0, 0))
	assert_vector(WindowLayout.clamp_into(Vector2i(100, 100), size, FHD_USABLE)).is_equal(Vector2i(100, 100))


func test_dock_is_bottom_right_above_taskbar() -> void:
	assert_vector(WindowLayout.dock_position(FHD_USABLE, Vector2i(640, 400))).is_equal(Vector2i(1280, 632))
	# 오른쪽 작업표시줄 60px
	assert_vector(WindowLayout.dock_position(Rect2i(0, 0, 1860, 1080), Vector2i(640, 400))).is_equal(Vector2i(1220, 680))


func test_rescale_keeps_bottom_right_corner() -> void:
	var pos := WindowLayout.rescale_keep_bottom_right(Vector2i(1280, 632), Vector2i(640, 400), Vector2i(960, 600))
	assert_vector(pos).is_equal(Vector2i(960, 432))
	assert_vector(pos + Vector2i(960, 600)).is_equal(Vector2i(1920, 1032))


func test_near_dock_snaps() -> void:
	var size := Vector2i(640, 400)
	assert_bool(WindowLayout.is_near_dock(Vector2i(1275, 625), size, FHD_USABLE)).is_true()
	assert_bool(WindowLayout.is_near_dock(Vector2i(1240, 632), size, FHD_USABLE)).is_false()


func test_screen_index_for() -> void:
	var screens: Array[Rect2i] = [Rect2i(0, 0, 1920, 1032), Rect2i(1920, 0, 1920, 1032)]
	var size := Vector2i(640, 240)
	assert_int(WindowLayout.screen_index_for(Vector2i(100, 100), size, screens)).is_equal(0)
	assert_int(WindowLayout.screen_index_for(Vector2i(2000, 100), size, screens)).is_equal(1)
	# 두 화면에 걸치면 더 많이 겹치는 쪽
	assert_int(WindowLayout.screen_index_for(Vector2i(1800, 100), size, screens)).is_equal(1)
	# 일부만 화면 밖 → 그 화면 (안으로 보정 대상)
	var single: Array[Rect2i] = [Rect2i(0, 0, 1920, 1032)]
	assert_int(WindowLayout.screen_index_for(Vector2i(1700, 900), size, single)).is_equal(0)
	# 모니터를 뺀 뒤 남은 위치 → 어느 화면에도 없음
	assert_int(WindowLayout.screen_index_for(Vector2i(5000, 100), size, screens)).is_equal(-1)

