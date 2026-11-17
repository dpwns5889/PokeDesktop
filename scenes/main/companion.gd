extends Control
## 메인 컴패니언 창 (320×200). (기획서 6.1)
## 레이아웃: 위 버튼 줄(18px) / 장면 / 아래 HUD(19px)
## - 위 버튼 줄 왼쪽: 도감·보관함·지역·원정·가방·상점 → 장면을 덮는 패널(OverlayPanel). 별도 OS 창은 쓰지 않는다.
## - 위 버튼 줄 오른쪽: 설정(톱니바퀴, 창·소리·개발용) / 종료(X)
## - 배경 드래그 이동, Ctrl+휠 배율 (M1)
## - 우클릭 메뉴: 개발(디버그) 빌드에서만 — 지금 인카운터, 돈 +10,000원, 저장 초기화
## - 인카운터: 풀숲 흔들림 → 포켓몬 등장 → 클릭하면 전투 → 결과 (M3)
## - 풀숲 위 말풍선(v0.33): 대기 중 ". .. ..." 반복, 인카운터가 나면 "!" 가 2배로 확 커지며 나타남,
##   타이머가 멈추면(선택한 볼이 없음) "?" (v0.34)
## - 장면 왼쪽 아래: 엔트리 포켓몬 오버월드 앞모습(걷기 애니메이션, 누르면 파티 패널) / 오른쪽 위: 엔트리로 받는 버프 (v0.27, 기획서 6.1)
## 상태는 EncounterManager가 갖고, 이 화면은 EventBus 시그널을 받아 표시만 바꾼다.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const ConfirmPanel := preload("res://scenes/ui/confirm_panel.gd")
const CaughtPanel := preload("res://scenes/ui/caught_panel.gd")
const EvolutionOverlay := preload("res://scenes/ui/evolution_overlay.gd")
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")
## 위 버튼 줄: [ID, 표시 이름, 패널 스크립트]
const PANELS := [
	[&"dex", "도감", preload("res://scenes/ui/dex_panel.gd")],
	[&"party", "파티", preload("res://scenes/ui/party_panel.gd")],
	[&"storage", "보관함", preload("res://scenes/ui/storage_panel.gd")],
	[&"region", "지역", preload("res://scenes/ui/region_panel.gd")],
	[&"expedition", "원정", preload("res://scenes/ui/expedition_panel.gd")],
	[&"bag", "가방", preload("res://scenes/ui/bag_panel.gd")],
	[&"shop", "상점", preload("res://scenes/ui/shop_panel.gd")],
]
const WIDTH := 320.0
## 지역 바닥 발판(예전 풀숲 자리, v0.37): 타원 중심 위치(기준 해상도). 포켓몬은 이 위에 나타난다.
const BATTLE_GROUND_POS := Vector2(240, 159)   # v0.38: 6px 위로
## 포켓몬 발(그림의 실제 아래 끝)이 오는 높이 = 발판 타원 중심보다 조금 아래 (v0.38)
const POKEMON_FEET_Y := BATTLE_GROUND_POS.y + 3.0
## 포켓몬 전투 스프라이트 칸 크기 (PokemonSprites.CELL)
const POKEMON_CELL := 80.0
## 나는 포켓몬 (v0.39, v0.40): 발판 위로 FLOAT_HEIGHT 만큼 띄우고 위아래로 천천히 흔들며, 발판에 그림자를 둔다.
## 타입이 아니라 전투 스프라이트가 공중에 떠 있는 모습인 종만 띄운다(스프라이트를 보고 고른 목록, v0.40).
const FLOAT_HEIGHT := 16.0
const FLOAT_BOB_PX := 3.0
const FLOAT_BOB_SEC := 0.9
## 스프라이트가 떠 있는 종: 버터플·독침붕·피죤투·깨비드릴조·주뱃·골뱃·도나리·코일·레어코일·고오스·고우스트·
## 또가스·또도가스·프테라·프리져·썬더·파이어·뮤. (구구·피죤·깨비참·리자몽·망나뇽 등은 서 있는 모습이라 안 띄움)
const FLOATING_SPECIES := [12, 15, 18, 22, 41, 42, 49, 81, 82, 92, 93, 109, 110, 142, 144, 145, 146, 151]
## 말풍선 꼬리 끝 위치 (발판 위쪽, 화면 세로 가운데쯤, 기준 해상도) (v0.39)
const EMOTE_POS := Vector2(240, 105)
## 엔트리 아이콘 줄 영역 (기준 해상도, 장면 왼쪽 아래). 과녁이 이 영역을 피한다.
const ENTRY_STRIP_RECT := Rect2(3, 145, 104, 34)
## 엔트리는 오버월드 앞모습(32×32, 걷기 2프레임)으로 표시 (v0.28). 없으면 메뉴 아이콘.
const ENTRY_ICON := 32
const ENTRY_ANIM_SEC := 0.45
## 버프 상자 오른쪽 끝·위 (장면 오른쪽 위)
const BUFF_RIGHT := 317.0
const BUFF_TOP := 20.0
const BUFF_GOOD := Color(0.62, 0.85, 1.0)
const BUFF_BAD := Color(1.0, 0.55, 0.5)
const TITLE_RIGHT := 312.0
enum DevMenu { ENCOUNTER, MONEY, RESET_SAVE }

