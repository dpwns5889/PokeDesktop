extends SceneTree
## tools/source/regions_gen<N>.json → assets/data/regions/<id>.tres (RegionData). (기획서 4.4)
## 실행: <godot> --headless --path . -s res://tools/json_to_regions.gd -- --gen 1

const SRC := "res://tools/source/regions_gen%d.json"
const OUT_DIR := "res://assets/data/regions"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--gen")
	var gen := int(args[i + 1]) if i >= 0 and i + 1 < args.size() else 1
	quit(_run(gen))


func _run(gen: int) -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SRC % gen))
	if not data is Dictionary:
		push_error("JSON을 읽지 못했습니다: %s" % (SRC % gen))
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var n := 0
	for r in data.regions:
		var region := RegionData.new()
		region.id = StringName(r.id)
		region.name_ko = r.name_ko
		region.order = int(r.order)
		var types: Array[StringName] = []
		for t in r.main_types:
			types.append(StringName(t))
		region.main_types = types
		region.level_cap = int(r.level_cap)
		region.level_scale = float(r.get("level_scale", 0.2))
		var iv: Array = r.get("interval", [])
		if iv.size() == 2:
			region.encounter_interval = Vector2(float(iv[0]), float(iv[1]))
		region.battle_ground = int(r.get("battle_ground", 0))
		region.capture_fill = float(r.get("capture_fill", 1.0))
		region.item_tier = int(r.get("item_tier", 1))
		region.sky_color = Color(r.sky)
		region.ground_color = Color(r.ground)
		var conds: Array[Dictionary] = []
		for c in r.unlock:
			var cc := {}
			for k in c:
				cc[k] = int(c[k]) if c[k] is float else c[k]
			conds.append(cc)
		region.unlock_conditions = conds
		var entries: Array[EncounterEntry] = []
		for e in r.encounters:
			var en := EncounterEntry.new()
			en.dex_id = int(e[0])
			en.weight = int(e[1])
			en.min_level = int(e[2])
			en.max_level = int(e[3])
			en.min_player_level = int(e[4]) if e.size() > 4 else 1
			en.difficulty_bonus = float(e[5]) if e.size() > 5 else 0.0   # 추가 난이도 (v0.76)
			entries.append(en)
		region.encounters = entries
		var path := "%s/%s.tres" % [OUT_DIR, r.id]
		var err := ResourceSaver.save(region, path)
		if err != OK:
			push_error("저장 실패 %s: %s" % [path, error_string(err)])
			return 1
		n += 1
	print("지역 %d개 저장: %s" % [n, OUT_DIR])
	return 0
