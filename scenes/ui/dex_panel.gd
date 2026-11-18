extends OverlayPanel
## 도감 패널. 151종 격자: 미발견 ?, 발견만 실루엣, 포획은 원래 모습. (기획서 4.7, 6.2)
## 도감을 완성하면(v0.77) 제목 줄에 "색다름" 전환: 색이 다른 모습으로 잡은 종은 색이 다른 전투 모습, 못 잡은 종은 흐리게.

const CELL := 34
const ICON := 24   # v0.55: 오버월드 아이콘 1:1
const COLUMNS := 8

var _header: Label
var _grid: GridContainer
var _detail: RichTextLabel
var _icon_cache: Dictionary = {}   # dex_id -> AtlasTexture
var _shiny_icon_cache: Dictionary = {}   # dex_id -> AtlasTexture (전투 시트의 색이 다른 첫 프레임)
## 색이 다른 도감 보기 (v0.77, 도감 완성 후)
var _shiny_view := false
var _shiny_toggle: Button


func _panel_title() -> String:
	return "도감"


func _ready() -> void:
	super()
	_shiny_toggle = add_header_button("색다름", func() -> void:
		_shiny_view = not _shiny_view
		refresh())
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
	_shiny_toggle.visible = PlayerState.is_dex_complete()
	_shiny_view = _shiny_view and _shiny_toggle.visible
	_shiny_toggle.text = "일반" if _shiny_view else "색다름"
	if _shiny_view:
		_header.text = "색이 다른 %d / %d" % [PlayerState.dex_shiny_count(), all.size()]
	else:
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
	if _shiny_view:   # 도감 완성 뒤라 모두 본 종
		var got := PlayerState.is_shiny_caught(s.dex_id)
		cell.get_node("Unknown").visible = false
		tex.visible = true
		tex.texture = _shiny_icon(s) if got else _icon(s)
		tex.modulate = Color.WHITE if got else Color(1, 1, 1, 0.3)
		cell.tooltip_text = "No.%03d %s%s" % [s.dex_id, s.name_ko, " (색이 다른)" if got else ""]
		return
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
	if _shiny_view:
		var shiny := int(entry.get("shiny", 0))
		line2 = "색이 다른 모습 %d마리 포획" % shiny if shiny > 0 else "색이 다른 모습은 아직"
	_detail.text = "No.%03d %s  %s\n%s" % [s.dex_id, s.name_ko, UiUtil.types_bbcode(s.types), line2]


func _icon(s: PokemonSpecies) -> Texture2D:
	if not _icon_cache.has(s.dex_id):
		_icon_cache[s.dex_id] = UiUtil.pokemon_icon(s)
	return _icon_cache[s.dex_id]


## 오버월드 그림에는 색이 다른 모습이 없어 전투 시트의 색이 다른 첫 프레임을 그림 부분만 잘라 쓴다 (칸에 맞춰 줄어듦)
func _shiny_icon(s: PokemonSpecies) -> Texture2D:
	if not _shiny_icon_cache.has(s.dex_id):
		var tex := PokemonSprites.make_frames(s, false, true).get_frame_texture(&"idle", 0)
		var at := tex as AtlasTexture
		if at:
			var img := at.atlas.get_image()
			if img:
				if img.is_compressed():
					img.decompress()
				var r := img.get_region(Rect2i(at.region)).get_used_rect()
				if r.size != Vector2i.ZERO:
					var side := maxi(r.size.x, r.size.y)   # 정사각형으로 (가운데 기준)
					var cell := at.region.size   # 옆 칸이 보이지 않게 칸 안으로
					var x := clampf(roundf(r.get_center().x - side / 2.0), 0.0, cell.x - side)
					var y := clampf(roundf(r.get_center().y - side / 2.0), 0.0, cell.y - side)
					var crop := AtlasTexture.new()
					crop.atlas = at.atlas
					crop.region = Rect2(at.region.position + Vector2(x, y), Vector2(side, side))
					tex = crop
		_shiny_icon_cache[s.dex_id] = tex
	return _shiny_icon_cache[s.dex_id]
