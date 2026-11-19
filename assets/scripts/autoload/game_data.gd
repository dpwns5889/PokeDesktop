extends Node
## 데이터 레지스트리. res://assets/data/ 아래 리소스를 스캔해 조회 기능을 제공한다. (기획서 7장)
## 세대는 데이터로만 추가한다 — 코드에 종 수나 세대 번호를 하드코딩하지 않는다.

const POKEMON_DIR := "res://assets/data/pokemon"
const TYPES_PATH := "res://assets/data/types/types.json"
const REGIONS_DIR := "res://assets/data/regions"
const LEGENDARY_DIR := "res://assets/data/legendary_rules"
const TRAITS_DIR := "res://assets/data/traits"
const ITEMS_DIR := "res://assets/data/items"
const EXPEDITIONS_DIR := "res://assets/data/expeditions"

## 활성 세대. 2세대 추가 시 assets/data/pokemon/gen2/ 를 만들고 여기에 2를 넣는다.
var enabled_generations: Array[int] = [1]

var _species: Dictionary = {}       # dex_id(int) -> PokemonSpecies
var _sorted_ids: Array[int] = []
var _type_names: Dictionary = {}    # StringName -> 한국어 이름
var _regions: Dictionary = {}       # StringName -> RegionData
var _legendary_rules: Array[LegendaryRule] = []
var _traits: Dictionary = {}        # StringName -> TraitData
var _items: Dictionary = {}         # StringName -> ItemData
const CAPSULE_TEMPLATE := &"trait_capsule"
var _capsule_template: ItemData
var _expeditions: Dictionary = {}   # StringName -> ExpeditionData
var _trait_roll: TraitRollConfig


func _ready() -> void:
	reload()


func reload() -> void:
	_species.clear()
	for gen in enabled_generations:
		var dir := "%s/gen%d" % [POKEMON_DIR, gen]
		if not DirAccess.dir_exists_absolute(dir):
			push_warning("세대 %d 데이터 폴더가 없습니다: %s" % [gen, dir])
			continue
		for file in ResourceLoader.list_directory(dir):
			if not file.ends_with(".tres"):
				continue
			var res := load("%s/%s" % [dir, file]) as PokemonSpecies
			if res != null:
				_species[res.dex_id] = res
	_sorted_ids.assign(_species.keys())
	_sorted_ids.sort()

	_regions.clear()
	for r in _load_all(REGIONS_DIR):
		if r is RegionData:
			_regions[r.id] = r

	# 전설 규칙: 활성 세대의 종만
	_legendary_rules.clear()
	for r in _load_all(LEGENDARY_DIR):
		if r is LegendaryRule and _species.has(r.dex_id):
			_legendary_rules.append(r)

	_items.clear()
	for it in _load_all(ITEMS_DIR):
		if it is ItemData:
			_items[it.id] = it

	_traits.clear()
	_trait_roll = null
	for t in _load_all(TRAITS_DIR):
		if t is TraitData:
			_traits[t.id] = t
		elif t is TraitRollConfig:
			_trait_roll = t

	# 특성 캡슐 (v0.79): 템플릿 아이템(trait_capsule) → 캡슐에 담길 수 있는 특성(일반·희귀)마다 아이템 하나.
	# 가방·판매·저장은 보통 아이템처럼 다룬다 (id = trait_capsule_<특성>, 그림은 템플릿 것)
	_capsule_template = _items.get(CAPSULE_TEMPLATE)
	if _capsule_template:
		_items.erase(CAPSULE_TEMPLATE)
		for t: TraitData in _traits.values():
			if is_capsule_trait(t):
				var it: ItemData = _capsule_template.duplicate()
				it.id = capsule_id(t.id)
				it.name_ko = "%s (%s)" % [_capsule_template.name_ko, t.name_ko]
				it.params = {&"trait": t.id}
				it.icon_id = CAPSULE_TEMPLATE
				_items[it.id] = it

	_expeditions.clear()
	for x in _load_all(EXPEDITIONS_DIR):
		if x is ExpeditionData:
			_expeditions[x.id] = x

	_type_names.clear()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(TYPES_PATH))
	if raw is Dictionary:
		for k in raw:
			_type_names[StringName(k)] = raw[k]


