extends SceneTree
## tools/source/traits.json → assets/data/traits/*.tres (TraitData) + _roll_config.tres (TraitRollConfig)
## tools/source/expeditions_gen1.json → assets/data/expeditions/*.tres (ExpeditionData)  (기획서 4.6, 4.10)
## 실행: <godot> --headless --path . -s res://tools/json_to_traits_expeditions.gd


func _init() -> void:
	quit(_traits() + _expeditions())


func _traits() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tools/source/traits.json"))
	if not data is Dictionary:
		push_error("traits.json 을 읽지 못했습니다")
		return 1
	var dir := "res://assets/data/traits"
	_clean(dir)
	for t in data.traits:
		var tr := TraitData.new()
		tr.id = StringName(t.id)
		tr.name_ko = t.name_ko
		tr.description = t.description
		tr.tier = StringName(t.tier)
		tr.weight = int(t.weight)
		tr.trigger = StringName(t.get("trigger", "expedition"))
		var effects: Array[Dictionary] = []
		for e in t.effects:
			effects.append(e)
		tr.effects = effects
		var ex: Array[StringName] = []
		for x in t.get("exclusive_with", []):
			ex.append(StringName(x))
		tr.exclusive_with = ex
		ResourceSaver.save(tr, "%s/%s.tres" % [dir, t.id])
	var cfg := TraitRollConfig.new()
	var cw: Array[int] = []
	for w in data.roll.count_weights:
		cw.append(int(w))
	cfg.count_weights = cw
	var tw := {}
	for k in data.roll.tier_weights:
		tw[StringName(k)] = int(data.roll.tier_weights[k])
	cfg.tier_weights = tw
	ResourceSaver.save(cfg, "%s/_roll_config.tres" % dir)
	print("특성 %d개 + 생성 규칙 저장" % data.traits.size())
	return 0


func _expeditions() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tools/source/expeditions_gen1.json"))
	if not data is Dictionary:
		push_error("expeditions_gen1.json 을 읽지 못했습니다")
		return 1
	var dir := "res://assets/data/expeditions"
	_clean(dir)
	for x in data.expeditions:
		var ex := ExpeditionData.new()
		ex.id = StringName(x.id)
		ex.name_ko = x.name_ko
		ex.order = int(x.order)
		ex.duration_sec = int(x.duration_min) * 60
		ex.required_power = int(x.required_power)
		var rt: Array[StringName] = []
		for t in x.recommended_types:
			rt.append(StringName(t))
		ex.recommended_types = rt
		var wt: Array[StringName] = []
		for t in x.weak_types:
			wt.append(StringName(t))
		ex.weak_types = wt
		ex.currency_reward = Vector2i(int(x.currency[0]), int(x.currency[1]))
		ex.reward_rolls = int(x.rolls)
		ex.exp_reward = int(x.exp)
		ex.player_exp_reward = int(x.player_exp)
		var table: Array[Dictionary] = []
		for r in x.rewards:
			table.append({"item": StringName(r[0]), "min": int(r[1]), "max": int(r[2]), "weight": int(r[3])})
		ex.reward_table = table
		var conds: Array[Dictionary] = []
		for c in x.unlock:
			conds.append(c)
		ex.unlock_conditions = conds
		ResourceSaver.save(ex, "%s/%s.tres" % [dir, x.id])
	print("원정지 %d개 저장" % data.expeditions.size())
	return 0


func _clean(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
