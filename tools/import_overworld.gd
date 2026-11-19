extends SceneTree
## HGSS 오버월드(필드) 포켓몬 시트 → 종별 앞모습 PNG. (기획서 7.4, 4.13 — 메인 화면 엔트리 표시)
##
## 실행: <godot> --headless --path . -s res://tools/import_overworld.gd -- --gen 1
## 이후:  <godot> --headless --path . --import   (생성된 PNG 임포트)
##
## 원본 시트 구조 (1세대 시트에서 확인, v0.28)
## - 구분선 #004080 으로 나뉜 블록이 한 줄에 15개. 블록 폭은 61~64px(고르지 않음), 높이 128px(마지막 줄 127px).
## - 블록 하나 = 한 종. 블록 안: 왼쪽 열 = 위(뒷모습) 2프레임(0·1행), 아래(앞모습) 2프레임(2·3행), 칸 32×32.
##   오른쪽 열 = 옆모습. 우리는 왼쪽 열 2·3행(앞모습 걷기 2프레임)만 쓴다.
## - 블록 배경색은 블록마다 다를 수 있다(대부분 #A0B080) → 프레임 가장자리에서 이어진 배경색만 투명 처리(flood fill).
## - 암수 모습이 다른 종: 수컷 블록에 파란 점(#0080FF), 바로 뒤 암컷 블록에 분홍 점(#FF00FF). 점은 배경색으로 지운다.
##   1세대 시트에서는 이상해꽃·피카츄 두 종.
##
## 결과
## - res://assets/generated/overworld/gen<N>/<dex 4자리>.png  64×32 (앞1 | 앞2), 암컷 모습이 있으면 64×64 (2행 = 암컷)
## - res://assets/generated/overworld/gen<N>/walk/<dex 4자리>.png  64×128 걷기 시트 (v0.45, M12 걸어다니는 엔트리)
##   행: 0 아래(앞) / 1 위(뒤) / 2 왼쪽 / 3 오른쪽, 열: 걷기 2프레임. 암컷 모습은 <dex>_f.png
##   원본 블록: 왼쪽 열 0·1행 = 위, 2·3행 = 아래 / 오른쪽 열 0·1행 = 왼쪽, 2·3행 = 오른쪽
## - res://tools/previews/preview_overworld_gen<N>.png       (검토용: 도감 순서)

const SHEETS := {
	1: "res://assets/sprites/DS _ DSi - Pokemon HeartGold _ SoulSilver - Overworld - Pokemon (1st Generation, Overworld).png",
}
const SPECIES_COUNT := {1: 151}
const OUT_DIR := "res://assets/generated/overworld/gen%d"
const PREVIEW := "res://tools/previews/preview_overworld_gen%d.png"

const LINE := Color8(0, 64, 128)
const MALE_DOT := Color8(0, 128, 255)
const FEMALE_DOT := Color8(255, 0, 255)
const CELL := 32
const BLOCK_H := 128
const BLOCKS_PER_ROW := 15
const FRONT_ROWS := [2, 3]
## 걷기 시트 행 순서(아래·위·왼쪽·오른쪽) → 원본 블록의 [열, 행 2개]
const WALK_SRC := [[0, [2, 3]], [0, [0, 1]], [1, [0, 1]], [1, [2, 3]]]
const WALK_DIR := "/walk"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--gen")
	var gen := int(args[i + 1]) if i >= 0 and i + 1 < args.size() else 1
	quit(_run(gen))