var _dev_menu: PopupMenu        # 개발용 우클릭 메뉴 (디버그 빌드만)
var _panels: Dictionary = {}     # id -> OverlayPanel
var _buttons: Dictionary = {}    # id -> Button
var _open_id: StringName = &""
var _confirm: ConfirmPanel
## 포획 정보 창 (v0.31): 확인을 누를 때까지 열려 있고, 그동안 버튼 줄은 잠긴다
var _caught: CaughtPanel
## 아직 "확인"을 누르지 않은 새 지역 이름 (해금 알림 팝업)
var _unlock_names: Array[String] = []
var _ball_box: Control
var _ball_icon: TextureRect
var _ball_label: Label
var _exp_fill: ColorRect
var _battle: Control
var _emote: EmoteBubble
## 전투 중 이름·레벨 줄 오른쪽 끝의 "과녁을 클릭해서 잡자!" (v0.38)
var _battle_prompt: Label
## 지금 포켓몬 그림이 실제로 그려진 영역 (두 프레임 합침, 기준 해상도)
var _pokemon_used := Rect2()
## 나는 포켓몬의 그림자와 흔들림
var _shadow: Polygon2D
var _bob: Tween
var _ground_plate: BattleGround
## 장면 왼쪽 아래 엔트리 아이콘 줄, 오른쪽 위 버프 상자 (v0.27)
var _entry_strip: PanelContainer
var _entry_icons: HBoxContainer
var _buff_box: PanelContainer
var _buff_list: VBoxContainer
var _entry_anim_frame := 0
## 버프 목록 내용 (바뀔 때만 다시 그림)
var _buff_key := ""
## 개발용 자동 플레이 (실행 인자 `-- --autoplay`): 등장하면 자동으로 전투를 시작하고 과녁을 누른다.
var _autoplay := false

@onready var _pokemon: AnimatedSprite2D = $Pokemon
@onready var _hitbox: Control = $PokemonHitbox
## 제목은 RichTextLabel (성별 기호에 색을 넣기 위해 BBCode 사용)
@onready var _title: RichTextLabel = $Title
## 전투 중에만: 제목 아래 이름·성별·레벨
@onready var _battle_info: RichTextLabel = $BattleInfo
@onready var _hud_label: Label = $Hud/Label
@onready var _panel_layer: Control = $PanelLayer
@onready var _button_row: HBoxContainer = $ButtonBar/Buttons


func _ready() -> void:
	_autoplay = OS.is_debug_build() and OS.get_cmdline_user_args().has("--autoplay")
	gui_input.connect(_on_gui_input)
	_hitbox.gui_input.connect(_on_hitbox_gui_input)
	_build_panels()
	_build_hud_widgets()
	_build_entry_widgets()
	_build_ground_plate()
	_build_shadow()
	_build_battle_prompt()
	_emote = EmoteBubble.new()
	_emote.position = EMOTE_POS
	add_child(_emote)
	move_child(_emote, _panel_layer.get_index())   # 패널·버튼 줄·HUD 아래
	if OS.is_debug_build():
		_build_dev_menu()
	add_child(EvolutionOverlay.new())   # 진화 연출: 버튼 줄·장면·패널 위 (HUD는 보임)

	EventBus.encounter_started.connect(_on_encounter_started)
	EventBus.encounter_appeared.connect(_on_encounter_appeared)
	EventBus.battle_started.connect(func(_e: Dictionary, _b: StringName) -> void: _close_panels())
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.encounter_fled.connect(_on_encounter_fled)
	EventBus.pokemon_caught.connect(_on_pokemon_caught)
	EventBus.encounter_ended.connect(_show_idle)
	EventBus.encounter_ended.connect(_show_unlock_notice)
	EventBus.game_reset.connect(_on_game_reset)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.region_unlocked.connect(_on_region_unlocked)
	EventBus.current_region_changed.connect(_on_current_region_changed)
	EventBus.expedition_finished.connect(_on_expedition_finished)
	PlayerState.changed.connect(_update_hud)   # 볼 개수·레벨 등이 바뀌면 HUD 갱신
	PlayerState.changed.connect(_refresh_entry_widgets)   # 엔트리·레벨·진화가 바뀌면 아이콘·버프 갱신
	EventBus.entries_changed.connect(_refresh_entry_widgets)
	# 타이머 멈춤/재개 → 말풍선 "?" / ". .. ..." (v0.34)
	EventBus.ball_shortage_changed.connect(func(_short: bool) -> void: _update_waiting_emote())
	# 전투 후 엔트리 특성(픽업·꿀모으기·볼줍기) 결과는 안내 문구 아래 한 줄로 (기획서 6.1, v0.28)
	EventBus.battle_traits_triggered.connect(func(lines: PackedStringArray) -> void:
		_append_title.call_deferred("  ".join(lines)))
	EventBus.battle_started.connect(func(_e: Dictionary, _b: StringName) -> void: _refresh_entry_widgets())
	EventBus.encounter_ended.connect(_refresh_entry_widgets)

	# 개발용: 실행 인자 `-- --open=dex|party|storage|region|expedition|bag|shop` 으로 시작하자마자 패널을 연다
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--open="):
				_toggle_panel.call_deferred(StringName(arg.trim_prefix("--open=")))

	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_hud)
	add_child(timer)
	_show_idle()


