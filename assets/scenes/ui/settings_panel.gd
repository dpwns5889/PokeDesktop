extends OverlayPanel
## 설정 패널 (위 버튼 줄의 톱니바퀴). (기획서 6.3)
## 창: 항상 위에 표시, 전체화면 앱 실행 중 숨기기(v0.77), 창 옮기기(v0.60), 창 크기, 우하단으로 되돌리기 / 소리: 효과음 크기, 배경음 크기(M11), 인카운터 알림음
## 개발용 기능은 메인 창 우클릭 메뉴(디버그 빌드만)에 있다.

const SCALES := ["자동", "1배", "2배", "3배", "4배"]
const SECTION_INDENT := 10   ## 구역(창·소리·데이터) 아래 항목의 왼쪽 들여쓰기 px (기획서 6.3)

var _on_top: CheckButton
var _hide_fullscreen: CheckButton
var _move: CheckButton
var _scale: OptionButton
var _volume: HSlider
var _volume_label: Label
var _bgm_volume: HSlider
var _bgm_label: Label
var _encounter_sound: CheckButton
var _loading := false


func _panel_title() -> String:
	return "설정"


func _build_content(box: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 3)
	scroll.add_child(list)

	var sec := _section(list, "창")
	_on_top = CheckButton.new()
	_on_top.text = "항상 위에 표시"
	_on_top.focus_mode = Control.FOCUS_NONE
	_on_top.toggled.connect(func(on: bool) -> void:
		if not _loading:
			WindowManager.set_always_on_top(on))
	sec.add_child(_on_top)
	_hide_fullscreen = CheckButton.new()
	_hide_fullscreen.text = "전체화면 앱 실행 중 숨기기"
	_hide_fullscreen.focus_mode = Control.FOCUS_NONE
	_hide_fullscreen.tooltip_text = "게임·영상을 전체화면으로 볼 때 창을 숨긴다 (항상 위에 표시가 켜져 있을 때)"
	_hide_fullscreen.toggled.connect(func(on: bool) -> void:
		if not _loading:
			Settings.set_value(&"hide_on_fullscreen", on))
	sec.add_child(_hide_fullscreen)

	var scale_row := _row(sec, "창 크기")
	_scale = OptionButton.new()
	_scale.focus_mode = Control.FOCUS_NONE
	for s in SCALES:
		_scale.add_item(s)
	_scale.item_selected.connect(func(i: int) -> void:
		if not _loading:
			WindowManager.set_scale(i))   # 0 = 자동, 1~4 = 배율
	scale_row.add_child(_scale)

	# 창 옮기기 (v0.60): 켜면 화면 빈 곳을 잡고 창을 끌 수 있다. 끄면 드래그 안 됨
	_move = CheckButton.new()
	_move.text = "창 옮기기 (켜면 화면을 잡고 끌기)"
	_move.focus_mode = Control.FOCUS_NONE
	_move.toggled.connect(func(on: bool) -> void:
		if not _loading:
			WindowManager.move_mode = on)
	sec.add_child(_move)

	var reset := Button.new()
	reset.text = "우하단으로 되돌리기"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(WindowManager.reset_position)
	sec.add_child(reset)

	sec = _section(list, "소리")
	var vol_row := _row(sec, "효과음 크기")
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.custom_minimum_size.x = 100
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.value_changed.connect(_on_volume_changed)
	_volume.drag_ended.connect(func(_changed: bool) -> void:
		Settings.save_settings()
		AudioManager.play(&"button_click"))   # 바뀐 크기로 들려준다
	vol_row.add_child(_volume)
	_volume_label = Label.new()
	_volume_label.custom_minimum_size.x = 40
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol_row.add_child(_volume_label)

	var bgm_row := _row(sec, "배경음 크기")
	_bgm_volume = HSlider.new()
	_bgm_volume.min_value = 0
	_bgm_volume.max_value = 100
	_bgm_volume.step = 5
	_bgm_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgm_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bgm_volume.custom_minimum_size.x = 100
	_bgm_volume.focus_mode = Control.FOCUS_NONE
	_bgm_volume.value_changed.connect(func(v: float) -> void:
		_bgm_label.text = "%d%%" % int(v)
		if not _loading:
			Settings.set_value(&"bgm_volume", v / 100.0, false))   # 끄는 동안 바로 들리게, 저장은 놓을 때
	_bgm_volume.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	bgm_row.add_child(_bgm_volume)
	_bgm_label = Label.new()
	_bgm_label.custom_minimum_size.x = 40
	_bgm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_row.add_child(_bgm_label)

	_encounter_sound = CheckButton.new()
	_encounter_sound.text = "인카운터 알림음"
	_encounter_sound.focus_mode = Control.FOCUS_NONE
	_encounter_sound.toggled.connect(func(on: bool) -> void:
		if not _loading:
			Settings.set_value(&"encounter_sound", on))
	sec.add_child(_encounter_sound)

	# 저장된 데이터 삭제 (v0.96): 확인 창을 한 번 거친다 (기획서 6.3)
	sec = _section(list, "데이터")
	var wipe := Button.new()
	wipe.text = "저장된 데이터 삭제"
	wipe.focus_mode = Control.FOCUS_NONE
	wipe.add_theme_color_override(&"font_color", Color(0.85, 0.1, 0.1))   # 확인 창 DANGER_COLOR 와 같음
	wipe.pressed.connect(_on_wipe)
	sec.add_child(wipe)



func _on_wipe() -> void:
	confirm_requested.emit("저장된 데이터 삭제",
		"저장된 진행을 모두 지웁니다.\n(레벨, 도감, 보관함, 아이템, 재화)\n설정(창 크기·소리 등)은 유지됩니다.\n되돌릴 수 없습니다. 계속할까요?",
		"삭제", SaveManager.reset_save)


func refresh() -> void:
	_loading = true
	_on_top.button_pressed = WindowManager.is_always_on_top()
	_move.button_pressed = WindowManager.move_mode
	_hide_fullscreen.button_pressed = bool(Settings.get_value(&"hide_on_fullscreen"))
	_scale.select(clampi(int(Settings.get_value(&"window_scale")), 0, SCALES.size() - 1))
	_volume.value = roundi(float(Settings.get_value(&"sfx_volume")) * 100.0)
	_volume_label.text = "%d%%" % int(_volume.value)
	_bgm_volume.value = roundi(float(Settings.get_value(&"bgm_volume")) * 100.0)
	_bgm_label.text = "%d%%" % int(_bgm_volume.value)
	_encounter_sound.button_pressed = bool(Settings.get_value(&"encounter_sound"))
	_loading = false


func _on_volume_changed(v: float) -> void:
	_volume_label.text = "%d%%" % int(v)
	if not _loading:
		Settings.set_value(&"sfx_volume", v / 100.0, false)   # 끌 때마다 파일에 쓰지 않음 (놓을 때 저장)


## 노란 구역 제목을 붙이고, 그 아래 항목을 왼쪽으로 들여 넣을 상자를 돌려준다 (기획서 6.3, v0.96)
func _section(parent: Control, text: String) -> VBoxContainer:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", Color(1, 0.85, 0.35))
	parent.add_child(l)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override(&"margin_left", SECTION_INDENT)
	parent.add_child(indent)
	var items := VBoxContainer.new()
	items.add_theme_constant_override(&"separation", 3)
	indent.add_child(items)
	return items


func _row(parent: Control, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 90
	row.add_child(l)
	return row

