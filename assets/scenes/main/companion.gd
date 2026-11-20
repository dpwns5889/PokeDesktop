extends Control
## 메인 컴패니언 창 (448×200, v0.46). (기획서 6.1)
## 가로: 왼쪽 0~320 = 기존 UI(버튼 줄·장면·HUD·패널·확인 창), 오른쪽 320~448 = 전투 칸(발판·야생 포켓몬·말풍선·이름·게이지·과녁)
## 왼쪽 세로: 위 버튼 줄(18px) / 장면 / 아래 HUD(19px). 패널·확인 창은 왼쪽만 덮어 전투 칸을 가리지 않는다.
## - 위 버튼 줄 왼쪽: 도감·보관함·지역·원정·가방·상점 → 장면을 덮는 패널(OverlayPanel). 별도 OS 창은 쓰지 않는다.
## - 위 버튼 줄 오른쪽: 설정(톱니바퀴, 창·소리·개발용) / 종료(X)
## - 배경 드래그 이동, Ctrl+휠 배율 (M1)
## - 우클릭 메뉴: 개발(디버그) 빌드에서만 — 지금 인카운터, 돈 +10,000원, 레벨 +1, 저장 초기화
## - 인카운터: 풀숲 흔들림 → 포켓몬 등장 → 클릭하면 전투 → 결과 (M3)
## - 풀숲 위 말풍선(v0.33): 대기 중 ". .. ..." 반복, 인카운터가 나면 "!" 가 2배로 확 커지며 나타남,
##   타이머가 멈추면(선택한 볼이 없음) "?" (v0.34)
## - 장면 오른쪽 아래: 엔트리 포켓몬 오버월드 앞모습(걷기 애니메이션, 누르면 파티 패널, v0.59) / 오른쪽 위: 쓰고 있는 아이템 효과 (v0.62, 기획서 6.1)
## - 엔트리 포켓몬이 장면 안을 걸어다닌다 (M12, v0.45, OverworldWalker). 인카운터·전투 중에는 멈춰서 발판을 바라본다.
## 상태는 EncounterManager가 갖고, 이 화면은 EventBus 시그널을 받아 표시만 바꾼다.

const BATTLE_SCENE := preload("res://assets/scenes/battle/battle.tscn")
const ConfirmPanel := preload("res://assets/scenes/ui/confirm_panel.gd")
const CaughtPanel := preload("res://assets/scenes/ui/caught_panel.gd")
const EvolutionOverlay := preload("res://assets/scenes/ui/evolution_overlay.gd")
const SettingsPanel := preload("res://assets/scenes/ui/settings_panel.gd")
## 위 버튼 줄: [ID, 표시 이름, 패널 스크립트]
const PANELS := [
	[&"dex", "도감", preload("res://assets/scenes/ui/dex_panel.gd")],
	[&"party", "파티", preload("res://assets/scenes/ui/party_panel.gd")],
	[&"storage", "보관함", preload("res://assets/scenes/ui/storage_panel.gd")],
	[&"region", "지역", preload("res://assets/scenes/ui/region_panel.gd")],
	[&"expedition", "원정", preload("res://assets/scenes/ui/expedition_panel.gd")],
	[&"bag", "가방", preload("res://assets/scenes/ui/bag_panel.gd")],
	[&"shop", "상점", preload("res://assets/scenes/ui/shop_panel.gd")],
]
## 왼쪽 UI 폭 (버튼 줄·HUD·패널). 오른쪽 BATTLE_COLUMN 은 전투 칸 (v0.46)
const WIDTH := 320.0
const BATTLE_COLUMN := Rect2(320, 0, 128, 200)
## 전투 칸 테두리 두께 (v0.47, 버튼 줄 색)
const BATTLE_FRAME_PX := 2
## 버전 표시 글자색: 잘 안 보이게 흐린 흰색 (v0.64)
const VERSION_COLOR := Color(1, 1, 1, 0.3)
## 엔트리 상자 접기/펴기 화살표 탭 (v0.47, v0.59): 상자 왼쪽에 붙은 작은 탭. 접으면 상자가 왼쪽 UI 오른쪽 끝 밖으로 들어간다.
const ENTRY_TAB_SIZE := Vector2(9, 34)
const ENTRY_SLIDE_SEC := 0.18
## 지역 바닥 발판(예전 풀숲 자리, v0.37): 타원 중심 위치(기준 해상도). 포켓몬은 이 위에 나타난다.
const BATTLE_GROUND_POS := Vector2(384, 159)   # v0.38: 6px 위로, v0.46: 오른쪽 전투 칸 가운데
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
## 말풍선 꼬리 끝 위치 (발판 위쪽, 화면 세로 가운데쯤, 기준 해상도) (v0.39, v0.46 전투 칸)
const EMOTE_POS := Vector2(384, 105)
## 색이 다른 포켓몬 이름 색 (전투 칸 이름 줄, v0.46)
const SHINY_NAME_COLOR := "#b07800"
## 엔트리 아이콘 줄: 장면 오른쪽 아래(v0.59, 이전 왼쪽 아래). 상자 오른쪽 끝 x, 위 y
const ENTRY_STRIP_RIGHT := WIDTH - 3.0
const ENTRY_STRIP_TOP := 145.0
## 알림 문구(원정 귀환·지역 해금·레벨 업·전투 후 특성, v0.59): 장면 왼쪽 아래, 아래부터 쌓인다
const NOTICE_LEFT := 6.0
const NOTICE_BOTTOM := 179.0
const NOTICE_HEIGHT := 68.0
const NOTICE_MAX_LINES := 4
const NOTICE_SEC := 10.0
## 사라지기 전 흐려지는 시간 (v0.66)
const NOTICE_FADE_SEC := 3.0
const NOTICE_OUTLINE := Color(0.1, 0.13, 0.2)
## 엔트리는 오버월드 앞모습(32×32, 걷기 2프레임)으로 표시 (v0.28). 없으면 메뉴 아이콘.
const ENTRY_ICON := 32
const ENTRY_ANIM_SEC := 0.45
## 걸어다니는 엔트리의 발 위치 영역 (기준 해상도, M12 v0.45). 위 버튼 줄(18px)과 아래 HUD(19px) 사이의 장면 전체.
## 그림 높이(최대 32px)만큼 위를 띄워 머리가 버튼 줄에 가리지 않게 한다.
const WALK_AREA := Rect2(14, 18 + 30, 320 - 28, 200 - 19 - 1 - 48)
## 버프 상자 오른쪽 끝·위 (장면 오른쪽 위)
const BUFF_RIGHT := 317.0
const BUFF_TOP := 20.0
const BUFF_GOOD := Color(0.62, 0.85, 1.0)
const BUFF_BAD := Color(1.0, 0.55, 0.5)
const TITLE_RIGHT := 312.0
## 도감 완성 알림 문구 (v0.77)
const DEX_COMPLETE_TEXT := "관동 지방의 포켓몬 151종을 모두 잡았다!\n\n이제 색이 다른 포켓몬이 [color=#ffd959]더 자주 나타난다[/color].\n도감에서 색이 다른 포켓몬 기록을 볼 수 있다."
const CROWN_COLOR := Color(1.0, 0.82, 0.25)
## 아이템 인카운터 아이콘 크기 (24px 아이콘 2배, v0.84)
const FOUND_ICON_PX := 32.0   # 아이템 아이콘 기본 크기 = 원본 32px (v0.101, v0.91은 24px, 이전 2배 48)
enum DevMenu { ENCOUNTER, MONEY, LEVEL_UP, RESET_SAVE }

