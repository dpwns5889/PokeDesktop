extends OverlayPanel
## 포획 정보 창 (v0.31): 포켓몬을 잡으면 그 개체의 정보를 보여 주고, "확인"을 누를 때까지 열려 있다.
## 모습과 정보를 한 덩어리로 창 가운데에 모은다(v0.36). 왼쪽: 전투 모습(색이 다른·암컷 반영) / 오른쪽: "새로 등록!"(처음 잡은 종, 이름 위), 이름·성별·레벨, 타입·색이 다른, 능력치, 특성
## 제목 줄의 "닫기"는 숨긴다(확인으로만 닫힘). 열려 있는 동안 위 버튼 줄은 잠긴다(companion).

const SPRITE := 80
## 오른쪽 정보 칸 폭 (모습과 함께 가운데 정렬, v0.36)
const INFO_WIDTH := 170
const NEW_COLOR := Color(1.0, 0.85, 0.35)

var _sprite: TextureRect
var _new_label: Label
var _name: RichTextLabel
var _status: HBoxContainer
var _stats: Dictionary = {}   # stat key -> Label
var _traits: VBoxContainer
var _scroll: ScrollContainer
var _inst: Dictionary = {}


func _panel_title() -> String:
	return "잡았다!"


func _ready() -> void:
	super()
	_header_row.get_node("Close").visible = false


func _build_content(box: VBoxContainer) -> void:
	# 모습 + 정보를 한 덩어리로 창 가운데에 모은다 (v0.36). 특성이 많아 넘치면 스크롤.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	center.add_child(row)

	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(SPRITE, SPRITE)
	_sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(_sprite)

	var info := VBoxContainer.new()
	info.custom_minimum_size.x = INFO_WIDTH
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override(&"separation", 3)
	row.add_child(info)

	_new_label = _tag("새로 등록!")   # 처음 잡은 종이면 이름 위에 (v0.35)
	info.add_child(_new_label)
	_name = UiUtil.rich_label()
	info.add_child(_name)
	_status = HBoxContainer.new()
	_status.add_theme_constant_override(&"separation", 3)
	info.add_child(_status)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 0)
	info.add_child(grid)
	for k in Formulas.STAT_KEYS:
		var l := Label.new()
		grid.add_child(l)
		_stats[k] = l

	_traits = VBoxContainer.new()
	_traits.add_theme_constant_override(&"separation", 2)
	info.add_child(_traits)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER   # v0.80 팝업 규칙: 가운데
	box.add_child(bottom)
	var ok := Button.new()
	ok.text = "확인"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size.x = 60
	ok.pressed.connect(close_panel)
	bottom.add_child(ok)


## 잡은 개체를 보여 주며 연다. new_dex = 이번에 처음 잡은 종인가
func show_pokemon(inst: Dictionary, new_dex: bool) -> void:
	_inst = inst
	_fill(new_dex)
	open_panel()


func _fill(new_dex: bool) -> void:
	var s := GameData.get_species(int(_inst.get("dex_id", 0)))
	if s == null:
		return
	var female := String(_inst.get("gender", "")) == "female"
	var shiny := bool(_inst.get("shiny", false))
	var frames := PokemonSprites.make_frames(s, female, shiny)
	_sprite.texture = frames.get_frame_texture(&"idle", 0)

	var g := UiUtil.gender_bbcode(String(_inst.get("gender", "")))
	_name.text = "%s%s Lv%d" % [s.name_ko, (" " + g) if g != "" else "", int(_inst.get("level", 1))]

	for c in _status.get_children():
		_status.remove_child(c)
		c.queue_free()
	UiUtil.add_type_badges(_status, s.types)
	if shiny:
		_status.add_child(_tag("색이 다른"))
	_new_label.visible = new_dex

	var st := PlayerState.stats_of(_inst)
	for k in Formulas.STAT_KEYS:
		_stats[k].text = "%s %d" % [UiUtil.STAT_NAMES[k], st.get(k, 0)]

	for c in _traits.get_children():
		_traits.remove_child(c)
		c.queue_free()
	var traits: Array = _inst.get("traits", [])
	if traits.is_empty():
		var none := Label.new()
		none.text = "특성 없음"
		none.add_theme_color_override(&"font_color", Color(0.6, 0.62, 0.7))
		_traits.add_child(none)
	for t in traits:
		var td := GameData.get_trait(StringName(t))
		if td == null:
			continue
		var badge := TraitBadge.new()
		badge.setup(td)
		_traits.add_child(badge)
	_scroll.scroll_vertical = 0


func _tag(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", NEW_COLOR)
	return l


## 지금 보여 주는 개체 (테스트용)
func shown() -> Dictionary:
	return _inst
