extends Node
## 상점 구매/판매, 보관함 확장. (기획서 4.11, 4.12)
## 결과는 {ok: bool, reason: String} 로 돌려준다(화면에 그대로 표시할 수 있는 한국어 문구).

const STORAGE_EXPANSION_SLOTS := 20
const STORAGE_EXPANSION_BASE_COST := 5000
const STORAGE_MAX := 300

## 상점 계약 (v0.92, 기획서 4.12): 한 번 사면 영구 해금. 가방에는 들어가지 않고 PlayerState.shop_unlocks 에 기록한다.
## cost = 계약 비용, region = 이 지역이 해금돼야 상점에 보임("" = 조건 없음), needs = 먼저 맺어야 하는 계약, ball = 목록에 쓸 그림
const CONTRACTS := {
	&"great_ball_discount": {"name": "슈퍼볼 할인 계약", "cost": 10000, "region": &"cave", "needs": &"", "ball": &"great_ball"},
	&"ultra_ball_sale": {"name": "하이퍼볼 취급 계약", "cost": 22000, "region": &"", "needs": &"great_ball_discount", "ball": &"ultra_ball"},
}


## 아이템 구매
func buy(item_id: StringName, amount: int = 1) -> Dictionary:
	var item := GameData.get_item(item_id)
	if item == null or amount <= 0:
		return _fail("살 수 없는 아이템입니다.")
	if not is_on_sale(item):
		return _fail("상점에서 팔지 않는 아이템입니다.")
	var cost := price_of(item) * amount
	if PlayerState.currency < cost:
		return _fail("돈이 부족합니다. (%s 필요)" % format_money(cost))
	PlayerState.add_currency(-cost)
	PlayerState.add_item(item_id, amount)
	EventBus.items_received.emit({item_id: amount}, &"shop")
	return _ok()


## 지금 상점에 있는가: 해금 레벨(v0.79)과 계약(v0.92, params.requires_contract)을 본다
func is_on_sale(item: ItemData) -> bool:
	if not item.is_on_sale(PlayerState.level):
		return false
	var need := String(item.params.get(&"requires_contract", ""))
	return need == "" or has_contract(StringName(need))


## 지금 구매가: 계약을 맺었으면 계약 가격(params.contract_price), 아니면 item.buy_price (v0.92)
func price_of(item: ItemData) -> int:
	var c := String(item.params.get(&"contract", ""))
	if c != "" and has_contract(StringName(c)):
		return int(item.params.get(&"contract_price", item.buy_price))
	return item.buy_price


func has_contract(id: StringName) -> bool:
	return PlayerState.shop_unlocks.has(String(id))


## 지금 상점 목록에 보이는(아직 안 맺은) 계약 id 들, 순서대로
func visible_contracts() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CONTRACTS:
		var c: Dictionary = CONTRACTS[id]
		if has_contract(id):
			continue
		if c.region != &"" and not PlayerState.unlocked_regions.has(c.region):
			continue
		if c.needs != &"" and not has_contract(c.needs):
			continue
		out.append(id)
	return out


## 계약을 맺는다 (돈을 내면 영구 해금)
func buy_contract(id: StringName) -> Dictionary:
	if not visible_contracts().has(id):
		return _fail("맺을 수 없는 계약입니다.")
	var cost := int(CONTRACTS[id].cost)
	if PlayerState.currency < cost:
		return _fail("돈이 부족합니다. (%s 필요)" % format_money(cost))
	PlayerState.add_currency(-cost)
	PlayerState.shop_unlocks.append(String(id))
	PlayerState.changed.emit()
	return _ok()


## 아이템 판매
func sell(item_id: StringName, amount: int = 1) -> Dictionary:
	var item := GameData.get_item(item_id)
	if item == null or amount <= 0:
		return _fail("팔 수 없는 아이템입니다.")
	if not item.can_sell():
		return _fail("팔 수 없는 아이템입니다.")
	if PlayerState.item_count(item_id) < amount:
		return _fail("가진 개수가 부족합니다.")
	PlayerState.remove_item(item_id, amount)
	PlayerState.add_currency(item.sell_price * amount)
	return _ok()


## 가진 귀중품(판매 전용) {id: 개수}와 판매 합계 (v0.84 "귀중품 모두 팔기")
func valuables() -> Dictionary:
	var items := {}
	var total := 0
	for it in GameData.all_items(&"valuable"):
		var n := PlayerState.item_count(it.id)
		if n > 0 and it.can_sell():
			items[it.id] = n
			total += it.sell_price * n
	return {"items": items, "total": total}


## 귀중품을 모두 판다. 반환 {ok, reason, count, money}
func sell_all_valuables() -> Dictionary:
	var v := valuables()
	if v.items.is_empty():
		return _fail("팔 귀중품이 없습니다.")
	var count := 0
	for id in v.items:
		PlayerState.remove_item(id, v.items[id])
		count += int(v.items[id])
	PlayerState.add_currency(v.total)
	return {"ok": true, "reason": "", "count": count, "money": v.total}


## 지금까지 확장한 횟수
func storage_expansions() -> int:
	return maxi(0, (PlayerState.storage_capacity - PlayerState.BASE_STORAGE_CAPACITY) / STORAGE_EXPANSION_SLOTS)


func can_expand_storage() -> bool:
	return PlayerState.storage_capacity + STORAGE_EXPANSION_SLOTS <= STORAGE_MAX


## 다음 확장 비용: 5,000원 × (확장 횟수 + 1)
func next_expansion_cost() -> int:
	return STORAGE_EXPANSION_BASE_COST * (storage_expansions() + 1)


func expand_storage() -> Dictionary:
	if not can_expand_storage():
		return _fail("보관함이 이미 최대(%d칸)입니다." % STORAGE_MAX)
	var cost := next_expansion_cost()
	if PlayerState.currency < cost:
		return _fail("돈이 부족합니다. (%s 필요)" % format_money(cost))
	PlayerState.add_currency(-cost)
	PlayerState.storage_capacity += STORAGE_EXPANSION_SLOTS
	PlayerState.changed.emit()
	return _ok()


## 1234567 → "1,234,567원"
static func format_money(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out + "원"


func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
