extends GdUnitTestSuite
## SaveManager: 저장·불러오기·손상 복구. 실제 세이브와 분리된 임시 폴더를 쓴다. (기획서 7.5)

var _dir: String
var _snapshot: Dictionary
var _saved_dir: String


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	_saved_dir = SaveManager.save_dir
	_dir = "user://test_saves_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_dir)
	SaveManager.save_dir = _dir
	PlayerState.reset()


func after_test() -> void:
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)
	SaveManager.save_dir = _saved_dir
	PlayerState.load_save_dict(_snapshot)


func _catch(dex_id: int) -> void:
	PlayerState.add_caught({&"dex_id": dex_id, &"level": 5, &"gender": &"male", &"shiny": false, &"region": &"grassland"})


func _files() -> PackedStringArray:
	return DirAccess.get_files_at(_dir)


func test_save_then_load_restores_state() -> void:
	_catch(16)
	_catch(25)
	PlayerState.add_exp(10)
	assert_bool(SaveManager.save_game()).is_true()
	var level := PlayerState.level
	var exp := PlayerState.experience
	PlayerState.reset()
	assert_str(String(SaveManager.load_game())).is_equal("loaded")
	assert_int(PlayerState.storage_count()).is_equal(2)
	assert_int(PlayerState.level).is_equal(level)
	assert_int(PlayerState.experience).is_equal(exp)


func test_second_save_keeps_previous_as_backup() -> void:
	_catch(16)
	SaveManager.save_game()
	_catch(19)
	SaveManager.save_game()
	assert_array(_files()).contains([SaveManager.SAVE_FILE, SaveManager.SAVE_FILE + ".bak"])
	assert_array(_files()).not_contains([SaveManager.SAVE_FILE + ".tmp"])
	var bak = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path() + ".bak"))
	assert_int(bak.pokemon.size()).is_equal(1)


func test_corrupt_save_recovers_from_backup() -> void:
	_catch(16)
	SaveManager.save_game()
	_catch(19)
	SaveManager.save_game()      # .bak = 1마리, save.json = 2마리
	var f := FileAccess.open(SaveManager.save_path(), FileAccess.WRITE)
	f.store_string("{ 깨진 세이브")
	f.close()
	PlayerState.reset()
	assert_str(String(SaveManager.load_game())).is_equal("loaded_backup")
	assert_int(PlayerState.storage_count()).is_equal(1)
	# 손상 파일은 지우지 않고 보관
	var corrupt := Array(_files()).filter(func(n: String) -> bool: return n.contains(".corrupt-"))
	assert_int(corrupt.size()).is_equal(1)
	# 복구한 내용으로 save.json 을 다시 썼다
	assert_bool(FileAccess.file_exists(SaveManager.save_path())).is_true()


func test_both_corrupt_starts_new_game() -> void:
	for name in [SaveManager.SAVE_FILE, SaveManager.SAVE_FILE + ".bak"]:
		var f := FileAccess.open(_dir.path_join(name), FileAccess.WRITE)
		f.store_string("not json")
		f.close()
	_catch(16)
	assert_str(String(SaveManager.load_game())).is_equal("recovered_new")
	assert_int(PlayerState.storage_count()).is_equal(0)
	var corrupt := Array(_files()).filter(func(n: String) -> bool: return n.contains(".corrupt-"))
	assert_int(corrupt.size()).is_equal(2)


func test_no_save_is_new_game() -> void:
	assert_str(String(SaveManager.load_game())).is_equal("new")
	assert_int(PlayerState.level).is_equal(1)


func test_save_file_has_version() -> void:
	SaveManager.save_game()
	var d = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path()))
	assert_int(int(d.save_version)).is_equal(SaveManager.SAVE_VERSION)


func test_reset_save_deletes_files_and_state() -> void:
	_catch(16)
	SaveManager.save_game()
	_catch(19)
	SaveManager.save_game()
	var f := FileAccess.open(_dir.path_join(SaveManager.SAVE_FILE + ".corrupt-1"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var reset_emitted := [false]
	var on_reset := func() -> void: reset_emitted[0] = true
	EventBus.game_reset.connect(on_reset)
	SaveManager.reset_save()
	EventBus.game_reset.disconnect(on_reset)
	assert_array(Array(_files())).is_empty()
	assert_int(PlayerState.storage_count()).is_equal(0)
	assert_int(PlayerState.level).is_equal(1)
	assert_dict(PlayerState.dex).is_empty()
	assert_bool(reset_emitted[0]).is_true()
	# 초기화 뒤 불러오면 새 게임
	assert_str(String(SaveManager.load_game())).is_equal("new")
