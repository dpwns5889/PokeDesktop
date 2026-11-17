class_name ExpeditionLogic
extends RefCounted
## 원정·특성 계산 (순수 함수). (기획서 4.6, 4.10)
##
## 특성 (v0.28 개편): 원정에는 trigger = expedition 인 특성만 쓴다.
## - scope self  : 그 포켓몬만 (전투력 배율, 불리 타입 무시·강화). 전투력 효과는 모두 self.
## - scope party : 원정 전체 (시간·보상·성공 확률·추가 아이템). 같은 특성은 파티에 여러 마리여도 1번만,
##                 다른 특성끼리는 곱한다. 상한: 시간 ×0.6~1.3, 보상(요구치 초과 보너스 포함) 최대 ×2.0.
## - when 조건: expeditions(원정지 id) / self_types(자신의 타입) / max_duration_min(원정 기본 시간 이하)

const RECOMMENDED_BONUS := 1.25
const WEAK_PENALTY := 0.85
const DIVERSITY_TYPES := 4
const DIVERSITY_BONUS := 0.05
const MIN_START_RATIO := 0.7
const MAX_BONUS_RATIO := 1.5
const FAIL_REWARD_RATIO := 0.3
const MIN_DURATION_MULT := 0.6
const MAX_DURATION_MULT := 1.3
const MAX_REWARD_MULT := 2.0
const MAX_SUCCESS_BONUS := 0.3


# ---------------------------------------------------------------- 특성

## 특성 ID 목록 → TraitData 목록 (알 수 없는 특성은 무시). trigger 를 주면 그 발동 특성만.
static func traits_of(trait_ids: Array, trigger: StringName = &"") -> Array[TraitData]:
	var out: Array[TraitData] = []
	for id in trait_ids:
		var t := GameData.get_trait(StringName(id))
		if t != null and (trigger == &"" or t.trigger == trigger):
			out.append(t)
	return out


