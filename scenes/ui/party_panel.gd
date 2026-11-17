extends OverlayPanel
## 파티 패널: 엔트리(전투에 함께 나가는 포켓몬, 최대 3마리)를 넣고 뺀다. (기획서 4.13, 6.2)
## 제목 줄: "파티 · 엔트리 n/3"
## 왼쪽: 엔트리 3칸 + 빼기 + 전투 보너스 / 오른쪽: 넣을 수 있는 포켓몬(레벨 순) + 넣기
## 목록을 두 번 누르면 바로 넣고 뺀다. 원정 중인 포켓몬은 목록에 나오지 않는다.
## 전투 특성이 있는 포켓몬은 이름 뒤에 * (v0.28)

const LIST_WIDTH := 150
const BONUS_NAMES := [[&"attack", "게이지"], [&"speed", "과녁"], [&"defense", "감점"], [&"hp", "시간"]]
const BONUS_SIGN := {&"attack": "+", &"speed": "+", &"defense": "-", &"hp": "+"}

var _entry_list: ItemList
var _remove: Button
var _bonus: Label
var _pick_list: ItemList
var _add: Button
var _message: Label
var _entry_uids: Array[String] = []
var _pick_uids: Array[String] = []
var _icon_cache: Dictionary = {}


func _panel_title() -> String:
	return "파티"


func _ready() -> void:
	super()
	EventBus.entries_changed.connect(_refresh_if_visible)
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: _refresh_if_visible())
	EventBus.pokemon_evolved.connect(func(_u: String, _f: int, _t: int) -> void: _refresh_if_visible())


func _build_content(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 4)
	box.add_child(row)

	# 왼쪽: 엔트리
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	left.add_theme_constant_override(&"separation", 0)   # v0.55: 오버월드 아이콘(24px)로 높이가 늘어 간격을 줄임
	row.add_child(left)
	_entry_list = ItemList.new()
	_entry_list.fixed_icon_size = Vector2i(UiUtil.ICON_SIZE, UiUtil.ICON_SIZE)   # 3칸 + 빼기 + 보너스 두 줄이 패널 높이에 들어가게 (v0.55 오버월드 24px)
	_entry_list.auto_height = true
	_entry_list.add_theme_constant_override(&"v_separation", 0)   # v0.55: 아이콘 24px 로 커져 줄 간격을 줄여 패널 높이에 맞춘다
	_entry_list.item_selected.connect(func(_i: int) -> void: _update_buttons())
	_entry_list.item_activated.connect(func(_i: int) -> void: _on_remove())
	left.add_child(_entry_list)
	_remove = _button("빼기", _on_remove)
	left.add_child(_remove)
	_bonus = Label.new()
	_bonus.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bonus.add_theme_constant_override(&"line_spacing", -4)
	_bonus.add_theme_color_override(&"font_color", Color(0.75, 0.8, 0.9))
	_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
	_bonus.tooltip_text = "엔트리의 능력치로 받는 전투 보너스 (최대 25%: 종족값 80인 Lv80 포켓몬 3마리 기준)\n게이지: 공격+특공 / 과녁: 스피드 / 감점: 방어+특방 / 시간: HP"
	left.add_child(_bonus)

	# 오른쪽: 넣을 포켓몬
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 2)
	row.add_child(right)
	_pick_list = ItemList.new()
	_pick_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pick_list.fixed_icon_size = Vector2i(UiUtil.ICON_SIZE, UiUtil.ICON_SIZE)   # v0.55 오버월드 아이콘 1:1
	_pick_list.item_selected.connect(func(_i: int) -> void: _update_buttons())
	_pick_list.item_activated.connect(func(_i: int) -> void: _on_add())
	right.add_child(_pick_list)
	_message = Label.new()
	_message.add_theme_color_override(&"font_color", Color(1, 0.85, 0.35))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	right.add_child(_message)
	_add = _button("넣기", _on_add)
	right.add_child(_add)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func refresh() -> void:
	_title_label.text = "파티 · 엔트리 %d/%d" % [PlayerState.entries.size(), PlayerState.MAX_ENTRIES]
	_entry_list.clear()
	_entry_uids.clear()
	for p in PlayerState.entry_pokemon():
		_add_row(_entry_list, p)
		_entry_uids.append(p.uid)
	for i in range(PlayerState.entries.size(), PlayerState.MAX_ENTRIES):
		var idx := _entry_list.add_item("(빈 자리)")
		_entry_list.set_item_disabled(idx, true)
		_entry_list.set_item_selectable(idx, false)
		_entry_list.set_item_custom_fg_color(idx, Color(1, 1, 1, 0.35))

	var keep := _pick_list.get_selected_items()
	_pick_list.clear()
	_pick_uids.clear()
	var avail: Array[Dictionary] = []
	for p in PlayerState.pokemon:
		if not PlayerState.is_entry(p.uid) and not PlayerState.is_busy(p.uid):
			avail.append(p)
	avail.sort_custom(func(a, b): return a.level > b.level or (a.level == b.level and a.dex_id < b.dex_id))
	for p in avail:
		_add_row(_pick_list, p)
		_pick_uids.append(p.uid)
	if keep.size() > 0 and _pick_uids.size() > 0:
		_pick_list.select(mini(keep[0], _pick_uids.size() - 1))

	_bonus.text = _bonus_text()
	_update_buttons()


func _add_row(list: ItemList, p: Dictionary) -> void:
	var s := GameData.get_species(p.dex_id)
	# 전투 특성(엔트리일 때 발동)이 있으면 * 표시, 마우스를 올리면 특성 이름 (기획서 4.6)
	var battle := ExpeditionLogic.traits_of(p.get("traits", []), &"battle")
	var idx := list.add_item("%s Lv%d%s" % [s.name_ko if s else "?", p.level, " *" if not battle.is_empty() else ""])
	if not battle.is_empty():
		list.set_item_tooltip(idx, "전투 특성: " + ", ".join(battle.map(func(t: TraitData) -> String: return t.name_ko)))
	if s:
		if not _icon_cache.has(s.dex_id):
			_icon_cache[s.dex_id] = UiUtil.pokemon_icon(s)
		list.set_item_icon(idx, _icon_cache[s.dex_id])


## 현재 지역의 평균적인 야생 포켓몬을 상대로 한 전투 보너스
func _bonus_text() -> String:
	if PlayerState.entries.is_empty():
		return "엔트리를 넣으면\n전투 보너스가 생긴다"
	var b := EncounterManager.entry_bonus()
	var parts: Array = []
	for pair in BONUS_NAMES:
		parts.append("%s %s%d%%" % [pair[1], BONUS_SIGN[pair[0]], roundi(float(b.get(pair[0], 0.0)) * 100)])
	return "%s  %s\n%s  %s" % parts


func _update_buttons() -> void:
	var sel_e := _entry_list.get_selected_items()
	_remove.disabled = sel_e.is_empty() or sel_e[0] >= _entry_uids.size()
	_add.disabled = _pick_list.get_selected_items().is_empty() or PlayerState.entries.size() >= PlayerState.MAX_ENTRIES


func _on_add() -> void:
	var sel := _pick_list.get_selected_items()
	if sel.is_empty():
		return
	var reason := PlayerState.add_entry(_pick_uids[sel[0]])
	_show_message(reason)
	refresh()


func _on_remove() -> void:
	var sel := _entry_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _entry_uids.size():
		return
	PlayerState.remove_entry(_entry_uids[sel[0]])
	_show_message("")
	refresh()


func _show_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""
