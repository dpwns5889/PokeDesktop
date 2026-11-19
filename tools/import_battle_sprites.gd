extends SceneTree
## HGSS 전투 스프라이트 시트 → 종별 시트 PNG. (기획서 7.4)
##
## 실행: <godot> --headless --path . -s res://tools/import_battle_sprites.gd -- --gen 1
## 이후:  <godot> --headless --path . --import   (생성된 PNG 임포트)
##
## 원본 시트 구조
## - 칸 80×80, 칸 사이 1px 구분선(#3261A8), 칸 간격 81px → 가로 40칸 고정 격자
## - 종별 블록 = 머리줄 + 2행(일반 / 색이 다름) × 4열(앞1, 앞2, 뒤1, 뒤2), 한 줄에 블록 10개
## - 암수 스프라이트가 다른 종은 수컷 블록 바로 뒤에 암컷 블록
## - 앞모습 배경 #93BBEC → 투명 처리. (DS 색은 8의 배수라 배경색과 겹치지 않음)
##
## 결과
## - res://assets/generated/sprites/gen<N>/<dex 4자리>.png  (PokemonSprites 배치)
## - res://tools/previews/preview_gen<N>.png               (검토용: 도감 순서, 종당 [일반|암컷|색다름])
## - res://assets/data/atlas/gen<N>_battle.json                      (사용한 블록 좌표 기록)

const SHEETS := {
	1: "res://assets/sprites/DS _ DSi - Pokemon HeartGold _ SoulSilver - Battle - Pokemon (1st Generation) (1).png",
	2: "res://assets/sprites/DS _ DSi - Pokemon HeartGold _ SoulSilver - Battle - Pokemon (2nd Generation).png",
}
const CSV := "res://tools/source/pokemon_gen%d.csv"
const OUT_DIR := "res://assets/generated/sprites/gen%d"

const CELL := 80
const PITCH := 81
const BLOCKS_PER_ROW := 10
const COLS_PER_BLOCK := 4
const FRONT_BG := Color8(147, 187, 236)
const BACK_BG := Color8(84, 165, 75)
const PREVIEW_PER_ROW := 6


func _init() -> void:
	var gen := _arg_int("--gen", 1)
	var code := _run(gen)
	quit(code)


