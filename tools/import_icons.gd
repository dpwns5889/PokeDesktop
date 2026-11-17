extends SceneTree
## 아이템 아이콘 시트 → 아이콘 PNG. (기획서 7.4, 4.11)
##
## 실행: <godot> --headless --path . -s res://tools/import_icons.gd
## 영역 정의: res://data/atlas/items.json
## 결과: res://Assets/Generated/icons/<item_id>.png (24×24, 배경 투명, 가운데 정렬)
##       res://Assets/Generated/preview_icons.png (검토용)
## 경험사탕은 HGSS에 없는 아이템이라 이상한사탕 아이콘의 색을 바꿔 만든다(임시).
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
			for y in cut.get_height():
				for x in cut.get_width():
					if cut.get_pixel(x, y).is_equal_approx(bg):
						cut.set_pixel(x, y, Color(0, 0, 0, 0))
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
		var shift := float(e.hue_shift)
		for y in size:
			for x in size:
				var c := icon.get_pixel(x, y)
				if c.a > 0.0 and c.s > 0.15:
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
