extends OverlayPanel
## 포획 정보 창 (v0.31): 포켓몬을 잡으면 그 개체의 정보를 보여 주고, "확인"을 누를 때까지 열려 있다.
## 모습과 정보를 한 덩어리로 창 가운데에 모은다(v0.36). 왼쪽: 전투 모습(색이 다른·암컷 반영) / 오른쪽: "새로 등록!"(처음 잡은 종, 이름 위), 이름·성별·레벨, 타입, 특성 (v0.91: 색이 다르면 이름이 노란색)
## 제목 줄의 "닫기"는 숨긴다(확인으로만 닫힘). 열려 있는 동안 위 버튼 줄은 잠긴다(companion).

## 그림 칸 폭. 전투 모습은 80px 칸 안에 그려져 위·아래에 투명 여백이 있다 → 그림의 실제 윗부분이 칸 맨 위에 오도록 위로 올린다 (v0.91)
const SPRITE := 80
## 그림과 정보 칸 사이 간격 (v0.91: 8 → 12, 특성 상자가 그림에 붙어 보여서)
const SPRITE_GAP := 12
## 그림만 배치 자리에서 왼쪽·아래로 옮겨 그린다 (v0.91). 정보 칸 위치는 그대로
const SPRITE_NUDGE := Vector2(-4, 4)
## 오른쪽 정보 칸 최대 폭 (모습과 함께 가운데 정렬, v0.36). v0.91: 이름·타입이 한 줄이라 넓힘 (그림 80 + 간격 12 + 214 = 306).
## 실제 폭은 내용(이름 줄·특성 상자 중 가장 넓은 것)에 맞춘다 → 그림 + 정보 덩어리가 가로로 정확히 가운데에 온다
const INFO_WIDTH := 214
const NEW_COLOR := Color(1.0, 0.85, 0.35)
## 특성 상자 폭: 정보 칸(214)보다 좁게. 가장 긴 이름(희귀 6글자)이 들어가는 폭 (v0.91)
const TRAIT_BADGE_WIDTH := 110.0
## "새로 등록!" 위·아래 여백, 줄 사이 간격 (v0.91: 답답해 보여 넓힘)
const NEW_PAD := 3
const ROW_GAP := 2
## 확인 버튼 아래 여백: 이 창은 내용이 많아 버튼을 다른 팝업(18)보다 조금 내렸다 (v0.91). HUD 경험치 바와는 떨어져 있다
const BOTTOM_GAP := 8