# ---------------------------------------------------------------- 패널 (위 버튼 줄)

func _build_panels() -> void:
	var normal := _button_style(Color(0.16, 0.3, 0.55))
	var hover := _button_style(Color(0.24, 0.42, 0.72))
	var pressed := _button_style(Color(0.95, 0.75, 0.3))
	for p in PANELS:
		var id: StringName = p[0]
		var panel: OverlayPanel = p[2].new()
		_panel_layer.add_child(panel)
		panel.closed.connect(_on_panel_closed.bind(id))
		panel.confirm_requested.connect(_on_confirm_requested)
		panel.open_requested.connect(func(pid: StringName) -> void:
			if _open_id != pid:
				_toggle_panel(pid))
		_panels[id] = panel

		var b := Button.new()
		b.text = p[1]
		_style_bar_button(b, normal, hover, pressed)
		b.toggle_mode = true
		b.pressed.connect(_toggle_panel.bind(id))
		_button_row.add_child(b)
		_buttons[id] = b

	# 오른쪽 끝: 설정(톱니바퀴) · 종료(X)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_row.add_child(spacer)
	var settings: OverlayPanel = SettingsPanel.new()
	_panel_layer.add_child(settings)
	settings.closed.connect(_on_panel_closed.bind(&"settings"))
	settings.confirm_requested.connect(_on_confirm_requested)
	_panels[&"settings"] = settings
	var gear := IconButton.new(IconButton.Kind.GEAR)
	_style_bar_button(gear, normal, hover, pressed)
	gear.toggle_mode = true
	gear.pressed.connect(_toggle_panel.bind(&"settings"))
	_button_row.add_child(gear)
	_buttons[&"settings"] = gear
	var close := IconButton.new(IconButton.Kind.CLOSE)
	_style_bar_button(close, normal, _button_style(Color(0.8, 0.25, 0.25)), pressed)
	close.pressed.connect(_ask_quit)
	_button_row.add_child(close)

	_caught = CaughtPanel.new()
	_panel_layer.add_child(_caught)   # 다른 패널 위, 확인 창 아래
	_caught.closed.connect(func() -> void:
		_sync_buttons()
		_show_unlock_notice.call_deferred())   # 기다리던 지역 해금 알림

	_confirm = ConfirmPanel.new()
	_panel_layer.add_child(_confirm)
	_confirm.closed.connect(_on_panel_closed.bind(&"confirm"))
	_confirm.closed.connect(func() -> void: _show_unlock_notice.call_deferred())


func _style_bar_button(b: Button, normal: StyleBox, hover: StyleBox, pressed: StyleBox) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.add_theme_stylebox_override(&"hover_pressed", pressed)
	b.add_theme_stylebox_override(&"disabled", normal)
	b.add_theme_color_override(&"font_pressed_color", Color(0.15, 0.1, 0.05))
	b.add_theme_color_override(&"font_hover_pressed_color", Color(0.15, 0.1, 0.05))


## X 버튼: 화면 안 확인 창을 먼저 띄우고, 확인하면 종료 (M11)
func _ask_quit() -> void:
	_confirm.ask("종료", "게임을 종료할까요?\n(진행 상황은 저장된다)", "종료", quit_game)


## 색이 다른 포켓몬 등장 연출: 포켓몬 주변에 별 모양 반짝임이 퍼졌다 사라진다 (M11)
func _play_shiny_sparkle() -> void:
	var fx := ShinySparkle.new()
	fx.position = _pokemon_used.get_center() if _pokemon_used.has_area() else _pokemon.position
	add_child(fx)
	move_child(fx, _panel_layer.get_index())


## 종료: 저장(종료 알림)하고 끝낸다
func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


func _button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


