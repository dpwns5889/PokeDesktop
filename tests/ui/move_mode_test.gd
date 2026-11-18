extends GdUnitTestSuite
## 창 옮기기 모드 (기획서 3.1·6.3, v0.60): 설정에서 켰을 때만 창을 끌 수 있다.

const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")


func after_test() -> void:
	WindowManager.move_mode = false


func test_move_mode_starts_off_and_settings_toggle_switches_it() -> void:
	assert_bool(WindowManager.move_mode).is_false()
	var p = auto_free(SettingsPanel.new())
	add_child(p)
	p.open_panel()
	assert_bool(p._move.button_pressed).is_false()
	var seen: Array[bool] = []
	var cb := func(on: bool) -> void: seen.append(on)
	WindowManager.move_mode_changed.connect(cb)
	p._move.button_pressed = true
	assert_bool(WindowManager.move_mode).is_true()
	p._move.button_pressed = false
	assert_bool(WindowManager.move_mode).is_false()
	WindowManager.move_mode_changed.disconnect(cb)
	assert_array(seen).contains_exactly([true, false])


func test_drag_is_gated_by_move_mode() -> void:
	# 배경 왼쪽 클릭으로 드래그를 시작하는 곳은 move_mode 조건이 붙어 있어야 한다
	var src := FileAccess.get_file_as_string("res://scenes/main/companion.gd")
	assert_str(src).contains("MOUSE_BUTTON_LEFT when WindowManager.move_mode:")
	assert_int(src.count("WindowManager.begin_drag()")).is_equal(1)
