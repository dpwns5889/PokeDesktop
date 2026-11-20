extends OverlayPanel
## 지역 패널: 해금된 지역으로 이동, 잠긴 지역은 해금 조건과 진행도. (기획서 4.4, 6.2)

## 달성한 해금 조건 글자색 (기획서 6.2, v0.98)
const DONE_COLOR := Color(0.6, 0.95, 0.55)

var _list: ItemList
var _detail: RichTextLabel
var _move: Button
var _ids: Array[StringName] = []


func _panel_title() -> String:
	return "지역"


func _ready() -> void:
	super()
	EventBus.region_unlocked.connect(func(_id: StringName) -> void: _refresh_if_visible())
	EventBus.current_region_changed.connect(func(_id: StringName) -> void: _refresh_if_visible())
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: _refresh_if_visible())


func _build_content(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size.x = 118
	_list.item_selected.connect(_show_detail)
	row.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_detail = UiUtil.rich_label(false)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override(&"line_separation", 1)   # 행간 (기획서 6.2, v0.98)
	right.add_child(_detail)
	_move = Button.new()
	_move.focus_mode = Control.FOCUS_NONE
	_move.pressed.connect(_on_move)
	right.add_child(_move)


func refresh() -> void:
	var keep := _selected_id()
	_list.clear()
	_ids.clear()
	for r in GameData.all_regions():
		var unlocked := PlayerState.unlocked_regions.has(r.id)
		var text := r.name_ko
		if r.id == PlayerState.current_region:
			text += " (현재)"
		elif not unlocked:
			text += " (잠김)"
		var idx := _list.add_item(text)
		_list.set_item_custom_fg_color(idx, Color.WHITE if unlocked else Color(1, 1, 1, 0.45))
		_ids.append(r.id)
	var sel := _ids.find(keep if keep != &"" else PlayerState.current_region)
	if sel >= 0:
		_list.select(sel)
		_show_detail(sel)


func _selected_id() -> StringName:
	var sel := _list.get_selected_items()
	return _ids[sel[0]] if sel.size() > 0 and sel[0] < _ids.size() else &""


func _show_detail(index: int) -> void:
	var r := GameData.get_region(_ids[index])
	var types := UiUtil.types_bbcode(r.main_types, ", ")
	var lv_min := 999
	var lv_max := 0
	for e in r.encounters:
		lv_min = mini(lv_min, e.min_level)
		lv_max = maxi(lv_max, e.max_level)
	var species := {}
	var caught := 0
	for e in r.encounters:
		if not species.has(e.dex_id):
			species[e.dex_id] = true
			caught += 1 if PlayerState.is_caught(e.dex_id) else 0
	var lines: Array[String] = ["주요 타입: %s" % types, "레벨: %d~%d" % [lv_min, lv_max],
			"잡은 포켓몬: %d / %d" % [caught, species.size()]]
	var unlocked := PlayerState.unlocked_regions.has(r.id)
	if not unlocked:
		lines.append("해금 조건")
		for c in r.unlock_conditions:
			var p := UnlockManager.progress(c)
			var line := "- %s (%d/%d)" % [p.label, p.current, p.target]
			lines.append("[color=#%s]%s[/color]" % [DONE_COLOR.to_html(false), line] if p.current >= p.target else line)
	_detail.text = "\n".join(lines)
	_move.disabled = not unlocked or r.id == PlayerState.current_region
	_move.text = "현재 지역" if r.id == PlayerState.current_region else ("이 지역으로 이동" if unlocked else "잠김")


func _on_move() -> void:
	var id := _selected_id()
	if id != &"":
		PlayerState.set_current_region(id)