## 같은 버튼을 다시 누르면 닫고, 다른 버튼이면 바꿔서 연다. 한 번에 패널 하나만.
func _toggle_panel(id: StringName) -> void:
	if not _panels.has(id):
		return
	var reopen := _open_id != id
	_close_panels()
	if reopen:
		_open_id = id
		_panels[id].open_panel()
	_sync_buttons()


func _close_panels() -> void:
	for p in _panels.values():
		p.close_panel()
	_confirm.close_panel()
	_open_id = &""
	_sync_buttons()


func _on_panel_closed(id: StringName) -> void:
	if _open_id == id:
		_open_id = &""
	_sync_buttons()


func _sync_buttons() -> void:
	var in_battle := EncounterManager.state == EncounterManager.State.BATTLE
	var locked := in_battle or (_caught != null and _caught.visible)   # 포획 정보 창이 열려 있으면 잠금
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == _open_id)
		_buttons[id].disabled = locked
	# 보상을 기다리는 원정이 있으면 버튼에 표시
	var waiting := ExpeditionManager.claimable_count()
	_buttons[&"expedition"].text = "원정!" if waiting > 0 else "원정"
	_buttons[&"expedition"].add_theme_color_override(&"font_color", Color(1, 0.85, 0.35) if waiting > 0 else Color.WHITE)


func _on_expedition_finished(id: StringName) -> void:
	var x := GameData.get_expedition(id)
	if x and EncounterManager.state in [EncounterManager.State.WAITING, EncounterManager.State.PAUSED]:
		_title.text += "\n%s에서 돌아왔다!" % x.name_ko
	_sync_buttons()


## 패널이 요청한 확인 창: 지금 패널 위에 겹쳐 띄우고, 닫히면 원래 패널이 그대로 보인다.
func _on_confirm_requested(title_text: String, message: String, ok_text: String, on_ok: Callable) -> void:
	_confirm.ask(title_text, message, ok_text, on_ok)


# ---------------------------------------------------------------- 인카운터 표시

func _on_game_reset() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null
	_battle_info.hide()
	_battle_prompt.hide()
	_title.text = "저장을 초기화했다"
	_update_hud()


func _show_idle() -> void:
	_pokemon.hide()
	_pokemon.stop()
	_stop_bob()
	_hitbox.hide()
	_update_waiting_emote()   # 대기: ". .. ..." / 멈춤: "?"
	_apply_region_look()
	var region := GameData.get_region(PlayerState.current_region)
	_title.text = region.name_ko if region else ""
	_update_hud()


## 지역별 배경색과 바닥 발판 (배경 아트가 생기면 region.background 로 교체)
func _apply_region_look() -> void:
	var region := GameData.get_region(PlayerState.current_region)
	if region:
		$Background.color = region.sky_color
		$Ground.color = region.ground_color
	_ground_plate.shaking = false
	_ground_plate.set_region(region)   # 지역마다 다른 바닥 (v0.37)


func _on_region_unlocked(id: StringName) -> void:
	var region := GameData.get_region(id)
	if region:
		# 레벨업 문구 뒤에 붙도록 한 박자 늦게 (해금 판정이 레벨업 처리보다 먼저 실행됨)
		_append_title.call_deferred("새 지역 해금: %s!" % region.name_ko)   # 효과음은 AudioManager
		_unlock_names.append(region.name_ko)
		_show_unlock_notice.call_deferred()


## 새 지역 해금 알림 팝업 (v0.24). 인카운터 대기 중일 때만 띄우고(전투·결과 표시 중이면 끝난 뒤),
## 여러 지역이 한꺼번에 열리면 한 팝업에 모은다. "확인"을 눌러야 목록을 비운다
## (전투 시작으로 패널이 닫히면 전투가 끝난 뒤 다시 띄운다).
func _show_unlock_notice() -> void:
	if _unlock_names.is_empty():
		return
	if EncounterManager.state not in [EncounterManager.State.WAITING, EncounterManager.State.PAUSED]:
		return
	if _confirm.visible and not _confirm.is_notice:
		return   # 다른 확인 창이 떠 있으면 그 창이 닫힌 뒤
	if _caught.visible:
		return   # 포획 정보 창을 확인한 뒤
	_confirm.notify("새 지역 해금", "새로운 지역이 해금되었다!\n%s\n\n지역 버튼에서 이동할 수 있다." % ", ".join(_unlock_names),
		func() -> void: _unlock_names.clear())


## 지역을 바꾸면 다음 인카운터부터 적용. 대기 중이면 화면도 바로 바꾼다.
func _on_current_region_changed(_id: StringName) -> void:
	if EncounterManager.state == EncounterManager.State.WAITING or EncounterManager.state == EncounterManager.State.PAUSED:
		_show_idle()