func _run(gen: int) -> int:
	if not SHEETS.has(gen):
		push_error("세대 %d 오버월드 시트가 없습니다." % gen)
		return 1
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEETS[gen]))
	if sheet == null:
		push_error("시트를 읽지 못했습니다: %s" % SHEETS[gen])
		return 1
	sheet.convert(Image.FORMAT_RGBA8)

	var cols := _find_col_starts(sheet)
	if cols.size() != BLOCKS_PER_ROW:
		push_error("블록 열이 %d개입니다(예상 %d)." % [cols.size(), BLOCKS_PER_ROW])
		return 1
	var rows := _find_row_starts(sheet)

	# 블록 목록 (읽는 순서). 블록 안에 앞모습이 없으면 끝(아래 배너)으로 본다.
	var blocks: Array[Vector2i] = []
	for y0 in rows:
		for x0 in cols:
			if _front_empty(sheet, x0, y0):
				continue
			blocks.append(Vector2i(x0, y0))

	# 블록 → 도감 번호. 분홍 점 블록 = 바로 앞 종의 암컷.
	var count: int = SPECIES_COUNT[gen]
	var males := {}     # dex -> Image(64×32)
	var females := {}
	var walk_m := {}    # dex -> Image(64×128) 걷기 시트
	var walk_f := {}
	var dex := 0
	for b in blocks:
		var female := _has_color(sheet, b, FEMALE_DOT)
		if not female:
			dex += 1
		if dex > count:
			break
		var strip := _cut_front(sheet, b)
		var walk := _cut_walk(sheet, b)
		if female:
			females[dex] = strip
			walk_f[dex] = walk
		else:
			males[dex] = strip
			walk_m[dex] = walk
	if males.size() != count:
		push_error("종 %d개를 찾았습니다(예상 %d). 시트 구조를 확인하세요." % [males.size(), count])
		return 1

	var out_dir := OUT_DIR % gen
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for d in males:
		var img: Image = males[d]
		if females.has(d):
			var both := Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
			both.blit_rect(males[d], Rect2i(0, 0, CELL * 2, CELL), Vector2i.ZERO)
			both.blit_rect(females[d], Rect2i(0, 0, CELL * 2, CELL), Vector2i(0, CELL))
			img = both
		img.save_png(ProjectSettings.globalize_path(out_dir + "/%04d.png" % d))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir + WALK_DIR))
	for d in walk_m:
		walk_m[d].save_png(ProjectSettings.globalize_path(out_dir + WALK_DIR + "/%04d.png" % d))
	for d in walk_f:
		walk_f[d].save_png(ProjectSettings.globalize_path(out_dir + WALK_DIR + "/%04d_f.png" % d))

	_save_preview(gen, males, females)
	print("오버월드 %d종 저장 (암컷 모습 %d종: %s) → %s" % [males.size(), females.size(), females.keys(), out_dir])
	return 0


## 세로 구분선(위쪽 1000px 의 90% 이상이 선 색) → 블록 시작 x
func _find_col_starts(sheet: Image) -> Array[int]:
	var out: Array[int] = [0]
	var h := mini(1000, sheet.get_height())
	for x in sheet.get_width():
		var n := 0
		for y in h:
			if sheet.get_pixel(x, y).is_equal_approx(LINE):
				n += 1
		if n > h * 0.9:
			out.append(x + 1)
	return out


## 가로 구분선(가로 60% 이상이 선 색, 직전 선과 100px 이상 떨어짐) → 블록 시작 y
## (큰 스프라이트가 선을 일부 가리는 줄이 있어 세로선보다 기준을 낮춘다)
func _find_row_starts(sheet: Image) -> Array[int]:
	var out: Array[int] = [0]
	var w := sheet.get_width()
	for y in sheet.get_height():
		if y - out.back() < 100:
			continue
		var n := 0
		for x in w:
			if sheet.get_pixel(x, y).is_equal_approx(LINE):
				n += 1
		if n > w * 0.6:
			out.append(y + 1)
	return out


func _bg(sheet: Image, b: Vector2i) -> Color:
	return sheet.get_pixel(b.x, b.y)


func _frame_rect(sheet: Image, b: Vector2i, row: int) -> Rect2i:
	var y := b.y + CELL * row
	return Rect2i(b.x, y, CELL, mini(CELL, sheet.get_height() - y))


func _front_empty(sheet: Image, x0: int, y0: int) -> bool:
	if y0 + CELL * 2 >= sheet.get_height():
		return true
	var bg := sheet.get_pixel(x0, y0)
	var r := _frame_rect(sheet, Vector2i(x0, y0), FRONT_ROWS[0])
	var other := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := sheet.get_pixel(x, y)
			if not c.is_equal_approx(bg) and not c.is_equal_approx(LINE):
				other += 1
	return other < 20


func _has_color(sheet: Image, b: Vector2i, color: Color) -> bool:
	for y in range(b.y, mini(b.y + BLOCK_H, sheet.get_height())):
		for x in range(b.x, mini(b.x + CELL * 2, sheet.get_width())):
			if sheet.get_pixel(x, y).is_equal_approx(color):
				return true
	return false


