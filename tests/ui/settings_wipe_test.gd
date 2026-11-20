extends GdUnitTestSuite
## 설정 맨 아래 "저장된 데이터 삭제" 버튼 (기획서 6.3, v0.96)

const SettingsPanel := preload("res://assets/scenes/ui/settings_panel.gd")


func test_wipe_button_asks_confirm_and_only_wipes_on_ok() -> void:
	var panel: SettingsPanel = auto_free(SettingsPanel.new())
	add_child(panel)
	var got: Array = []
	panel.confirm_requested.connect(func(t: String, _m: String, ok: String, cb: Callable) -> void: got.append([t, ok, cb]))
	var wipe: Button = panel.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "저장된 데이터 삭제")[0]
	wipe.pressed.emit()
	assert_int(got.size()).is_equal(1)   # 누르면 확인 창만 요청, 아직 지우지 않음
	assert_str(got[0][1]).is_equal("삭제")
	assert_bool(got[0][2] == SaveManager.reset_save).is_true()
