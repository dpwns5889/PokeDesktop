class_name CaptureGame
extends RefCounted
## 인카운터 전투(과녁 클릭 포획)의 규칙. 화면과 분리된 순수 로직이라 테스트할 수 있다. (기획서 4.3)
##
## 사용: new(params, playfield, rng) → 매 프레임 update(delta) → 클릭 시 click(pos)
## 끝나면 is_finished() / is_success().

enum HitResult { MISS, HIT, INNER_HIT }

## 과녁: {pos: Vector2, age: float}
var targets: Array[Dictionary] = []
var gauge: float = 0.0
var time_left: float

var _p: Dictionary
var _playfield: Rect2
var _avoid: Array[Rect2] = []
var _rng: RandomNumberGenerator
var _spawn_timer: float = 0.5   # 첫 과녁은 0.5초 뒤
var _finished := false
var _success := false


## playfield: 과녁이 나타날 수 있는 영역.
## avoid: 과녁이 겹치면 안 되는 영역들(게이지 표시줄, 포켓몬). 과녁 전체(반지름 포함)가 피한다.
func _init(params: Dictionary, playfield: Rect2, rng: RandomNumberGenerator, avoid: Array[Rect2] = []) -> void:
	_p = params
	_playfield = playfield
	_avoid = avoid
	_rng = rng
	time_left = params[&"time_limit"]


func radius() -> float:
	return _p[&"target_radius"]


func life() -> float:
	return _p[&"target_life"]


func is_finished() -> bool:
	return _finished


func is_success() -> bool:
	return _success


func update(delta: float) -> void:
	if _finished:
		return
	time_left -= delta
	gauge = maxf(0.0, gauge - _p[&"decay_per_sec"] * delta)

	# 수명이 다한 과녁 = 놓침
	for i in range(targets.size() - 1, -1, -1):
		targets[i].age += delta
		if targets[i].age >= life():
			targets.remove_at(i)
			_apply_penalty()

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and targets.size() < _p[&"max_targets"]:
		_spawn()
		_spawn_timer = life() * 0.5

	if time_left <= 0.0:
		time_left = 0.0
		_finished = true
		_success = false


func click(pos: Vector2) -> HitResult:
	if _finished:
		return HitResult.MISS
	var best := -1
	var best_dist := INF
	for i in targets.size():
		var d := pos.distance_to(targets[i].pos)
		if d <= radius() and d < best_dist:
			best = i
			best_dist = d
	if best < 0:
		_apply_penalty()
		return HitResult.MISS
	targets.remove_at(best)
	var inner := best_dist <= radius() * Formulas.CAPTURE_INNER_RATIO
	gauge += _p[&"fill"] * (Formulas.CAPTURE_INNER_BONUS if inner else 1.0)
	if gauge >= 1.0:
		gauge = 1.0
		_finished = true
		_success = true
	return HitResult.INNER_HIT if inner else HitResult.HIT


func _apply_penalty() -> void:
	gauge = maxf(0.0, gauge - _p[&"penalty"])


func _spawn() -> void:
	var r := radius()
	var area := _playfield.grow(-r)
	for attempt in 24:
		var pos := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if _overlaps_avoid(pos, r):
			continue
		var ok := true
		for t in targets:
			if t.pos.distance_to(pos) < r * 2.5:
				ok = false
				break
		if ok:
			targets.append({"pos": pos, "age": 0.0})
			return


func _overlaps_avoid(pos: Vector2, r: float) -> bool:
	for a in _avoid:
		if a.grow(r).has_point(pos):
			return true
	return false
