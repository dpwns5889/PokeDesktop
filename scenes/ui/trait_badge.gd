class_name TraitBadge
extends Control
## 특성 하나를 상자로 표시한다 (팰월드의 패시브 표시를 참고). (기획서 4.6)
## - 좋은 특성: 위쪽 화살표(^). 등급이 높을수록 화살표가 늘어난다(일반 1, 희귀 2, 전설 3).
##   테두리·화살표 색 (v0.54): 일반 = 회색, 희귀 = 파랑, 전설 = 주황→노랑 그라데이션
## - 나쁜 특성: 빨간 테두리 + 아래쪽 화살표(v).
## 마우스를 올리면 설명이 보인다.

const HEIGHT := 18.0
const CHEVRON_W := 7.0
const CHEVRON_GAP := 2.0
const POSITIVE := Color(0.35, 0.65, 1.0)      # 희귀
const NEGATIVE := Color(1.0, 0.38, 0.35)
const BG_POSITIVE := Color(0.12, 0.2, 0.34)
const BG_NEGATIVE := Color(0.32, 0.12, 0.13)
const NORMAL := Color(0.68, 0.7, 0.74)        # 일반 (v0.54)
const BG_NORMAL := Color(0.19, 0.2, 0.23)
const LEGEND_FROM := Color(1.0, 0.55, 0.12)   # 전설: 왼쪽 주황 → 오른쪽 노랑 (v0.54)
const LEGEND_TO := Color(1.0, 0.86, 0.25)
const BG_LEGEND := Color(0.3, 0.2, 0.07)

var trait_data: TraitData


func setup(t: TraitData) -> void:
	trait_data = t
	tooltip_text = "%s\n%s" % [t.name_ko, t.description]
	custom_minimum_size = Vector2(0, HEIGHT)
	queue_redraw()


func is_negative() -> bool:
	return trait_data != null and trait_data.tier == &"negative"


func chevron_count() -> int:
	if trait_data == null:
		return 0
	match trait_data.tier:
		&"negative", &"normal":
			return 1
		&"rare":
			return 2
		&"legend":
			return 3
	return 1


## 등급별 (테두리·화살표 색, 배경색)
func tier_colors() -> Array[Color]:
	match trait_data.tier if trait_data else &"normal":
		&"negative":
			return [NEGATIVE, BG_NEGATIVE]
		&"rare":
			return [POSITIVE, BG_POSITIVE]
		&"legend":
			return [LEGEND_FROM, BG_LEGEND]
	return [NORMAL, BG_NORMAL]


func _draw() -> void:
	if trait_data == null:
		return
	var neg := is_negative()
	var legend := trait_data.tier == &"legend"
	var cols := tier_colors()
	var color: Color = cols[0]
	var box := StyleBoxFlat.new()
	box.bg_color = cols[1]
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	if legend and size.x > 4.0 and size.y > 4.0:
		# 주황→노랑 테두리: 가로 그라데이션 판을 깔고 안쪽을 배경색으로 덮는다
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(1, 0), Vector2(w - 1, 0), Vector2(w, 1), Vector2(w, h - 1),
				Vector2(w - 1, h), Vector2(1, h), Vector2(0, h - 1), Vector2(0, 1)]),
			PackedColorArray([LEGEND_FROM, LEGEND_TO, LEGEND_TO, LEGEND_TO, LEGEND_TO, LEGEND_FROM, LEGEND_FROM, LEGEND_FROM]))
		box.set_border_width_all(0)
		box.set_corner_radius_all(2)
		draw_style_box(box, Rect2(Vector2.ONE, size - Vector2(2, 2)))
	else:
		draw_style_box(box, Rect2(Vector2.ZERO, size))

	# 화살표: 위쪽(^) 또는 아래쪽(v)
	var x := 4.0
	var mid := size.y / 2.0
	for i in chevron_count():
		var pts: PackedVector2Array
		if neg:
			pts = [Vector2(x, mid - 2.5), Vector2(x + CHEVRON_W / 2.0, mid + 2.5), Vector2(x + CHEVRON_W, mid - 2.5)]
		else:
			pts = [Vector2(x, mid + 2.5), Vector2(x + CHEVRON_W / 2.0, mid - 2.5), Vector2(x + CHEVRON_W, mid + 2.5)]
		var c := color
		if legend:   # 화살표도 주황 → 노랑
			c = LEGEND_FROM.lerp(LEGEND_TO, float(i) / maxf(1.0, chevron_count() - 1))
		draw_polyline(pts, c, 2.0)
		x += CHEVRON_W + CHEVRON_GAP
	var font := get_theme_default_font()
	draw_string(font, Vector2(x + 3.0, mid + 6.0), trait_data.name_ko, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
