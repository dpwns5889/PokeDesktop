class_name EncounterLogic
extends RefCounted
## 출현 결정 (순수 함수). (기획서 4.2)


## 플레이어 레벨 조건을 만족하는 항목 중 가중치 랜덤. 없으면 null.
## type_weights = {type: 배율} (엔트리의 출현 특성, 기획서 4.6) — 비어 있으면 원래 가중치 그대로.
static func pick_entry(entries: Array[EncounterEntry], player_level: int, rng: RandomNumberGenerator,
		type_weights: Dictionary = {}) -> EncounterEntry:
	if not type_weights.is_empty():
		return _pick_weighted(entries, player_level, rng, type_weights)
	var pool: Array[EncounterEntry] = []
	var total := 0
	for e in entries:
		if e.min_player_level <= player_level and e.weight > 0:
			pool.append(e)
			total += e.weight
	if pool.is_empty():
		return null
	var roll := rng.randi_range(1, total)
	for e in pool:
		roll -= e.weight
		if roll <= 0:
			return e
	return pool.back()


static func _pick_weighted(entries: Array[EncounterEntry], player_level: int, rng: RandomNumberGenerator,
		type_weights: Dictionary) -> EncounterEntry:
	var pool: Array[EncounterEntry] = []
	var ws: Array[float] = []
	var total := 0.0
	for e in entries:
		if e.min_player_level <= player_level and e.weight > 0:
			var w := e.weight * BattleTraits.species_weight_mult(GameData.get_species(e.dex_id), type_weights)
			pool.append(e)
			ws.append(w)
			total += w
	if pool.is_empty():
		return null
	var roll := rng.randf_range(0.0, total)
	for i in pool.size():
		roll -= ws[i]
		if roll <= 0.0:
			return pool[i]
	return pool.back()


## &"male" / &"female" / &"none"
static func roll_gender(species: PokemonSpecies, rng: RandomNumberGenerator) -> StringName:
	if species.is_genderless():
		return &"none"
	return &"male" if rng.randf() < species.gender_ratio else &"female"


## 이 지역에서 조건을 만족해 후보가 되는 전설 규칙 (기획서 4.5)
static func eligible_legendaries(region: RegionData, rules: Array[LegendaryRule], is_met: Callable) -> Array[LegendaryRule]:
	var eligible: Array[LegendaryRule] = []
	for r in rules:
		if (r.region_ids.is_empty() or r.region_ids.has(region.id)) and is_met.call(r.conditions):
			eligible.append(r)
	return eligible


## 전설 출현 판정 (기획서 4.5, v0.97). 후보가 있으면 확률을 **한 번만** 굴리고, 나오면 후보 중 하나를 고른다.
## misses = 이 지역에서 전설을 못 만난 인카운터 수 → 확률 +1%p씩, 최대 20%
static func roll_legendary(region: RegionData, rules: Array[LegendaryRule], is_met: Callable,
		rng: RandomNumberGenerator, misses: int = 0) -> LegendaryRule:
	var eligible := eligible_legendaries(region, rules, is_met)
	if eligible.is_empty():
		return null
	var chance := minf(eligible[0].chance + misses * Formulas.LEGEND_PITY_STEP, Formulas.LEGEND_CHANCE_MAX)
	if rng.randf() >= chance:
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]


## 인카운터 1건. 지역에 출현 가능한 항목이 없으면 빈 Dictionary.
## rules/is_met 을 주면 전설 출현을 먼저 판정한다.
static func roll_encounter(region: RegionData, player_level: int, rng: RandomNumberGenerator,
		rules: Array[LegendaryRule] = [], is_met: Callable = Callable(), type_weights: Dictionary = {},
		shiny_mult: float = 1.0, legend_misses: int = 0) -> Dictionary:
	if not rules.is_empty() and is_met.is_valid():
		var rule := roll_legendary(region, rules, is_met, rng, legend_misses)
		if rule != null:
			var ls := GameData.get_species(rule.dex_id)
			if ls != null:
				return {
					&"dex_id": rule.dex_id,
					&"level": rule.level,
					&"gender": roll_gender(ls, rng),
					&"shiny": Formulas.roll_shiny(rng, shiny_mult),
					&"region": region.id,
					&"legendary": true,
				}
	var entry := pick_entry(region.encounters, player_level, rng, type_weights)
	if entry == null:
		return {}
	var species := GameData.get_species(entry.dex_id)
	if species == null:
		push_warning("지역 %s: 알 수 없는 종 %d" % [region.id, entry.dex_id])
		return {}
	return {
		&"dex_id": entry.dex_id,
		&"level": Formulas.roll_wild_level(entry, region.level_scale, region.level_cap, player_level, rng),
		&"gender": roll_gender(species, rng),
		&"shiny": Formulas.roll_shiny(rng, shiny_mult),   # 1/512 (M11), 특이한 향로면 ×4
		&"region": region.id,
		&"legendary": false,
		&"difficulty_bonus": entry.difficulty_bonus,   # 출현 표의 추가 난이도 (v0.76)
	}


## 아이템 인카운터 (v0.84): 이번 인카운터가 아이템이면 {id, count}, 포켓몬이면 빈 Dictionary. mult = 픽업 등 확률 배율
## 수량은 표 행의 [최소, 최대]에서 고르게 (없으면 1개, v0.88)
static func roll_item_encounter(region: RegionData, mult: float, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= Formulas.ITEM_ENCOUNTER_CHANCE * mult:
		return {}
	var table: Array = Formulas.ITEM_ENCOUNTER_TABLES.get(region.item_tier if region else 1, Formulas.ITEM_ENCOUNTER_TABLES[1])
	var weights: Array[int] = []
	for r in table:
		weights.append(int(r[1]))
	var row: Array = table[ExpeditionLogic._weighted_index(weights, rng)]
	var count := rng.randi_range(int(row[2]), int(row[3])) if row.size() >= 4 else 1
	return {&"id": StringName(row[0]), &"count": count}
