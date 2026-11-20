class_name BattleTraits
extends RefCounted
## 전투 특성 (엔트리일 때 발동, 기획서 4.6·4.13, v0.28). 순수 함수.
## 같은 특성은 엔트리에 여러 마리여도 1번만, 다른 특성끼리는 곱한다(출현 타입은 타입별로).

## 출현 배율이 이 값을 넘지 않게 (같은 타입에 서로 다른 특성 2개가 겹칠 때)
const MAX_TYPE_WEIGHT := 2.25
const MAX_INTERVAL_MULT := 1.5
## 간격을 줄이는 특성(발광, v0.103)이 겹쳐도 이 값 밑으로는 내려가지 않는다
const MIN_INTERVAL_MULT := 0.7


## 엔트리 개체들 → 합친 전투 효과
## {type_weights: {type: mult}, interval_mult, wild_level_add, fill_mult,
##  item_encounter_mult (픽업, v0.84), per_level_currency, refund_ball, refund_chance,
##  trait_count_weights (트레이스, v0.103: 포획 시 특성 개수 가중치, 없으면 []), traits: [TraitData]}
static func collect(entries: Array) -> Dictionary:
	var out := {
		"type_weights": {}, "interval_mult": 1.0, "wild_level_add": 0, "fill_mult": 1.0,
		"item_encounter_mult": 1.0, "trait_count_weights": [], "per_level_currency": 0, "refund_ball": false, "refund_chance": 0.0, "traits": [],
	}
	var seen := {}
	for inst in entries:
		for t in ExpeditionLogic.traits_of(inst.get("traits", []), &"battle"):
			if seen.has(t.id):
				continue
			seen[t.id] = true
			out.traits.append(t)
			for e in t.effects:
				match e.get("kind"):
					"encounter_type_weight":
						for ty in e.types:
							var k := StringName(ty)
							out.type_weights[k] = minf(MAX_TYPE_WEIGHT, float(out.type_weights.get(k, 1.0)) * float(e.value))
					"encounter_interval_mult":
						out.interval_mult = clampf(out.interval_mult * float(e.value), MIN_INTERVAL_MULT, MAX_INTERVAL_MULT)   # 악취 ×1.15 / 발광 ×0.9
					"wild_level_add":
						out.wild_level_add += int(e.value)
					"battle_fill_mult":
						out.fill_mult *= float(e.value)
					"item_encounter_mult":   # 픽업 (v0.84: 전투 후 줍기 → 아이템 인카운터 확률)
						out.item_encounter_mult *= float(e.value)
					"trait_count_weights":   # 트레이스 (v0.103): 포획 순간 엔트리에 있으면 특성이 붙을 확률 ↑
						out.trait_count_weights = Array(e.value).map(func(w: Variant) -> int: return int(w))
					"after_battle_currency":
						out.per_level_currency += int(e.per_level)
					"refund_ball":   # 볼줍기 (v0.56: 성공·실패 상관없이 확률로, v0.81: 30% → 15%)
						out.refund_ball = true
						out.refund_chance = maxf(float(out.refund_chance), float(e.get("chance", 0.15)))
	return out


## 출현 가중치 배율: 종의 타입 중 하나라도 맞으면 그 배율(여러 개면 가장 큰 것)
static func species_weight_mult(species: PokemonSpecies, type_weights: Dictionary) -> float:
	if species == null or type_weights.is_empty():
		return 1.0
	var m := 1.0
	for t in species.types:
		m = maxf(m, float(type_weights.get(t, 1.0)))
	return m


## 의기양양: 야생 레벨 + add, 단 지역 최고 레벨(이미 넘었으면 그 레벨)까지
static func boosted_level(level: int, add: int, level_cap: int) -> int:
	if add <= 0:
		return level
	return mini(level + add, maxi(level, mini(level_cap, Formulas.MAX_POKEMON_LEVEL)))


## 전투 후 꿀모으기 돈 (포획 성공·실패 모두)
static func after_battle_currency(fx: Dictionary, wild_level: int) -> int:
	return int(fx.get("per_level_currency", 0)) * wild_level


## 메인 화면 버프 목록용 짧은 문구 [{text, good}]
static func buff_lines(fx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tw: Dictionary = fx.get("type_weights", {})
	for t in tw:
		out.append({"text": "%s 출현+%d%%" % [GameData.type_name(t), roundi((float(tw[t]) - 1.0) * 100)], "good": true})
	if int(fx.get("wild_level_add", 0)) > 0:
		out.append({"text": "야생 Lv+%d" % int(fx.wild_level_add), "good": true})
	if float(fx.get("item_encounter_mult", 1.0)) > 1.0:
		out.append({"text": "픽업", "good": true})
	if int(fx.get("per_level_currency", 0)) > 0:
		out.append({"text": "꿀모으기", "good": true})
	if bool(fx.get("refund_ball", false)):
		out.append({"text": "볼줍기", "good": true})
	if not Array(fx.get("trait_count_weights", [])).is_empty():
		out.append({"text": "특성 확률+", "good": true})
	if float(fx.get("fill_mult", 1.0)) > 1.0:
		out.append({"text": "게이지 +%d%%" % roundi((float(fx.fill_mult) - 1.0) * 100), "good": true})
	if float(fx.get("fill_mult", 1.0)) < 1.0:
		out.append({"text": "게이지 -%d%%" % roundi((1.0 - float(fx.fill_mult)) * 100), "good": false})
	if float(fx.get("interval_mult", 1.0)) < 1.0:
		out.append({"text": "출현 +%d%%" % roundi((1.0 / float(fx.interval_mult) - 1.0) * 100), "good": true})
	if float(fx.get("interval_mult", 1.0)) > 1.0:
		out.append({"text": "출현 -%d%%" % roundi((1.0 - 1.0 / float(fx.interval_mult)) * 100), "good": false})
	return out
