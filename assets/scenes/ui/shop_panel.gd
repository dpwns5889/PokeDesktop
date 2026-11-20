extends OverlayPanel
## 상점 패널. (기획서 4.12, 6.2)
## 왼쪽 = 소지금·구매/판매·상품 목록 / 오른쪽 = 고른 상품 설명, 개수, 합계, 구매/판매 버튼, 결과 문구

const STORAGE_ROW := &"__storage__"
## 계약 줄 id 앞붙이 (v0.92): "__contract__great_ball_discount"
const CONTRACT_PREFIX := "__contract__"
## 보관함 확장 그림 (v0.66, tools/import_icons.gd 가 assets/sprites/ExpandBag.png 를 24px 로 줄여 만든다)
const STORAGE_ICON := "res://assets/generated/icons/expand_storage.png"
const LIST_WIDTH := 120   # 가장 긴 일반 아이템(골드코롱 x99 등)이 아이콘까지 약 113px (v0.91)

var _money: Label
## 모드 드롭다운 (구매/판매/업그레이드, v0.93). v0.93: 왼쪽 열 맨 위 (소지금은 제목 줄)
var _mode: OptionButton
enum Mode { BUY, SELL, UPGRADE }
var _list: ItemList
var _ids: Array[StringName] = []
# 오른쪽
var _icon: TextureRect
var _name: Label
var _desc: Label
## 가격(판매가): 개수 칸 오른쪽, 합계 바로 위 줄 (v0.66)
var _price: Label
var _qty_row: HBoxContainer
var _qty: SpinBox
var _total: Label
var _button: Button
var _message: Label
## 제목 줄 "귀중품 모두 팔기" (v0.84)
var _sell_all: Button


func _panel_title() -> String:
	return "상점"


func _ready() -> void:
	super()
	PlayerState.changed.connect(_refresh_if_visible)
	# 판매 화면에서 귀중품이 있을 때만 (v0.84)
	_sell_all = add_header_button("귀중품 모두 팔기", _on_sell_all)
	_sell_all.visible = false


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
	# v0.93: 소지금은 제목 줄(제목 바로 오른쪽)로, 모드 드롭다운은 왼쪽 열 맨 위로
	_money = Label.new()
	_header_row.add_child(_money)
	_header_row.move_child(_money, 1)
	_mode = OptionButton.new()
	_mode.focus_mode = Control.FOCUS_NONE
	_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for name in ["구매", "판매", "업그레이드"]:
		_mode.add_item(name)
	_mode.item_selected.connect(_set_mode)
	left.add_child(_mode)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(24, 24)
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
	_icon.custom_minimum_size = Vector2(32, 32)
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
	# 개수 칸 | 오른쪽에 가격(위)·합계(아래) 두 줄 — 줄을 하나 더 쓰지 않아 구매 버튼이 밀려나지 않게 (v0.66)
	_qty_row = HBoxContainer.new()
	right.add_child(_qty_row)
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = 99
	_qty.value = 1
	_qty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_qty.value_changed.connect(func(_v: float) -> void: _update_order())
	_qty_row.add_child(_qty)
	var sums := VBoxContainer.new()
	sums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sums.add_theme_constant_override(&"separation", -2)
	_qty_row.add_child(sums)
	_price = Label.new()
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sums.add_child(_price)
	_total = Label.new()
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sums.add_child(_total)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_order)
	right.add_child(_button)


## 모드를 바꾼다 (드롭다운에서 고르거나 테스트가 부른다)
func _set_mode(index: int) -> void:
	_mode.select(index)
	_message.text = ""
	refresh()


func _selling() -> bool:
	return _mode.selected == Mode.SELL


func _upgrading() -> bool:
	return _mode.selected == Mode.UPGRADE


