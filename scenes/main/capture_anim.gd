class_name CaptureAnim
extends Node2D
## 포획 연출 (기획서 4.3, v0.50): 게이지를 다 채우면
##   1) 전투 칸 왼쪽 아래에서 볼이 돌며 포물선으로 날아가
##   2) 포켓몬 위에서 열리고, 포켓몬이 하얗게 빛나며 작아져 볼 속으로 빨려 들어간 뒤
##   3) 볼이 닫혀 발판에 떨어져 한 번 튀고
##   4) 3번 흔들린 다음 볼에서 별 3개가 튀어 나와 날아가며 잡힌다 → finished (v0.51~0.52: 색이 다른 등장 반짝임과 다른 효과)
## 실패는 없다(게이지를 다 채우면 언제나 잡힘). 연출 중 클릭은 받지 않는다.
## 그림: Assets/Generated/ui/balls/<볼 id>.png (tools/make_ball_frames.py) — 16×24 칸 10개
##   0~7 회전(0 = 똑바로 선 모습), 8 납작(바닥에 부딪힌 모습, 쓰지 않음), 9 열림. 위치(position) = 볼 아래 가운데.
##   v0.51: 놓인 볼·흔들림은 0번(똑바로 선 모습). v0.50 은 8번(납작)을 써서 볼이 가로로 찌그러져 보였다.

signal finished

const BALL_DIR := "res://Assets/Generated/ui/balls/%s.png"
const CELL := Vector2(16, 24)
const SPIN_FRAMES := 8
const FRONT_FRAME := 0
const OPEN_FRAME := 9

const THROW_SEC := 0.6
const THROW_ARC := 46.0          # 포물선 높이 (px)
const SPIN_SEC := 0.06           # 회전 프레임 간격
const ABSORB_SEC := 0.45
const DROP_SEC := 0.3
const BOUNCE_PX := 6.0
const SHAKES := 3
const SHAKE_WAIT_SEC := 0.45
const SHAKE_DEG := 22.0
const SHAKE_SEC := 0.12
const CLICK_WAIT_SEC := 0.35
## 흔들림 소리 피치 범위 (매번 무작위, v0.54)
const WOBBLE_PITCH := Vector2(0.9, 1.1)
## 볼 그림 높이 (칸 아래 16px)
const BALL_PX := 16.0

var _ball: Sprite2D
var _spin_t := 0.0
var _spinning := false
var _frame_spin := 0
var _from := Vector2.ZERO
var _stars: CatchStars
var _to := Vector2.ZERO


func _ready() -> void:
	_ball = Sprite2D.new()
	_ball.centered = false
	_ball.offset = Vector2(-CELL.x / 2.0, -CELL.y)
	_ball.hframes = 10
	_ball.visible = false
	add_child(_ball)


static func ball_texture(ball_id: StringName) -> Texture2D:
	var path := BALL_DIR % ball_id
	if not ResourceLoader.exists(path):
		path = BALL_DIR % "poke_ball"
	return load(path) if ResourceLoader.exists(path) else null


func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_t += delta
	while _spin_t >= SPIN_SEC:
		_spin_t -= SPIN_SEC
		_frame_spin = (_frame_spin + 1) % SPIN_FRAMES
		_ball.frame = _frame_spin


func _throw_step(t: float) -> void:
	_ball.position = _from.lerp(_to, t) + Vector2(0, -THROW_ARC * 4.0 * t * (1.0 - t))


