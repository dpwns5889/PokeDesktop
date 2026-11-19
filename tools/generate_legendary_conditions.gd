extends SceneTree
## 전설·환상 포켓몬 출현 조건 자동 생성 → assets/data/legendary_rules/<dex>.tres. (기획서 4.5)
## 실행: <godot> --headless --path . -s res://tools/generate_legendary_conditions.gd -- --gen 1
## 생성 결과는 손으로 고쳐도 된다(다시 실행하면 덮어쓴다).
##
## 규칙 (다른 세대를 추가해도 같은 규칙):
##   대상      = is_legendary 또는 is_mythical 인 종 (도감 순)
##   주 타입    = 첫 번째 타입
##   플레이어 Lv = 25 + 3 × (대상 중 순번)
##   타입 포획  = ceil(주 타입을 가진 비전설 종 수 × 0.6) 종
##   도감 포획  = floor(비전설 종 수 × 비율). 비율: 일반 전설 0.7, 종족값 합 680 이상 0.9, 환상 0.95 (M10)
##   등장 지역  = 주 타입이 대표 타입인 지역 (없으면 모든 지역)
##   등장 레벨  = 일반 전설 50, 종족값 합 680 이상 70, 환상 30
##   확률      = 인카운터마다 3% (M10 밸런스)

const SPECIES_DIR := "res://assets/data/pokemon/gen%d"
const REGIONS_DIR := "res://assets/data/regions"
const OUT_DIR := "res://assets/data/legendary_rules"
const CHANCE := 0.03
const STRONG_BST := 680


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--gen")
	var max_gen := int(args[i + 1]) if i >= 0 and i + 1 < args.size() else 1
	quit(_run(max_gen))


func _run(max_gen: int) -> int:
	var species: Array[PokemonSpecies] = []
	for gen in range(1, max_gen + 1):
		var dir := SPECIES_DIR % gen
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tres"):
				species.append(load(dir.path_join(f)))
	species.sort_custom(func(a, b): return a.dex_id < b.dex_id)
	var regions: Array[RegionData] = []
	for f in DirAccess.get_files_at(REGIONS_DIR):
		if f.ends_with(".tres"):
			regions.append(load(REGIONS_DIR.path_join(f)))

	var normal := species.filter(func(s): return not (s.is_legendary or s.is_mythical))
	var legends := species.filter(func(s): return s.is_legendary or s.is_mythical)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for f in DirAccess.get_files_at(OUT_DIR):
		if f.ends_with(".tres"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(f)))

	for idx in legends.size():
		var s: PokemonSpecies = legends[idx]
		var main_type: StringName = s.types[0]
		var type_total := normal.filter(func(n): return n.types.has(main_type)).size()
		var strong := s.base_stat_total() >= STRONG_BST
		var ratio := 0.95 if s.is_mythical else (0.9 if strong else 0.7)

		var rule := LegendaryRule.new()
		rule.dex_id = s.dex_id
		rule.chance = CHANCE
		rule.level = 30 if s.is_mythical else (70 if strong else 50)
		var conds: Array[Dictionary] = [
			{"type": "player_level", "value": 25 + 3 * idx},
			{"type": "type_caught_count", "type_id": String(main_type), "value": ceili(type_total * 0.6)},
			{"type": "dex_caught_count", "value": floori(normal.size() * ratio)},
		]
		rule.conditions = conds
		var region_ids: Array[StringName] = []
		for r in regions:
			if r.main_types.has(main_type):
				region_ids.append(r.id)
		rule.region_ids = region_ids
		var path := "%s/%04d.tres" % [OUT_DIR, s.dex_id]
		ResourceSaver.save(rule, path)
		print("%s(%d) Lv%d 지역%s 조건 %s" % [s.name_en, s.dex_id, rule.level, region_ids, conds])
	return 0