var _dev_menu: PopupMenu        # 개발용 우클릭 메뉴 (디버그 빌드만)
var _crown: Control             # 도감 완성 왕관 (v0.77)
## 아이템 인카운터에서 발판 위에 보여 주는 아이템 (v0.84, 아이콘 2배)
var _found_icon: TextureRect
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
## 지금 포켓몬 그림이 실제로 그려진 영역 (두 프레임 합침, 기준 해상도)
var _pokemon_used := Rect2()
## 나는 포켓몬의 그림자와 흔들림
var _shadow: Polygon2D
var _bob: Tween
var _ground_plate: BattleGround
## 포획 연출 (v0.50): 볼 던지기 → 빨려 들어감 → 3번 흔들림 → 포획
var _capture: CaptureAnim
## 이번 전투에 쓴 볼 (battle_started)
var _battle_ball: StringName = &"poke_ball"
## 장면 오른쪽 아래 엔트리 아이콘 줄(v0.59), 오른쪽 위 버프 상자 (v0.27)
var _entry_strip: PanelContainer
## 엔트리 상자·탭을 왼쪽 UI(0~WIDTH) 안에서만 그리는 틀: 접힌 상자가 전투 칸 위로 보이지 않게 (v0.59)
var _entry_clip: Control
## 왼쪽 아래 알림 문구 (v0.59): {id, text}. 오래된 줄부터 NOTICE_SEC 뒤 사라진다
var _notice: RichTextLabel
var _notices: Array[Dictionary] = []
var _notice_seq := 0
## 알림 줄 나이를 올리고 흐리게 다시 그리는 타이머 (줄이 있을 때만 돈다, v0.66)
var _notice_timer: Timer
var _entry_icons: HBoxContainer
var _buff_box: PanelContainer
var _buff_list: VBoxContainer
var _entry_anim_frame := 0
## 엔트리 상자 접기/펴기 탭과 상태 (v0.47)
var _entry_tab: EntryTab
var _entry_open := true
var _entry_slide: Tween
## 전투 칸 테두리 (v0.47) / 왼쪽 장면을 땅 색으로 덮는 면 (v0.47: 하늘 없음)
var _battle_frame: Control
var _field: ColorRect
## 왼쪽 들판 타일맵 (v0.48). 그림이 없으면 _field 땅 색만 보인다.
var _field_map: FieldMap
## 전투 칸 배경 (v0.53): 지역의 하늘색(위) → 땅색(아래) 세로 그라데이션
var _battle_bg: TextureRect
## 전투 칸 오른쪽 아래 버전 표시 (v0.64)
var _version_label: Label
## 걸어다니는 엔트리 (OverworldWalker, 발 높이 순으로 겹침 정렬)
var _walkers: Node2D
## 버프 목록 내용 (바뀔 때만 다시 그림)
var _buff_key := ""
## 엔트리 아이콘 내용 (바뀔 때만 다시 그림)
var _entry_key := ""
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
	# 창 옮기기 모드(v0.60)일 때는 배경 위에서 이동 커서
	WindowManager.move_mode_changed.connect(func(on: bool) -> void:
		mouse_default_cursor_shape = Control.CURSOR_MOVE if on else Control.CURSOR_ARROW)
	_hitbox.gui_input.connect(_on_hitbox_gui_input)
	_build_panels()
	_build_hud_widgets()
	_build_walkers()
	_build_entry_widgets()
	_build_ground_plate()
	_build_shadow()
	_build_battle_frame()
	_build_version_label()
	_capture = CaptureAnim.new()
	add_child(_capture)
	move_child(_capture, _pokemon.get_index() + 1)   # 포켓몬 위, 과녁·테두리 아래
	_emote = EmoteBubble.new()
	_emote.position = EMOTE_POS
	add_child(_emote)
	move_child(_emote, _panel_layer.get_index())   # 패널·버튼 줄·HUD 아래
	if OS.is_debug_build():
		_build_dev_menu()
	add_child(EvolutionOverlay.new())   # 진화 연출: 버튼 줄·장면·패널 위 (HUD는 보임)

	EventBus.encounter_started.connect(_on_encounter_started)
	EventBus.encounter_appeared.connect(_on_encounter_appeared)
	EventBus.item_appeared.connect(_on_item_appeared)
	EventBus.item_found.connect(_on_item_found)
	EventBus.item_lost.connect(_on_item_lost)
	EventBus.battle_started.connect(func(_e: Dictionary, b: StringName) -> void:
		_battle_ball = b
		_close_panels()
		_refresh_entry_widgets())
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.encounter_fled.connect(_on_encounter_fled)
	EventBus.pokemon_caught.connect(_on_pokemon_caught)
	EventBus.encounter_ended.connect(_show_idle)
	EventBus.encounter_started.connect(func(_e: Dictionary) -> void: _set_walkers_watching(true))
	EventBus.encounter_ended.connect(func() -> void: _set_walkers_watching(false))
	EventBus.encounter_ended.connect(_show_unlock_notice)
	# 진화로 도감을 완성할 수도 있다 (v0.77). 이미 완성된 세이브를 처음 불러왔을 때도 한 번 띄운다
	EventBus.pokemon_evolved.connect(func(_u: String, _f: int, _t: int) -> void: _show_unlock_notice.call_deferred())
	_show_unlock_notice.call_deferred()
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
	# 전투 후 엔트리 특성(픽업·꿀모으기·볼줍기) 결과는 왼쪽 아래 알림 한 줄로 (기획서 6.1, v0.28, v0.59)
	EventBus.battle_traits_triggered.connect(func(lines: PackedStringArray) -> void:
		_push_notice.call_deferred("  ".join(lines)))
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
	# 도감 완성 왕관 (v0.77): 완성 알림을 확인하면 톱니바퀴 왼쪽에 보인다. 장식 (툴팁만)
	_crown = Control.new()
	_crown.name = "Crown"
	_crown.custom_minimum_size = Vector2(16, 16)
	_crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crown.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(2, 13), Vector2(2, 4), Vector2(5, 8), Vector2(8, 2),
			Vector2(11, 8), Vector2(14, 4), Vector2(14, 13)])
		_crown.draw_colored_polygon(pts, CROWN_COLOR)
		_crown.draw_rect(Rect2(2, 11, 12, 2), CROWN_COLOR.darkened(0.3))
		_crown.draw_rect(Rect2(7, 7, 2, 2), Color(0.9, 0.25, 0.3)))   # 가운데 보석
	_button_row.add_child(_crown)
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
	# 테마 Button 글자는 흰 버튼용 진회색이라, 파란 버튼 줄은 밝은 글자로 고정
	b.add_theme_color_override(&"font_color", Color(0.875, 0.875, 0.875))
	b.add_theme_color_override(&"font_hover_color", Color(0.95, 0.95, 0.95))
	b.add_theme_color_override(&"font_disabled_color", Color(0.875, 0.875, 0.875, 0.5))
	b.add_theme_color_override(&"font_pressed_color", Color(0.15, 0.1, 0.05))
	b.add_theme_color_override(&"font_hover_pressed_color", Color(0.15, 0.1, 0.05))


