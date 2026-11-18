class_name FieldMap
extends TileMapLayer
## 메인 화면 왼쪽 들판 타일맵 (기획서 6.1, v0.48).
## 배치는 FieldMaps(scripts/data/field_maps.gd), 그림은 Assets/Generated/field/<지역>.png (tools/make_field_tiles.py —
## v0.64부터 Assets/Sprites/tilemap 의 Tileset1.png(땅·길·물·단·꽃밭·다리)와 Object.png(나무·바위·덤불·기계)에서 잘라 쓴다).
## 지역이 바뀌면 그 지역의 그림·배치로 다시 깐다. 걸어다니는 엔트리는 is_blocked 로 물·단과 모든 오브젝트를 피한다.
## 칸 번호 (타일 그림의 가로 순서)
##   0~2 땅, 3 장식, 4 풀숲 윗줄, 5 풀숲, 6~14 길 9칸, 15~23 물 9칸, 24~32 단 9칸, 33 돌, 34 덤불,
##   여러 칸 오브젝트 (위 줄부터 왼→오): 35~46 나무 3×4, 47~50 큰 바위 2×2, 51~52 작은 나무 1×2, 53~58 기계 3×2,
##   59 상자, 60~62 가로 나무다리 (왼끝·가운데·오른끝), 63~65 세로 나무다리 (위끝·가운데·아래끝), 66~69 꽃밭 4종,
##   70 물 위 회색 돌, 71~74 물 위 회색 큰 바위 2×2 (회색 돌은 물에만, 땅 위 돌은 갈색 돌을 지역 색으로),
##   75~90 나무 군락 4×4 — 여러 그루가 붙은 숲(T). 한 그루 나무(Y)는 35~46
##   91~98 군락 옆 땅 칸 (줄 r: 91 + 2r 왼쪽 옆, 92 + 2r 오른쪽 옆 — 끝 나무의 잘린 잎 가장자리), 99 풀 덤불(v, 지나갈 수 있음)

const TILE := 16
const ROCK := 33
const BUSH := 34
## 여러 칸 오브젝트: 글자 → [첫 칸 번호, 가로 칸, 세로 칸] (v0.64)
const TREE := 35
const BOULDER := TREE + 3 * 4
const SMALL_TREE := BOULDER + 2 * 2
const MACHINE := SMALL_TREE + 1 * 2
const CRATE := MACHINE + 3 * 2
const OBJECTS := {
	"Y": [TREE, 3, 4],
	"O": [BOULDER, 2, 2],
	"i": [SMALL_TREE, 1, 2],
	"m": [MACHINE, 3, 2],
	"Q": [FLOWERS + FLOWER_KINDS + 1, 2, 2],
}
const BRIDGE_H := CRATE + 1
const BRIDGE_V := BRIDGE_H + 3
const FLOWERS := BRIDGE_V + 3
const FLOWER_KINDS := 4
## 물 위 회색 돌 / 큰 바위 (물결 테두리가 있는 그림이라 물에만 둔다)
const WATER_ROCK := FLOWERS + FLOWER_KINDS
const WATER_BOULDER := WATER_ROCK + 1
## 나무 군락 (Object.png 12~15줄): 열 0 = 첫 그루 왼쪽, 1 = 오른쪽(+ 다음 그루 경계), 2 = 다음 그루 왼쪽, 3 = 마지막 그루 오른쪽,
## 줄 0 = 뒤 나무와 겹친 윗부분, 1 = 꼭대기, 2 = 몸통, 3 = 밑동
const CLUSTER := WATER_BOULDER + 2 * 2
## 군락 양 끝 옆 땅(.) 칸: 군락 그림은 끝 나무가 칸 경계에서 잘려 있어, 옆 칸에 삐져나온 잎 가장자리를 그린다
const CLUSTER_SIDE := CLUSTER + 4 * 4
## 풀 덤불 v (Tileset1 덤불을 작게, 지나갈 수 있음). 덤불 b 는 Object 열매 덤불에서 열매를 지운 것(못 지나감)
const LEAF_BUSH := CLUSTER_SIDE + 4 * 2
const COLUMNS := LEAF_BUSH + 1
## 물 가장자리를 고를 때 물과 이어진 것으로 보는 글자 (다리·물 위 돌 아래도 물, v0.64)
const WATERY := ["w", "=", "|", "q", "Q"]
const SHEET := "res://Assets/Generated/field/%s.png"
## 못 지나가는 글자: 물·단 + 모든 물체 (나무 군락·한 그루 나무·돌·덤불·큰 바위·작은 나무·기계·상자·물 위 돌, v0.64)
const BLOCKED := ["w", "h", "T", "Y", "o", "b", "O", "i", "m", "c", "q", "Q"]
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