## 대기 중 말풍선: 타이머가 멈춰 있으면 "?", 아니면 ". .. ..." (인카운터 진행 중에는 건드리지 않음)
func _update_waiting_emote() -> void:
	match EncounterManager.state:
		EncounterManager.State.PAUSED:
			_emote.show_question()
		EncounterManager.State.WAITING:
			_emote.show_waiting()


func _on_encounter_started(_enc: Dictionary) -> void:
	_ground_plate.shaking = true   # 예전 풀숲 흔들림 대신 바닥 발판이 떨린다 (v0.37)
	_emote.show_alert()   # "!" 가 2배로 확 커지며
	_title.text = "무언가 다가온다!"


## 지역 바닥 발판: 언제나 보이고 포켓몬 바로 뒤에 그린다 (v0.37, 예전 풀숲 대신)
func _build_ground_plate() -> void:
	_ground_plate = BattleGround.new()
	_ground_plate.position = BATTLE_GROUND_POS
	add_child(_ground_plate)
	move_child(_ground_plate, _pokemon.get_index())   # 포켓몬 바로 뒤
	_ground_plate.set_region(GameData.get_region(PlayerState.current_region))


## 나는 포켓몬 아래 발판에 드리우는 그림자 (반투명 타원, 포켓몬 바로 뒤)
func _build_shadow() -> void:
	_shadow = Polygon2D.new()
	_shadow.color = Color(0, 0, 0, 0.28)
	_shadow.visible = false
	add_child(_shadow)
	move_child(_shadow, _pokemon.get_index())


func _set_shadow(width: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * width / 2.0, sin(a) * 3.0))
	_shadow.polygon = pts
	_shadow.position = Vector2(BATTLE_GROUND_POS.x, POKEMON_FEET_Y - 1.0)


## 전투 스프라이트가 공중에 떠 있는 모습인가 (타입과 무관, v0.40)
static func is_floating(species: PokemonSpecies) -> bool:
	return species != null and FLOATING_SPECIES.has(species.dex_id)


func _stop_bob() -> void:
	if _bob and _bob.is_valid():
		_bob.kill()
	_bob = null
	_pokemon.offset = Vector2.ZERO
	_shadow.hide()


## 이름·레벨 줄(BattleInfo)과 같은 높이, 오른쪽 정렬 (v0.38)
func _build_battle_prompt() -> void:
	_battle_prompt = Label.new()
	_battle_prompt.text = "과녁을 클릭해서 잡자!"
	_battle_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_battle_prompt.position = _battle_info.position
	_battle_prompt.size = _battle_info.size
	_battle_prompt.add_theme_color_override(&"font_color", Color(0.125, 0.125, 0.125))
	_battle_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_prompt.visible = false
	add_child(_battle_prompt)
	move_child(_battle_prompt, _battle_info.get_index() + 1)