## X 버튼: 화면 안 확인 창을 먼저 띄우고, 확인하면 종료 (M11)
func _ask_quit() -> void:
	_confirm.ask("종료", "진행 상황을 저장하고 게임을 종료할까요?", "종료", quit_game)   # v0.57 가운데 정렬, v0.59 문구


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
	var waiting := ExpeditionManager.claimable_count() > 0
	var exp_button: Button = _buttons[&"expedition"]
	exp_button.text = "원정!" if waiting else "원정"
	var color := Color(1, 0.85, 0.35) if waiting else Color.WHITE
	# 0.5초마다 불리므로 바뀔 때만 (테마 덮어쓰기는 같은 값이어도 다시 배치를 일으킨다)
	if exp_button.get_theme_color(&"font_color") != color:
		exp_button.add_theme_color_override(&"font_color", color)


func _on_expedition_finished(id: StringName) -> void:
	var x := GameData.get_expedition(id)
	if x:
		_push_notice("%s에서 돌아왔다!" % x.name_ko)   # v0.59: 왼쪽 아래 알림 (전투 중에도)
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
	_title.text = "저장을 초기화했다"
	_clear_notices()
	_set_walkers_watching(false)
	_refresh_entry_widgets()   # 엔트리가 비었으니 엔트리 상자·걸어다니는 포켓몬도 지운다 (v0.91)
	_update_hud()


func _show_idle() -> void:
	if _capture:
		_capture.clear()
	if _found_icon:
		_found_icon.hide()
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
		_field.color = region.ground_color   # v0.47: 걸어다니는 왼쪽 장면은 하늘 없이 땅 색
		_set_battle_bg(region.sky_color, region.ground_color)
	_set_field_region()
	_ground_plate.shaking = false
	_ground_plate.set_region(region)   # 지역마다 다른 바닥 (v0.37)


