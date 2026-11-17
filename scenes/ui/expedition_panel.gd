extends OverlayPanel
## 원정 패널. (기획서 4.10, 6.2)
## 목록 화면: 진행 중인 원정(남은 시간 / 귀환 → 보상 받기, 취소) + 원정지(잠김·조건, 파티 편성)
## 편성 화면: 원정 중이 아닌 포켓몬을 5마리 이상 고르면 전투력·성공 확률·시간을 바로 보여준다.
## "자동 선택" = 전투력 높은 순으로 요구치를 넘을 때까지 (ExpeditionLogic.auto_select)

enum View { LIST, PARTY }

var _view: View = View.LIST
var _target: StringName = &""          # 편성 중인 원정지
var _rows: Array[Dictionary] = []      # 목록 행: {kind: "active"/"dest", index/id}
var _party_uids: Array[String] = []    # 편성 목록의 행 순서
var _last_message := ""

const LIST_WIDTH := 150

# 목록 화면: 왼쪽 목록 / 오른쪽 설명·버튼
var _list_box: HBoxContainer
var _slots: Label
var _list: ItemList
var _detail: RichTextLabel
var _action: Button
var _action2: Button
# 편성 화면: 왼쪽 포켓몬 목록 / 오른쪽 원정지 정보·전투력·버튼
var _party_box: HBoxContainer
var _party_title: RichTextLabel
var _party_list: ItemList
var _summary: Label
var _start: Button


func _panel_title() -> String:
	return "원정"


func _ready() -> void:
	super()
	EventBus.expedition_finished.connect(func(_id: StringName) -> void: _refresh_if_visible())
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: _refresh_if_visible())
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)


func open_panel() -> void:
	_view = View.LIST
	_last_message = ""
	super()


func _build_content(box: VBoxContainer) -> void:
	# 목록 화면
	_list_box = HBoxContainer.new()
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override(&"separation", 6)
	box.add_child(_list_box)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	_list_box.add_child(left)
	_slots = Label.new()
	left.add_child(_slots)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(_i: int) -> void:
		_last_message = ""
		_show_list_detail())
	left.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_child(right)
	_detail = UiUtil.rich_label(false)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	_action = _button("", _on_action)
	right.add_child(_action)
	_action2 = _button("", _on_action2)
	right.add_child(_action2)

	# 편성 화면
	_party_box = HBoxContainer.new()
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_box.add_theme_constant_override(&"separation", 6)
	_party_box.visible = false
	box.add_child(_party_box)
	var pleft := VBoxContainer.new()
	pleft.custom_minimum_size.x = LIST_WIDTH
	_party_box.add_child(pleft)
	var pick := Label.new()
	pick.text = "포켓몬 고르기 (* = 특성)"
	pleft.add_child(pick)
	_party_list = ItemList.new()
	_party_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_list.select_mode = ItemList.SELECT_TOGGLE
	_party_list.fixed_icon_size = Vector2i(20, 20)
	_party_list.multi_selected.connect(func(_i: int, _s: bool) -> void: _update_summary())
	pleft.add_child(_party_list)
	var pright := VBoxContainer.new()
	pright.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_box.add_child(pright)
	_party_title = UiUtil.rich_label()
	pright.add_child(_party_title)
	_summary = Label.new()
	_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pright.add_child(_summary)
	pright.add_child(_button("자동 선택", _on_auto))
	var pbtns := HBoxContainer.new()
	pright.add_child(pbtns)
	var back := _button("뒤로", func() -> void:
		_view = View.LIST
		refresh())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbtns.add_child(back)
	_start = _button("출발", _on_start)
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbtns.add_child(_start)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func refresh() -> void:
	_list_box.visible = _view == View.LIST
	_party_box.visible = _view == View.PARTY
	if _view == View.LIST:
		_refresh_list()
	else:
		_refresh_party()


func _tick() -> void:
	if visible and _view == View.LIST:
		# 남은 시간 표시만 갱신 (선택 유지)
		_refresh_list()


# ---------------------------------------------------------------- 목록

