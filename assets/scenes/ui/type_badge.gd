class_name TypeBadge
extends Control
## 타입 하나를 대표 색 상자로 표시한다 (예: [불꽃]). 밝은 색 위에는 어두운 글자.

const HEIGHT := 16.0
const PAD := 4.0
const FONT_SIZE := 16
## 이 픽셀 폰트는 글자 오른쪽에 빈 칸 1px(자간)이 붙고, 계산한 기준선이 실제 글자보다 1px 아래다.
## 화면에서 잰 값으로 보정해 글자를 상자 정가운데에 둔다 (v0.24)
const TRAILING_SPACE := 1.0
const BASELINE_NUDGE := -1.0

var type_id: StringName = &""
var _text := ""


func setup(t: StringName) -> void:
	type_id = t
	_text = GameData.type_name(t)
	var font := get_theme_default_font()
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x if font else 32.0
	custom_minimum_size = Vector2(w - TRAILING_SPACE + PAD * 2.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if type_id == &"":
		return
	var c := UiUtil.type_color(type_id)
	var box := StyleBoxFlat.new()
	box.bg_color = c
	box.border_color = c.darkened(0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var text_color := Color(0.12, 0.12, 0.14) if c.get_luminance() > 0.55 else Color.WHITE
	# 상자가 최소 크기보다 넓게 늘어나도 글자가 가운데에 오도록 실제 크기로 위치를 잡는다
	var font := get_theme_default_font()
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x - TRAILING_SPACE
	var ascent := font.get_ascent(FONT_SIZE)
	var descent := font.get_descent(FONT_SIZE)
	var x := floorf((size.x - w) / 2.0)
	var baseline := floorf((size.y - (ascent + descent)) / 2.0 + ascent) + BASELINE_NUDGE
	draw_string(font, Vector2(x, baseline), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)