func _on_region_unlocked(id: StringName) -> void:
	var region := GameData.get_region(id)
	if region:
		# 레벨업 문구 뒤에 붙도록 한 박자 늦게 (해금 판정이 레벨업 처리보다 먼저 실행됨)
		_push_notice.call_deferred("새 지역 해금: %s!" % region.name_ko)   # 효과음은 AudioManager
		_unlock_names.append(UiUtil.region_bbcode(region))   # 대표 타입 색 (v0.89)
		_show_unlock_notice.call_deferred()


## 새 지역 해금 알림 팝업 (v0.24). 인카운터 대기 중일 때만 띄우고(전투·결과 표시 중이면 끝난 뒤),
## 여러 지역이 한꺼번에 열리면 한 팝업에 모은다. "확인"을 눌러야 목록을 비운다
## (전투 시작으로 패널이 닫히면 전투가 끝난 뒤 다시 띄운다).
## 도감 완성 알림(v0.77)도 같은 조건으로, 지역 해금보다 먼저 띄운다 → 포획 정보 창을 확인한 뒤에 뜬다.
func _show_unlock_notice() -> void:
	var dex_due := PlayerState.is_dex_complete() and not PlayerState.dex_complete_noticed
	var legend_due := UnlockManager.legend_notice_due()   # 전설 울음소리 (v0.97, 기획서 4.5)
	if _unlock_names.is_empty() and not dex_due and legend_due.is_empty():
		return
	if EncounterManager.state not in [EncounterManager.State.WAITING, EncounterManager.State.PAUSED]:
		return
	if _confirm.visible and not _confirm.is_notice:
		return   # 다른 확인 창이 떠 있으면 그 창이 닫힌 뒤
	if _caught.visible:
		return   # 포획 정보 창을 확인한 뒤
	if dex_due:
		_confirm.notify("도감 완성!", DEX_COMPLETE_TEXT, func() -> void:
			PlayerState.mark_dex_complete_noticed(), true)   # BBCode: "더 자주 나타난다"만 노란색 (v0.90)
		AudioManager.play(&"region_unlocked")
		return
	if _unlock_names.is_empty():
		_notify_legend(legend_due)
		return
	_confirm.notify("새 지역 해금", "새로운 지역이 해금되었다!\n%s\n\n지역 버튼에서 이동할 수 있다." % ", ".join(_unlock_names),
		func() -> void: _unlock_names.clear(), true)


## 전설 조건을 처음 채웠을 때 "~에서 울음소리가 들려온다." (v0.97). 같은 지역은 한 줄로, 확인하면 다시 안 뜬다
func _notify_legend(due: Array[LegendaryRule]) -> void:
	var ids: Array[int] = []
	var names: Array[String] = []
	for rule in due:
		ids.append(rule.dex_id)
		for rid in rule.region_ids:
			var region := GameData.get_region(rid)
			if region and not names.has(UiUtil.region_bbcode(region)):
				names.append(UiUtil.region_bbcode(region))
	if names.is_empty():
		PlayerState.mark_legend_noticed(ids)   # 보여 줄 지역이 없으면 조용히 처리
		return
	var lines: Array[String] = []
	for n in names:
		lines.append("%s에서 울음소리가 들려온다." % n)
	_confirm.notify("전설의 기척", "\n".join(lines), func() -> void: PlayerState.mark_legend_noticed(ids), true)
	AudioManager.play(&"region_unlocked")


## 지역을 바꾸면 다음 인카운터부터 적용. 대기 중이면 화면도 바로 바꾼다.
func _on_current_region_changed(_id: StringName) -> void:
	if not _walkers_should_watch():   # 대기·멈춤 중
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
	_found_icon = TextureRect.new()
	_found_icon.name = "FoundItem"
	_found_icon.size = Vector2(FOUND_ICON_PX, FOUND_ICON_PX)
	_found_icon.position = Vector2(BATTLE_GROUND_POS.x - FOUND_ICON_PX / 2.0, POKEMON_FEET_Y - FOUND_ICON_PX)
	_found_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_found_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_found_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_found_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_found_icon.visible = false
	add_child(_found_icon)
	move_child(_found_icon, _pokemon.get_index() + 1)


## 아이템 이름 (여러 개면 "슈퍼볼 ×2", v0.88)
func _item_label(id: StringName, count: int) -> String:
	var item := GameData.get_item(id)
	var item_name := item.name_ko if item else String(id)
	return item_name + (" ×%d" % count if count > 1 else "")


## 아이템 인카운터 (v0.84, v0.98): 발판 위에 아이템이 나타난다. 클릭해야 얻는다
func _on_item_appeared(id: StringName, count: int) -> void:
	var item := GameData.get_item(id)
	_ground_plate.shaking = false
	_emote.hide_bubble()
	_found_icon.texture = item.load_icon() if item else null
	_found_icon.modulate = Color.WHITE
	_found_icon.show()
	var hit := Rect2(_found_icon.position, _found_icon.size).grow(4)   # 아이콘을 클릭 영역으로
	_hitbox.position = hit.position
	_hitbox.size = hit.size
	_hitbox.show()
	_title.text = "%s을(를) 발견했다!" % _item_label(id, count)
	_update_hud()
	if _autoplay:
		get_tree().create_timer(1.0).timeout.connect(_start_battle)