func _refresh_list() -> void:
	var keep := _list.get_selected_items()
	var keep_idx: int = keep[0] if keep.size() > 0 else -1
	_slots.text = "진행 중 %d / %d" % [PlayerState.expeditions.size(), ExpeditionManager.max_slots()]
	_list.clear()
	_rows.clear()
	for i in PlayerState.expeditions.size():
		var e: Dictionary = PlayerState.expeditions[i]
		var x := GameData.get_expedition(StringName(e.id))
		var label := x.name_ko if x else String(e.id)
		var done := ExpeditionManager.is_done(e)
		var idx := _list.add_item("%s  %s" % [label, "귀환! 보상 받기" if done else _time_text(ExpeditionManager.seconds_left(e))])
		_list.set_item_custom_fg_color(idx, Color(1, 0.85, 0.35) if done else Color(0.6, 0.85, 1))
		_rows.append({"kind": "active", "index": i})
	for x in GameData.all_expeditions():
		if ExpeditionManager.is_running(x.id):
			continue
		var unlocked := ExpeditionManager.is_unlocked(x)
		var idx := _list.add_item("%s  %s" % [x.name_ko, _duration_text(x.duration_sec)] + ("" if unlocked else " (잠김)"))
		if not unlocked:
			_list.set_item_custom_fg_color(idx, Color(1, 1, 1, 0.45))
		_rows.append({"kind": "dest", "id": x.id})
	if _rows.size() > 0:
		_list.select(clampi(keep_idx, 0, _rows.size() - 1))
	_show_list_detail()


func _selected_row() -> Dictionary:
	var sel := _list.get_selected_items()
	return _rows[sel[0]] if sel.size() > 0 and sel[0] < _rows.size() else {}


func _show_list_detail() -> void:
	var row := _selected_row()
	_action2.visible = false
	if row.is_empty():
		_detail.text = _last_message
		_action.visible = false
		return
	_action.visible = true
	if row.kind == "active":
		var e: Dictionary = PlayerState.expeditions[row.index]
		var done := ExpeditionManager.is_done(e)
		var names := ", ".join(e.party.map(func(u: String) -> String: return _pokemon_name(u)))
		var x := GameData.get_expedition(StringName(e.id))
		var lines: Array[String] = [x.name_ko if x else String(e.id),
			"귀환! 보상을 받을 수 있다" if done else "남은 시간 %s" % _time_text(ExpeditionManager.seconds_left(e)),
			"전투력 %d (요구치의 %d%%)" % [e.power, roundi(e.ratio * 100)],
			"파티: %s" % names]
		_detail.text = _last_message if _last_message != "" else "\n".join(lines)
		_action.text = "보상 받기" if done else "진행 중"
		_action.disabled = not done
		_action2.visible = not done
		_action2.text = "취소"
	else:
		var x := GameData.get_expedition(row.id)
		var lines: Array[String] = [x.name_ko, "시간 %s · 요구 전투력 %d" % [_duration_text(x.duration_sec), x.required_power]]
		if not x.recommended_types.is_empty():
			lines.append("추천 " + UiUtil.types_bbcode(x.recommended_types, ", "))
		if not x.weak_types.is_empty():
			lines.append("불리 " + UiUtil.types_bbcode(x.weak_types, ", "))
		if not ExpeditionManager.is_unlocked(x):
			for c in x.unlock_conditions:
				var p := UnlockManager.progress(c)
				lines.append("조건: %s (%d/%d)" % [p.label, p.current, p.target])
			_action.disabled = true
			_action.text = "잠김"
		elif PlayerState.expeditions.size() >= ExpeditionManager.max_slots():
			lines.append("보낼 수 있는 원정 수를 모두 썼다")
			_action.disabled = true
			_action.text = "파티 편성"
		else:
			_action.disabled = false
			_action.text = "파티 편성"
		_detail.text = _last_message if _last_message != "" else "\n".join(lines)


func _on_action() -> void:
	var row := _selected_row()
	if row.is_empty():
		return
	if row.kind == "active":
		var r := ExpeditionManager.claim(row.index)
		_last_message = _result_text(r)
		refresh()
	else:
		_target = row.id
		_view = View.PARTY
		refresh()


func _on_action2() -> void:
	var row := _selected_row()
	if not row.is_empty() and row.kind == "active":
		ExpeditionManager.cancel(row.index)
		_last_message = "원정을 취소했다. (보상 없음)"
		refresh()


func _result_text(r: Dictionary) -> String:
	if not r.ok:
		return r.reason
	var parts: Array[String] = [ShopManager.format_money(r.currency)]
	for id in r.items:
		var item := GameData.get_item(id)
		parts.append("%s %d" % [item.name_ko if item else String(id), r.items[id]])
	var head := "성공!" if r.success else "실패... (보상 30%)"
	var lv := ""
	if r.levels.size() > 0:
		lv = "  레벨 업 %d마리" % r.levels.size()
	return "%s %s\n경험치 +%d%s" % [head, ", ".join(parts), r.pokemon_exp.values().max() if r.pokemon_exp.size() > 0 else 0, lv]


