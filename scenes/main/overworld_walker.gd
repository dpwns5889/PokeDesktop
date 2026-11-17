class_name OverworldWalker
extends Node2D
## 메인 화면 안을 걸어다니는 엔트리 포켓몬 (기획서 6.1, M12, v0.45).
## - HGSS 오버월드 걷기 시트(64×128, 행: 아래·위·왼쪽·오른쪽, 열: 2프레임)를 쓴다 (PokemonSprites.overworld_walk_sheet).
## - 위치(position) = 발 위치. 발은 언제나 bounds 안에 머문다 → 그림이 창 밖으로 나가지 않는다.
## - 행동: 잠깐 쉬기(가끔 고개만 돌림) → 네 방향 중 하나로 조금 걷기 → 쉬기 … 를 반복.
##   쉬는 중에도 제자리 걸음 2프레임을 천천히 번갈아 HGSS 데리고 다니기처럼 보이게 한다.
## - 지켜보기(watch): 인카운터·전투 중에는 멈춰서 지정한 곳(바닥 발판)을 바라본다.
## - 마우스 입력은 받지 않는다(Node2D) → 과녁 클릭·창 드래그를 막지 않는다.

enum Dir { DOWN, UP, LEFT, RIGHT }
const CELL := 32
## 걷는 속도 (기준 해상도 px/초)
const SPEED := 18.0
## 걷기 프레임 전환 간격 / 쉬는 중 제자리 걸음 간격
const WALK_FRAME_SEC := 0.2
const IDLE_FRAME_SEC := 0.45
## 쉬는 시간 (초)
const IDLE_MIN := 1.5
const IDLE_MAX := 5.0
## 한 번에 걷는 거리 (px)
const WALK_MIN := 16.0
const WALK_MAX := 72.0
## 쉬고 난 뒤 걷지 않고 고개만 돌릴 확률
const TURN_ONLY_CHANCE := 0.3
## 발밑 그림자 (반지름 px)
const SHADOW_RADIUS := Vector2(7, 2.5)
const DIR_VEC := {Dir.DOWN: Vector2.DOWN, Dir.UP: Vector2.UP, Dir.LEFT: Vector2.LEFT, Dir.RIGHT: Vector2.RIGHT}

## 발 위치가 머무는 영역 (부모 좌표)
var bounds := Rect2()
## 못 지나가는 곳인가 (발 위치 → bool, v0.48 들판 타일맵). 비어 있으면 bounds 만 지킨다.
var blocked := Callable()
## 이 걷는 포켓몬이 누구인지 (개체 uid) / 그림이 바뀌었는지 판단하는 키 (종·성별)
var uid := ""
var look_key := ""
var rng := RandomNumberGenerator.new()
var dir: int = Dir.DOWN
var walking := false
var watching := false

var _pos := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _anim_t := 0.0
var _frame := 0
var _sprite: Sprite2D
var _shadow: Polygon2D
## 걷기 시트가 없어 아이콘 한 장으로 대신하는 중
var _single := false


func _init() -> void:
	_shadow = Polygon2D.new()
	_shadow.color = Color(0, 0, 0, 0.22)
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * SHADOW_RADIUS.x, sin(a) * SHADOW_RADIUS.y))
	_shadow.polygon = pts
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)


## 그림과 영역·시작 위치를 정한다. sheet 가 없으면 fallback(아이콘 한 장)을 쓴다.
func setup(sheet: Texture2D, fallback: Texture2D, area: Rect2, start: Vector2) -> void:
	bounds = area
	set_look(sheet, fallback)
	_pos = _clamp(start)
	_target = _pos
	_wait = rng.randf_range(0.3, IDLE_MAX)
	_apply()


## 그림만 바꾼다 (진화 등). 위치·행동은 그대로.
func set_look(sheet: Texture2D, fallback: Texture2D) -> void:
	_single = sheet == null
	if _single:
		_sprite.texture = fallback
		_sprite.hframes = 1
		_sprite.vframes = 1
		_sprite.frame = 0
		var s := fallback.get_size() if fallback else Vector2(CELL, CELL)
		_sprite.offset = Vector2(-s.x / 2.0, -s.y)
	else:
		_sprite.texture = sheet
		_sprite.hframes = 2
		_sprite.vframes = 4
		_sprite.offset = Vector2(-CELL / 2.0, -feet_offset(sheet))
	_apply()