var _sprite: TextureRect
## 그림 칸: 크기를 그림이 있는 부분(투명 여백 제외)에 맞춘다 (v0.91)
var _sprite_box: Control
var _new_label: Label
var _name: RichTextLabel
var _status: HBoxContainer
var _traits: VBoxContainer
var _info: VBoxContainer
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
	# (v0.91) 가로·세로 가운데
	var center := CenterContainer.new()   # 그림 + 정보 전체를 팝업 가운데에 (가로·세로, v0.91). 내용이 더 크면 스크롤
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", SPRITE_GAP)
	center.add_child(row)

	var sprite_margin := MarginContainer.new()   # 그림은 정보 칸(오른쪽)의 세로 가운데에 (v0.91)
	sprite_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprite_margin)
	_sprite_box = Control.new()
	_sprite_box.custom_minimum_size = Vector2(SPRITE, SPRITE)
	sprite_margin.add_child(_sprite_box)
	_sprite = TextureRect.new()
	_sprite.size = Vector2(SPRITE, SPRITE)
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_sprite_box.add_child(_sprite)

	var info := VBoxContainer.new()
	info.custom_minimum_size.x = INFO_WIDTH   # _fill 이 내용 폭에 맞춰 줄인다
	_info = info
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.add_theme_constant_override(&"separation", ROW_GAP)
	row.add_child(info)

	# v0.91: 한 줄씩 — 새로 등록! / 이름·성별·레벨·타입 1(·타입 2) / 특성 1 / 특성 2 / 특성 3 (능력치는 뺌)
	_new_label = _tag("새로 등록!")   # 처음 잡은 종이면 이름 위에 (v0.35)
	var pad := StyleBoxEmpty.new()   # 위·아래 여백 (v0.91)
	pad.content_margin_top = NEW_PAD
	pad.content_margin_bottom = NEW_PAD
	_new_label.add_theme_stylebox_override(&"normal", pad)
	info.add_child(_new_label)
	var line := HFlowContainer.new()   # 이름·성별·레벨과 타입 상자를 한 줄에. 길면 아래로 줄바꿈
	line.add_theme_constant_override(&"h_separation", 6)
	line.add_theme_constant_override(&"v_separation", 0)
	info.add_child(line)
	_name = UiUtil.rich_label()
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF   # 한 줄 폭만큼만 차지
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.add_child(_name)
	_status = HBoxContainer.new()
	_status.add_theme_constant_override(&"separation", 3)
	line.add_child(_status)

	_traits = VBoxContainer.new()
	_traits.add_theme_constant_override(&"separation", ROW_GAP)
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
	add_popup_bottom_gap(box, BOTTOM_GAP)   # 확인 버튼이 아래 HUD(경험치 바)와 닿지 않게, 다른 팝업보다는 조금 아래 (v0.91)


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
	var tex := frames.get_frame_texture(&"idle", 0)
	_sprite.texture = tex
	_place_sprite(tex)

	var g := UiUtil.gender_bbcode(String(_inst.get("gender", "")))
	var nm := ("[color=#%s]%s[/color]" % [NEW_COLOR.to_html(false), s.name_ko]) if shiny else s.name_ko   # 색이 다르면 이름을 노란색 (v0.91)
	_name.text = "%s%s Lv%d" % [nm, (" " + g) if g != "" else "", int(_inst.get("level", 1))]

	for c in _status.get_children():
		_status.remove_child(c)
		c.queue_free()
	UiUtil.add_type_badges(_status, s.types)
	_new_label.visible = new_dex

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
		badge.custom_minimum_size.x = TRAIT_BADGE_WIDTH   # 폭을 줄임 (v0.91)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.clip_contents = true   # 더 긴 이름은 끝이 잘린다 (툴팁에 전체)
		_traits.add_child(badge)
	_fit_info_width()
	_scroll.scroll_vertical = 0


## 정보 칸 폭을 내용에 맞춘다: 이름·성별·레벨 + 타입 상자 / 특성 상자 / "새로 등록!" 중 가장 넓은 것 (최대 INFO_WIDTH).
## 폭이 남으면 그림 + 정보 덩어리가 오른쪽으로 치우쳐 보인다 (v0.91)
func _fit_info_width() -> void:
	var line_w := _name.get_content_width() + 6.0 + _status.get_combined_minimum_size().x
	var w := maxf(line_w, _new_label.get_combined_minimum_size().x)
	if _traits.get_child_count() > 0 and _traits.get_child(0) is TraitBadge:
		w = maxf(w, TRAIT_BADGE_WIDTH)
	_info.custom_minimum_size.x = minf(ceilf(w), float(INFO_WIDTH))


## 그림이 있는 부분(투명 여백 제외)의 위·왼쪽 끝이 칸 모서리에 오게 그림을 옮기고, 칸 크기를 그 부분에 맞춘다 (v0.91)
func _place_sprite(tex: Texture2D) -> void:
	var used := Rect2i(0, 0, SPRITE, SPRITE)
	var at := tex as AtlasTexture
	if at:
		var img := at.atlas.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var r := img.get_region(Rect2i(at.region)).get_used_rect()
			if r.size != Vector2i.ZERO:
				used = r
	# 가로도 그림이 있는 부분만 (v0.91: 가로 가운데를 맞추려고). 칸 밖은 투명이라 잘라 내지 않고 SPRITE_NUDGE 만큼 옮긴다
	_sprite.position = Vector2(-used.position.x, -used.position.y) + SPRITE_NUDGE
	_sprite_box.custom_minimum_size = Vector2(used.size.x, used.size.y)


func _tag(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", NEW_COLOR)
	return l


## 지금 보여 주는 개체 (테스트용)
func shown() -> Dictionary:
	return _inst