## 원정 특성의 효과 목록 (자신 것만). scope 를 주면 그 범위만.
static func expedition_effects(trait_ids: Array, scope: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in traits_of(trait_ids, &"expedition"):
		for e in t.effects:
			if scope == "" or e.get("scope", "self") == scope:
				out.append(e)
	return out


## 효과의 when 조건을 이 원정지·개체가 만족하는가
static func condition_met(e: Dictionary, expedition: ExpeditionData, species: PokemonSpecies = null) -> bool:
	var when: Dictionary = e.get("when", {})
	if when.is_empty():
		return true
	if when.has("expeditions") and expedition != null and not Array(when.expeditions).has(String(expedition.id)):
		return false
	if when.has("max_duration_min") and expedition != null and expedition.duration_sec > int(when.max_duration_min) * 60:
		return false
	if when.has("self_types"):
		if species == null:
			return false
		var hit := false
		for t in species.types:
			if Array(when.self_types).has(String(t)):
				hit = true
		if not hit:
			return false
	return true


## 포획 시 무작위 특성 (기획서 4.6). 고정 특성(전설 등)은 따로 붙인다.
static func roll_traits(rng: RandomNumberGenerator, config: TraitRollConfig, pool: Array[TraitData]) -> Array[String]:
	var out: Array[String] = []
	if config == null or pool.is_empty():
		return out
	var count := _weighted_index(config.count_weights, rng)
	for i in count:
		var tiers: Array = config.tier_weights.keys()
		var tw: Array[int] = []
		for t in tiers:
			tw.append(int(config.tier_weights[t]))
		var tier: StringName = tiers[_weighted_index(tw, rng)]
		var candidates: Array[TraitData] = []
		var weights: Array[int] = []
		for t in pool:
			if t.tier != tier or t.weight <= 0 or out.has(String(t.id)):
				continue
			var blocked := false
			for other in out:
				if t.exclusive_with.has(StringName(other)):
					blocked = true
			if not blocked:
				candidates.append(t)
				weights.append(t.weight)
		if candidates.is_empty():
			continue
		out.append(String(candidates[_weighted_index(weights, rng)].id))
	return out


# ---------------------------------------------------------------- 전투력

## 개체 하나의 원정 전투력 (기획서 4.10). 특성의 전투력 효과는 자신에게만 (v0.28).
static func pokemon_power(inst: Dictionary, expedition: ExpeditionData) -> float:
	var species := GameData.get_species(inst.dex_id)
	if species == null:
		return 0.0
	var traits: Array = inst.get("traits", [])
	var stats := Formulas.calc_stats(species.base_stats, inst.level, {}, inst.get("ivs", {}))
	var power := 0.0
	for v in stats.values():
		power += v
	var ignore_weak := false
	var weak := WEAK_PENALTY
	var mult := 1.0
	for e in expedition_effects(traits, "self"):
		if not condition_met(e, expedition, species):
			continue
		match e.get("kind"):
			"power_mult":
				mult *= float(e.value)
			"ignore_weak_type":
				ignore_weak = true
			"weak_type_mult":
				weak = minf(weak, float(e.value))
	var tb := type_bonus(species.types, expedition, weak)
	if ignore_weak and tb < 1.0:
		tb = 1.0
	return power * tb * mult


## 추천 타입이 하나라도 있으면 1.25, 아니고 불리 타입이 있으면 weak(기본 0.85)
static func type_bonus(types: Array[StringName], expedition: ExpeditionData, weak: float = WEAK_PENALTY) -> float:
	for t in types:
		if expedition.recommended_types.has(t):
			return RECOMMENDED_BONUS
	for t in types:
		if expedition.weak_types.has(t):
			return weak
	return 1.0


## 원정 전체 효과 (같은 특성은 1번만, 다른 특성끼리 곱한 뒤 상한).
## {duration_mult, reward_mult, success_bonus, bonus_items: [{item, chance, min, max}], traits: [id]}
static func party_mods(party: Array[Dictionary], expedition: ExpeditionData) -> Dictionary:
	var mods := {"duration_mult": 1.0, "reward_mult": 1.0, "success_bonus": 0.0, "bonus_items": [], "traits": []}
	var seen := {}
	for inst in party:
		for t in traits_of(inst.get("traits", []), &"expedition"):
			if seen.has(t.id):
				continue
			var used := false
			for e in t.effects:
				if e.get("scope", "self") != "party" or not condition_met(e, expedition):
					continue
				used = true
				match e.kind:
					"duration_mult", "reward_mult":
						mods[e.kind] *= float(e.value)
					"success_bonus":
						mods.success_bonus += float(e.value)
					"bonus_item":
						mods.bonus_items.append({"item": e.item, "chance": float(e.chance),
							"min": int(e.get("min", 1)), "max": int(e.get("max", 1))})
			if used:
				seen[t.id] = true
				mods.traits.append(String(t.id))
	mods.duration_mult = clampf(mods.duration_mult, MIN_DURATION_MULT, MAX_DURATION_MULT)
	mods.success_bonus = minf(MAX_SUCCESS_BONUS, mods.success_bonus)
	return mods


## 파티 요약: 전투력·성공 확률·소요 시간·원정 전체 특성 효과
static func party_summary(party: Array[Dictionary], expedition: ExpeditionData) -> Dictionary:
	var power := 0.0
	var types := {}
	for inst in party:
		power += pokemon_power(inst, expedition)
		var s := GameData.get_species(inst.dex_id)
		if s:
			for t in s.types:
				types[t] = true
	power = party_power(power, types.size())
	var mods := party_mods(party, expedition)
	var ratio := power / maxf(1.0, expedition.required_power)
	return {
		"power": int(round(power)),
		"required": expedition.required_power,
		"ratio": ratio,
		"can_start": ratio >= MIN_START_RATIO,
		"success_chance": success_chance(ratio, mods.success_bonus),
		"duration_sec": int(round(expedition.duration_sec * mods.duration_mult)),
		"mods": mods,
	}


## 자동 선택 (기획서 4.10): 이 원정지 기준 전투력이 높은 순으로, 최소 인원을 채우고
## 요구치(100%)를 넘을 때까지 더한다. 끝까지 더해도 못 넘으면 후보 전부.
## 원정 전체에 손해를 주는 부정 특성(시간·보상)이 있는 개체는 뒤로 미룬다(그것 없이 못 채울 때만 넣음).
## candidates = 원정 중이 아닌 개체 목록. 반환: uid 목록
static func auto_select(candidates: Array[Dictionary], expedition: ExpeditionData) -> Array[String]:
	var powers := {}
	var harmful := {}
	for p in candidates:
		powers[p.uid] = pokemon_power(p, expedition)
		harmful[p.uid] = _hurts_party(p, expedition)
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		if harmful[a.uid] != harmful[b.uid]:
			return not harmful[a.uid]
		return powers[a.uid] > powers[b.uid])
	# party_summary 와 같은 계산을 한 마리씩 더하며 이어서 한다 (후보가 많아도 빠르게)
	var out: Array[String] = []
	var sum := 0.0
	var types := {}
	var need := maxf(1.0, expedition.required_power)
	for p in sorted:
		out.append(String(p.uid))
		sum += powers[p.uid]
		var s := GameData.get_species(p.dex_id)
		if s:
			for t in s.types:
				types[t] = true
		if out.size() >= expedition.min_party and party_power(sum, types.size()) / need >= 1.0:
			break
	return out


