extends OverlayPanel
## 가방 패널: 왼쪽 = 소지금·아이템 목록 / 오른쪽 = 고른 아이템 설명·사용 버튼. (기획서 4.11, 6.2)
## 경험사탕·진화의 돌·특성 캡슐·깜빡열매(v0.79)는 보관함에서 포켓몬을 골라 쓴다(버튼 → 보관함 패널).
## 향로(v0.41): 타입을 고르고 "쓰기" → 30분 동안 그 타입이 잘 나온다. 특이한 향로는 바로 "쓰기".
## 행복의 알(v0.61): 바로 "쓰기" → 15분 동안 플레이어 경험치 ×1.5.

const CATEGORY_NAMES := {&"ball": "볼", &"exp_candy": "경험사탕", &"evolution": "진화 도구", &"valuable": "귀중품", &"incense": "향로", &"boost": "도구",
	&"trait_tool": "특성 도구", &"trait_capsule": "특성 캡슐"}
const LIST_WIDTH := 150

var _money: Label
var _list: ItemList
var _ids: Array[StringName] = []
# 오른쪽
var _icon: TextureRect
var _name: Label
var _category: Label
var _desc: Label
var _action: Button
var _type_pick: OptionButton
var _type_ids: Array[StringName] = []


func _panel_title() -> String:
	return "가방"


func _ready() -> void:
	super()
	PlayerState.changed.connect(_refresh_if_visible)


func _build_content(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	row.add_child(left)
	_money = Label.new()
	left.add_child(_money)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(20, 20)
	_list.item_selected.connect(func(_i: int) -> void: _show_detail())
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	_name = Label.new()
	head.add_child(_name)
	_category = Label.new()
	_category.add_theme_color_override(&"font_color", Color(0.7, 0.75, 0.85))
	right.add_child(_category)
	_desc = Label.new()
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_desc)
	# 아래 줄: [타입 고르기(향로만)] [사용 버튼] — 한 줄에 두어 설명이 길어도 버튼이 잘리지 않게 (v0.41)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 3)
	right.add_child(bottom)
	_type_pick = OptionButton.new()
	_type_pick.focus_mode = Control.FOCUS_NONE
	_type_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_pick.visible = false
	bottom.add_child(_type_pick)
	_action = Button.new()
	_action.focus_mode = Control.FOCUS_NONE
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action.pressed.connect(_on_action)
	bottom.add_child(_action)


func refresh() -> void:
	var keep := _selected_id()
	_money.text = "소지금 %s" % ShopManager.format_money(PlayerState.currency)
	_list.clear()
	_ids.clear()
	for item in GameData.all_items():
		var count := PlayerState.item_count(item.id)
		if not item.infinite and count <= 0:
			continue
		var idx := _list.add_item("%s %s" % [item.name_ko, "" if item.infinite else "x%d" % count], item.load_icon())
		if item.id == PlayerState.selected_ball:
			_list.set_item_custom_fg_color(idx, Color(1, 0.85, 0.35))
		_ids.append(item.id)
		if item.id == keep:
			_list.select(idx)
	if _list.get_selected_items().is_empty() and _ids.size() > 0:
		_list.select(0)
	_show_detail()


func _selected_id() -> StringName:
	var sel := _list.get_selected_items()
	return _ids[sel[0]] if sel.size() > 0 and sel[0] < _ids.size() else &""


func _show_detail() -> void:
	var item := GameData.get_item(_selected_id())
	if item == null:
		_icon.texture = null
		_name.text = ""
		_category.text = ""
		_desc.text = "가방이 비어 있다"
		_action.visible = false
		return
	_icon.texture = item.load_icon()
	_name.text = item.name_ko
	var count_text := "무한" if item.infinite else "%d개" % PlayerState.item_count(item.id)
	_category.text = "%s · %s" % [CATEGORY_NAMES.get(item.category, ""), count_text]
	_desc.text = item.description
	_action.visible = true
	_type_pick.visible = false
	match item.category:
		&"ball":
			var using := item.id == PlayerState.selected_ball
			_action.text = "사용 중인 볼" if using else "이 볼로 잡기"
			_action.disabled = using
		&"exp_candy":
			_action.text = "보관함에서 주기"
			_action.disabled = false
		&"evolution", &"trait_tool", &"trait_capsule":
			_action.text = "보관함에서 쓰기"
			_action.disabled = false
		&"incense":
			_show_incense(item)
		&"boost":
			_show_boost(item)
		_:
			_action.visible = false


## 향로: 지금 효과와 남은 시간을 설명에 덧붙이고, 타입 향로면 타입 고르기를 보여 준다
func _show_incense(item: ItemData) -> void:
	var now := int(Time.get_unix_time_from_system())
	_action.text = "쓰기"
	_action.disabled = PlayerState.item_count(item.id) <= 0
	if item.id == &"incense":
		if _type_ids.is_empty():
			_fill_types()
		_type_pick.visible = true
		var cur := PlayerState.incense_type(now)
		if cur != &"":
			_desc.text += "\n지금: %s 타입, %d분 남음" % [GameData.type_name(cur), ceili(PlayerState.item_seconds_left("incense", now) / 60.0)]
			if _type_pick.selected < 0:
				_type_pick.select(maxi(0, _type_ids.find(cur)))
	else:
		var left := PlayerState.item_seconds_left("shiny_incense", now)
		if left > 0:
			_desc.text += "\n지금: %d분 남음 (쓰면 30분 연장)" % ceili(left / 60.0)


## 행복의 알 (v0.61): 쓰고 있으면 남은 시간을 설명에 덧붙인다
func _show_boost(item: ItemData) -> void:
	var now := int(Time.get_unix_time_from_system())
	_action.text = "쓰기"
	_action.disabled = PlayerState.item_count(item.id) <= 0
	var left := PlayerState.item_seconds_left(String(item.id), now)
	if left > 0:
		_desc.text += "\n지금: %d분 남음 (쓰면 연장)" % ceili(left / 60.0)   # 한 줄에 들어가게 (쓰기 버튼이 밀려나지 않게)


## 고를 수 있는 타입 = 이 세대 포켓몬에게 있는 타입 (GameData.type_ids 순서)
func _fill_types() -> void:
	var present := {}
	for s in GameData.all_species():
		for t in s.types:
			present[t] = true
	_type_pick.clear()
	_type_ids.clear()
	for t in GameData.type_ids():
		if present.has(t):
			_type_pick.add_item(GameData.type_name(t))
			_type_ids.append(t)
	_type_pick.select(0)


func _on_action() -> void:
	var item := GameData.get_item(_selected_id())
	if item and item.category == &"incense":
		var now := int(Time.get_unix_time_from_system())
		var reason := ""
		if item.id == &"incense":
			reason = PlayerState.use_incense(_type_ids[_type_pick.selected] if _type_pick.selected >= 0 else &"", now)
		else:
			reason = PlayerState.use_shiny_incense(now)
		refresh()
		if reason != "":
			_desc.text = reason
		return
	if item and item.category == &"boost":
		var now := Time.get_unix_time_from_system()
		var reason := EncounterManager.use_sweet_honey(now) if item.id == &"sweet_honey" else PlayerState.use_lucky_egg(int(now))
		refresh()
		if reason != "":
			_desc.text = reason
		return
	if item and item.is_ball():
		PlayerState.select_ball(item.id)
		refresh()
	elif item and item.category in [&"exp_candy", &"evolution", &"trait_tool", &"trait_capsule"]:
		open_requested.emit(&"storage")
