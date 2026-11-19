extends GdUnitTestSuite
## 도감 완성·색이 다른 도감·세이브 v1→v2·보관함 필터 (기획서 v0.77)

const StoragePanel := preload("res://assets/scenes/ui/storage_panel.gd")

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _register_all_but(skip: int) -> void:
	for s in GameData.all_species():
		if s.dex_id != skip:
			PlayerState.register_caught_species(s.dex_id)


func test_dex_completes_on_last_species_and_raises_shiny_rate() -> void:
	_register_all_but(151)
	assert_bool(PlayerState.is_dex_complete()).is_false()
	assert_float(PlayerState.shiny_multiplier(0)).is_equal(1.0)
	PlayerState.register_caught_species(151)
	assert_bool(PlayerState.is_dex_complete()).is_true()
	assert_bool(PlayerState.dex_complete_noticed).is_false()
	assert_float(PlayerState.shiny_multiplier(0)).is_equal(PlayerState.DEX_COMPLETE_SHINY_MULT)


func test_shiny_catch_counts_in_shiny_dex() -> void:
	PlayerState.register_caught_species(25, true)
	PlayerState.register_caught_species(25, true)
	PlayerState.register_caught_species(1)
	assert_int(PlayerState.dex_shiny_count()).is_equal(1)
	assert_bool(PlayerState.is_shiny_caught(25)).is_true()
	assert_bool(PlayerState.is_shiny_caught(1)).is_false()


func test_completion_survives_save_and_old_complete_save_becomes_complete() -> void:
	_register_all_but(0)
	PlayerState.dex_complete_noticed = true
	var d := PlayerState.to_save_dict()
	PlayerState.load_save_dict(d)
	assert_bool(PlayerState.is_dex_complete()).is_true()
	assert_bool(PlayerState.dex_complete_noticed).is_true()
	# 완성 필드가 없는 예전 세이브: 151종을 잡았으면 불러올 때 완성 (알림은 아직)
	d.erase("dex_completed_at")
	d.erase("dex_complete_noticed")
	PlayerState.load_save_dict(d)
	assert_bool(PlayerState.is_dex_complete()).is_true()
	assert_bool(PlayerState.dex_complete_noticed).is_false()


func test_migrate_v1_moves_locked_and_fills_shiny_dex() -> void:
	var v1 := {
		"save_version": 1,
		"player": {},
		"dex": {"25": {"seen": true, "caught": 2}},
		"pokemon": [
			{"uid": "a", "dex_id": 25, "shiny": true, "locked": true},
			{"uid": "b", "dex_id": 25, "shiny": false},
		],
	}
	var d := SaveManager.migrate(v1)
	assert_int(int(d.save_version)).is_equal(SaveManager.SAVE_VERSION)
	assert_bool(d.pokemon[0].favorite).is_true()
	assert_bool(d.pokemon[0].has("locked")).is_false()
	assert_bool(d.pokemon[1].favorite).is_false()
	assert_int(int(d.dex["25"].shiny)).is_equal(1)


func test_storage_filter_status_and_types() -> void:
	var fire_shiny := {"uid": "x", "dex_id": 4, "shiny": true, "favorite": false, "traits": ["t"]}   # 파이리
	var water := {"uid": "y", "dex_id": 7, "shiny": false, "favorite": true, "traits": []}   # 꼬부기
	var none: Array[String] = []
	var no_types: Array[StringName] = []
	var shiny_traits: Array[String] = ["shiny", "traits"]
	var fire_or_water: Array[StringName] = [&"fire", &"water"]
	var grass: Array[StringName] = [&"grass"]
	assert_bool(StoragePanel.matches_filter(fire_shiny, none, no_types)).is_true()
	assert_bool(StoragePanel.matches_filter(fire_shiny, shiny_traits, no_types)).is_true()   # 상태끼리 그리고
	assert_bool(StoragePanel.matches_filter(water, shiny_traits, no_types)).is_false()
	assert_bool(StoragePanel.matches_filter(water, none, fire_or_water)).is_true()   # 타입끼리 또는
	assert_bool(StoragePanel.matches_filter(fire_shiny, shiny_traits, grass)).is_false()   # 상태 그리고 타입


## v0.90: 도감 완성 팝업 문구는 분수 표시 없이, "더 자주 나타난다"만 노란색(BBCode)
func test_popup_text_has_no_fraction_and_yellow_highlight() -> void:
	var text: String = preload("res://assets/scenes/main/companion.gd").DEX_COMPLETE_TEXT
	assert_bool(text.contains("1/512") or text.contains("1/128")).is_false()
	assert_str(text).contains("[color=#ffd959]더 자주 나타난다[/color]")
