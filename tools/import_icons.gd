extends SceneTree
## 아이템 아이콘 시트 → 아이콘 PNG. (기획서 7.4, 4.11)
##
## 실행: <godot> --headless --path . -s res://tools/import_icons.gd
## 영역 정의: res://data/atlas/items.json
## 결과: res://Assets/Generated/icons/<item_id>.png (24×24, 배경 투명, 가운데 정렬)
##       res://Assets/Generated/preview_icons.png (검토용)
## 경험사탕은 HGSS에 없는 아이템이라 이상한사탕 아이콘의 색을 바꿔 만든다(임시).
## recolor 항목에 "hue_set"(0~1)을 주면 회색까지 포함해 그 색으로 물들인다(어두운 외곽선 제외, "min_sat" 최소 채도, 채도 0인 회색은 "gray_hue", v0.84 별의모래·별의조각).
## 항목에 "sheet" 를 주면 그 시트(배경 투명)에서 자른다 — 배경색 지우기는 하지 않는다(흰 반짝임이 지워지지 않게). (v0.43, 금구슬)

const DEF := "res://data/atlas/items.json"
const OUT_DIR := "res://Assets/Generated/icons"


func _init() -> void:
	quit(_run())


func _run() -> int:
	var def: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEF))
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(def.sheet))
	if sheet == null:
		push_error("시트를 읽지 못했습니다: %s" % def.sheet)
		return 1
	sheet.convert(Image.FORMAT_RGBA8)
	var bg := Color8(def.background[0], def.background[1], def.background[2])
	var size := int(def.icon_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var made := {}
	var extra_sheets := {}   # 경로 → Image (항목별 "sheet")
	var icons: Dictionary = def.icons
	# 1) 시트에서 자르기
	for id in icons:
		var e: Dictionary = icons[id]
		if not e.has("region"):
			continue
		var r: Array = e.region
		var src := sheet
		var own_sheet: bool = e.has("sheet")
		if own_sheet:
			if not extra_sheets.has(e.sheet):
				var img := Image.load_from_file(ProjectSettings.globalize_path(e.sheet))
				if img == null:
					push_error("시트를 읽지 못했습니다: %s" % e.sheet)
					return 1
				img.convert(Image.FORMAT_RGBA8)
				extra_sheets[e.sheet] = img
			src = extra_sheets[e.sheet]
		var cut := src.get_region(Rect2i(r[0], r[1], r[2], r[3]))
		if not own_sheet:
			_clear_outer_background(cut, bg)
		# "fit": 큰 그림(예: 48×48 보관함 확장)을 아이콘 크기로 부드럽게 줄인다 (v0.66). 배경을 지운 뒤에 (v0.84)
		if e.has("fit"):
			var f := int(e.fit)
			cut.resize(f, f, Image.INTERPOLATE_LANCZOS)
		var icon := Image.create(size, size, false, Image.FORMAT_RGBA8)
		icon.fill(Color(0, 0, 0, 0))
		icon.blit_rect(cut, Rect2i(Vector2i.ZERO, cut.get_size()), (Vector2i(size, size) - cut.get_size()) / 2)
		made[id] = icon
	# 2) 색 바꿔 만들기
	for id in icons:
		var e: Dictionary = icons[id]
		if not e.has("recolor"):
			continue
		var icon: Image = made[e.recolor].duplicate()
		var shift := float(e.get("hue_shift", 0.0))
		for y in size:
			for x in size:
				var c := icon.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if e.has("hue_set"):
					if c.v > 0.2:   # 외곽선은 그대로. 채도 0인 회색은 "gray_hue"(없으면 hue_set)로
						var h := float(e.hue_set) if c.s > 0.0 else float(e.get("gray_hue", e.hue_set))
						c = Color.from_hsv(h, maxf(c.s, float(e.get("min_sat", 0.3))), c.v, c.a)
				elif c.s > 0.15:
					c.h = fposmod(c.h + shift, 1.0)
				icon.set_pixel(x, y, c)
		made[id] = icon

	var ids := made.keys()
	ids.sort()
	var preview := Image.create(size * 2 * ids.size(), size * 2, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.92, 0.92, 0.92))
	for i in ids.size():
		var img: Image = made[ids[i]]
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, ids[i]]))
		var big := img.duplicate()
		big.resize(size * 2, size * 2, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(big, Rect2i(0, 0, size * 2, size * 2), Vector2i(i * size * 2, 0))
	preview.save_png(ProjectSettings.globalize_path("res://Assets/Generated/preview_icons.png"))
	print("아이콘 %d개 저장 (순서: %s)" % [ids.size(), ", ".join(ids)])
	return 0


## 가장자리에서 이어진 배경색만 투명하게 (v0.84). 그림 안쪽의 흰 반짝임·면은 남긴다 (이전에는 모든 흰색을 지워 구멍이 났다)
static func _clear_outer_background(img: Image, bg: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var c := img.get_pixelv(p)
		if c.a == 0.0 or not c.is_equal_approx(bg):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