func get_species(dex_id: int) -> PokemonSpecies:
	return _species.get(dex_id)


func has_species(dex_id: int) -> bool:
	return _species.has(dex_id)


func species_count() -> int:
	return _species.size()


## 도감 번호 순서의 전체 종 목록.
func all_species() -> Array[PokemonSpecies]:
	var out: Array[PokemonSpecies] = []
	for id in _sorted_ids:
		out.append(_species[id])
	return out


## 전설·환상 포켓몬 (전설 조건 자동 생성에 사용, 기획서 4.5)
func legendaries() -> Array[PokemonSpecies]:
	return all_species().filter(func(s: PokemonSpecies) -> bool: return s.is_legendary or s.is_mythical)


func type_name(type_id: StringName) -> String:
	return _type_names.get(type_id, String(type_id))


func type_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_type_names.keys())
	return out


func get_region(id: StringName) -> RegionData:
	return _regions.get(id)


## 해금 순서(order)로 정렬한 지역 ID
func region_ids() -> Array[StringName]:
	var list: Array = _regions.values()
	list.sort_custom(func(a: RegionData, b: RegionData) -> bool: return a.order < b.order)
	var out: Array[StringName] = []
	for r in list:
		out.append(r.id)
	return out


func all_regions() -> Array[RegionData]:
	var out: Array[RegionData] = []
	for id in region_ids():
		out.append(_regions[id])
	return out


func legendary_rules() -> Array[LegendaryRule]:
	return _legendary_rules


func get_item(id: StringName) -> ItemData:
	return _items.get(id)


## 특성 캡슐 (v0.79): 담길 수 있는 특성인가 (일반·희귀, 부정·고정 제외)
func is_capsule_trait(t: TraitData) -> bool:
	return t != null and t.weight > 0 and (t.tier == &"normal" or t.tier == &"rare")


func capsule_id(trait_id: StringName) -> StringName:
	return StringName("%s_%s" % [CAPSULE_TEMPLATE, trait_id])


## 캡슐 공통 값(해금 레벨·판매가 등)
func capsule_template() -> ItemData:
	return _capsule_template


## order 순 아이템 목록. category 를 주면 그 분류만.
func all_items(category: StringName = &"") -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in _items.values():
		if category == &"" or it.category == category:
			out.append(it)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.order < b.order or (a.order == b.order and a.name_ko < b.name_ko))   # 특성 캡슐은 order 가 같아 이름 순
	return out


func get_trait(id: StringName) -> TraitData:
	return _traits.get(id)


## 무작위로 붙을 수 있는 특성 (weight > 0)
## 모든 특성 (id 순)
func all_traits() -> Array[TraitData]:
	var out: Array[TraitData] = []
	for t in _traits.values():
		out.append(t)
	out.sort_custom(func(a: TraitData, b: TraitData) -> bool: return String(a.id) < String(b.id))
	return out


func random_trait_pool() -> Array[TraitData]:
	var out: Array[TraitData] = []
	for t in _traits.values():
		if t.weight > 0:
			out.append(t)
	out.sort_custom(func(a: TraitData, b: TraitData) -> bool: return String(a.id) < String(b.id))
	return out


func trait_roll_config() -> TraitRollConfig:
	return _trait_roll


func get_expedition(id: StringName) -> ExpeditionData:
	return _expeditions.get(id)


## order 순 원정지
func all_expeditions() -> Array[ExpeditionData]:
	var out: Array[ExpeditionData] = []
	for x in _expeditions.values():
		out.append(x)
	out.sort_custom(func(a: ExpeditionData, b: ExpeditionData) -> bool: return a.order < b.order)
	return out


func _load_all(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres"):
			var r := load(dir.path_join(file))
			if r != null:
				out.append(r)
	return out
