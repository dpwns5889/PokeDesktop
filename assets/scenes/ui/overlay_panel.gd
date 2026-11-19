class_name OverlayPanel
extends Panel
## 메인 창 안에서 장면을 덮는 패널의 공통 틀 (도감·보관함·지역·가방·상점 등). (기획서 6.2)
## 별도 OS 창을 쓰지 않는다. 위쪽 버튼 줄과 아래쪽 HUD 사이 영역을 덮는다.
##
## 하위 클래스: _panel_title() 로 제목, _build_content(content) 에서 내용을 만들고, refresh() 에서 다시 그린다.
## 하위 클래스는 _init 을 따로 두지 않는다(부모 _init 이 내용을 만든다).

signal closed
## 확인 창이 필요할 때 (메인 창이 ConfirmPanel 로 띄운다)
signal confirm_requested(title_text: String, message: String, ok_text: String, on_ok: Callable)
## 다른 패널로 바꿔 달라는 요청 (예: 가방 → 보관함)
signal open_requested(panel_id: StringName)

## 패널이 덮는 영역 (기준 해상도). 메인 창(companion)의 레이아웃과 맞춘다.
const AREA := Rect2(0, 18, 320, 163)   # 위 버튼 줄 18px, 아래 HUD 19px

## 팝업(확인 창·포획 정보·원정 보상)의 확인 버튼 아래 여백 (v0.58 확인 창, v0.91 모든 팝업). 아래 HUD의 경험치 바와 닿지 않게
const POPUP_BOTTOM_GAP := 18

var content: VBoxContainer
var _title_label: Label
var _header_row: HBoxContainer


func _init() -> void:
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_STOP   # 아래 장면(드래그·포켓몬 클릭)으로 클릭이 새지 않게
	visible = false
	# 불투명 배경: 기본 Panel 스타일은 반투명이라 뒤 장면이 비친다
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.17, 0.23)
	bg.border_color = Color(0.11, 0.2, 0.38)
	bg.border_width_left = 1
	bg.border_width_right = 1
	add_theme_stylebox_override(&"panel", bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 4
	root.offset_right = -4
	root.offset_top = 2
	root.offset_bottom = -2
	root.add_theme_constant_override(&"separation", 2)
	add_child(root)

	var header := HBoxContainer.new()
	_header_row = header
	root.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close := Button.new()
	close.name = "Close"
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	header.add_child(close)

	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 2)
	root.add_child(content)
	_build_content(content)


func _ready() -> void:
	_title_label.text = _panel_title()
	EventBus.game_reset.connect(_refresh_if_visible)


func open_panel() -> void:
	show()
	refresh()


func close_panel() -> void:
	if visible:
		hide()
		closed.emit()


## 팝업 맨 아래(버튼 줄 다음)에 여백을 붙인다 (v0.91). 반환: 여백 Control
func add_popup_bottom_gap(box: VBoxContainer, height: int = POPUP_BOTTOM_GAP) -> Control:
	var gap := Control.new()
	gap.name = "BottomGap"
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	return gap


## 제목 줄(닫기 버튼 왼쪽)에 버튼을 추가한다.
func add_header_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_header_row.add_child(b)
	_header_row.move_child(b, _header_row.get_child_count() - 2)
	return b


## 하위 클래스에서 구현
func _panel_title() -> String:
	return ""


## 하위 클래스에서 구현
func _build_content(_box: VBoxContainer) -> void:
	pass


## 하위 클래스에서 구현
func refresh() -> void:
	pass


func _refresh_if_visible() -> void:
	if visible:
		refresh()
