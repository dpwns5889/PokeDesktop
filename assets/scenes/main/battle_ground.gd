class_name BattleGround
extends Sprite2D
## 지역 바닥 발판 (기획서 6.1, v0.37 — 예전 풀숲을 대신한다).
## - 언제나 장면 오른쪽 아래에 있고, 야생 포켓몬은 이 위에 나타난다.
## - 지역마다 그림이 다르다: RegionData.battle_ground = assets/generated/ui/ground.png 의 칸 번호
##   (0 풀밭 1 물 2 모래 3 흙길 4 얼음 5 진흙 6 바위 7 눈 8 어두운 바위). set_region() 으로 바꾼다.
## - 인카운터 예고(풀숲 흔들림 자리) 동안 shaking = true → 좌우로 덜덜 떨린다.
## 위치 = 타원 중심(기준 해상도). 그림이 없으면 아무것도 그리지 않는다.

const SHEET := "res://assets/generated/ui/ground.png"
const CELL := Vector2(128, 64)
## 떨림: 좌우 SHAKE_PX 픽셀, 초당 SHAKE_HZ 번
const SHAKE_PX := 2.0
const SHAKE_HZ := 14.0

## 지금 보여 주는 칸 번호
var index := 0
var shaking := false:
	set(v):
		shaking = v
		_t = 0.0
		set_process(v)
		offset = Vector2.ZERO

var _t := 0.0


func _ready() -> void:
	if ResourceLoader.exists(SHEET):
		var at := AtlasTexture.new()
		at.atlas = load(SHEET)
		at.region = Rect2(Vector2.ZERO, CELL)
		texture = at
	set_process(false)


func has_sheet() -> bool:
	return texture is AtlasTexture


## 칸 수 (시트 크기에서 계산)
func cell_count() -> int:
	if not has_sheet():
		return 0
	var atlas := (texture as AtlasTexture).atlas
	return int(atlas.get_width() / CELL.x) * int(atlas.get_height() / CELL.y)


## 지역에 맞는 칸으로 바꾼다 (지역이 없거나 번호가 범위 밖이면 0 = 풀밭)
func set_region(region: RegionData) -> void:
	set_index(region.battle_ground if region else 0)


func set_index(i: int) -> void:
	if not has_sheet():
		return
	index = i if i >= 0 and i < cell_count() else 0
	var at := texture as AtlasTexture
	var cols := int(at.atlas.get_width() / CELL.x)
	at.region = Rect2(Vector2(index % cols, index / cols) * CELL, CELL)


func _process(delta: float) -> void:
	_t += delta
	# 좌우로 덜덜 (정수 픽셀로 반올림해서 흐려지지 않게)
	offset = Vector2(roundf(sin(_t * TAU * SHAKE_HZ) * SHAKE_PX), 0)
