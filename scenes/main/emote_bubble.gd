class_name EmoteBubble
extends Node2D
## 풀숲 위 말풍선 (기획서 6.1, v0.33).
## - 대기 중: ".", "..", "..." 를 차례로 반복 (DOT_SEC 마다)
## - 인카운터 발생(풀숲 흔들림): "!" 가 작게 시작해 2배 크기로 확 커지며 나타난다 (v0.34: 1.5배 → 2배)
## - 타이머가 멈춤(선택한 볼이 없음 등): "?" 두 장을 번갈아 (v0.34)
## - 그 밖(포켓몬 등장·전투·결과): 숨김
## 위치 = 말풍선 꼬리 끝(아래 가운데). 크기를 바꿔도 꼬리 끝이 제자리에 있다.
## 그림: Assets/Generated/ui/emote.png (tools/import_emote.gd). 없으면 아무것도 그리지 않는다.

const SHEET := "res://Assets/Generated/ui/emote.png"
const CELL := 16
const DOT_FRAMES := [0, 1, 2]
const ALERT_FRAME := 3
const QUESTION_FRAMES := [4, 5]
const DOT_SEC := 0.45
const QUESTION_SEC := 0.45
const ALERT_SCALE := 2.0
const POP_SEC := 0.12

enum Mode { HIDDEN, WAITING, ALERT, QUESTION }

var mode: Mode = Mode.HIDDEN
var _frames: Array[Texture2D] = []
var _dot := 0
var _t := 0.0
var _tween: Tween


func _ready() -> void:
	if ResourceLoader.exists(SHEET):
		var tex: Texture2D = load(SHEET)
		for i in tex.get_width() / CELL:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(CELL * i, 0, CELL, CELL)
			_frames.append(at)
	visible = false
	set_process(false)


func has_frames() -> bool:
	return _frames.size() > QUESTION_FRAMES.back()


## 대기: 점 애니메이션 (처음은 "." 부터)
func show_waiting() -> void:
	if mode == Mode.WAITING:
		return
	_kill_tween()
	mode = Mode.WAITING
	_dot = 0
	_t = 0.0
	scale = Vector2.ONE
	visible = has_frames()
	set_process(true)
	queue_redraw()


## 타이머 멈춤: "?" 두 장 번갈아
func show_question() -> void:
	if mode == Mode.QUESTION:
		return
	_kill_tween()
	mode = Mode.QUESTION
	_dot = 0
	_t = 0.0
	scale = Vector2.ONE
	visible = has_frames()
	set_process(true)
	queue_redraw()


## 인카운터: "!" 가 갑자기 2배로 커지며 나타난다
func show_alert() -> void:
	_kill_tween()
	mode = Mode.ALERT
	set_process(false)
	visible = has_frames()
	scale = Vector2(0.2, 0.2)
	queue_redraw()
	_tween = create_tween()
	_tween.tween_property(self, ^"scale", Vector2(ALERT_SCALE, ALERT_SCALE), POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_bubble() -> void:
	_kill_tween()
	mode = Mode.HIDDEN
	visible = false
	set_process(false)


## 지금 그리는 칸 (테스트용): 0 ".", 1 "..", 2 "...", 3 "!", 4·5 "?"
func current_frame() -> int:
	match mode:
		Mode.ALERT:
			return ALERT_FRAME
		Mode.QUESTION:
			return QUESTION_FRAMES[_dot % QUESTION_FRAMES.size()]
	return DOT_FRAMES[_dot % DOT_FRAMES.size()]


func _process(delta: float) -> void:
	var step := QUESTION_SEC if mode == Mode.QUESTION else DOT_SEC
	var count := QUESTION_FRAMES.size() if mode == Mode.QUESTION else DOT_FRAMES.size()
	_t += delta
	if _t >= step:
		_t -= step
		_dot = (_dot + 1) % count
		queue_redraw()


func _draw() -> void:
	if not has_frames() or mode == Mode.HIDDEN:
		return
	# 꼬리 끝(아래 가운데)이 원점에 오도록
	draw_texture(_frames[current_frame()], Vector2(-CELL / 2.0, -CELL))


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
