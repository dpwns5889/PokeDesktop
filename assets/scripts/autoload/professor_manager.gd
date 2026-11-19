extends Node
## 박사에게 보내기(놓아주기 대신)와 경험사탕 사용. (기획서 4.8)
## - 보내면 개체가 사라지고 레벨에 비례한 경험사탕을 받는다(Formulas.transfer_candies).
## - 원정 중이거나 즐겨찾기한 개체는 보낼 수 없다. 원정 중인 개체는 사탕도 줄 수 없다.
## - 특성 캡슐·깜빡열매 (v0.79, 플레이어 Lv12부터): 특성이 있는 개체를 한 마리씩 보내면 가끔 그 특성을 담은 캡슐.
##   캡슐을 쓰면 그 특성이 확정으로 붙는다. 깜빡열매는 부정 특성 하나를 지운다.
## 결과는 {ok: bool, reason: String, ...} (화면에 그대로 표시할 수 있는 한국어 문구).

const CANDY_S := &"exp_candy_s"
const CANDY_M := &"exp_candy_m"
const FORGET_BERRY := &"forget_berry"
## 캡슐이 나올 확률: 보내는 개체의 담길 수 있는 특성 하나를 고르게 고른 뒤 그 등급의 확률로 (v0.79)
const CAPSULE_CHANCE := {&"normal": 0.25, &"rare": 0.10}
## 무작위 특성 최대 개수 (고정 특성 "전설"·"색이다른"은 세지 않음, 기획서 4.6)
const MAX_RANDOM_TRAITS := 3

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


# ---------------------------------------------------------------- 박사에게 보내기

## 보낼 수 있는가. 반환: "" = 가능, 아니면 이유
func transfer_block_reason(inst: Dictionary) -> String:
	if inst.is_empty():
		return "없는 포켓몬입니다."
	if PlayerState.is_busy(inst.uid):
		return "원정 중인 포켓몬은 보낼 수 없습니다."
	if inst.get("favorite", false):
		return "즐겨찾기한 포켓몬은 보낼 수 없습니다."
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
	# 특성 캡슐은 한 마리씩 보낼 때만 (중복 보내기에서는 안 나옴, v0.79)
	var capsule := _roll_capsule(PlayerState.find_pokemon(uids[0])) if uids.size() == 1 else &""
	var sent := PackedStringArray()
	for u in uids:
		if PlayerState.remove_pokemon(u):
			sent.append(u)
	var received := {}
	for id in rewards:
		if rewards[id] > 0:
			PlayerState.add_item(id, rewards[id])
			received[id] = rewards[id]
	if capsule != &"":
		PlayerState.add_item(capsule, 1)
		received[capsule] = 1
	if not received.is_empty():
		EventBus.items_received.emit(received, &"professor")
	EventBus.pokemon_transferred.emit(sent, rewards)
	return {"ok": true, "reason": "", "count": sent.size(), "rewards": rewards, "capsule": capsule}


## 일괄 보내기 대상: 종마다 가장 좋은 1마리(레벨 높은 순, 특성 많은 순)를 남기고 나머지.
## 즐겨찾기·원정 중·엔트리 개체는 제외. keep_traits = true 면 특성이 있는 개체도 남긴다.
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


## 즐겨찾기 (v0.71, 잠금을 대신함). 즐겨찾기한 개체는 보낼 수 없고, 파티·원정 목록 맨 위에 온다.
func set_favorite(uid: String, favorite: bool) -> void:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return
	p.favorite = favorite
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
	if used > 0:
		EventBus.item_used.emit(item_id)   # 효과음 (v0.62)
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


# ---------------------------------------------------------------- 특성 캡슐 · 깜빡열매 (v0.79)

func capsules_unlocked() -> bool:
	var t := GameData.capsule_template()
	return t != null and PlayerState.level >= t.unlock_level


## 이 개체의 특성 중 캡슐에 담길 수 있는 것 (일반·희귀)
func capsule_traits(inst: Dictionary) -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in inst.get("traits", []):
		var t := GameData.get_trait(StringName(id))
		if GameData.is_capsule_trait(t):
			out.append(t)
	return out


## 한 마리를 보낼 때 특성별 캡슐 확률 {trait_id: 0~1}. 해금 전이거나 담길 특성이 없으면 빈 사전
func capsule_odds(inst: Dictionary) -> Dictionary:
	var out := {}
	if not capsules_unlocked():
		return out
	var ts := capsule_traits(inst)
	for t in ts:
		out[t.id] = float(CAPSULE_CHANCE[t.tier]) / ts.size()
	return out


