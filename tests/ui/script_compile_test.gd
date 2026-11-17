extends GdUnitTestSuite
## 모든 스크립트·씬이 컴파일·로드되는지 확인한다.
## 화면(UI) 스크립트는 로직 테스트가 직접 쓰지 않아, 문법 오류가 있어도 다른 테스트가 통과할 수 있다.

const DIRS := ["res://scenes", "res://scripts", "res://tools"]


func test_all_scripts_compile() -> void:
	var broken: Array[String] = []
	for path in _files(".gd"):
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate() and not path.begins_with("res://tools"):
			broken.append(path)
	assert_array(broken).is_empty()


func test_all_scenes_load() -> void:
	var broken: Array[String] = []
	for path in _files(".tscn"):
		var ps := load(path) as PackedScene
		if ps == null or not ps.can_instantiate():
			broken.append(path)
	assert_array(broken).is_empty()


func test_main_scene_and_panels_instantiate() -> void:
	var main: Node = auto_free((load("res://scenes/main/companion.tscn") as PackedScene).instantiate())
	assert_object(main).is_not_null()
	for p in ["dex_panel", "storage_panel", "region_panel", "expedition_panel", "bag_panel", "shop_panel", "confirm_panel", "settings_panel"]:
		var panel: Node = auto_free(load("res://scenes/ui/%s.gd" % p).new())
		assert_object(panel).override_failure_message(p).is_not_null()


func _files(ext: String) -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		_walk(d, ext, out)
	return out


func _walk(dir: String, ext: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(sub), ext, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