## 시트에서 그림이 실제로 끝나는 높이(칸 위에서부터 px) = 발 위치. 모든 칸 중 가장 아래.
static func feet_offset(sheet: Texture2D) -> float:
	var img := sheet.get_image()
	if img == null:
		return CELL
	if img.is_compressed():
		img.decompress()
	var bottom := 0
	for r in 4:
		for c in 2:
			var used := img.get_region(Rect2i(c * CELL, r * CELL, CELL, CELL)).get_used_rect()
			if used.size != Vector2i.ZERO:
				bottom = maxi(bottom, used.end.y)
	return float(bottom if bottom > 0 else CELL)


## 지켜보기 시작/끝. 시작하면 멈춰서 point(부모 좌표)를 바라본다.
func set_watching(on: bool, point: Vector2 = Vector2.ZERO) -> void:
	watching = on
	if on:
		walking = false
		_target = _pos
		dir = dir_toward(point - _pos)
	else:
		_wait = rng.randf_range(0.5, 2.0)
	_apply()


## 벡터 방향 → 네 방향 중 가장 가까운 것 (가로·세로 중 큰 쪽)
static func dir_toward(v: Vector2) -> int:
	if v == Vector2.ZERO:
		return Dir.DOWN
	if absf(v.x) >= absf(v.y):
		return Dir.RIGHT if v.x > 0 else Dir.LEFT
	return Dir.DOWN if v.y > 0 else Dir.UP


func foot_position() -> Vector2:
	return _pos


func current_frame() -> int:
	return _sprite.frame


func _process(delta: float) -> void:
	step(delta)


## 한 프레임 진행 (테스트에서 직접 부른다)
func step(delta: float) -> void:
	_anim_t += delta
	var frame_sec := WALK_FRAME_SEC if walking else IDLE_FRAME_SEC
	if _anim_t >= frame_sec:
		_anim_t = fmod(_anim_t, frame_sec)
		_frame = 1 - _frame
	if not watching:
		if walking:
			_pos = _pos.move_toward(_target, SPEED * delta)
			if _pos.is_equal_approx(_target):
				walking = false
				_wait = rng.randf_range(IDLE_MIN, IDLE_MAX)
		else:
			_wait -= delta
			if _wait <= 0.0:
				_next_move()
	_apply()


## 쉬기가 끝났을 때: 고개만 돌리거나, 네 방향 중 하나로 걷기 시작
func _next_move() -> void:
	if rng.randf() < TURN_ONLY_CHANCE:
		dir = rng.randi_range(0, 3)
		_wait = rng.randf_range(IDLE_MIN, IDLE_MAX)
		return
	for _try in 4:
		var d := rng.randi_range(0, 3)
		var goal := _clamp(_pos + DIR_VEC[d] * rng.randf_range(WALK_MIN, WALK_MAX))
		goal = _clear_until(goal)
		if goal.distance_to(_pos) >= 4.0:
			dir = d
			_target = goal
			walking = true
			return
	_wait = rng.randf_range(0.5, 1.5)   # 구석이라 갈 곳이 없으면 잠깐 뒤 다시


## 지금 위치에서 goal 쪽으로 막히기 직전까지 (2px 간격으로 몸 폭 양 끝과 가운데를 본다)
func _clear_until(goal: Vector2) -> Vector2:
	if not blocked.is_valid():
		return goal
	var dist := _pos.distance_to(goal)
	var step := (goal - _pos).normalized()
	var last := _pos
	var t := 0.0
	while t < dist:
		t = minf(t + 2.0, dist)   # 마지막에는 도착 지점 자체도 본다
		var p := _pos + step * t
		if is_blocked_at(p):
			return last
		last = p
	return goal


## 몸 폭(발 좌우 5px)과 가운데 중 하나라도 막힌 곳에 닿는가
func is_blocked_at(p: Vector2) -> bool:
	if not blocked.is_valid():
		return false
	for dx in [-5.0, 0.0, 5.0]:
		if blocked.call(p + Vector2(dx, 0)):
			return true
	return false


## 막히지 않은 곳으로 옮긴다 (지역이 바뀌어 나무·물 위에 서게 됐을 때 등). 못 찾으면 그대로.
func relocate_if_blocked() -> void:
	if not is_blocked_at(_pos):
		return
	for _try in 200:
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not is_blocked_at(p):
			_pos = p
			_target = p
			walking = false
			_apply()
			return


func _clamp(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x, bounds.end.x), clampf(p.y, bounds.position.y, bounds.end.y))


func _apply() -> void:
	position = _pos.round()
	if not _single and _sprite.texture != null:
		_sprite.frame = dir * 2 + _frame