# ---------------------------------------------------------------- 편성

func _refresh_party() -> void:
	var x := GameData.get_expedition(_target)
	var title := "%s · %s" % [x.name_ko, _duration_text(x.duration_sec)]
	if not x.recommended_types.is_empty():
		title += "\n추천 " + UiUtil.types_bbcode(x.recommended_types, ", ")
	_party_title.text = title
	var keep := _selected_party()
	# 원정 중이 아닌 개체를 이 원정지 기준 전투력 순으로
	var avail: Array[Dictionary] = []
	for p in PlayerState.pokemon:
		if not PlayerState.is_busy(p.uid) and not PlayerState.is_entry(p.uid):   # 엔트리는 원정 불가 (4.13)
			avail.append(p)
	var powers := {}
	for p in avail:
		powers[p.uid] = ExpeditionLogic.pokemon_power(p, x)
	avail.sort_custom(func(a, b): return powers[a.uid] > powers[b.uid])
	_party_list.clear()
	_party_uids.clear()
	for p in avail:
		var s := GameData.get_species(p.dex_id)
		var trait_mark := "*" if p.get("traits", []).size() > 0 else ""
		var idx := _party_list.add_item("%s Lv%d  %d%s" % [s.name_ko if s else "?", p.level, roundi(powers[p.uid]), trait_mark],
			UiUtil.pokemon_icon(s) if s else null)
		_party_uids.append(p.uid)
		if keep.has(p.uid):
			_party_list.select(idx, false)
	_update_summary()


func _selected_party() -> Array:
	var out: Array = []
	for i in _party_list.get_selected_items():
		out.append(_party_uids[i])
	return out


func _update_summary() -> void:
	var x := GameData.get_expedition(_target)
	var uids := _selected_party()
	if x == null:
		return
	var n := uids.size()
	if n == 0:
		_summary.text = "요구 전투력 %d\n왼쪽에서 %d마리 이상 고르기" % [x.required_power, x.min_party]
		_start.disabled = true
		return
	var sum := ExpeditionManager.preview(_target, uids)
	var size_ok := n >= x.min_party
	var line3 := "성공 %d%% · %s" % [roundi(sum.success_chance * 100), _duration_text(sum.duration_sec)]
	if not size_ok:
		line3 = "%d마리 이상 필요" % x.min_party
	elif not sum.can_start:
		line3 = "전투력 부족"
	_summary.text = "전투력 %d / %d (%d%%)\n%d마리 · %s" % [sum.power, sum.required, roundi(sum.ratio * 100), n, line3]
	_start.disabled = not (size_ok and sum.can_start)


func _on_auto() -> void:
	var pick := ExpeditionManager.auto_select(_target)
	_party_list.deselect_all()
	for i in _party_uids.size():
		if pick.has(_party_uids[i]):
			_party_list.select(i, false)
	_party_list.get_v_scroll_bar().value = 0   # 목록이 전투력 순이라 고른 개체는 맨 위
	_update_summary()


func _on_start() -> void:
	var r := ExpeditionManager.start(_target, _selected_party())
	if r.ok:
		_last_message = "%s에 출발했다! (%s 뒤 귀환)" % [GameData.get_expedition(_target).name_ko, _duration_text(r.entry.end_at - r.entry.started_at)]
		_view = View.LIST
		refresh()
	else:
		_summary.text = r.reason


# ---------------------------------------------------------------- 공통

func _pokemon_name(uid: String) -> String:
	var p := PlayerState.find_pokemon(uid)
	var s := GameData.get_species(p.get("dex_id", 0)) if not p.is_empty() else null
	return s.name_ko if s else "?"


## 1800 → "30분", 5400 → "1시간 30분"
static func _duration_text(sec: int) -> String:
	var m := int(round(sec / 60.0))
	if m < 60:
		return "%d분" % m
	return "%d시간" % (m / 60) + (" %d분" % (m % 60) if m % 60 > 0 else "")


## 남은 시간 "1:02:03" / "12:34"
static func _time_text(sec: int) -> String:
	if sec >= 3600:
		return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]
	return "%02d:%02d" % [sec / 60, sec % 60]