## 포켓몬 그림이 실제로 그려진 영역(투명 여백 제외, 모든 프레임 합침)을 재서,
## 아래 끝이 POKEMON_FEET_Y, 가로 가운데가 발판 가운데에 오도록 놓는다. 클릭 영역도 그 영역에 맞춘다 (v0.38).
## 스프라이트마다 칸 안의 위치·크기가 달라 발판 위에서 떠 보이거나 묻혀 보이던 문제를 없앤다.
func _place_pokemon(floating: bool = false) -> void:
	_stop_bob()
	var used := Rect2()
	var frames := _pokemon.sprite_frames
	for i in frames.get_frame_count(&"idle"):
		var tex := frames.get_frame_texture(&"idle", i)
		var img := tex.get_image() if tex else null
		if img == null or img.is_empty():
			continue
		var r := Rect2(img.get_used_rect())
		if r.has_area():
			used = r if not used.has_area() else used.merge(r)
	if not used.has_area():
		used = Rect2(0, 0, POKEMON_CELL, POKEMON_CELL)
	var feet := POKEMON_FEET_Y - (FLOAT_HEIGHT if floating else 0.0)   # 나는 포켓몬은 띄운다 (v0.39)
	var top_left := Vector2(roundf(BATTLE_GROUND_POS.x - used.get_center().x), roundf(feet - used.end.y))
	_pokemon.position = top_left + Vector2(POKEMON_CELL, POKEMON_CELL) / 2.0
	_pokemon_used = Rect2(top_left + used.position, used.size)
	var hit := _pokemon_used.grow(4)
	_hitbox.position = hit.position
	_hitbox.size = hit.size
	if floating:
		_set_shadow(clampf(used.size.x * 0.7, 14.0, 48.0))
		_shadow.show()
		# 위아래로 천천히 (정수 픽셀 단위로 보이게 offset 은 짧은 거리만)
		_bob = create_tween().set_loops()
		_bob.tween_property(_pokemon, ^"offset:y", -FLOAT_BOB_PX, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bob.tween_property(_pokemon, ^"offset:y", 0.0, FLOAT_BOB_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_encounter_appeared(enc: Dictionary) -> void:
	_ground_plate.shaking = false   # 포켓몬이 발판 위에 나타난다
	_emote.hide_bubble()   # 포켓몬이 나오면 말풍선은 숨김
	var species := GameData.get_species(enc[&"dex_id"])
	_pokemon.sprite_frames = PokemonSprites.make_frames(species, enc[&"gender"] == &"female", enc[&"shiny"])
	_place_pokemon(is_floating(species))
	_pokemon.modulate = Color.WHITE
	_pokemon.show()
	_pokemon.play(&"idle")
	_hitbox.show()
	var head := "전설의 포켓몬 " if enc.get(&"legendary", false) else "야생 "
	if enc.get(&"shiny", false):
		head = "색이 다른 " + head   # M11: 반짝임 연출과 함께
		_play_shiny_sparkle()
	var g := UiUtil.gender_bbcode(String(enc[&"gender"]), false)   # 무성이면 빈 문자열
	_title.text = "%s%s%s Lv%d %s" % [head, species.name_ko, (" " + g) if g != "" else "", enc[&"level"],
		"등장!" if enc.get(&"legendary", false) else "나타났다!"]
	_update_hud()
	if _autoplay:
		get_tree().create_timer(1.0).timeout.connect(_start_battle)


func _start_battle() -> void:
	if _battle != null:
		return
	var params := EncounterManager.begin_battle()
	if params.is_empty():
		if EncounterManager.block_reason == &"storage_full":
			_title.text = "보관함이 가득 찼다! (%d/%d)" % [PlayerState.storage_count(), PlayerState.storage_capacity]
		return
	_hitbox.hide()
	_battle = BATTLE_SCENE.instantiate()
	_battle.autoplay = _autoplay
	add_child(_battle)
	move_child(_battle, _panel_layer.get_index())   # 패널·버튼 줄·HUD 아래, 포켓몬 위
	_battle.finished.connect(EncounterManager.finish_battle)
	var avoid: Array[Rect2] = []
	if _entry_strip.visible:
		avoid.append(ENTRY_STRIP_RECT.grow(2))   # 왼쪽 아래 엔트리 아이콘은 과녁이 피한다
	_battle.start(params, EncounterManager.rng, _pokemon_rect(), avoid)
	# 전투 중: 맨 윗줄에 이름·성별·레벨(왼쪽) + "과녁을 클릭해서 잡자!"(오른쪽) → 그 아래 포획 게이지(battle.gd) (v0.39)
	_title.text = ""
	_show_battle_info(EncounterManager.current)
	_battle_prompt.show()
	_update_hud()


func _show_battle_info(enc: Dictionary) -> void:
	var species := GameData.get_species(enc[&"dex_id"])
	var g := UiUtil.gender_bbcode(String(enc[&"gender"]), false)
	_battle_info.text = "%s%s%s%s Lv%d" % ["색이 다른 " if enc.get(&"shiny", false) else "",
		"전설 " if enc.get(&"legendary", false) else "", species.name_ko,
		(" " + g) if g != "" else "", enc[&"level"]]
	_battle_info.show()


## 포켓몬이 실제로 그려진 영역 (투명 여백 제외, 기준 해상도).
func _pokemon_rect() -> Rect2:
	return _pokemon_used.grow(2)


func _on_battle_finished(_success: bool) -> void:
	_battle_info.hide()
	_battle_prompt.hide()
	if _battle != null:
		_battle.queue_free()
		_battle = null


func _on_pokemon_caught(inst: Dictionary) -> void:
	var species := GameData.get_species(inst.dex_id)
	_pokemon.hide()
	_stop_bob()   # 그림자도 함께 숨김
	_hitbox.hide()
	_title.text = "%s%s를(을) 잡았다!" % ["색이 다른 " if inst.get("shiny", false) else "", species.name_ko]
	_update_hud()
	# 포획 정보 창 (v0.31). 이번 포획으로 도감 포획 수가 1이 됐으면 새로 등록한 종
	var new_dex := int(PlayerState.dex.get(int(inst.dex_id), {}).get("caught", 0)) == 1
	_close_panels()
	_caught.show_pokemon(inst, new_dex)
	_sync_buttons()


func _on_encounter_fled(enc: Dictionary) -> void:
	var species := GameData.get_species(enc[&"dex_id"])
	_pokemon.modulate = Color(1, 1, 1, 0.35)
	_hitbox.hide()
	_title.text = "%s는(은) 도망쳤다..." % species.name_ko
	_update_hud()


func _on_player_leveled_up(new_level: int) -> void:
	_title.text += "\n레벨 업! Lv%d" % new_level
	_update_hud()


func _append_title(line: String) -> void:
	_title.text += "\n" + line


# ---------------------------------------------------------------- HUD

## HUD 위쪽 2px 경험치 막대 + 오른쪽 볼 표시
# ---------------------------------------------------------------- 엔트리 아이콘 · 버프 (v0.27)

func _overlay_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.16, 0.55)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


## 엔트리 걷기 애니메이션: 모두 같은 박자로 프레임을 바꾼다
func _tick_entry_anim() -> void:
	_entry_anim_frame = (_entry_anim_frame + 1) % 2
	if _entry_icons == null or not _entry_strip.visible:
		return
	for icon in _entry_icons.get_children():
		var frames: Array = icon.get_meta(&"frames", [])
		if not frames.is_empty():
			icon.texture = frames[_entry_anim_frame % frames.size()]


func _build_entry_widgets() -> void:
	var anim := Timer.new()
	anim.wait_time = ENTRY_ANIM_SEC
	anim.autostart = true
	anim.timeout.connect(_tick_entry_anim)
	add_child(anim)
	_entry_strip = PanelContainer.new()
	_entry_strip.position = ENTRY_STRIP_RECT.position
	_entry_strip.add_theme_stylebox_override(&"panel", _overlay_style())
	_entry_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_entry_strip)
	move_child(_entry_strip, _panel_layer.get_index())   # 패널·버튼 줄·HUD 아래
	_entry_icons = HBoxContainer.new()
	_entry_icons.add_theme_constant_override(&"separation", 2)
	_entry_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_strip.add_child(_entry_icons)

	_buff_box = PanelContainer.new()
	_buff_box.add_theme_stylebox_override(&"panel", _overlay_style())
	_buff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buff_box)
	move_child(_buff_box, _panel_layer.get_index())
	_buff_list = VBoxContainer.new()
	_buff_list.add_theme_constant_override(&"separation", 0)
	_buff_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_box.add_child(_buff_list)
	_refresh_entry_widgets()