## 아이템을 클릭해 얻었다: 알림만 (얻는 것과 소리는 EncounterManager 가 했다)
func _on_item_found(id: StringName, count: int) -> void:
	var label := _item_label(id, count)
	_hitbox.hide()
	_title.text = "%s을(를) 얻었다!" % label
	_push_notice("발견: %s" % label)
	_update_hud()


## 클릭하지 않아 아이템이 사라졌다
func _on_item_lost(id: StringName, count: int) -> void:
	_found_icon.modulate = Color(1, 1, 1, 0.35)
	_hitbox.hide()
	_title.text = "%s은(는) 사라졌다..." % _item_label(id, count)
	_update_hud()


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


## 전투 칸 배경: 하늘색(위) → 땅색(아래) 두 색 그라데이션 (v0.53). 배경·땅 바로 위, 발판·포켓몬 아래.
func _set_battle_bg(top: Color, bottom: Color) -> void:
	if _battle_bg == null:
		_battle_bg = TextureRect.new()
		_battle_bg.name = "BattleBackground"
		_battle_bg.position = BATTLE_COLUMN.position
		_battle_bg.size = BATTLE_COLUMN.size
		_battle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle_bg.stretch_mode = TextureRect.STRETCH_SCALE
		_battle_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var tex := GradientTexture2D.new()
		tex.width = 1
		tex.height = int(BATTLE_COLUMN.size.y)
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.gradient = Gradient.new()
		_battle_bg.texture = tex
		add_child(_battle_bg)
		move_child(_battle_bg, $Ground.get_index() + 1)
	var g: Gradient = (_battle_bg.texture as GradientTexture2D).gradient
	g.set_color(0, top)
	g.set_color(1, bottom)


## 지금 버전 문자열 "v0.64" (project.godot 의 application/config/version, 기획서 문서 버전과 같게 둔다)
static func version_text() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "?"))


## 전투 칸 오른쪽 아래 구석의 흐린 버전 표시 (v0.64). 테두리 바로 안쪽, 테두리 아래에 그린다.
func _build_version_label() -> void:
	_version_label = Label.new()
	_version_label.name = "VersionLabel"
	_version_label.text = version_text()
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.size = Vector2(BATTLE_COLUMN.size.x - BATTLE_FRAME_PX * 2 - 2, 16)
	_version_label.position = BATTLE_COLUMN.position + Vector2(BATTLE_FRAME_PX, BATTLE_COLUMN.size.y - BATTLE_FRAME_PX - 16)
	_version_label.add_theme_color_override(&"font_color", VERSION_COLOR)
	_version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version_label)
	move_child(_version_label, _battle_frame.get_index())


## 오른쪽 전투 칸 테두리 (v0.47, 2px, 버튼 줄 색): 칸이 창 끝에 붕 떠 보이지 않게 액자처럼 두른다.
## 과녁·포켓몬 위, 패널 아래에 그린다 (v0.46 의 1px 구분선을 대신함).
func _build_battle_frame() -> void:
	_battle_frame = Control.new()
	_battle_frame.name = "BattleFrame"
	_battle_frame.position = BATTLE_COLUMN.position
	_battle_frame.size = BATTLE_COLUMN.size
	_battle_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := BATTLE_FRAME_PX
	var sz := BATTLE_COLUMN.size
	for r in [Rect2(0, 0, sz.x, w), Rect2(0, sz.y - w, sz.x, w), Rect2(0, 0, w, sz.y), Rect2(sz.x - w, 0, w, sz.y)]:
		var edge := ColorRect.new()
		edge.color = $ButtonBar.color
		edge.position = r.position
		edge.size = r.size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle_frame.add_child(edge)
	add_child(_battle_frame)
	move_child(_battle_frame, _panel_layer.get_index())


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
	_capture.clear()
	_pokemon.scale = Vector2.ONE
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
	if EncounterManager.collect_item():   # 아이템 인카운터: 클릭하면 줍는다 (v0.98)
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
	_battle.finished.connect(_on_capture_game_finished)
	# 전투 칸(오른쪽 128px)만 차지한다 → 왼쪽 UI 클릭을 막지 않는다 (v0.46)
	_battle.position = BATTLE_COLUMN.position
	_battle.size = BATTLE_COLUMN.size
	_battle.clip_contents = true   # v0.60: 과녁 끝이 왼쪽 UI 쪽으로 넘어가 보이지 않게
	move_child(_battle_frame, _panel_layer.get_index())   # 테두리는 과녁 위
	_battle.start(params, EncounterManager.rng)
	# 전투 중: 전투 칸 맨 윗줄에 이름·성별·레벨 → 그 아래 포획 게이지(battle.gd). 안내는 왼쪽 안내 문구로 (v0.46)
	_title.text = "과녁을 클릭해서 잡자!"
	_show_battle_info(EncounterManager.current)
	_update_hud()


func _show_battle_info(enc: Dictionary) -> void:
	var species := GameData.get_species(enc[&"dex_id"])
	var g := UiUtil.gender_bbcode(String(enc[&"gender"]), false)
	# 전투 칸이 좁아(128px) "색이 다른"·"전설" 글자 대신 색이 다른 개체는 이름을 금색으로 (v0.46)
	var name_text := species.name_ko
	if enc.get(&"shiny", false):
		name_text = "[color=%s]%s[/color]" % [SHINY_NAME_COLOR, name_text]
	_battle_info.text = "%s%s Lv%d" % [name_text, (" " + g) if g != "" else "", enc[&"level"]]
	_battle_info.show()


func _on_battle_finished(_success: bool) -> void:
	_battle_info.hide()
	if _battle != null:
		_battle.queue_free()
		_battle = null


