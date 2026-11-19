extends Control
## 인카운터 전투 화면: 과녁을 그리고 클릭을 CaptureGame에 전달한다. (기획서 4.3)
## 규칙은 CaptureGame(assets/scripts/logic/capture_game.gd)에 있고, 이 노드는 표시와 입력만 맡는다.

signal finished(success: bool)

## v0.46: 메인 창 오른쪽 전투 칸(128×200)에 놓인다. 좌표는 이 노드 기준(전투 칸 왼쪽 위 = 0,0).
## 세로 배치 (메인 창 companion 과 맞춤):
##   3~19 이름·성별·레벨(companion 의 BattleInfo) / 22~28 포획 게이지 + 남은 초 / 32~198 과녁
## 칸이 좁아 과녁은 야생 포켓몬 위에도 나타난다(포켓몬을 피하지 않음).
const GAUGE_RECT := Rect2(4, 22, 96, 6)
const PLAYFIELD := Rect2(2, 32, 124, 166)
const POP_SEC := 0.45

const COL_TARGET := Color(1.0, 0.95, 0.85, 0.9)
const COL_TARGET_EDGE := Color(0.15, 0.15, 0.2, 1.0)
const COL_INNER := Color(0.86, 0.25, 0.2, 1.0)
const COL_RING := Color(1, 1, 1, 0.85)
const COL_GAUGE_BG := Color(0.1, 0.12, 0.18, 0.85)
const COL_GAUGE := Color(0.35, 0.85, 0.45)
const COL_GAUGE_LOW := Color(0.95, 0.75, 0.25)
const COL_TEXT := Color(0.125, 0.125, 0.125)   # 하늘 배경 위 글자 (제목과 같은 색)

## 개발용 자동 플레이 (실행 인자 `-- --autoplay`)
var autoplay := false

var _game: CaptureGame
var _pops: Array[Dictionary] = []   # {pos, text, color, t}
var _auto_timer := 0.0
var _rng: RandomNumberGenerator
var _done := false


## pokemon_rect: 포켓몬이 그려진 영역(기준 해상도). 과녁이 포켓몬을 가리지 않게 피한다.
## extra_avoid: 그 밖에 피할 영역 (예: 왼쪽 아래 엔트리 아이콘 줄, v0.27)
func start(params: Dictionary, rng: RandomNumberGenerator, pokemon_rect: Rect2 = Rect2(),
		extra_avoid: Array[Rect2] = []) -> void:
	_rng = rng
	var avoid: Array[Rect2] = [GAUGE_RECT.grow(4)]
	if pokemon_rect.has_area():
		avoid.append(pokemon_rect)
	avoid.append_array(extra_avoid)
	_game = CaptureGame.new(params, PLAYFIELD, rng, avoid)
	set_process(true)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS   # 위치·크기는 companion 이 전투 칸에 맞춘다 (v0.46)
	set_process(false)


func _process(delta: float) -> void:
	if _game == null:
		return
	_game.update(delta)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].t += delta
		if _pops[i].t >= POP_SEC:
			_pops.remove_at(i)
	if autoplay:
		_autoplay_step(delta)
	queue_redraw()
	if _game.is_finished() and not _done:
		_done = true
		set_process(false)
		finished.emit(_game.is_success())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _game == null:
		return
	accept_event()   # 전투 중 왼쪽 클릭은 창 드래그로 넘기지 않는다
	_on_click(mb.position)


func _on_click(pos: Vector2) -> void:
	var hit := _game.click(pos)
	if hit != CaptureGame.HitResult.MISS:
		AudioManager.play(&"attack")
	match hit:
		CaptureGame.HitResult.INNER_HIT:
			_pops.append({"pos": pos, "text": "굿!", "color": Color(1, 0.9, 0.3), "t": 0.0})
		CaptureGame.HitResult.HIT:
			_pops.append({"pos": pos, "text": "+", "color": Color.WHITE, "t": 0.0})
		_:
			_pops.append({"pos": pos, "text": "-", "color": Color(1, 0.4, 0.4), "t": 0.0})


func _draw() -> void:
	if _game == null:
		return
	var r := _game.radius()
	for t in _game.targets:
		var remain: float = 1.0 - t.age / _game.life()
		draw_circle(t.pos, r, COL_TARGET)
		draw_arc(t.pos, r, 0, TAU, 24, COL_TARGET_EDGE, 1.0)
		draw_circle(t.pos, r * Formulas.CAPTURE_INNER_RATIO, COL_INNER)
		# 줄어드는 바깥 고리: 남은 시간
		draw_arc(t.pos, r * (1.0 + remain), 0, TAU, 32, COL_RING, 1.0)

	# 게이지
	draw_rect(GAUGE_RECT.grow(1), COL_GAUGE_BG)
	var fill := GAUGE_RECT
	fill.size.x *= _game.gauge
	draw_rect(fill, COL_GAUGE if _game.gauge >= 0.5 else COL_GAUGE_LOW)
	var font := get_theme_default_font()
	draw_string(font, Vector2(GAUGE_RECT.end.x + 4, GAUGE_RECT.end.y + 3), "%ds" % ceili(_game.time_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)

	for p in _pops:
		var a: float = 1.0 - p.t / POP_SEC
		var c: Color = p.color
		c.a = a
		draw_string(font, p.pos + Vector2(-6, -6 - p.t * 20.0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)


## 개발용: 사람처럼 반응 시간(0.25초)을 두고, 0.3초마다 가장 오래된 과녁을 (약간 빗나가게) 클릭한다.
func _autoplay_step(delta: float) -> void:
	_auto_timer -= delta
	if _auto_timer > 0.0 or _game.targets.is_empty() or _game.targets[0].age < 0.25:
		return
	_auto_timer = 0.3
	var t: Dictionary = _game.targets[0]
	var off := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * _game.radius() * 0.8
	_on_click(t.pos + off)
