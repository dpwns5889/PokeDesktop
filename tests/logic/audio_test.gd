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


func test_capture_sounds_loaded_and_pitch() -> void:
	for id in [&"ball_throw", &"ball_wobble", &"ball_catch"]:
		assert_bool(AudioManager.has_sound(id)).override_failure_message("효과음 없음: %s" % id).is_true()
		assert_bool(AudioManager.NO_BGM_PAUSE.has(id)).is_true()   # 연출 중 BGM 이 끊기지 않게
	AudioManager.play(&"ball_wobble", 0.93)
	assert_float(AudioManager._players[&"ball_wobble"].pitch_scale).is_equal_approx(0.93, 0.0001)
	AudioManager.play(&"ball_wobble")
	assert_float(AudioManager._players[&"ball_wobble"].pitch_scale).is_equal(1.0)
	AudioManager._players[&"ball_wobble"].stop()


## v0.62: 새 효과음 파일 연결 — 이름에 맞는 파일, 떨어짐 소리는 BGM 을 멈추지 않음
func test_v062_sound_files() -> void:
	assert_str(AudioManager.SOUNDS[&"buy_item"]).is_equal("ItemBuy.ogg")
	assert_str(AudioManager.SOUNDS[&"use_item"]).is_equal("Use item.ogg")
	assert_str(AudioManager.SOUNDS[&"pokemon_run"]).is_equal("Battle flee.ogg")
	assert_str(AudioManager.SOUNDS[&"ball_throw"]).is_equal("Pokeballthrow.ogg")
	assert_str(AudioManager.SOUNDS[&"ball_drop"]).is_equal("Pokeball drop.ogg")
	assert_str(AudioManager.SOUNDS[&"ball_wobble"]).is_equal("PokemonBallShake.mp3")
	assert_str(AudioManager.SOUNDS[&"ball_open"]).is_equal("PokemonBallOpen.mp3")
	assert_bool(AudioManager.NO_BGM_PAUSE.has(&"ball_open")).is_true()
	assert_str(AudioManager.SOUNDS[&"ball_catch"]).is_equal("Pokeballcatch click.ogg")
	assert_bool(AudioManager.NO_BGM_PAUSE.has(&"ball_drop")).is_true()


## v0.62: 아이템을 쓰면 use_item 소리 (향로·특이한 향로·행복의 알·경험사탕)
func test_using_items_plays_use_item() -> void:
	var p: AudioStreamPlayer = AudioManager._players[&"use_item"]
	var now := 2_000_000_000
	for id in [&"incense", &"shiny_incense", &"lucky_egg"]:
		PlayerState.add_item(id, 1)
	PlayerState.add_item(&"exp_candy_s", 1)
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	var uses := [
		func() -> void: PlayerState.use_incense(&"fire", now),
		func() -> void: PlayerState.use_shiny_incense(now),
		func() -> void: PlayerState.use_lucky_egg(now),
		func() -> void: ProfessorManager.use_candy(inst.uid, &"exp_candy_s"),
	]
	for use in uses:
		p.stop()
		use.call()
		assert_bool(p.playing).is_true()
	p.stop()
	# 실패(아이템 없음)면 소리 없음
	PlayerState.use_lucky_egg(now)
	assert_bool(p.playing).is_false()


## v0.62: 경험사탕으로 레벨업하면 레벨업 소리 없이 아이템 사용 소리만
func test_candy_levelup_plays_only_use_item() -> void:
	var lv: AudioStreamPlayer = AudioManager._players[&"pokemon_levelup"]
	var use: AudioStreamPlayer = AudioManager._players[&"use_item"]
	lv.stop()
	use.stop()
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	PlayerState.add_item(&"exp_candy_m", 1)
	var r := ProfessorManager.use_candy(inst.uid, &"exp_candy_m")
	assert_int(r.levels).is_greater(0)
	assert_bool(lv.playing).is_false()
	assert_bool(use.playing).is_true()
	use.stop()
	# 원정 등 아이템이 아닌 레벨업은 그대로 레벨업 소리
	PlayerState.add_pokemon_exp(inst, 10_000)
	assert_bool(lv.playing).is_true()
	lv.stop()
