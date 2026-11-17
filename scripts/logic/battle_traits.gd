class_name BattleTraits
extends RefCounted
## 전투 특성 (엔트리일 때 발동, 기획서 4.6·4.13, v0.28). 순수 함수.
## 같은 특성은 엔트리에 여러 마리여도 1번만, 다른 특성끼리는 곱한다(출현 타입은 타입별로).

## 출현 배율이 이 값을 넘지 않게 (같은 타입에 서로 다른 특성 2개가 겹칠 때)
const MAX_TYPE_WEIGHT := 2.25
const MAX_INTERVAL_MULT := 1.5


## 엔트리 개체들 → 합친 전투 효과
## {type_weights: {type: mult}, interval_mult, wild_level_add, fill_mult,
##  after_items: [{chance, table}], per_level_currency, refund_ball, traits: [TraitData]}
static func collect(entries: Array) -> Dictionary:
	var out := {
		"type_weights": {}, "interval_mult": 1.0, "wild_level_add": 0, "fill_mult": 1.0,
		"after_items": [], "per_level_currency": 0, "refund_ball": false, "traits": [],
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
						out.interval_mult = minf(MAX_INTERVAL_MULT, out.interval_mult * float(e.value))
					"wild_level_add":
						out.wild_level_add += int(e.value)
					"battle_fill_mult":
						out.fill_mult *= float(e.value)
					"after_battle_item":
						out.after_items.append({"chance": float(e.chance), "table": e.table})
					"after_battle_currency":
						out.per_level_currency += int(e.per_level)
					"refund_ball_on_fail":
						out.refund_ball = true
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


## 전투 후 보상 (포획 성공·실패 모두). 반환 {items: {id: n}, currency: int}
static func roll_after_battle(fx: Dictionary, wild_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var items := {}
	for a in fx.get("after_items", []):
		if rng.randf() < float(a.chance):
			var table: Array = a.table
			var weights: Array[int] = []
			for row in table:
				weights.append(int(row[1]))
			var id := StringName(table[ExpeditionLogic._weighted_index(weights, rng)][0])
			items[id] = int(items.get(id, 0)) + 1
	return {"items": items, "currency": int(fx.get("per_level_currency", 0)) * wild_level}


## 메인 화면 버프 목록용 짧은 문구 [{text, good}]
static func buff_lines(fx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tw: Dictionary = fx.get("type_weights", {})
	for t in tw:
		out.append({"text": "%s 출현+%d%%" % [GameData.type_name(t), roundi((float(tw[t]) - 1.0) * 100)], "good": true})
	if int(fx.get("wild_level_add", 0)) > 0:
		out.append({"text": "야생 Lv+%d" % int(fx.wild_level_add), "good": true})
	if not Array(fx.get("after_items", [])).is_empty():
		out.append({"text": "픽업", "good": true})
	if int(fx.get("per_level_currency", 0)) > 0:
		out.append({"text": "꿀모으기", "good": true})
	if bool(fx.get("refund_ball", false)):
		out.append({"text": "볼줍기", "good": true})
	if float(fx.get("fill_mult", 1.0)) < 1.0:
		out.append({"text": "게이지 -%d%%" % roundi((1.0 - float(fx.fill_mult)) * 100), "good": false})
	if float(fx.get("interval_mult", 1.0)) > 1.0:
		out.append({"text": "출현 -%d%%" % roundi((1.0 - 1.0 / float(fx.interval_mult)) * 100), "good": false})
	return out
