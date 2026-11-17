class_name IconButton
extends Button
## 글자 대신 도형을 그리는 작은 버튼 (위 버튼 줄의 설정 톱니바퀴, 종료 X).
## 폰트에 없는 기호를 쓰지 않으려고 직접 그린다.

enum Kind { GEAR, CLOSE }

const SIZE := Vector2(18, 16)
const COLOR := Color(0.92, 0.94, 1.0)
const COLOR_PRESSED := Color(0.15, 0.1, 0.05)

var kind: Kind = Kind.GEAR


func _init(k: Kind = Kind.GEAR) -> void:
	kind = k
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "설정" if k == Kind.GEAR else "종료"


func _draw() -> void:
	var c := size / 2.0
	var color := COLOR_PRESSED if button_pressed else COLOR
	match kind:
		Kind.GEAR:
			# 톱니 8개 + 바깥 원 + 가운데 구멍
			var r_out := 6.0
			var r_in := 4.3
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				var r := r_out if i % 2 == 0 else r_in
				pts.append(c + Vector2.from_angle(a - TAU / 32.0) * r)
				pts.append(c + Vector2.from_angle(a + TAU / 32.0) * r)
			draw_colored_polygon(pts, color)
			var bg := get_theme_stylebox(&"pressed" if button_pressed else &"normal")
			var hole := Color(0.95, 0.75, 0.3) if button_pressed else Color(0.16, 0.3, 0.55)
			if bg is StyleBoxFlat:
				hole = (bg as StyleBoxFlat).bg_color
			draw_circle(c, 1.8, hole)
		Kind.CLOSE:
			var d := 4.5
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), color, 2.0)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), color, 2.0)
