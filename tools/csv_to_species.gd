extends SceneTree
## data/source/pokemon_gen<N>.csv → data/pokemon/gen<N>/<dex>_<name>.tres (PokemonSpecies). (기획서 7.3)
##
## 실행: <godot> --headless --path . -s res://tools/csv_to_species.gd -- --gen 1
## CSV는 tools/build_species_csv.py 로 만든다. 151종을 손으로 만들지 않는다.

const CSV := "res://data/source/pokemon_gen%d.csv"
const OUT_DIR := "res://data/pokemon/gen%d"
const STAT_KEYS := ["hp", "atk", "def", "spa", "spd", "spe"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--gen")
	var gen := int(args[i + 1]) if i >= 0 and i + 1 < args.size() else 1
	quit(_run(gen))


func _run(gen: int) -> int:
	var f := FileAccess.open(CSV % gen, FileAccess.READ)
	if f == null:
		push_error("CSV를 열지 못했습니다: %s" % (CSV % gen))
		return 1
	var dir := OUT_DIR % gen
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# 이전 결과 정리 (종이 빠진 경우 대비)
	for old in DirAccess.get_files_at(dir):
		if old.ends_with(".tres"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [dir, old]))

	var header := f.get_csv_line()
	var count := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size():
			continue
		var d := {}
		for c in header.size():
			d[header[c]] = row[c]
		var s := _to_species(d)
		var path := "%s/%04d_%s.tres" % [dir, s.dex_id, s.name_en.replace("-", "_")]
		var err := ResourceSaver.save(s, path)
		if err != OK:
			push_error("저장 실패 %s: %s" % [path, error_string(err)])
			return 1
		count += 1
	print("종 리소스 %d개 저장: %s" % [count, dir])
	return 0


func _to_species(d: Dictionary) -> PokemonSpecies:
	var s := PokemonSpecies.new()
	s.dex_id = int(d.dex_id)
	s.generation = int(d.generation)
	s.name_ko = d.name_ko
	s.name_en = d.name_en
	var types: Array[StringName] = [StringName(d.type1)]
	if d.type2 != "":
		types.append(StringName(d.type2))
	s.types = types
	var stats := {}
	for k in STAT_KEYS:
		stats[k] = int(d[k])
	s.base_stats = stats
	s.catch_rate = int(d.catch_rate)
	s.base_exp = int(d.base_exp)
	s.gender_ratio = float(d.gender_ratio)
	s.has_gender_sprites = d.has_gender_sprites == "1"
	s.evo_stage = int(d.evo_stage)
	s.is_legendary = d.is_legendary == "1"
	s.is_mythical = d.is_mythical == "1"
	if s.is_legendary or s.is_mythical:
		s.fixed_trait_ids = [&"legend"] as Array[StringName]
	var evos: Array[Dictionary] = []
	if d.evolutions != "":
		for part in d.evolutions.split(";"):
			var p: PackedStringArray = part.split(":")
			var e := {"to": int(p[0]), "method": StringName(p[1])}
			if p[1] == "level":
				e["value"] = int(p[2])
			else:
				e["item"] = StringName(p[2])
			evos.append(e)
	s.evolutions = evos
	return s
