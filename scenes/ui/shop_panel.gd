extends OverlayPanel
## 상점 패널. (기획서 4.12, 6.2)
## 왼쪽 = 소지금·구매/판매·상품 목록 / 오른쪽 = 고른 상품 설명, 개수, 합계, 구매/판매 버튼, 결과 문구

const STORAGE_ROW := &"__storage__"
const LIST_WIDTH := 150

var _money: Label
## 구매/판매 전환 버튼 (v0.53: 드롭다운 대신 토글 버튼 두 개)
var _buy_tab: Button
var _sell_tab: Button
var _list: ItemList
var _ids: Array[StringName] = []
# 오른쪽
var _icon: TextureRect
var _name: Label
var _desc: Label
var _qty_row: HBoxContainer
var _qty: SpinBox
var _total: Label
var _button: Button
var _message: Label


func _panel_title() -> String:
	return "상점"


func _ready() -> void:
	super()
	PlayerState.changed.connect(_refresh_if_visible)


func open_panel() -> void:
	_message.text = ""
	super()


func _build_content(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	row.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_money = Label.new()
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_money)
	var group := ButtonGroup.new()
	_buy_tab = _mode_button("구매", group, top)
	_sell_tab = _mode_button("판매", group, top)
	_buy_tab.set_pressed_no_signal(true)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(20, 20)
	_list.item_selected.connect(func(_i: int) -> void:
		_message.text = ""
		_update_order())
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
	# 결과 문구는 이름 바로 아래 (아래쪽에 두면 공간이 모자랄 때 잘린다)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override(&"font_color", Color(1, 0.85, 0.35))
	right.add_child(_message)
	_desc = Label.new()
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_desc)
	_qty_row = HBoxContainer.new()
	right.add_child(_qty_row)
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = 99
	_qty.value = 1
	_qty.value_changed.connect(func(_v: float) -> void: _update_order())
	_qty_row.add_child(_qty)
	_total = Label.new()
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty_row.add_child(_total)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_order)
	right.add_child(_button)


func _mode_button(text: String, group: ButtonGroup, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(func(on: bool) -> void:
		if on:
			_message.text = ""
			refresh())
	parent.add_child(b)
	return b


func _selling() -> bool:
	return _sell_tab.button_pressed


func refresh() -> void:
	_money.text = ShopManager.format_money(PlayerState.currency)
	var keep := _selected_id()
	_list.clear()
	_ids.clear()
	for item in GameData.all_items():
		if _selling():
			var n := PlayerState.item_count(item.id)
			if item.can_sell() and n > 0:
				_list.add_item("%s x%d" % [item.name_ko, n], item.load_icon())
				_ids.append(item.id)
		elif item.can_buy():
			_list.add_item(item.name_ko, item.load_icon())
			_ids.append(item.id)
	if not _selling():
		_list.add_item("보관함 확장")
		_ids.append(STORAGE_ROW)
	var i := _ids.find(keep)
	if i < 0 and _ids.size() > 0:
		i = 0
	if i >= 0:
		_list.select(i)
	_update_order()


func _selected_id() -> StringName:
	var sel := _list.get_selected_items()
	return _ids[sel[0]] if sel.size() > 0 and sel[0] < _ids.size() else &""


## 오른쪽: 설명·개수·합계·버튼
func _update_order() -> void:
	_message.visible = _message.text != ""   # 빈 문구가 자리만 차지하지 않게
	var id := _selected_id()
	_button.text = "판매" if _selling() else "구매"
	if id == &"":
		_icon.texture = null
		_name.text = ""
		_desc.text = "팔 수 있는 아이템이 없다" if _selling() else ""
		_qty_row.visible = false
		_button.disabled = true
		return
	if id == STORAGE_ROW:
		_icon.texture = null
		_name.text = "보관함 확장"
		_qty_row.visible = false
		if ShopManager.can_expand_storage():
			_desc.text = "보관함이 %d칸 늘어난다.\n지금 %d칸 → %d칸\n가격 %s" % [ShopManager.STORAGE_EXPANSION_SLOTS,
				PlayerState.storage_capacity, PlayerState.storage_capacity + ShopManager.STORAGE_EXPANSION_SLOTS,
				ShopManager.format_money(ShopManager.next_expansion_cost())]
		else:
			_desc.text = "보관함이 이미 최대(%d칸)다." % ShopManager.STORAGE_MAX
		_button.disabled = not ShopManager.can_expand_storage()
		return
	var item := GameData.get_item(id)
	_icon.texture = item.load_icon()
	_name.text = item.name_ko
	var price := item.sell_price if _selling() else item.buy_price
	_desc.text = "%s\n%s %s" % [item.description, "판매가" if _selling() else "가격", ShopManager.format_money(price)]
	_qty_row.visible = true
	_qty.max_value = maxi(1, PlayerState.item_count(id)) if _selling() else 99
	_total.text = "합계 %s" % ShopManager.format_money(price * int(_qty.value))
	_button.disabled = false


func _on_order() -> void:
	var id := _selected_id()
	var qty := int(_qty.value)
	var result: Dictionary
	if _selling():
		result = ShopManager.sell(id, qty)
		if result.ok:
			_message.text = "%s %d개를 팔았다." % [GameData.get_item(id).name_ko, qty]
	elif id == STORAGE_ROW:
		result = ShopManager.expand_storage()
		if result.ok:
			_message.text = "보관함이 %d칸이 되었다." % PlayerState.storage_capacity
	else:
		result = ShopManager.buy(id, qty)
		if result.ok:
			_message.text = "%s %d개를 샀다." % [GameData.get_item(id).name_ko, qty]
	if not result.ok:
		_message.text = result.reason
	_qty.value = 1
	refresh()
