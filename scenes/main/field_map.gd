class_name FieldMap
extends TileMapLayer
## 메인 화면 왼쪽 들판 타일맵 (기획서 6.1, v0.48).
## 배치는 FieldMaps(scripts/data/field_maps.gd), 그림은 Assets/Generated/field/<지역>.png (tools/make_field_tiles.py).
## 지역이 바뀌면 그 지역의 그림·배치로 다시 깐다. 걸어다니는 엔트리는 is_blocked 로 나무·물·단·돌·덤불을 피한다.
## 칸 번호 (타일 그림의 가로 순서)
##   0~2 땅, 3 장식, 4 풀숲 윗줄, 5 풀숲, 6~14 길 9칸, 15~23 물 9칸, 24~32 단 9칸, 33 돌, 34 덤불·수정,
##   35~50 나무 64×64 = 4×4칸 (v0.49, 위 줄부터 왼→오)

const TILE := 16
const COLUMNS := 51
const TREE := 4   # 나무 한 그루 = 4×4칸
const SHEET := "res://Assets/Generated/field/%s.png"
const BLOCKED := ["w", "T", "h", "o", "b"]
const BASE9 := {"p": 6, "w": 15, "h": 24}

var region_id: StringName = &""
var _rows: Array = []
var _source: TileSetAtlasSource


func _init() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	_source = TileSetAtlasSource.new()
	_source.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(_source, 0)
	tile_set = ts


## 지역 그림·배치로 다시 깐다. 그림이 없으면 비우고 false (호출하는 쪽이 땅 색으로 대신).
func set_region(id: StringName) -> bool:
	region_id = id
	var path := SHEET % id
	if not ResourceLoader.exists(path):
		clear()
		_rows = []
		return false
	var tex: Texture2D = load(path)
	if _source.texture != tex:
		_source.texture = tex
		for i in COLUMNS:
			if not _source.has_tile(Vector2i(i, 0)):
				_source.create_tile(Vector2i(i, 0))
	_rows = FieldMaps.rows_for(id)
	clear()
	for y in _rows.size():
		for x in String(_rows[y]).length():
			set_cell(Vector2i(x, y), 0, Vector2i(tile_index(_rows, x, y), 0))
	return true


## 이 위치(이 노드 기준 px)가 못 지나가는 칸인가. 맵 밖은 막힘.
func is_blocked(local: Vector2) -> bool:
	if _rows.is_empty():
		return false
	var cx := floori(local.x / TILE)
	var cy := floori(local.y / TILE)
	if cy < 0 or cy >= _rows.size() or cx < 0 or cx >= String(_rows[cy]).length():
		return true
	return String(_rows[cy])[cx] in BLOCKED


## 나무 칸이 4×4 나무의 몇 번째 열(horizontal)·줄인가. 이어진 "T" 줄의 시작부터 4칸씩 짝짓되,
## 맵 왼쪽·위 끝에 닿은 줄은 끝(오른쪽·아래)에 맞춰 짝지어 맵 밖으로 잘린 나무처럼 보이게 한다 (v0.49).
static func _tree_part(rows: Array, x: int, y: int, horizontal: bool) -> int:
	var at := func(i: int) -> bool:
		var cx := i if horizontal else x
		var cy := y if horizontal else i
		if cy < 0 or cy >= rows.size() or cx < 0 or cx >= String(rows[cy]).length():
			return false
		return String(rows[cy])[cx] == "T"
	var pos := x if horizontal else y
	var start := pos
	while at.call(start - 1):
		start -= 1
	var end := pos
	while at.call(end + 1):
		end += 1
	if start == 0:
		return TREE - 1 - (end - pos) % TREE
	return (pos - start) % TREE


## 배치 글자 → 칸 번호. 길·물·단·풀숲은 같은 글자 이웃을 보고 가장자리 칸을 고른다(맵 밖은 같은 글자로 본다).
## tools/preview_field_maps.py 와 같은 규칙.
static func tile_index(rows: Array, x: int, y: int) -> int:
	var row: String = rows[y]
	var ch := row[x]
	var same := func(dx: int, dy: int) -> bool:
		var nx := x + dx
		var ny := y + dy
		if ny < 0 or ny >= rows.size() or nx < 0 or nx >= String(rows[ny]).length():
			return true
		return String(rows[ny])[nx] == ch
	match ch:
		".":
			var k := (x * 7 + y * 13 + x * y) % 20
			return 0 if k < 12 else (1 if k < 17 else 2)
		"*":
			return 3
		"g":
			return 4 if not same.call(0, -1) else 5
		"p", "w", "h":
			var col := 0 if not same.call(-1, 0) else (2 if not same.call(1, 0) else 1)
			var r := 0 if not same.call(0, -1) else (2 if not same.call(0, 1) else 1)
			return BASE9[ch] + r * 3 + col
		"T":
			return 35 + _tree_part(rows, x, y, false) * TREE + _tree_part(rows, x, y, true)
		"o":
			return 33
		"b":
			return 34
	return 0
