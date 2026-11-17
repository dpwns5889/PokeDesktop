extends GdUnitTestSuite
## 효과음 연결 (기획서 5장).

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_all_sfx_files_load() -> void:
	for id in AudioManager.SOUNDS:
		var p: AudioStreamPlayer = AudioManager._players.get(id)
		assert_object(p).override_failure_message(String(id)).is_not_null()
		assert_float(p.stream.get_length()).override_failure_message(String(id)).is_greater(0.0)


func test_buttons_play_click() -> void:
	var b: Button = auto_free(Button.new())
	add_child(b)
	await get_tree().process_frame
	var played := [false]
	var p: AudioStreamPlayer = AudioManager._players[&"button_click"]
	p.stop()
	b.pressed.emit()
	assert_bool(p.playing).is_true()


func test_items_received_on_buy_transfer_and_expedition() -> void:
	var got: Array = []
	var sources: Array = []
	var cb := func(items: Dictionary, source: StringName) -> void:
		got.append(items)
		sources.append(source)
	EventBus.items_received.connect(cb)
	PlayerState.currency = 1000
	ShopManager.buy(&"great_ball", 1)
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 20, &"gender": &"male", &"region": &"grassland"})
	ProfessorManager.transfer([inst.uid])
	EventBus.items_received.disconnect(cb)
	assert_int(got.size()).is_equal(2)
	assert_dict(got[0]).is_equal({&"great_ball": 1})
	assert_bool(got[1].has(&"exp_candy_m")).is_true()
	assert_array(sources).contains_exactly([&"shop", &"professor"])


func test_shop_buy_plays_buy_sound_not_get_sound() -> void:
	var buy: AudioStreamPlayer = AudioManager._players[&"buy_item"]
	var get_: AudioStreamPlayer = AudioManager._players[&"get_item"]
	buy.stop()
	get_.stop()
	PlayerState.currency = 1000
	ShopManager.buy(&"great_ball", 1)
	assert_bool(buy.playing).is_true()
	assert_bool(get_.playing).is_false()
	buy.stop()
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 20, &"gender": &"male", &"region": &"grassland"})
	ProfessorManager.transfer([inst.uid])
	assert_bool(get_.playing).is_true()
	assert_bool(buy.playing).is_false()


func test_levelup_evolve_unlock_play_sounds() -> void:
	for id in [&"pokemon_levelup", &"pokemon_evolved", &"region_unlocked"]:
		AudioManager._players[id].stop()
	var inst := PlayerState.add_caught({&"dex_id": 1, &"level": 15, &"gender": &"male", &"region": &"grassland"})
	EvolutionManager.queue.clear()
	PlayerState.add_pokemon_exp(inst, 10_000)
	assert_bool(AudioManager._players[&"pokemon_levelup"].playing).is_true()
	EvolutionManager.confirm_current()
	assert_bool(AudioManager._players[&"pokemon_evolved"].playing).is_true()
	EvolutionManager.queue.clear()
	PlayerState.level = 3
	UnlockManager.check_regions()
	assert_bool(AudioManager._players[&"region_unlocked"].playing).is_true()


func test_attack_sound_on_target_hit() -> void:
	var p: AudioStreamPlayer = AudioManager._players[&"attack"]
	p.stop()
	var battle: Control = auto_free(load("res://scenes/battle/battle.tscn").instantiate())
	add_child(battle)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	battle.start(Formulas.capture_params(255, 3, false, 1.0), rng)
	for i in 20:
		battle._game.update(0.05)
	var target: Dictionary = battle._game.targets[0]
	battle._on_click(Vector2(-50, -50))   # 빗나감 → 소리 없음
	assert_bool(p.playing).is_false()
	battle._on_click(target.pos)
	assert_bool(p.playing).is_true()


func test_encounter_uses_sound_file() -> void:
	var p: AudioStreamPlayer = AudioManager._players[&"encounter"]
	assert_bool(p.stream is AudioStreamMP3).is_true()


func test_volume_setting_applies_to_sounds() -> void:
	var before = Settings.get_value(&"sfx_volume")
	Settings.set_value(&"sfx_volume", 0.3, false)   # 파일에 쓰지 않음 (실제 설정 보호)
	AudioManager.play(&"button_click")
	assert_float(AudioManager._players[&"button_click"].volume_db).is_equal_approx(linear_to_db(0.3), 0.01)
	Settings.set_value(&"sfx_volume", before, false)
