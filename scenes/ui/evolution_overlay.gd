extends Panel
## 진화 연출. 메인 창 안에서 버튼 줄과 장면을 덮는다(HUD는 보인다). (기획서 4.9)
## 1) "○○의 상태가...!" 진화 전/후 모습이 점점 빠르게 번갈아 깜빡인다. 이때 "취소"로 멈출 수 있다.
## 2) 끝나면 진화가 확정되고 "○○는(은) ○○(으)로 진화했다!" + "확인".
## EvolutionManager 의 대기열을 하나씩 보여준다.

const AREA := Rect2(0, 0, 320, 181)
## 깜빡임 간격 (초): 점점 빨라진다
const FLASHES := [0.5, 0.42, 0.36, 0.3, 0.26, 0.22, 0.18, 0.15, 0.12, 0.1, 0.08, 0.08, 0.06, 0.06]

var _sprite: AnimatedSprite2D
var _text: Label
var _button: Button
var _from_frames: SpriteFrames
var _to_frames: SpriteFrames
var _step := 0
var _timer: Timer
var _phase := 0   # 0 = 진행 중, 1 = 끝 (확인 대기)
var _from_name := ""
var _to_name := ""


func _init() -> void:
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.13)
	add_theme_stylebox_override(&"panel", bg)

	_sprite = AnimatedSprite2D.new()
	_sprite.position = Vector2(160, 80)
	add_child(_sprite)
	_text = Label.new()
	_text.position = Vector2(8, 128)
	_text.size = Vector2(304, 20)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_text)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.position = Vector2(120, 152)
	_button.size = Vector2(80, 22)
	_button.pressed.connect(_on_button)
	add_child(_button)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_flash)
	add_child(_timer)


func _ready() -> void:
	# 보여주는 중에 다음 진화가 들어오면 "확인"을 누를 때 이어서 보여준다
	EventBus.evolution_requested.connect(func(_uid: String, _to: int) -> void:
		if not visible:
			_show_current())
	EventBus.game_reset.connect(hide)


func _show_current() -> void:
	var e := EvolutionManager.current()
	if e.is_empty():
		hide()
		return
	var p := PlayerState.find_pokemon(e.uid)
	var from := GameData.get_species(e.from)
	var to := GameData.get_species(e.to)
	if p.is_empty() or from == null or to == null:
		EvolutionManager.cancel_current()
		return
	var female: bool = p.get("gender", "") == "female"
	_from_frames = PokemonSprites.make_frames(from, female, p.get("shiny", false))
	_to_frames = PokemonSprites.make_frames(to, female, p.get("shiny", false))
	_from_name = from.name_ko
	_to_name = to.name_ko
	_sprite.sprite_frames = _from_frames
	_sprite.modulate = Color.WHITE
	_sprite.play(&"idle")
	_text.text = "어라...? %s의 모습이...!" % _from_name
	_button.text = "취소"
	_phase = 0
	_step = 0
	show()
	_timer.start(0.9)


## 진화 전/후 모습을 번갈아 보여준다 (점점 빠르게, 하얗게 빛나며)
func _flash() -> void:
	if _step >= FLASHES.size():
		_finish()
		return
	var to_turn := _step % 2 == 0
	_sprite.sprite_frames = _to_frames if to_turn else _from_frames
	_sprite.play(&"idle")
	_sprite.modulate = Color(3, 3, 3)   # 실루엣처럼 하얗게
	_timer.start(FLASHES[_step])
	_step += 1


func _finish() -> void:
	var r := EvolutionManager.confirm_current()
	_phase = 1
	_sprite.modulate = Color.WHITE
	if r.ok:
		_sprite.sprite_frames = _to_frames
		_sprite.play(&"idle")
		_text.text = "%s는(은) %s(으)로 진화했다!" % [_from_name, _to_name]
	else:
		_sprite.sprite_frames = _from_frames
		_text.text = r.reason
	_button.text = "확인"


func _on_button() -> void:
	if _phase == 0:
		_timer.stop()
		_sprite.sprite_frames = _from_frames
		_sprite.modulate = Color.WHITE
		_text.text = "%s의 변화가 멈췄다." % _from_name
		_phase = 2
		_button.text = "확인"
		EvolutionManager.cancel_current.call_deferred()   # 다음 진화가 있으면 그때 다시 보여준다
		return
	# 확인: 다음 진화가 대기 중이면 evolution_requested 로 다시 열린다
	if EvolutionManager.current().is_empty():
		hide()
	else:
		_show_current()
