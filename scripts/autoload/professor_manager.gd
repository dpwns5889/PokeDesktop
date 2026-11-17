extends Node
## 박사에게 보내기(놓아주기 대신)와 경험사탕 사용. (기획서 4.8)
## - 보내면 개체가 사라지고 레벨에 비례한 경험사탕을 받는다(Formulas.transfer_candies).
## - 원정 중이거나 잠금된 개체는 보낼 수 없다. 원정 중인 개체는 사탕도 줄 수 없다.
## 결과는 {ok: bool, reason: String, ...} (화면에 그대로 표시할 수 있는 한국어 문구).

const CANDY_S := &"exp_candy_s"
const CANDY_M := &"exp_candy_m"


# ---------------------------------------------------------------- 박사에게 보내기

## 보낼 수 있는가. 반환: "" = 가능, 아니면 이유
func transfer_block_reason(inst: Dictionary) -> String:
	if inst.is_empty():
		return "없는 포켓몬입니다."
	if PlayerState.is_busy(inst.uid):
		return "원정 중인 포켓몬은 보낼 수 없습니다."
	if inst.get("locked", false):
		return "잠금된 포켓몬은 보낼 수 없습니다."
	if PlayerState.is_entry(inst.uid):
		return "엔트리 포켓몬은 보낼 수 없습니다. 파티에서 먼저 빼세요."
	return ""


## 여러 마리를 보냈을 때 받을 사탕 합계 {exp_candy_s: n, exp_candy_m: n}
func preview_rewards(uids: Array) -> Dictionary:
	var total := {CANDY_S: 0, CANDY_M: 0}
	for u in uids:
		var p := PlayerState.find_pokemon(u)
		if p.is_empty():
			continue
		var c := Formulas.transfer_candies(p.level)
		total[CANDY_S] += c[CANDY_S]
		total[CANDY_M] += c[CANDY_M]
	return total


## 보내기. 하나라도 보낼 수 없으면 아무것도 보내지 않는다.
func transfer(uids: Array) -> Dictionary:
	if uids.is_empty():
		return _fail("보낼 포켓몬을 고르세요.")
	for u in uids:
		var reason := transfer_block_reason(PlayerState.find_pokemon(u))
		if reason != "":
			return _fail(reason)
	var rewards := preview_rewards(uids)
	var sent := PackedStringArray()
	for u in uids:
		if PlayerState.remove_pokemon(u):
			sent.append(u)
	var received := {}
	for id in rewards:
		if rewards[id] > 0:
			PlayerState.add_item(id, rewards[id])
			received[id] = rewards[id]
	if not received.is_empty():
		EventBus.items_received.emit(received, &"professor")
	EventBus.pokemon_transferred.emit(sent, rewards)
	return {"ok": true, "reason": "", "count": sent.size(), "rewards": rewards}


## 일괄 보내기 대상: 종마다 가장 좋은 1마리(레벨 높은 순, 특성 많은 순)를 남기고 나머지.
## 잠금·원정 중·엔트리 개체는 제외. keep_traits = true 면 특성이 있는 개체도 남긴다.
func duplicate_candidates(keep_traits: bool = true) -> Array[String]:
	var by_species := {}
	for p in PlayerState.pokemon:
		by_species.get_or_add(p.dex_id, []).append(p)
	var out: Array[String] = []
	for dex_id in by_species:
		var group: Array = by_species[dex_id]
		if group.size() < 2:
			continue
		group.sort_custom(func(a, b):
			if a.level != b.level:
				return a.level > b.level
			return a.get("traits", []).size() > b.get("traits", []).size())
		for i in range(1, group.size()):
			var p: Dictionary = group[i]
			if transfer_block_reason(p) != "":
				continue
			if keep_traits and p.get("traits", []).size() > 0:
				continue
			out.append(p.uid)
	return out


func set_locked(uid: String, locked: bool) -> void:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return
	p.locked = locked
	PlayerState.changed.emit()


# ---------------------------------------------------------------- 경험사탕

## 사탕 count 개 사용. 반환: {ok, reason, used, levels}
func use_candy(uid: String, item_id: StringName, count: int = 1) -> Dictionary:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return _fail("없는 포켓몬입니다.")
	if PlayerState.is_busy(uid):
		return _fail("원정 중인 포켓몬에게는 줄 수 없습니다.")
	if p.level >= Formulas.MAX_POKEMON_LEVEL:
		return _fail("이미 최대 레벨입니다.")
	var item := GameData.get_item(item_id)
	if item == null or item.category != &"exp_candy":
		return _fail("경험사탕이 아닙니다.")
	count = mini(count, PlayerState.item_count(item_id))
	if count <= 0:
		return _fail("%s이(가) 없습니다." % item.name_ko)
	var per := int(item.params.get(&"exp", 0))
	var used := 0
	var levels := 0
	for i in count:
		if p.level >= Formulas.MAX_POKEMON_LEVEL:
			break
		PlayerState.remove_item(item_id, 1)
		levels += PlayerState.add_pokemon_exp(p, per)
		used += 1
	return {"ok": true, "reason": "", "used": used, "levels": levels}


## 다음 레벨까지 필요한 경험치
func exp_needed_for_next(p: Dictionary) -> int:
	if p.level >= Formulas.MAX_POKEMON_LEVEL:
		return 0
	return Formulas.exp_to_next(p.level) - int(p.get("exp", 0))


## 다음 레벨까지 필요한 만큼 사탕을 쓴다. 작은 사탕(S)을 먼저 써서 낭비를 줄이고, 모자라면 M.
func use_candies_to_next_level(uid: String) -> Dictionary:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return _fail("없는 포켓몬입니다.")
	var need := exp_needed_for_next(p)
	if need <= 0:
		return _fail("이미 최대 레벨입니다.")
	var s_exp := int(GameData.get_item(CANDY_S).params.get(&"exp", 100))
	var have_s := PlayerState.item_count(CANDY_S)
	var have_m := PlayerState.item_count(CANDY_M)
	var plan_s := mini(have_s, ceili(float(need) / s_exp))
	var plan_m := 0
	if plan_s * s_exp < need:
		plan_m = mini(have_m, 1)   # S가 모자라면 M 1개로 충분 (M = S 8개분)
		var rest := need - plan_m * int(GameData.get_item(CANDY_M).params.get(&"exp", 800))
		plan_s = mini(have_s, maxi(0, ceili(float(rest) / s_exp)))
	if plan_s + plan_m == 0:
		return _fail("경험사탕이 없습니다.")
	var levels := 0
	var used := 0
	if plan_m > 0:
		var r := use_candy(uid, CANDY_M, plan_m)
		if r.ok:
			levels += r.levels
			used += r.used
	if plan_s > 0 and PlayerState.find_pokemon(uid).level < Formulas.MAX_POKEMON_LEVEL:
		var r2 := use_candy(uid, CANDY_S, plan_s)
		if r2.ok:
			levels += r2.levels
			used += r2.used
	return {"ok": true, "reason": "", "used": used, "levels": levels}


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
