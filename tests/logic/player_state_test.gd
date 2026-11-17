extends GdUnitTestSuite
## PlayerState: 레벨/경험치, 도감, 보관함, 저장 형식. (기획서 4.1, 4.7, 7.5)

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _enc(dex_id: int, level := 5) -> Dictionary:
	return {&"dex_id": dex_id, &"level": level, &"gender": &"male", &"shiny": false, &"region": &"grassland"}


func test_level_up_carries_over_exp() -> void:
	var need := Formulas.player_exp_to_next(1)
	PlayerState.add_exp(need + 3)
	assert_int(PlayerState.level).is_equal(2)
	assert_int(PlayerState.experience).is_equal(3)


func test_multiple_level_ups_at_once() -> void:
	PlayerState.add_exp(Formulas.player_exp_to_next(1) + Formulas.player_exp_to_next(2))
	assert_int(PlayerState.level).is_equal(3)


func test_level_capped_at_40() -> void:
	PlayerState.add_exp(100_000_000)
	assert_int(PlayerState.level).is_equal(40)
	assert_int(PlayerState.experience).is_equal(0)
	PlayerState.add_exp(1000)
	assert_int(PlayerState.level).is_equal(40)


func test_catch_updates_dex_and_gives_exp() -> void:
	PlayerState.level = 30   # 레벨업이 끼지 않도록 필요 경험치가 큰 레벨에서 비교
	PlayerState.add_caught(_enc(16, 4))
	assert_bool(PlayerState.is_caught(16)).is_true()
	assert_int(PlayerState.dex_caught_count()).is_equal(1)
	var first_exp := PlayerState.experience
	assert_int(first_exp).is_equal(Formulas.capture_player_exp(4, true))
	# 같은 종 두 번째는 신규 도감 보너스 없음
	PlayerState.add_caught(_enc(16, 4))
	assert_int(PlayerState.dex[16].caught).is_equal(2)
	assert_int(PlayerState.experience - first_exp).is_equal(Formulas.capture_player_exp(4, false))


func test_seen_without_catch() -> void:
	PlayerState.mark_seen(25)
	assert_int(PlayerState.dex_seen_count()).is_equal(1)
	assert_int(PlayerState.dex_caught_count()).is_equal(0)


func test_storage_full_at_capacity() -> void:
	PlayerState.storage_capacity = 3
	for i in 3:
		PlayerState.add_caught(_enc(16))
	assert_bool(PlayerState.is_storage_full()).is_true()


func test_stats_of_instance() -> void:
	var inst := PlayerState.add_caught(_enc(25, 50))
	inst.traits = []   # 무작위 특성의 능력치 배율을 빼고 비교
	var st := PlayerState.stats_of(inst)
	assert_int(st[&"hp"]).is_equal(95)
	assert_int(st[&"spe"]).is_equal(95)


func test_save_dict_roundtrip() -> void:
	PlayerState.add_caught(_enc(16, 4))
	PlayerState.add_caught(_enc(25, 6))
	PlayerState.mark_seen(19)
	PlayerState.add_item(&"great_ball", 3)
	PlayerState.currency = 1234
	PlayerState.select_ball(&"great_ball")
	var d := PlayerState.to_save_dict()
	# JSON 왕복 (실제 파일과 같은 조건: 숫자 키는 문자열, 숫자는 float)
	var restored = JSON.parse_string(JSON.stringify(d))
	PlayerState.reset()
	PlayerState.load_save_dict(restored)
	assert_int(PlayerState.storage_count()).is_equal(2)
	assert_int(PlayerState.pokemon[1].dex_id).is_equal(25)
	assert_int(typeof(PlayerState.pokemon[1].level)).is_equal(TYPE_INT)
	assert_bool(PlayerState.is_caught(16)).is_true()
	assert_bool(PlayerState.dex[19].seen).is_true()
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(3)
	assert_int(PlayerState.currency).is_equal(1234)
	assert_str(String(PlayerState.selected_ball)).is_equal("great_ball")


func test_load_tolerates_garbage_values() -> void:
	PlayerState.load_save_dict({
		"player": {"level": 999, "exp": -5, "current_region": "nowhere"},
		"storage_capacity": 1,
		"pokemon": [{"uid": "a", "dex_id": 16, "level": 500}, "garbage", {"no_uid": true}],
		"inventory": {"great_ball": -2},
	})
	assert_int(PlayerState.level).is_equal(40)
	assert_int(PlayerState.experience).is_equal(0)
	assert_str(String(PlayerState.current_region)).is_equal("grassland")
	assert_int(PlayerState.storage_capacity).is_equal(100)
	assert_int(PlayerState.storage_count()).is_equal(1)
	assert_int(PlayerState.pokemon[0].level).is_equal(100)
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(0)