## 원정 전체에 손해(시간 늘림·보상 줄임)를 주는 특성이 있는가
static func _hurts_party(inst: Dictionary, expedition: ExpeditionData) -> bool:
	for e in expedition_effects(inst.get("traits", []), "party"):
		if not condition_met(e, expedition):
			continue
		match e.kind:
			"duration_mult":
				if float(e.value) > 1.0:
					return true
			"reward_mult":
				if float(e.value) < 1.0:
					return true
	return false


## 개체 전투력 합 → 파티 전투력 (타입 다양성 보너스). 인원 보너스·파티 전투력 특성은 없다 (v0.24, v0.28)
static func party_power(power_sum: float, type_count: int) -> float:
	var bonus := 1.0 + (DIVERSITY_BONUS if type_count >= DIVERSITY_TYPES else 0.0)
	return power_sum * bonus


static func success_chance(ratio: float, bonus: float = 0.0) -> float:
	if ratio >= 1.0:
		return 1.0
	if ratio < MIN_START_RATIO:
		return 0.0
	return clampf((ratio - MIN_START_RATIO) / (1.0 - MIN_START_RATIO) + bonus, 0.0, 1.0)


# ---------------------------------------------------------------- 보상

## 원정 결과. {success, currency, items: {id: n}}
## 성공: 요구치 초과 보너스(최대 ×1.5) × 보상 특성(reward_mult), 합쳐서 최대 ×2.0. 실패: ×0.3.
## 추가 아이템 특성(bonus_item)은 성공했을 때만.
static func roll_rewards(expedition: ExpeditionData, ratio: float, mods: Dictionary, success: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var bonus := clampf(ratio, 1.0, MAX_BONUS_RATIO) if success else FAIL_REWARD_RATIO
	var reward_mult := float(mods.get("reward_mult", 1.0))
	var total := minf(MAX_REWARD_MULT, bonus * reward_mult)
	var currency := rng.randi_range(expedition.currency_reward.x, expedition.currency_reward.y)
	currency = int(round(currency * total))
	var rolls := int(round(expedition.reward_rolls * bonus))
	var items := {}
	var weights: Array[int] = []
	for r in expedition.reward_table:
		weights.append(int(r.weight))
	for i in rolls:
		if weights.is_empty():
			break
		var r: Dictionary = expedition.reward_table[_weighted_index(weights, rng)]
		var id := StringName(r.item)
		items[id] = int(items.get(id, 0)) + rng.randi_range(int(r.min), int(r.max))
	# 보상 특성: 아이템 수량에도 적용 (요구치 초과 보너스는 추첨 횟수로 이미 반영)
	if reward_mult != 1.0:
		var item_mult := minf(reward_mult, MAX_REWARD_MULT / maxf(1.0, bonus))
		for id in items:
			items[id] = maxi(1, int(round(items[id] * item_mult)))
	if success:
		for b in mods.get("bonus_items", []):
			if rng.randf() < float(b.chance):
				var id := StringName(b.item)
				items[id] = int(items.get(id, 0)) + rng.randi_range(int(b.min), int(b.max))
	return {"success": success, "currency": currency, "items": items}


## 참여 개체 하나가 받는 경험치 (자신의 exp_mult 특성 반영 — 지금은 해당 특성 없음)
static func pokemon_exp(inst: Dictionary, expedition: ExpeditionData) -> int:
	var mult := 1.0
	for e in expedition_effects(inst.get("traits", []), "self"):
		if e.get("kind") == "exp_mult":
			mult *= float(e.value)
	return int(round(expedition.exp_reward * mult))


static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll := rng.randi_range(1, total)
	for i in weights.size():
		roll -= int(weights[i])
		if roll <= 0:
			return i
	return weights.size() - 1
