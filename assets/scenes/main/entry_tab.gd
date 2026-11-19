class_name EntryTab
extends Control
## 엔트리 상자 접기/펴기 화살표 탭 (기획서 6.1, v0.47).
## 반투명 상자 위에 픽셀 삼각형을 그린다(폰트에 화살표 글자가 없어 직접 그림). 누르면 pressed.

signal pressed

const ARROW_COLOR := Color(0.92, 0.95, 1.0)
const ARROW_HOVER := Color(1.0, 0.85, 0.35)

## true = "◀"(접기), false = "▶"(펴기)
var pointing_left := true:
	set(v):
		pointing_left = v
		queue_redraw()
var style: StyleBox
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()   # 창 드래그로 넘기지 않는다
		pressed.emit()


func _draw() -> void:
	if style:
		draw_style_box(style, Rect2(Vector2.ZERO, size))
	# 높이 7px 삼각형 (정수 픽셀 줄로 그려 흐리지 않게)
	var c := ARROW_HOVER if _hover else ARROW_COLOR
	var cx := floorf(size.x / 2.0)
	var cy := floorf(size.y / 2.0)
	for i in 4:
		var h := 7 - i * 2   # 7, 5, 3, 1
		var x := cx - 2 + i if not pointing_left else cx + 1 - i
		draw_rect(Rect2(x, cy - floorf(h / 2.0), 1, h), c)