## 과녁 게임이 끝났을 때 (v0.50): 실패면 바로 결과, 성공이면 포획 연출을 보여 준 뒤 결과(포획 정보 창)
## 게이지를 다 채우면 언제나 잡힌다(흔들리다 빠져나오는 일은 없음).
func _on_capture_game_finished(success: bool) -> void:
	if not success:
		EncounterManager.finish_battle(false)
		return
	if _battle != null:
		_battle.hide()   # 과녁·게이지를 치우고 연출만
	_stop_bob()
	var item := GameData.get_item(_battle_ball)
	_title.text = "가랏! %s!" % (item.name_ko if item else "몬스터볼")
	var from := BATTLE_COLUMN.position + Vector2(12, BATTLE_COLUMN.size.y - 6)
	var to := Vector2(BATTLE_GROUND_POS.x, _pokemon_used.position.y + _pokemon_used.size.y * 0.45) if _pokemon_used.has_area() 		else _pokemon.position
	_capture.finished.connect(func() -> void: EncounterManager.finish_battle(true), CONNECT_ONE_SHOT)
	_capture.play(_battle_ball, from, to, POKEMON_FEET_Y, _pokemon)


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
	_push_notice("레벨 업! Lv%d" % new_level)
	var capsule := GameData.capsule_template()
	if capsule and new_level == capsule.unlock_level:   # v0.79
		_push_notice("특성 캡슐 해금! (박사에게 한 마리씩 보내기)")
	var new_items := PackedStringArray()   # v0.82: 이 레벨에 상점에 새로 나오는 아이템
	for it in GameData.all_items():
		if it.can_buy() and it.unlock_level == new_level:
			new_items.append(it.name_ko)
	if not new_items.is_empty():
		_push_notice("상점에 새 아이템: %s" % ", ".join(new_items))
	_update_hud()


## 왼쪽 아래 알림 한 줄 추가 (v0.59). 최대 NOTICE_MAX_LINES 줄.
## 각 줄은 (NOTICE_SEC - NOTICE_FADE_SEC)초 동안 그대로 보이다가 NOTICE_FADE_SEC 동안 천천히 흐려져 사라진다 (v0.66).
func _push_notice(line: String) -> void:
	_notice_seq += 1
	_notices.append({"id": _notice_seq, "text": line, "age": 0.0})
	while _notices.size() > NOTICE_MAX_LINES:
		_notices.pop_front()
	_render_notices()
	if _notice_timer and _notice_timer.is_stopped():
		_notice_timer.start()


## 나이(초)에 따른 줄의 불투명도: 처음엔 1, 마지막 NOTICE_FADE_SEC 동안 0까지 (v0.66)
static func notice_alpha(age: float) -> float:
	return clampf((NOTICE_SEC - age) / NOTICE_FADE_SEC, 0.0, 1.0)


func _tick_notices() -> void:
	var dt := _notice_timer.wait_time
	for n in _notices:
		n.age = float(n.age) + dt
	_notices = _notices.filter(func(n: Dictionary) -> bool: return float(n.age) < NOTICE_SEC)
	_render_notices()
	if _notices.is_empty():
		_notice_timer.stop()


func _clear_notices() -> void:
	_notices.clear()
	_render_notices()


## 줄마다 글자·외곽선의 알파를 나이에 맞춰 낮춘다
func _render_notices() -> void:
	if _notice == null:
		return
	var lines: PackedStringArray = []
	for n in _notices:
		var a := notice_alpha(float(n.age))
		var text := String(n.text).replace(char(91), "[lb]")   # 여는 대괄호를 BBCode 로 해석하지 않게
		lines.append("[color=#%s][outline_color=#%s]%s[/outline_color][/color]" % [
			Color(1, 1, 1, a).to_html(true), Color(NOTICE_OUTLINE, a).to_html(true), text])
	_notice.text = "\n".join(lines)


# ---------------------------------------------------------------- HUD

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
	_entry_clip = Control.new()
	_entry_clip.name = "EntryClip"
	_entry_clip.size = Vector2(WIDTH, 200)
	_entry_clip.clip_contents = true
	_entry_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_entry_clip)
	move_child(_entry_clip, _panel_layer.get_index())   # 패널·버튼 줄·HUD 아래
	_entry_strip = PanelContainer.new()
	_entry_strip.position = Vector2(ENTRY_STRIP_RIGHT, ENTRY_STRIP_TOP)
	_entry_strip.add_theme_stylebox_override(&"panel", _overlay_style())
	_entry_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_clip.add_child(_entry_strip)
	_entry_icons = HBoxContainer.new()
	_entry_icons.add_theme_constant_override(&"separation", 2)
	_entry_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_strip.add_child(_entry_icons)
	# 접기/펴기 화살표 탭 (v0.47). 상태는 설정에 저장
	_entry_open = bool(Settings.get_value(&"entry_strip_open"))
	_entry_tab = EntryTab.new()
	_entry_tab.size = ENTRY_TAB_SIZE
	_entry_tab.style = _overlay_style()
	_entry_tab.pressed.connect(_toggle_entry_strip)
	_entry_clip.add_child(_entry_tab)

	# 알림 문구 (v0.59): 안내 문구와 같은 흰 글자 + 외곽선, 아래 정렬
	_notice = RichTextLabel.new()
	_notice.name = "Notice"
	_notice.bbcode_enabled = true
	_notice.scroll_active = false
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.position = Vector2(NOTICE_LEFT, NOTICE_BOTTOM - NOTICE_HEIGHT)
	_notice.size = Vector2(WIDTH - NOTICE_LEFT * 2, NOTICE_HEIGHT)
	_notice.add_theme_color_override(&"default_color", Color(1, 1, 1))
	_notice.add_theme_constant_override(&"outline_size", 4)
	_notice.add_theme_color_override(&"font_outline_color", NOTICE_OUTLINE)
	add_child(_notice)
	move_child(_notice, _entry_clip.get_index())
	_notice_timer = Timer.new()
	_notice_timer.wait_time = 0.1
	_notice_timer.timeout.connect(_tick_notices)
	add_child(_notice_timer)

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