## 여러 칸 오브젝트의 칸이 그 물체의 몇 번째 열(horizontal, size칸)·줄인가. 이어진 같은 글자 줄의 시작부터 짝짓되,
## 맵 왼쪽·위 끝에 닿은 줄은 끝(오른쪽·아래)에 맞춰 짝지어 맵 밖으로 잘린 물체처럼 보이게 한다 (v0.49).
static func _part(rows: Array, x: int, y: int, horizontal: bool, ch: String, size: int) -> int:
	var at := func(i: int) -> bool:
		var cx := i if horizontal else x
		var cy := y if horizontal else i
		return _is(rows, cx, cy, ch)
	var pos := x if horizontal else y
	var start := pos
	while at.call(start - 1):
		start -= 1
	var end := pos
	while at.call(end + 1):
		end += 1
	if start == 0:
		return size - 1 - (end - pos) % size
	return (pos - start) % size


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
		var other := String(rows[ny])[nx]
		return other == ch or (ch == "w" and other in WATERY)
	if ch == "T":
		return _cluster_index(rows, x, y)
	if OBJECTS.has(ch):
		var o: Array = OBJECTS[ch]
		return o[0] + _part(rows, x, y, false, ch, o[2]) * o[1] + _part(rows, x, y, true, ch, o[1])
	match ch:
		".":
			var side := _cluster_side(rows, x, y)
			if side >= 0:
				return side
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
		"o":
			return ROCK
		"b":
			return BUSH
		"v":
			return LEAF_BUSH
		"c":
			return CRATE
		"q":
			return WATER_ROCK
		"=":   # 가로 다리: 왼쪽·오른쪽 끝은 기둥 띠가 있는 칸
			return BRIDGE_H + (0 if not _is(rows, x - 1, y, "=") else (2 if not _is(rows, x + 1, y, "=") else 1))
		"|":
			return BRIDGE_V + (0 if not _is(rows, x, y - 1, "|") else (2 if not _is(rows, x, y + 1, "|") else 1))
		"f":   # 꽃밭: 자리마다 4종 중 하나
			return FLOWERS + (x * 3 + y * 5) % FLOWER_KINDS
	return 0


## 나무 군락(T) 칸 번호 (v0.64). 가로: 이어진 T 줄의 시작부터 0, 1, 2, 1, 2 … (두 칸 = 한 그루, 마지막 그루 오른쪽은 3).
## 세로: 아래 끝이 밑동(3), 그 위로 몸통(2) → 꼭대기(1) → 뒤 나무와 겹친 부분(0) 을 되풀이 — 짙은 숲은 위로 쌓여 이어진다.
static func _cluster_index(rows: Array, x: int, y: int) -> int:
	var s := x
	while _is(rows, s - 1, y, "T"):
		s -= 1
	var e := x
	while _is(rows, e + 1, y, "T"):
		e += 1
	var i := x - s
	var col := 0
	if i > 0:
		col = (3 if x == e else 1) if i % 2 == 1 else 2
	var bottom := y
	while _is(rows, x, bottom + 1, "T"):
		bottom += 1
	var d := bottom - y
	var row: int = 3 if d == 0 else [2, 1, 0][(d - 1) % 3]
	return CLUSTER + row * 4 + col


## 땅(.) 칸이 나무 군락의 첫 그루 바로 왼쪽 / 마지막 그루 바로 오른쪽이면 그 줄의 옆 칸 번호, 아니면 -1.
## 끝이 홀수 칸이라 잘린 그루(열 2)로 끝나면 옆 칸을 두지 않는다.
static func _cluster_side(rows: Array, x: int, y: int) -> int:
	if _is(rows, x + 1, y, "T"):
		var i := _cluster_index(rows, x + 1, y) - CLUSTER
		if i % 4 == 0:
			return CLUSTER_SIDE + (i / 4) * 2
	if _is(rows, x - 1, y, "T"):
		var i := _cluster_index(rows, x - 1, y) - CLUSTER
		if i % 4 == 3:
			return CLUSTER_SIDE + (i / 4) * 2 + 1
	return -1


## (x, y) 칸이 ch 인가 (맵 밖은 아님)
static func _is(rows: Array, x: int, y: int, ch: String) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < String(rows[y]).length() and String(rows[y])[x] == ch