## from: 던지는 곳, to: 볼이 열리는 곳(포켓몬 가운데 위), rest_y: 볼이 떨어져 놓이는 높이(발판),
## pokemon: 빨려 들어갈 포켓몬 그림. 끝나면 finished.
func play(ball_id: StringName, from: Vector2, to: Vector2, rest_y: float, pokemon: Node2D) -> void:
	var tex := ball_texture(ball_id)
	if tex == null:
		finished.emit.call_deferred()
		return
	_ball.texture = tex
	_ball.frame = 0
	_ball.rotation = 0.0
	_ball.position = from
	_ball.visible = true

	# 1) 던지기: 돌면서 포물선
	AudioManager.play(&"ball_throw")
	_spinning = true
	var throw := create_tween()
	_from = from
	_to = to
	throw.tween_method(_throw_step, 0.0, 1.0, THROW_SEC)
	await throw.finished
	_spinning = false

	# 2) 열리고 포켓몬이 하얗게 빛나며 볼 속으로
	_ball.frame = OPEN_FRAME
	AudioManager.play(&"ball_open")   # v0.62
	if pokemon:
		var base_scale := pokemon.scale
		var absorb := create_tween().set_parallel()
		absorb.tween_property(pokemon, ^"modulate", Color(6, 6, 6, 1), ABSORB_SEC * 0.35)
		absorb.chain().tween_property(pokemon, ^"scale", base_scale * 0.05, ABSORB_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		absorb.tween_property(pokemon, ^"global_position", to + Vector2(0, -CELL.y * 0.6), ABSORB_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		absorb.tween_property(pokemon, ^"modulate:a", 0.0, ABSORB_SEC)
		await absorb.finished
		pokemon.hide()
		pokemon.scale = base_scale
		pokemon.modulate = Color.WHITE

	# 3) 닫혀서 발판에 떨어지고 한 번 튄다
	_ball.frame = FRONT_FRAME
	var drop := create_tween()
	drop.tween_property(_ball, ^"position:y", rest_y, DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(AudioManager.play.bind(&"ball_drop"))   # 발판에 처음 닿는 순간 (v0.62)
	drop.tween_property(_ball, ^"position:y", rest_y - BOUNCE_PX, DROP_SEC * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop.tween_property(_ball, ^"position:y", rest_y, DROP_SEC * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(AudioManager.play.bind(&"ball_drop"))   # 튀었다가 다시 닿는 순간 (2번째)
	await drop.finished

	# 4) 3번 흔들림 (볼 아래를 축으로 좌우)
	for i in SHAKES:
		await get_tree().create_timer(SHAKE_WAIT_SEC).timeout
		AudioManager.play(&"ball_wobble", randf_range(WOBBLE_PITCH.x, WOBBLE_PITCH.y))
		var shake := create_tween()
		var deg := deg_to_rad(SHAKE_DEG)
		shake.tween_property(_ball, ^"rotation", -deg, SHAKE_SEC).set_trans(Tween.TRANS_SINE)
		shake.tween_property(_ball, ^"rotation", deg, SHAKE_SEC * 2.0).set_trans(Tween.TRANS_SINE)
		shake.tween_property(_ball, ^"rotation", 0.0, SHAKE_SEC).set_trans(Tween.TRANS_SINE)
		await shake.finished
	await get_tree().create_timer(CLICK_WAIT_SEC).timeout

	# 잡았다: "착" + 볼에서 별 3개
	AudioManager.play(&"ball_catch")
	_stars = CatchStars.new()
	_stars.position = _ball.position + Vector2(0, -BALL_PX)
	add_child(_stars)
	await get_tree().create_timer(CatchStars.LIFE_SEC).timeout
	finished.emit()


## 볼을 치운다 (다음 인카운터)
func clear() -> void:
	_spinning = false
	if is_instance_valid(_stars):
		_stars.queue_free()
	_stars = null
	_ball.visible = false
	_ball.rotation = 0.0


## 연출 전체 길이 (초, 대략)
static func total_sec() -> float:
	return THROW_SEC + ABSORB_SEC + DROP_SEC * 1.8 + SHAKES * (SHAKE_WAIT_SEC + SHAKE_SEC * 4.0) + CLICK_WAIT_SEC + CatchStars.LIFE_SEC


## 잡힌 순간 볼에서 튀어 나와 날아가는 별 3개 (v0.51, v0.52). 위치 = 볼 꼭대기.
## 왼쪽 위·위·오른쪽 위로 튀어 나가며(처음 속도 VELOCITIES) 중력으로 조금씩 휘고, 날아가는 동안 서서히 사라진다.
## 하얀색에 가까운 연노란색, 테두리·밝은 점 없음 (v0.52). 정수 픽셀로 그림.
## v0.73: 별마다 무작위 방향(시계/반시계)·속도로 돈다. 돌린 모양도 픽셀 격자에 맞춰 그린다(각 칸을 거꾸로 돌려 SHAPE 에서 고름).
class CatchStars:
	extends Node2D

	const LIFE_SEC := 0.85
	const FADE_FROM := 0.45          # 이 비율부터 흐려짐
	const GRAVITY := 70.0            # px/초²
	const VELOCITIES := [Vector2(-34, -52), Vector2(0, -66), Vector2(34, -52)]
	const COL_FILL := Color(1.0, 0.98, 0.8)
	## 도는 속도 범위 (라디안/초). 방향(부호)은 별마다 무작위 (v0.73)
	const SPIN_MIN := 5.0
	const SPIN_MAX := 10.0

	## 11×11 다섯 꼭지 별 (v0.53: 7×7 의 1.5배)
	const SHAPE := [
		".....X.....",
		"....XXX....",
		"....XXX....",
		"...XXXXX...",
		"XXXXXXXXXXX",
		".XXXXXXXXX.",
		"..XXXXXXX..",
		"..XXXXXXX..",
		".XXXX.XXXX.",
		".XXX...XXX.",
		"XX.......XX",
	]
	const HALF := 5

	var _t := 0.0
	## 별마다 도는 속도 (라디안/초, 음수 = 반시계). 비어 있으면 _ready 에서 무작위로 정한다
	var spins: Array[float] = []

	func _ready() -> void:
		if spins.is_empty():
			for i in VELOCITIES.size():
				spins.append(randf_range(SPIN_MIN, SPIN_MAX) * (1.0 if randf() < 0.5 else -1.0))

	## angle 만큼 돌린 별의 픽셀들 (중심 기준 정수 칸). 각 칸을 거꾸로 돌려 SHAPE 에서 골라 빈틈 없이
	static func rotated_pixels(angle: float) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var r := HALF + 2
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var src := Vector2(x, y).rotated(-angle).round() + Vector2(HALF, HALF)
				var sx := int(src.x)
				var sy := int(src.y)
				if sy >= 0 and sy < SHAPE.size() and sx >= 0 and sx < SHAPE[sy].length() and SHAPE[sy][sx] == "X":
					out.append(Vector2i(x, y))
		return out

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE_SEC:
			queue_free()
			return
		queue_redraw()

	## t 초 뒤 i 번째 별의 위치 (볼 꼭대기 기준)
	static func star_pos(i: int, t: float) -> Vector2:
		var v: Vector2 = VELOCITIES[i]
		return v * t + Vector2(0, 0.5 * GRAVITY * t * t)

	func _draw() -> void:
		var k := _t / LIFE_SEC
		var a := 1.0 - clampf((k - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
		var col := Color(COL_FILL, a)
		for i in VELOCITIES.size():
			var c := star_pos(i, _t).round()
			var angle: float = spins[i] * _t if i < spins.size() else 0.0
			for p in rotated_pixels(angle):
				draw_rect(Rect2(c + Vector2(p), Vector2.ONE), col)