## 앞모습 2프레임 → 64×32 (배경 투명)
func _cut_front(sheet: Image, b: Vector2i) -> Image:
	var bg := _bg(sheet, b)
	var strip := Image.create(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in FRONT_ROWS.size():
		var r := _frame_rect(sheet, b, FRONT_ROWS[i])
		var cut := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		cut.fill(bg)
		cut.blit_rect(sheet, r, Vector2i.ZERO)
		for y in CELL:
			for x in CELL:
				var c := cut.get_pixel(x, y)
				if c.is_equal_approx(MALE_DOT) or c.is_equal_approx(FEMALE_DOT):
					cut.set_pixel(x, y, bg)
		_clear_background(cut, bg)
		_drop_right_edge_slivers(cut)
		strip.blit_rect(cut, Rect2i(0, 0, CELL, CELL), Vector2i(CELL * i, 0))
	return strip


## 걷기 시트 64×128 (행: 아래·위·왼쪽·오른쪽, 열: 2프레임, 배경 투명)
func _cut_walk(sheet: Image, b: Vector2i) -> Image:
	var out := Image.create(CELL * 2, CELL * 4, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for row in WALK_SRC.size():
		var col: int = WALK_SRC[row][0]
		var src_rows: Array = WALK_SRC[row][1]
		for i in 2:
			out.blit_rect(_cut_cell(sheet, b, col, src_rows[i]), Rect2i(0, 0, CELL, CELL), Vector2i(CELL * i, CELL * row))
	return out


## 블록의 한 칸(32×32)을 잘라 배경을 투명하게. 옆 칸에서 비어져 들어온 조각과 구분선은 지운다.
func _cut_cell(sheet: Image, b: Vector2i, col: int, row: int) -> Image:
	var bg := _bg(sheet, b)
	var r := _frame_rect(sheet, b, row)
	r.position.x += CELL * col
	r.size.x = mini(CELL, sheet.get_width() - r.position.x)
	var cut := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	cut.fill(bg)
	cut.blit_rect(sheet, r, Vector2i.ZERO)
	for y in CELL:
		for x in CELL:
			var c := cut.get_pixel(x, y)
			if c.is_equal_approx(MALE_DOT) or c.is_equal_approx(FEMALE_DOT) or c.is_equal_approx(LINE):   # 블록 폭이 좁은 줄은 구분선이 칸 안에 들어온다
				cut.set_pixel(x, y, bg)
	_clear_background(cut, bg)
	if col == 0:
		_drop_right_edge_slivers(cut)
	else:
		_drop_left_edge_slivers(cut)
	return cut


## 왼쪽 가장자리에 닿은 폭 2px 이하 조각 = 왼쪽 열 스프라이트가 비어져 들어온 것 → 지운다 (오른쪽 열 칸용)
func _drop_left_edge_slivers(img: Image) -> void:
	img.flip_x()
	_drop_right_edge_slivers(img)
	img.flip_x()


## 가장자리에서 이어진 배경색 픽셀만 투명으로 (스프라이트 안쪽의 같은 색은 남긴다)
func _clear_background(img: Image, bg: Color) -> void:
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
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)


## 오른쪽 가장자리에 닿은 폭 2px 이하 조각 = 옆 칸(옆모습) 스프라이트가 비어져 들어온 것 → 지운다.
## (신뇽처럼 큰 스프라이트 블록에서 생김. 또가스의 가스 같은 떨어진 조각은 가장자리에 닿지 않아 남는다)
func _drop_right_edge_slivers(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := {}
	for y in h:
		var start := Vector2i(w - 1, y)
		if seen.has(start) or img.get_pixelv(start).a == 0.0:
			continue
		var part: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		var min_x := w
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen.has(p) or img.get_pixelv(p).a == 0.0:
				continue
			seen[p] = true
			part.append(p)
			min_x = mini(min_x, p.x)
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				stack.append(p + d)
		if w - min_x <= 2:
			for p in part:
				img.set_pixelv(p, Color(0, 0, 0, 0))


## 검토용 미리보기: 종마다 [앞1 앞2 (암컷 앞1 앞2)] 를 회색 바탕에, 한 줄 10종
func _save_preview(gen: int, males: Dictionary, females: Dictionary) -> void:
	var per_row := 10
	var cw := CELL * 4 + 4
	var rows := ceili(males.size() / float(per_row))
	var img := Image.create(per_row * cw, rows * (CELL + 4), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.6, 0.65))
	for d in males:
		var k: int = d - 1
		var pos := Vector2i((k % per_row) * cw, (k / per_row) * (CELL + 4))
		img.blend_rect(males[d], Rect2i(0, 0, CELL * 2, CELL), pos)
		if females.has(d):
			img.blend_rect(females[d], Rect2i(0, 0, CELL * 2, CELL), pos + Vector2i(CELL * 2, 0))
	img.save_png(ProjectSettings.globalize_path(PREVIEW % gen))
