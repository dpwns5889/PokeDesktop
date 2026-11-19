extends SceneTree
## tools/source/items.json → assets/data/items/<id>.tres (ItemData). (기획서 4.11)
## 실행: <godot> --headless --path . -s res://tools/json_to_items.gd

const SRC := "res://tools/source/items.json"
const OUT_DIR := "res://assets/data/items"


func _init() -> void:
	quit(_run())


func _run() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SRC))
	if not data is Dictionary:
		push_error("JSON을 읽지 못했습니다: %s" % SRC)
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for f in DirAccess.get_files_at(OUT_DIR):
		if f.ends_with(".tres"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(f)))
	for it in data.items:
		var item := ItemData.new()
		item.id = StringName(it.id)
		item.name_ko = it.name_ko
		item.category = StringName(it.category)
		item.order = int(it.order)
		item.description = it.description
		var params := {}
		for k in it.params:
			params[StringName(k)] = it.params[k]
		item.params = params
		var sources: Array[StringName] = []
		for s in it.sources:
			sources.append(StringName(s))
		item.sources = sources
		item.buy_price = int(it.buy_price)
		item.sell_price = int(it.sell_price)
		item.infinite = bool(it.get("infinite", false))
		item.unlock_level = int(it.get("unlock_level", 0))
		var path := "%s/%s.tres" % [OUT_DIR, it.id]
		if ResourceSaver.save(item, path) != OK:
			push_error("저장 실패: " + path)
			return 1
	print("아이템 %d개 저장: %s" % [data.items.size(), OUT_DIR])
	return 0