# ---------------------------------------------------------------- 걸어다니는 엔트리 (M12, v0.45)

## 배경·땅 바로 위, 안내 문구·발판·포켓몬·말풍선보다 아래에 그린다.
## 그 아래에 왼쪽 장면 전체를 땅 색으로 덮는 면(_field)을 깐다 (v0.47: 하늘은 오른쪽 전투 칸에만).
func _build_walkers() -> void:
	_field = ColorRect.new()
	_field.name = "Field"
	_field.position = Vector2(0, 18)
	_field.size = Vector2(WIDTH, 200 - 18 - 19)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 배경 드래그는 그대로
	var region := GameData.get_region(PlayerState.current_region)
	_field.color = region.ground_color if region else $Ground.color
	add_child(_field)
	move_child(_field, _title.get_index())
	# 들판 타일맵 (v0.48): 장면 위쪽(버튼 줄 아래)부터. 마지막 줄은 HUD 에 가려진다.
	_field_map = FieldMap.new()
	_field_map.name = "FieldMap"
	_field_map.position = _field.position
	add_child(_field_map)
	move_child(_field_map, _title.get_index())
	_field_map.set_region(PlayerState.current_region)
	# 안내 문구가 타일 위에서도 읽히게: 흰 글자 + 어두운 외곽선 (v0.48)
	_title.add_theme_color_override(&"default_color", Color(1, 1, 1))
	_title.add_theme_constant_override(&"outline_size", 4)
	_title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.13, 0.2))
	_walkers = Node2D.new()
	_walkers.name = "Walkers"
	_walkers.y_sort_enabled = true
	add_child(_walkers)
	move_child(_walkers, _title.get_index())


## 엔트리가 바뀌면: 빠진 포켓몬은 지우고, 새 포켓몬은 무작위 위치에서 시작, 진화 등으로 모습이 바뀌면 그림만 교체.
func _refresh_walkers(entries: Array[Dictionary]) -> void:
	if _walkers == null:
		return
	var keep := {}
	for p in entries:
		keep[String(p.uid)] = p
	for w: OverworldWalker in _walkers.get_children():
		if not keep.has(w.uid):
			_walkers.remove_child(w)
			w.queue_free()
	var watching := _walkers_should_watch()
	for uid: String in keep:
		var p: Dictionary = keep[uid]
		var s := GameData.get_species(p.dex_id)
		var female := String(p.get("gender", "")) == "female"
		var key := "%d:%s" % [int(p.dex_id), female]
		var sheet := PokemonSprites.overworld_walk_sheet(s, female)
		var icon: Texture2D = UiUtil.pokemon_icon(s) if s else null
		var w := _find_walker(uid)
		if w == null:
			w = OverworldWalker.new()
			w.uid = uid
			w.look_key = key
			w.rng.randomize()
			w.blocked = _field_blocked
			w.grid_origin = _field_map.position if _field_map else Vector2(0, 18)   # 들판 칸에 맞춰 걷기 (v0.67)
			var start := Vector2(w.rng.randf_range(WALK_AREA.position.x, WALK_AREA.end.x),
				w.rng.randf_range(WALK_AREA.position.y, WALK_AREA.end.y))
			w.setup(sheet, icon, WALK_AREA, start)
			w.relocate_if_blocked()   # 나무·물 위에서 시작하지 않게
			_walkers.add_child(w)
			if watching:
				w.set_watching(true, BATTLE_GROUND_POS)
		elif w.look_key != key:
			w.look_key = key
			w.set_look(sheet, icon)


## 들판 타일맵에서 못 지나가는 곳인가 (발 위치, 메인 창 좌표)
func _field_blocked(p: Vector2) -> bool:
	return _field_map != null and _field_map.is_blocked(p - _field_map.position)


## 지역이 바뀌면 들판을 다시 깔고, 나무·물 위에 서게 된 엔트리는 빈 곳으로 옮긴다
func _set_field_region() -> void:
	if _field_map == null or _field_map.region_id == PlayerState.current_region:
		return
	_field_map.set_region(PlayerState.current_region)
	if _walkers:
		for w: OverworldWalker in _walkers.get_children():
			w.relocate_if_blocked()


func _find_walker(uid: String) -> OverworldWalker:
	for w: OverworldWalker in _walkers.get_children():
		if w.uid == uid:
			return w
	return null


## 인카운터가 시작돼 끝날 때까지(포켓몬 등장·전투·결과) 지켜본다
func _walkers_should_watch() -> bool:
	return EncounterManager.state not in [EncounterManager.State.WAITING, EncounterManager.State.PAUSED]


func _set_walkers_watching(on: bool) -> void:
	if _walkers == null:
		return
	for w: OverworldWalker in _walkers.get_children():
		w.set_watching(on, BATTLE_GROUND_POS)


