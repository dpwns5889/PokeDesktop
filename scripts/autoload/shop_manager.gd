extends Node
## 상점 구매/판매, 보관함 확장. (기획서 4.11, 4.12)
## 결과는 {ok: bool, reason: String} 로 돌려준다(화면에 그대로 표시할 수 있는 한국어 문구).

const STORAGE_EXPANSION_SLOTS := 20
const STORAGE_EXPANSION_BASE_COST := 5000
const STORAGE_MAX := 300


## 아이템 구매
func buy(item_id: StringName, amount: int = 1) -> Dictionary:
	var item := GameData.get_item(item_id)
	if item == null or amount <= 0:
		return _fail("살 수 없는 아이템입니다.")
	if not item.can_buy():
		return _fail("상점에서 팔지 않는 아이템입니다.")
	var cost := item.buy_price * amount
	if PlayerState.currency < cost:
		return _fail("돈이 부족합니다. (%s 필요)" % format_money(cost))
	PlayerState.add_currency(-cost)
	PlayerState.add_item(item_id, amount)
	EventBus.items_received.emit({item_id: amount}, &"shop")
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