func refresh() -> void:
	_money.text = "소지금: %s" % ShopManager.format_money(PlayerState.currency)   # v0.93
	if _sell_all:
		_sell_all.visible = _selling() and not ShopManager.valuables().items.is_empty()
	var keep := _selected_id()
	_list.clear()
	_ids.clear()
	if _upgrading():   # 업그레이드 = 보관함 확장 + 상점 계약 (v0.93)
		if ShopManager.can_expand_storage():
			_list.add_item("보관함 확장", _storage_icon())
			_ids.append(STORAGE_ROW)
		for cid in ShopManager.visible_contracts():
			var ball := GameData.get_item(ShopManager.CONTRACTS[cid].ball)
			_list.add_item(String(ShopManager.CONTRACTS[cid].name), ball.load_icon() if ball else null)
			_ids.append(StringName(CONTRACT_PREFIX + String(cid)))
	else:
		for item in GameData.all_items():
			if _selling():
				var n := PlayerState.item_count(item.id)
				if item.can_sell() and n > 0:
					_list.add_item("%s x%d" % [item.name_ko, n], item.load_icon())
					_ids.append(item.id)
			elif ShopManager.is_on_sale(item):
				_list.add_item(item.name_ko, item.load_icon())
				_ids.append(item.id)
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
		_desc.text = "팔 수 있는 아이템이 없다" if _selling() else ("더 할 수 있는 업그레이드가 없다" if _upgrading() else "")
		_qty_row.visible = false
		_button.disabled = true
		return
	if id == STORAGE_ROW:
		_icon.texture = _storage_icon()
		_name.text = "보관함 확장"
		_qty_row.visible = false   # 개수가 없어 합계도 없다 → 가격은 설명 끝에
		if ShopManager.can_expand_storage():
			_desc.text = "보관함이 %d칸 늘어난다.\n%d칸 → %d칸\n가격 %s" % [ShopManager.STORAGE_EXPANSION_SLOTS,
				PlayerState.storage_capacity, PlayerState.storage_capacity + ShopManager.STORAGE_EXPANSION_SLOTS,
				ShopManager.format_money(ShopManager.next_expansion_cost())]
		else:
			_desc.text = "보관함이 이미 최대(%d칸)다." % ShopManager.STORAGE_MAX
		_button.text = "확장"
		_button.disabled = not ShopManager.can_expand_storage()
		return
	if String(id).begins_with(CONTRACT_PREFIX):   # 상점 계약 (v0.92)
		_show_contract(StringName(String(id).trim_prefix(CONTRACT_PREFIX)))
		return
	var item := GameData.get_item(id)
	_icon.texture = item.load_icon()
	_name.text = item.name_ko
	var price := item.sell_price if _selling() else ShopManager.price_of(item)
	_desc.text = item.description
	_price.text = "%s %s" % ["판매가" if _selling() else "가격", ShopManager.format_money(price)]   # 합계 바로 위 (v0.66)
	_qty_row.visible = true
	_qty.max_value = maxi(1, PlayerState.item_count(id)) if _selling() else 99
	_total.text = "합계 %s" % ShopManager.format_money(price * int(_qty.value))
	_button.disabled = false


## 계약 줄의 오른쪽 설명 (v0.92): 무엇이 바뀌는지와 비용. 개수 칸은 없다(한 번만)
func _show_contract(cid: StringName) -> void:
	var c: Dictionary = ShopManager.CONTRACTS[cid]
	var ball := GameData.get_item(c.ball)
	_icon.texture = ball.load_icon() if ball else null
	_name.text = String(c.name)
	_qty_row.visible = false
	var cost := ShopManager.format_money(int(c.cost))
	match cid:
		&"great_ball_discount":
			var g := GameData.get_item(&"great_ball")
			_desc.text = "슈퍼볼이 %s에서 %s이 된다.\n가격 %s" % [ShopManager.format_money(g.buy_price),
				ShopManager.format_money(int(g.params.contract_price)), cost]
		&"ultra_ball_sale":
			var u := GameData.get_item(&"ultra_ball")
			_desc.text = "하이퍼볼을 %s에 살 수 있다.\n가격 %s" % [ShopManager.format_money(u.buy_price), cost]
	_button.text = "계약"
	_button.disabled = false


func _on_order() -> void:
	var id := _selected_id()
	var qty := int(_qty.value)
	var result: Dictionary
	if String(id).begins_with(CONTRACT_PREFIX):
		result = ShopManager.buy_contract(StringName(String(id).trim_prefix(CONTRACT_PREFIX)))
		if result.ok:
			AudioManager.play(&"buy_item")
		_message.text = "" if result.ok else result.reason
		refresh()
		return
	if _selling():
		result = ShopManager.sell(id, qty)
		if result.ok:   # v0.66: "팔았다" 문구 대신 구매와 같은 소리
			AudioManager.play(&"buy_item")
	elif id == STORAGE_ROW:
		result = ShopManager.expand_storage()   # 늘어난 칸 수는 설명에 바로 보인다
		if result.ok:
			AudioManager.play(&"buy_item")
	else:
		result = ShopManager.buy(id, qty)   # 구매 효과음이 난다 (items_received)
	# v0.78: 구매 성공 문구도 버튼을 아래로 밀어내서 없앴다. 실패 이유만 보인다
	_message.text = "" if result.ok else result.reason
	_qty.value = 1
	refresh()


## 보관함 확장 그림 (없으면 null — 그림 없이 글자만)
static func _storage_icon() -> Texture2D:
	return load(STORAGE_ICON) if ResourceLoader.exists(STORAGE_ICON) else null


## 귀중품 모두 팔기: 무엇을 얼마에 파는지 확인 창 → 판다 (v0.84)
func _on_sell_all() -> void:
	var v := ShopManager.valuables()
	if v.items.is_empty():
		return
	var parts: PackedStringArray = []
	for id in v.items:
		parts.append("%s %d" % [GameData.get_item(id).name_ko, v.items[id]])
	confirm_requested.emit("귀중품 모두 팔기", "%s\n모두 팔아 %s을 받는다." % [", ".join(parts), ShopManager.format_money(v.total)], "팔기",
		func() -> void:
			if ShopManager.sell_all_valuables().ok:
				AudioManager.play(&"buy_item")
			refresh())
