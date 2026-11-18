extends GdUnitTestSuite
## 프로젝트 이름 변경(PokeProject → PokeCompanion, v0.71)으로 바뀐 사용자 폴더: 옛 폴더의 세이브·설정을 복사 (기획서 7.5)

var _root: String


func before_test() -> void:
	_root = OS.get_user_data_dir().path_join("migration_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root.path_join("old"))


func after_test() -> void:
	for d in ["old", "new"]:
		var dir := _root.path_join(d)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(_root)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_copies_old_save_and_settings_once() -> void:
	_write(_root.path_join("old/save.json"), "{\"a\": 1}")
	_write(_root.path_join("old/settings.cfg"), "[x]")
	var new_dir := _root.path_join("new")
	assert_int(Settings.migrate_old_user_dir(_root.path_join("old"), new_dir)).is_equal(2)
	assert_str(FileAccess.get_file_as_string(new_dir.path_join("save.json"))).is_equal("{\"a\": 1}")
	# 새 폴더에 이미 세이브가 있으면 덮어쓰지 않는다
	_write(_root.path_join("old/save.json"), "{\"a\": 2}")
	assert_int(Settings.migrate_old_user_dir(_root.path_join("old"), new_dir)).is_equal(0)
	assert_str(FileAccess.get_file_as_string(new_dir.path_join("save.json"))).is_equal("{\"a\": 1}")


func test_no_old_dir_does_nothing() -> void:
	assert_int(Settings.migrate_old_user_dir(_root.path_join("missing"), _root.path_join("new"))).is_equal(0)
