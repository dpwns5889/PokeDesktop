class_name WindowLayout
extends RefCounted
## 창 배치 계산 (순수 함수). WindowManager가 사용한다. (기획서 2.2, 3장)

## 448×200 (v0.46): 왼쪽 320 = 기존 UI, 오른쪽 128 = 전투 칸
const BASE_SIZE := Vector2i(448, 200)
const MIN_SCALE := 1
const MAX_SCALE := 4
## 기본 위치(우하단) 근처 이 거리 안에 놓으면 기본 위치에 붙인다(도킹).
const DOCK_SNAP_DISTANCE := 12


## 첫 실행 시 자동 배율. 화면 세로 1440 이상 3×, 1080 이상 2×, 그 미만 1×.
static func auto_scale(screen_size: Vector2i) -> int:
	if screen_size.y >= 1440:
		return 3
	if screen_size.y >= 1080:
		return 2
	return 1


## 사용 가능 영역에 들어가는 최대 배율.
static func max_scale_for(usable: Rect2i) -> int:
	var fit := mini(usable.size.x / BASE_SIZE.x, usable.size.y / BASE_SIZE.y)
	return clampi(fit, MIN_SCALE, MAX_SCALE)


## 요청 배율을 허용 범위와 화면 크기에 맞춘다.
static func clamp_scale(requested: int, usable: Rect2i) -> int:
	return clampi(requested, MIN_SCALE, max_scale_for(usable))


static func window_size(scale: int) -> Vector2i:
	return BASE_SIZE * scale


## 기본 위치 = 작업표시줄을 제외한 영역의 오른쪽 아래 (v0.12, 이전에는 왼쪽 아래)
static func dock_position(usable: Rect2i, size: Vector2i) -> Vector2i:
	return bottom_right(usable, size)


static func bottom_right(usable: Rect2i, size: Vector2i) -> Vector2i:
	return Vector2i(usable.end.x - size.x, usable.end.y - size.y)


static func bottom_left(usable: Rect2i, size: Vector2i) -> Vector2i:
	return Vector2i(usable.position.x, usable.end.y - size.y)


## 창이 영역 밖으로 나가지 않도록 위치를 보정한다.
static func clamp_into(pos: Vector2i, size: Vector2i, usable: Rect2i) -> Vector2i:
	var max_x := maxi(usable.position.x, usable.end.x - size.x)
	var max_y := maxi(usable.position.y, usable.end.y - size.y)
	return Vector2i(clampi(pos.x, usable.position.x, max_x), clampi(pos.y, usable.position.y, max_y))


## 배율을 바꿀 때 창의 오른쪽 아래 모서리를 고정한 새 위치 (기본 위치가 우하단이므로).
static func rescale_keep_bottom_right(pos: Vector2i, old_size: Vector2i, new_size: Vector2i) -> Vector2i:
	return pos + old_size - new_size


## 위치가 기본 위치(우하단) 근처인지.
static func is_near_dock(pos: Vector2i, size: Vector2i, usable: Rect2i) -> bool:
	var target := dock_position(usable, size)
	return absi(pos.x - target.x) <= DOCK_SNAP_DISTANCE and absi(pos.y - target.y) <= DOCK_SNAP_DISTANCE


## 화면 목록(Rect2i 배열) 중 창과 가장 많이 겹치는 화면의 인덱스. 하나도 겹치지 않으면 -1.
static func screen_index_for(pos: Vector2i, size: Vector2i, screens: Array[Rect2i]) -> int:
	var win := Rect2i(pos, size)
	var best := -1
	var best_area := 0
	for i in screens.size():
		var inter := screens[i].intersection(win)
		var area := inter.size.x * inter.size.y
		if area > best_area:
			best_area = area
			best = i
	return best