## 엔트리 아이콘(왼쪽 아래)과 버프(오른쪽 위)를 다시 그린다. 버프는 전투 중에는 숨긴다(게이지와 겹치지 않게).
func _refresh_entry_widgets() -> void:
	if _entry_icons == null:
		return
	_clear_children(_entry_icons)
	var entries := PlayerState.entry_pokemon()
	for p in entries:
		var s := GameData.get_species(p.dex_id)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ENTRY_ICON, ENTRY_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var frames := PokemonSprites.overworld_frames(s, String(p.get("gender", "")) == "female")
		if frames.is_empty() and s:
			frames.append(UiUtil.pokemon_icon(s))
		icon.set_meta(&"frames", frames)
		icon.texture = frames[_entry_anim_frame % frames.size()] if not frames.is_empty() else null
		icon.tooltip_text = "%s Lv%d (엔트리)" % [s.name_ko if s else "?", p.level]
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon.gui_input.connect(_on_entry_icon_input)
		_entry_icons.add_child(icon)
	_entry_strip.visible = not entries.is_empty()
	_entry_strip.reset_size()

	_refresh_buffs(true)


## 버프 목록(오른쪽 위). 향로 남은 시간이 바뀌므로 HUD 갱신 때마다 부르고, 내용이 같으면 그대로 둔다.
func _refresh_buffs(force: bool = false) -> void:
	if _buff_list == null:
		return
	var buffs := EncounterManager.entry_buffs()
	var key := "\n".join(PackedStringArray(buffs.map(func(b) -> String: return b.text))) + str(EncounterManager.state == EncounterManager.State.BATTLE)
	if not force and key == _buff_key:
		return
	_buff_key = key
	_clear_children(_buff_list)
	for b in buffs:
		var l := Label.new()
		l.text = b.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override(&"font_color", BUFF_GOOD if b.good else BUFF_BAD)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buff_list.add_child(l)
	var show_buffs := not buffs.is_empty() and EncounterManager.state != EncounterManager.State.BATTLE
	_buff_box.visible = show_buffs
	_buff_box.reset_size()
	_place_buff_box.call_deferred()


## 크기 계산에 남지 않도록 바로 떼어 낸 뒤 지운다
func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## 버프 상자를 오른쪽 위에 붙이고, 제목 줄이 상자와 겹치지 않게 제목 폭을 줄인다.
func _place_buff_box() -> void:
	var w := _buff_box.get_combined_minimum_size().x
	_buff_box.position = Vector2(BUFF_RIGHT - w, BUFF_TOP)
	_title.size.x = (_buff_box.position.x - 4.0 if _buff_box.visible else TITLE_RIGHT) - _title.position.x


## 엔트리 아이콘을 누르면 파티 패널 (전투 중 제외)
func _on_entry_icon_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _caught.visible \
			and EncounterManager.state != EncounterManager.State.BATTLE and _open_id != &"party":
		_toggle_panel(&"party")
		accept_event()