func _run(gen: int) -> int:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEETS[gen]))
	if sheet == null:
		push_error("시트를 읽지 못했습니다: %s" % SHEETS[gen])
		return 1
	sheet.convert(Image.FORMAT_RGBA8)

	var species := _read_species(gen)
	var bands := _find_cell_bands(sheet)
	if bands.size() % 2 != 0:
		push_error("칸 행 수가 홀수입니다(%d). 시트 구조를 확인하세요." % bands.size())
		return 1

	# 블록 목록 (읽는 순서)
	var blocks: Array[Vector2i] = []  # 각 블록 왼쪽 위 칸의 (x, y)
	for r in range(0, bands.size(), 2):
		if bands[r + 1] != bands[r] + PITCH:
			push_error("블록 행 %d: 일반/색다름 행 간격이 %d px 입니다." % [r / 2, bands[r + 1] - bands[r]])
			return 1
		for b in BLOCKS_PER_ROW:
			var x := 1 + b * COLS_PER_BLOCK * PITCH
			if x + CELL > sheet.get_width():
				break
			if sheet.get_pixel(x, bands[r]).is_equal_approx(FRONT_BG):
				blocks.append(Vector2i(x, bands[r]))

	var expected := species.size()
	for s in species:
		if s.gender:
			expected += 1
	print("블록 %d개 검출 (필요 %d개)" % [blocks.size(), expected])
	if blocks.size() < expected:
		push_error("블록이 부족합니다. 암수 블록 목록(has_gender_sprites)이 시트와 맞는지 확인하세요.")
		return 1
	if blocks.size() > expected:
		print("  남는 블록 %d개는 사용하지 않습니다(예: 시트 끝의 보정판 스프라이트)." % (blocks.size() - expected))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR % gen))
	var atlas := {}
	var preview := Image.create(PREVIEW_PER_ROW * CELL * 3, ceili(float(species.size()) / PREVIEW_PER_ROW) * CELL, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.92, 0.92, 0.92))
	var bi := 0
	var leftover_bg := 0
	for i in species.size():
		var s: Dictionary = species[i]
		var rows: Array[Vector2i] = [blocks[bi]]
		bi += 1
		if s.gender:
			rows.append(blocks[bi])
			bi += 1
		var out := Image.create(CELL * 4, CELL * rows.size(), false, Image.FORMAT_RGBA8)
		for r in rows.size():
			var o := rows[r]
			# 일반 프레임1, 2 / 색다름 프레임1, 2
			var srcs := [o, o + Vector2i(PITCH, 0), o + Vector2i(0, PITCH), o + Vector2i(PITCH, PITCH)]
			for c in 4:
				var cell := sheet.get_region(Rect2i(srcs[c], Vector2i(CELL, CELL)))
				leftover_bg += _key_out(cell)
				out.blit_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
		var path := (OUT_DIR % gen) + "/%04d.png" % s.dex
		out.save_png(ProjectSettings.globalize_path(path))
		atlas[str(s.dex)] = rows.map(func(v: Vector2i) -> Array: return [v.x, v.y])

		# 미리보기: [일반 | 암컷(없으면 빈칸) | 색다름]
		var px := (i % PREVIEW_PER_ROW) * CELL * 3
		var py := (i / PREVIEW_PER_ROW) * CELL
		preview.blend_rect(out, Rect2i(0, 0, CELL, CELL), Vector2i(px, py))
		if s.gender:
			preview.blend_rect(out, Rect2i(0, CELL, CELL, CELL), Vector2i(px + CELL, py))
		preview.blend_rect(out, Rect2i(CELL * 2, 0, CELL, CELL), Vector2i(px + CELL * 2, py))

	preview.save_png(ProjectSettings.globalize_path("res://tools/previews/preview_gen%d.png" % gen))
	var f := FileAccess.open("res://assets/data/atlas/gen%d_battle.json" % gen, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sheet": SHEETS[gen], "cell": CELL, "pitch": PITCH,
		"layout": "block origin = 일반 앞모습 프레임1. 오른쪽 칸 = 프레임2, 아래 칸 = 색이 다른 개체",
		"entries": atlas}, "\t"))
	f.close()
	print("종 %d개 저장: %s" % [species.size(), OUT_DIR % gen])
	if leftover_bg > 0:
		push_warning("배경색이 아닌데 DS 색(8의 배수)도 아닌 픽셀 %d개 — 시트 확인 필요" % leftover_bg)
	return 0


## 각 행 y에 대해, 40개 칸 열의 첫 픽셀 중 배경색이 2개 이상이면 '칸 행'. 연속 80px = 칸 1행.
func _find_cell_bands(img: Image) -> Array[int]:
	var cols := (img.get_width() - 1) / PITCH
	var bands: Array[int] = []
	var run_start := -1
	for y in img.get_height() + 1:
		var is_cell := false
		if y < img.get_height():
			var n := 0
			for k in cols:
				var c := img.get_pixel(1 + k * PITCH, y)
				if c.is_equal_approx(FRONT_BG) or c.is_equal_approx(BACK_BG):
					n += 1
					if n >= 2:
						is_cell = true
						break
		if is_cell and run_start < 0:
			run_start = y
		elif not is_cell and run_start >= 0:
			var length := y - run_start
			if length == CELL:
				bands.append(run_start)
			elif length > 3:
				push_warning("높이 %d px 인 칸 행(y=%d)을 건너뜁니다." % [length, run_start])
			run_start = -1
	return bands


## 앞모습 배경을 투명으로. 반환: DS 색이 아닌 남은 픽셀 수(검증용).
func _key_out(cell: Image) -> int:
	var odd := 0
	for y in CELL:
		for x in CELL:
			var c := cell.get_pixel(x, y)
			if c.is_equal_approx(FRONT_BG):
				cell.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.r8 % 8 != 0 or c.g8 % 8 != 0 or c.b8 % 8 != 0:
				odd += 1
	return odd


func _read_species(gen: int) -> Array[Dictionary]:
	var f := FileAccess.open(CSV % gen, FileAccess.READ)
	var header := f.get_csv_line()
	var out: Array[Dictionary] = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size():
			continue
		var d := {}
		for i in header.size():
			d[header[i]] = row[i]
		out.append({"dex": int(d.dex_id), "gender": d.has_gender_sprites == "1"})
	out.sort_custom(func(a, b): return a.dex < b.dex)
	return out


func _arg_int(name: String, default: int) -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find(name)
	return int(args[i + 1]) if i >= 0 and i + 1 < args.size() else default
