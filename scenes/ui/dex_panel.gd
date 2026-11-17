extends OverlayPanel
## 도감 패널. 151종 격자: 미발견 ?, 발견만 실루엣, 포획은 원래 모습. (기획서 4.7, 6.2)

const CELL := 34
const ICON := 24   # v0.55: 오버월드 아이콘 1:1
const COLUMNS := 8

var _header: Label
var _grid: GridContainer
var _detail: RichTextLabel
var _icon_cache: Dictionary = {}   # dex_id -> AtlasTexture


func _panel_title() -> String:
	return "도감"


func _ready() -> void:
	super()
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: _refresh_if_visible())
	EventBus.encounter_appeared.connect(func(_e: Dictionary) -> void: _refresh_if_visible())


func _build_content(box: VBoxContainer) -> void:
	_header = Label.new()
	box.add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 2)
	_grid.add_theme_constant_override(&"v_separation", 2)
	scroll.add_child(_grid)
	_detail = UiUtil.rich_label(false)
	_detail.custom_minimum_size.y = 34
	_detail.text = "칸을 누르면 정보를 볼 수 있다"
	box.add_child(_detail)


func refresh() -> void:
	var all := GameData.all_species()
	_header.text = "포획 %d  발견 %d  / %d" % [PlayerState.dex_caught_count(), PlayerState.dex_seen_count(), all.size()]
	if _grid.get_child_count() != all.size():
		for c in _grid.get_children():
			c.queue_free()
		for s in all:
			_grid.add_child(_make_cell(s))
	for i in all.size():
		_update_cell(_grid.get_child(i), all[i])


func _make_cell(s: PokemonSpecies) -> Control:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := TextureRect.new()
	tex.name = "Icon"
	tex.position = Vector2(2, 2)
	tex.size = Vector2(ICON, ICON)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(tex)
	var q := Label.new()
	q.name = "Unknown"
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_preset(Control.PRESET_FULL_RECT)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(q)
	cell.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(s))
	return cell


func _update_cell(cell: Control, s: PokemonSpecies) -> void:
	var entry: Dictionary = PlayerState.dex.get(s.dex_id, {})
	var seen: bool = entry.get("seen", false)
	var caught := int(entry.get("caught", 0)) > 0
	var tex: TextureRect = cell.get_node("Icon")
	cell.get_node("Unknown").visible = not seen
	tex.visible = seen
	if seen:
		tex.texture = _icon(s)
		tex.modulate = Color.WHITE if caught else Color(0, 0, 0, 0.55)   # 발견만 = 실루엣
	cell.tooltip_text = "No.%03d %s" % [s.dex_id, s.name_ko if seen else "???"]


func _show_detail(s: PokemonSpecies) -> void:
	var entry: Dictionary = PlayerState.dex.get(s.dex_id, {})
	if not entry.get("seen", false):
		_detail.text = "No.%03d ???\n아직 만나지 못했다" % s.dex_id
		return
	var caught := int(entry.get("caught", 0))
	var line2 := "포획 %d마리" % caught if caught > 0 else "발견만 했다"
	_detail.text = "No.%03d %s  %s\n%s" % [s.dex_id, s.name_ko, UiUtil.types_bbcode(s.types), line2]


func _icon(s: PokemonSpecies) -> Texture2D:
	if not _icon_cache.has(s.dex_id):
		_icon_cache[s.dex_id] = UiUtil.pokemon_icon(s)
	return _icon_cache[s.dex_id]