func _build_hud_widgets() -> void:
	var back := ColorRect.new()
	back.color = Color(0.1, 0.18, 0.35)
	back.size = Vector2(WIDTH, 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Hud.add_child(back)
	_exp_fill = ColorRect.new()
	_exp_fill.color = Color(0.45, 0.85, 1.0)
	_exp_fill.size = Vector2(0, 2)
	_exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Hud.add_child(_exp_fill)

	# 선택한 볼 (클릭하면 다음 볼로, 기획서 4.3)
	_ball_box = HBoxContainer.new()
	_ball_box.position = Vector2(232, 2)   # HUD 19px: 위 2px 경험치 막대 아래
	_ball_box.size = Vector2(88, 16)
	_ball_box.add_theme_constant_override(&"separation", 1)
	_ball_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_ball_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ball_box.tooltip_text = "클릭: 볼 바꾸기"
	_ball_box.gui_input.connect(_on_ball_gui_input)
	$Hud.add_child(_ball_box)
	_ball_icon = TextureRect.new()
	_ball_icon.custom_minimum_size = Vector2(16, 16)
	_ball_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ball_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ball_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_box.add_child(_ball_icon)
	_ball_label = Label.new()
	_ball_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_box.add_child(_ball_label)


func _on_ball_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_ball_box.accept_event()
		AudioManager.play(&"button_click")   # 버튼은 아니지만 버튼처럼 동작
		PlayerState.cycle_ball()
		_update_hud()


func _update_hud() -> void:
	_refresh_buffs()   # 향로 남은 시간 (v0.41)
	if _exp_fill:
		var ratio := 1.0 if PlayerState.level >= PlayerState.MAX_PLAYER_LEVEL else float(PlayerState.experience) / PlayerState.exp_to_next()
		_exp_fill.size.x = WIDTH * ratio
	if _ball_label:
		var item := GameData.get_item(PlayerState.selected_ball)
		_ball_icon.texture = item.load_icon() if item else null
		var count := PlayerState.item_count(PlayerState.selected_ball)
		_ball_label.text = (item.name_ko if item else "?") + ("" if item and item.infinite else " %d" % count)
		_ball_label.modulate = Color(1, 0.55, 0.5) if not PlayerState.can_use_selected_ball() else Color.WHITE
	var status := ""
	match EncounterManager.state:
		EncounterManager.State.WAITING:
			var s := ceili(EncounterManager.seconds_until_next())
			status = "다음 인카운터 %02d:%02d" % [s / 60, s % 60]
		EncounterManager.State.PAUSED:
			status = "볼 부족 - 인카운터 정지"
		EncounterManager.State.PREVIEW:
			status = "무언가 나타났다!"
		EncounterManager.State.APPEARED:
			status = "클릭해서 잡기 (%d초)" % ceili(EncounterManager.seconds_until_flee())
		EncounterManager.State.BATTLE:
			status = "과녁을 클릭!"
		EncounterManager.State.RESULT:
			status = ""
	_hud_label.text = "Lv%d  %s" % [PlayerState.level, status]
	if not _buttons.is_empty():
		_sync_buttons()


# ---------------------------------------------------------------- 입력

func _on_hitbox_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_hitbox.accept_event()
		_start_battle()


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			WindowManager.begin_drag()
			accept_event()
		MOUSE_BUTTON_RIGHT when _dev_menu != null:
			_dev_menu.position = Vector2i(get_global_mouse_position())
			_dev_menu.popup()
			accept_event()
		MOUSE_BUTTON_WHEEL_UP when mb.ctrl_pressed:
			WindowManager.step_scale(1)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN when mb.ctrl_pressed:
			WindowManager.step_scale(-1)
			accept_event()



# ---------------------------------------------------------------- 개발용 우클릭 메뉴

func _build_dev_menu() -> void:
	_dev_menu = PopupMenu.new()
	_dev_menu.add_separator("개발용")
	_dev_menu.add_item("지금 인카운터", DevMenu.ENCOUNTER)
	_dev_menu.add_item("돈 +10,000원", DevMenu.MONEY)
	_dev_menu.add_item("저장 초기화...", DevMenu.RESET_SAVE)
	_dev_menu.id_pressed.connect(_on_dev_menu)
	add_child(_dev_menu)


func _on_dev_menu(id: int) -> void:
	match id:
		DevMenu.ENCOUNTER:
			_close_panels()
			EncounterManager.trigger_now()
		DevMenu.MONEY:
			PlayerState.add_currency(10000)
		DevMenu.RESET_SAVE:
			_confirm.ask("저장 초기화 (개발용)",
				"저장된 진행을 모두 지웁니다.\n(레벨, 도감, 보관함, 아이템, 재화)\n설정(창 크기·소리 등)은 유지됩니다.\n되돌릴 수 없습니다. 계속할까요?",
				"초기화", SaveManager.reset_save)