func _roll_capsule(inst: Dictionary) -> StringName:
	var ts := capsule_traits(inst)
	if ts.is_empty() or not capsules_unlocked():
		return &""
	var t := ts[rng.randi_range(0, ts.size() - 1)]
	return GameData.capsule_id(t.id) if rng.randf() < float(CAPSULE_CHANCE[t.tier]) else &""


## 고정 특성(전설·색이다른)을 뺀 특성 수
static func random_trait_count(traits: Array) -> int:
	var n := 0
	for id in traits:
		var t := GameData.get_trait(StringName(id))
		if t and t.tier != &"legend":
			n += 1
	return n


## 캡슐을 쓰면 어떻게 되는가. {ok, reason, replace: 빠지는 특성 id(같이 안 붙는 특성, "" = 없음), choose: 3개라 바꿀 특성을 골라야 함}
func capsule_plan(inst: Dictionary, trait_id: StringName) -> Dictionary:
	if inst.is_empty():
		return _fail("없는 포켓몬입니다.")
	if PlayerState.is_busy(inst.uid):
		return _fail("원정 중인 포켓몬에게는 쓸 수 없습니다.")
	var t := GameData.get_trait(trait_id)
	if t == null:
		return _fail("알 수 없는 특성입니다.")
	var traits: Array = inst.get("traits", [])
	if traits.has(String(trait_id)):
		return _fail("이미 %s 특성이 있습니다." % t.name_ko)
	for other in traits:
		var o := GameData.get_trait(StringName(other))
		if t.exclusive_with.has(StringName(other)) or (o and o.exclusive_with.has(trait_id)):
			return {"ok": true, "reason": "", "replace": String(other), "choose": false}
	return {"ok": true, "reason": "", "replace": "", "choose": random_trait_count(traits) >= MAX_RANDOM_TRAITS}


## 캡슐 사용. 특성이 3개면 replace(바꿀 특성 id)를 줘야 한다. 반환 {ok, reason, replaced: 빠진 특성 id}
func use_capsule(uid: String, item_id: StringName, replace: String = "") -> Dictionary:
	var item := GameData.get_item(item_id)
	if item == null or item.category != GameData.CAPSULE_TEMPLATE:
		return _fail("특성 캡슐이 아닙니다.")
	if PlayerState.item_count(item_id) <= 0:
		return _fail("%s이(가) 없습니다." % item.name_ko)
	var p := PlayerState.find_pokemon(uid)
	var trait_id: StringName = item.params.get(&"trait", &"")
	var plan := capsule_plan(p, trait_id)
	if not plan.ok:
		return plan
	var out: String = plan.replace
	if plan.choose:
		var r := GameData.get_trait(StringName(replace))
		if replace == "" or not p.traits.has(replace) or r == null or r.tier == &"legend":
			return _fail("바꿀 특성을 고르세요.")
		out = replace
	var traits: Array = p.traits
	if out != "":
		traits[traits.find(out)] = String(trait_id)   # 같은 자리에서 바꾼다
	else:
		traits.append(String(trait_id))
	PlayerState.remove_item(item_id, 1)
	PlayerState.changed.emit()
	EventBus.item_used.emit(item_id)
	return {"ok": true, "reason": "", "replaced": out}


## 이 개체의 부정 특성
func negative_traits(inst: Dictionary) -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in inst.get("traits", []):
		var t := GameData.get_trait(StringName(id))
		if t and t.is_negative():
			out.append(t)
	return out


## 깜빡열매: 부정 특성 trait_id 하나를 지운다
func use_forget_berry(uid: String, trait_id: String) -> Dictionary:
	if PlayerState.item_count(FORGET_BERRY) <= 0:
		return _fail("깜빡열매가 없습니다.")
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return _fail("없는 포켓몬입니다.")
	if PlayerState.is_busy(uid):
		return _fail("원정 중인 포켓몬에게는 쓸 수 없습니다.")
	var t := GameData.get_trait(StringName(trait_id))
	if t == null or not t.is_negative() or not p.get("traits", []).has(trait_id):
		return _fail("지울 부정 특성을 고르세요.")
	p.traits.erase(trait_id)
	PlayerState.remove_item(FORGET_BERRY, 1)
	PlayerState.changed.emit()
	EventBus.item_used.emit(FORGET_BERRY)
	return {"ok": true, "reason": ""}


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