## 엔트리 아이콘(왼쪽 아래)과 버프(오른쪽 위)를 다시 그린다. 버프는 전투 중에는 숨긴다(게이지와 겹치지 않게).
func _refresh_entry_widgets() -> void:
	if _entry_icons == null:
		return
	var entries := PlayerState.entry_pokemon()
	# PlayerState.changed 는 경험치·돈·아이템마다 오므로, 엔트리 모습이 그대로면 아이콘·걷는 포켓몬은 다시 만들지 않는다
	var key := str(entries.map(func(p: Dictionary) -> String:
		return "%s:%d:%s:%d" % [p.uid, int(p.dex_id), p.get("gender", ""), int(p.level)]))
	if key == _entry_key:
		_refresh_buffs(true)
		return
	_entry_key = key
	_clear_children(_entry_icons)
	for p in entries:
		var s := GameData.get_species(p.dex_id)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ENTRY_ICON, ENTRY_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var frames: Array[Texture2D] = []
		var atlas := PokemonSprites.atlas_icon(s, String(p.get("gender", "")) == "female", bool(p.get("shiny", false)), true)
		if atlas:
			frames.append(atlas)   # 도감 아틀라스 그림은 정지 1장 (v0.99)
		else:
			frames = PokemonSprites.overworld_frames(s, String(p.get("gender", "")) == "female")
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
	_entry_tab.visible = _entry_strip.visible
	_layout_entry_strip(false)
	_refresh_walkers(entries)

	_refresh_buffs(true)


## 엔트리 상자 접기/펴기 (v0.47): 화살표 탭을 누르면 상자가 오른쪽 밖으로(v0.59) 미끄러져 들어가거나 나온다.
func _toggle_entry_strip() -> void:
	_entry_open = not _entry_open
	Settings.set_value(&"entry_strip_open", _entry_open)
	AudioManager.play(&"button_click")
	_layout_entry_strip(true)


## 펼침: 상자는 오른쪽 아래 제자리, 탭은 상자 왼쪽에 붙어 "▶". 접힘: 상자는 왼쪽 UI 오른쪽 끝 밖, 탭만 오른쪽 끝에 "◀". (v0.59)
func _layout_entry_strip(animate: bool) -> void:
	var w := _entry_strip.size.x
	var strip_x := ENTRY_STRIP_RIGHT - w if _entry_open else WIDTH + 1.0
	var tab_x := strip_x - 1.0 - ENTRY_TAB_SIZE.x if _entry_open else WIDTH - ENTRY_TAB_SIZE.x
	var y := ENTRY_STRIP_TOP
	_entry_tab.position.y = y + (_entry_strip.size.y - ENTRY_TAB_SIZE.y) / 2.0
	_entry_tab.pointing_left = not _entry_open
	# 알림 문구는 엔트리 상자·탭 왼쪽까지만
	var notice_right := (tab_x if _entry_tab.visible else WIDTH) - 4.0
	_notice.size.x = notice_right - NOTICE_LEFT
	_entry_tab.tooltip_text = "엔트리 접기" if _entry_open else "엔트리 펴기"
	if _entry_slide:
		_entry_slide.kill()
	if not animate:
		_entry_strip.position = Vector2(strip_x, y)
		_entry_tab.position.x = tab_x
		return
	_entry_slide = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entry_slide.tween_property(_entry_strip, ^"position:x", strip_x, ENTRY_SLIDE_SEC)
	_entry_slide.tween_property(_entry_tab, ^"position:x", tab_x, ENTRY_SLIDE_SEC)


## 버프 목록(오른쪽 위). 향로 남은 시간이 바뀌므로 HUD 갱신 때마다 부르고, 내용이 같으면 그대로 둔다.
func _refresh_buffs(force: bool = false) -> void:
	if _buff_list == null:
		return
	var buffs := EncounterManager.active_buffs()
	var key := "\n".join(PackedStringArray(buffs.map(func(b) -> String: return b.text)))
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
	var show_buffs := not buffs.is_empty()   # v0.46: 게이지가 전투 칸으로 옮겨져 전투 중에도 보인다
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


## HUD 위쪽 2px 경험치 막대 + 오른쪽 볼 표시
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
			status = "클릭해서 %s (%d초)" % ["줍기" if EncounterManager.current.has(&"item") else "잡기", ceili(EncounterManager.seconds_until_flee())]
		EncounterManager.State.BATTLE:
			status = "과녁을 클릭!"
		EncounterManager.State.RESULT:
			status = ""
	_hud_label.text = "Lv%d  %s" % [PlayerState.level, status]
	if not _buttons.is_empty():
		_sync_buttons()
	if _crown:
		_crown.visible = PlayerState.dex_complete_noticed
		if _crown.visible:
			var bias_sec := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
			_crown.tooltip_text = "도감 완성 (%s)" % Time.get_date_string_from_unix_time(PlayerState.dex_completed_at + bias_sec)


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
		MOUSE_BUTTON_LEFT when WindowManager.move_mode:   # v0.60: 설정의 "창 옮기기"가 켜져 있을 때만
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
	_dev_menu.add_item("레벨 +1", DevMenu.LEVEL_UP)
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
		DevMenu.LEVEL_UP:
			PlayerState.debug_level_up()
		DevMenu.RESET_SAVE:
			_confirm.ask("저장 초기화 (개발용)",
				"저장된 진행을 모두 지웁니다.\n(레벨, 도감, 보관함, 아이템, 재화)\n설정(창 크기·소리 등)은 유지됩니다.\n되돌릴 수 없습니다. 계속할까요?",
				"초기화", SaveManager.reset_save)
