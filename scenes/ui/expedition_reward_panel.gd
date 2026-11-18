extends OverlayPanel
## 원정 보상 팝업 (기획서 4.10, 6.2, v0.59). 원정 패널에서 "보상 받기"를 누르면 그 위에 뜬다.
## 제목 줄: 원정지 이름 + 성공/실패. 위: 획득한 아이템(돈 포함) / 구분선 / 아래: 경험치와 레벨이 오른 포켓몬.
## 아이템·포켓몬은 사각형 칸 안에 그림, 칸 아래 가운데에 획득량(개수·오른 레벨). 마우스를 올리면 이름.
## 제목 줄의 "닫기"는 숨기고, 아래 "확인"을 눌러야 닫힌다.

const GOLD := Color("ffd95a")
const FAIL := Color("ff8080")
const LEVEL_COLOR := Color("9be37a")
## 아이템·포켓몬 칸 크기와 그림 크기 (기준 해상도)
const TILE := Vector2(36, 36)
const TILE_ICON := 24   # 아이콘 파일 크기 그대로 (1:1, v0.62)
## 아이템·포켓몬 영역 좌우 여백
const SIDE_PAD := 10
const COIN_ICON := "res://Assets/Generated/icons/coin.png"

var _result: Label
var _item_tiles: HFlowContainer
var _exp_label: Label
var _none_label: Label
var _mon_tiles: HFlowContainer
var _ok: Button


func _panel_title() -> String:
	return "원정 보상"


func _build_content(box: VBoxContainer) -> void:
	_header_row.get_node("Close").visible = false
	# 제목 옆 성공/실패
	_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_result = Label.new()
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.add_child(_result)
	_header_row.move_child(_result, _title_label.get_index() + 1)
	_header_row.add_theme_constant_override(&"separation", 8)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override(&"margin_left", SIDE_PAD)
	pad.add_theme_constant_override(&"margin_right", SIDE_PAD)
	scroll.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", 1)
	pad.add_child(inner)

	inner.add_child(_section_label("획득한 아이템"))
	_item_tiles = _flow()
	inner.add_child(_item_tiles)
	inner.add_child(HSeparator.new())
	_exp_label = _section_label("")
	inner.add_child(_exp_label)
	_none_label = Label.new()
	_none_label.text = "레벨이 오른 포켓몬은 없다"
	inner.add_child(_none_label)
	_mon_tiles = _flow()
	inner.add_child(_mon_tiles)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_ok = Button.new()
	_ok.text = "확인"
	_ok.custom_minimum_size.x = 60
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(close_panel)
	row.add_child(_ok)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", GOLD)
	return l


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override(&"h_separation", 4)
	f.add_theme_constant_override(&"v_separation", 4)
	return f


## ExpeditionManager.claim() 의 결과(ok = true)를 보여준다
func show_result(r: Dictionary) -> void:
	var x := GameData.get_expedition(StringName(r.get("expedition", "")))
	_title_label.text = x.name_ko if x else "원정 보상"
	_result.text = "성공!" if r.success else "실패... (보상 30%)"
	_result.add_theme_color_override(&"font_color", GOLD if r.success else FAIL)

	_clear(_item_tiles)
	for t in item_tiles(r):
		_item_tiles.add_child(_tile(t))
	var exp_map: Dictionary = r.get("pokemon_exp", {})
	_exp_label.text = "포켓몬  경험치 +%d" % (exp_map.values().max() if exp_map.size() > 0 else 0)
	_clear(_mon_tiles)
	var mons := pokemon_tiles(r)
	for t in mons:
		_mon_tiles.add_child(_tile(t))
	_none_label.visible = mons.is_empty()
	_mon_tiles.visible = not mons.is_empty()
	open_panel()


## 아이템 칸 목록: {icon: Texture2D, coin: 그림이 없을 때 직접 그린 동전, amount: 칸 아래 글자, tip: 이름}
## 돈 그림 = Assets/Generated/icons/coin.png (v0.62, tools/import_icons.gd 가 Assets/Sprites/Coin.png 에서 만든다)
static func item_tiles(r: Dictionary) -> Array[Dictionary]:
	var coin_tex: Texture2D = load(COIN_ICON) if ResourceLoader.exists(COIN_ICON) else null
	var out: Array[Dictionary] = [{"icon": coin_tex, "coin": coin_tex == null,
		"amount": ShopManager.format_money(r.currency).trim_suffix("원"), "tip": ShopManager.format_money(r.currency)}]
	for id in r.items:
		var item := GameData.get_item(id)
		var item_name := item.name_ko if item else String(id)
		out.append({"icon": item.load_icon() if item else null, "amount": "×%d" % r.items[id], "tip": "%s ×%d" % [item_name, r.items[id]]})
	return out


## 레벨이 오른 포켓몬 칸 목록: 칸 아래 "+오른 레벨", 마우스를 올리면 "이름 Lv 전 → 후"
static func pokemon_tiles(r: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var levels: Dictionary = r.get("levels", {})
	for uid in levels:
		var p := PlayerState.find_pokemon(uid)
		if p.is_empty():
			continue
		var s := GameData.get_species(p.dex_id)
		var to: int = p.level
		var gained := int(levels[uid])
		out.append({"icon": UiUtil.pokemon_icon(s, String(p.get("gender", "")) == "female") if s else null,
			"amount": "+%d" % gained, "color": LEVEL_COLOR,
			"tip": "%s  Lv%d → Lv%d" % [s.name_ko if s else "?", to - gained, to]})
	return out


## 사각형 칸: 위 가운데 그림, 아래 가운데 획득량
func _tile(t: Dictionary) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = TILE
	panel.tooltip_text = t.tip
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.25, 0.33)
	sb.border_color = Color(0.4, 0.46, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	panel.add_theme_stylebox_override(&"panel", sb)
	var icon_rect := Rect2((TILE.x - TILE_ICON) / 2.0, 1, TILE_ICON, TILE_ICON)
	if t.get("coin", false):
		var coin := Coin.new()
		coin.position = icon_rect.position
		coin.size = icon_rect.size
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(coin)
	else:
		var tex := TextureRect.new()
		tex.texture = t.icon
		tex.position = icon_rect.position
		tex.size = icon_rect.size
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex)
	var amount := Label.new()
	amount.text = t.amount
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.position = Vector2(-6, TILE.y - 16)   # 칸보다 조금 넓게 잡아 "2,350" 같은 글자도 가운데에
	amount.size = Vector2(TILE.x + 12, 16)
	amount.add_theme_color_override(&"font_color", t.get("color", Color.WHITE))
	amount.add_theme_constant_override(&"outline_size", 3)
	amount.add_theme_color_override(&"font_outline_color", Color(0.08, 0.09, 0.13))
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(amount)
	return panel


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## 돈 칸 대체 그림: coin.png 가 없을 때(스프라이트 없는 저장소 등) 직접 그리는 픽셀 동전
class Coin extends Control:
	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 9.0, Color("8a5a12"))
		draw_circle(c, 8.0, Color("f2c230"))
		draw_circle(c, 5.5, Color("d99a1c"))
		draw_circle(c, 4.5, Color("ffd95a"))
		draw_rect(Rect2(c.x - 1, c.y - 3, 2, 6), Color("b07800"))
