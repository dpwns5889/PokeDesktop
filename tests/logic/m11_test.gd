extends GdUnitTestSuite
## M11: 색이 다른 포켓몬(1/512, 고정 특성), BGM 플레이리스트·교차 페이드, 효과음, 종료 확인 (기획서 4.2, 5장, 6.1)

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	before_test_audio_reset()


## 테스트 중에 실제 EncounterManager 타이머가 인카운터 소리를 내면 BGM 이 멈춰(효과음 중 BGM 일시정지) 결과가 흔들린다 → 멈춰 둔다
func before() -> void:
	EncounterManager.set_process(false)


func after() -> void:
	EncounterManager.set_process(true)


func before_test_audio_reset() -> void:
	for id in AudioManager._players:
		AudioManager._players[id].stop()
	AudioManager._set_bgm_paused(false)


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)
	before_test_audio_reset()
	AudioManager.play_bgm("")
	AudioManager.start_playlist()


# ---------------------------------------------------------------- 색이 다른 포켓몬

func test_shiny_rate_is_about_one_in_512() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := 0
	for i in 512000:
		if Formulas.roll_shiny(rng):
			n += 1
	assert_int(n).is_between(880, 1120)   # 기대 1000


func test_encounters_can_be_shiny() -> void:
	var region := GameData.get_region(&"grassland")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var shiny := 0
	for i in 20000:
		var e := EncounterLogic.roll_encounter(region, 5, rng)
		if e[&"shiny"]:
			shiny += 1
	assert_int(shiny).is_between(20, 60)   # 기대 약 39


func test_shiny_catch_gets_fixed_trait_and_keeps_it() -> void:
	var plain := PlayerState.add_caught({&"dex_id": 25, &"level": 5, &"gender": &"male", &"shiny": false, &"region": &"grassland"})
	assert_bool(plain.traits.has("shiny")).is_false()
	var shiny := PlayerState.add_caught({&"dex_id": 25, &"level": 5, &"gender": &"male", &"shiny": true, &"region": &"grassland"})
	assert_bool(shiny.shiny).is_true()
	assert_str(String(shiny.traits[0])).is_equal("shiny")
	# 원정 전투력 ×1.2 (자신)
	var x := GameData.get_expedition(&"grassland_walk")
	var a := ExpeditionLogic.pokemon_power(plain, x)
	plain.traits = []
	shiny.traits = ["shiny"]
	assert_float(ExpeditionLogic.pokemon_power(shiny, x)).is_equal_approx(ExpeditionLogic.pokemon_power(plain, x) * 1.2, 0.01)
	# 저장 후에도 남는다
	var d = JSON.parse_string(JSON.stringify(PlayerState.to_save_dict()))
	PlayerState.load_save_dict(d)
	var back := PlayerState.find_pokemon(shiny.uid)
	assert_bool(back.shiny).is_true()
	assert_bool(back.traits.has("shiny")).is_true()


func test_shiny_battle_sprite_uses_shiny_columns() -> void:
	var s := GameData.get_species(25)
	var normal := PokemonSprites.make_frames(s, false, false)
	var shiny := PokemonSprites.make_frames(s, false, true)
	var r1: Rect2 = (normal.get_frame_texture(&"idle", 0) as AtlasTexture).region
	var r2: Rect2 = (shiny.get_frame_texture(&"idle", 0) as AtlasTexture).region
	assert_float(r2.position.x).is_equal(r1.position.x + PokemonSprites.CELL * 2)


# ---------------------------------------------------------------- BGM

func _make_tone(path: String) -> String:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(8000 * 2 * 10)   # 10초: 교차 페이드(3초) 동안 끝나지 않게
	wav.data = data
	ResourceSaver.save(wav, path)
	return path


func test_buses_and_volume() -> void:
	assert_int(AudioServer.get_bus_index(&"BGM")).is_not_equal(-1)
	assert_int(AudioServer.get_bus_index(&"SFX")).is_not_equal(-1)
	var before = Settings.get_value(&"bgm_volume")
	Settings.set_value(&"bgm_volume", 0.0, false)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"BGM"))).is_true()
	Settings.set_value(&"bgm_volume", 0.5, false)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"BGM"))).is_false()
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"BGM"))).is_equal_approx(linear_to_db(0.5), 0.01)
	Settings.set_value(&"bgm_volume", before, false)


func test_playlist_lists_bgm_folder_in_name_order() -> void:
	var list := AudioManager.find_playlist()
	assert_int(list.size()).is_greater(0)
	for path in list:
		assert_bool(path.begins_with(AudioManager.BGM_DIR)).is_true()
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
	var names := list.map(func(x: String) -> String: return x.get_file())
	var sorted := names.duplicate()
	sorted.sort_custom(func(x: String, y: String) -> bool: return x.naturalnocasecmp_to(y) < 0)
	assert_array(names).is_equal(sorted)


func test_playlist_advances_and_wraps() -> void:
	var n := AudioManager.playlist().size()
	if n == 0:
		return
	AudioManager.start_playlist()
	assert_int(AudioManager.current_track()).is_equal(0)
	assert_str(AudioManager.current_bgm()).is_equal(AudioManager.playlist()[0])
	for i in n - 1:
		AudioManager.next_track()
	assert_int(AudioManager.current_track()).is_equal(n - 1)
	AudioManager.next_track()   # 마지막 다음은 첫 곡 (반복)
	assert_int(AudioManager.current_track()).is_equal(0)
	# 곡은 한 번씩만 재생(반복은 플레이리스트가 맡음)
	var stream: AudioStream = load(AudioManager.playlist()[0])
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		assert_bool(AudioManager._bgm[AudioManager._bgm_index].stream.loop).is_false()


func test_new_sound_effects_loaded() -> void:
	for id in [&"pokemon_catch", &"pokemon_run", &"shiny", &"pokemon_levelup"]:
		assert_bool(AudioManager.has_sound(id)).override_failure_message(String(id)).is_true()


func test_crossfade_between_tracks() -> void:
	var a := _make_tone("user://m11_bgm_a.tres")
	var b := _make_tone("user://m11_bgm_b.tres")
	# 배경에서 돌던 플레이리스트를 바로 멈춘 상태에서 시작
	for t in AudioManager._bgm_tweens:
		t.kill()
	for pl in AudioManager._bgm:
		pl.stop()
	AudioManager._bgm_path = ""
	AudioManager.play_bgm(a)
	assert_str(AudioManager.current_bgm()).is_equal(a)
	var playing := AudioManager._bgm.filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_int(playing.size()).is_equal(1)
	assert_float(playing[0].volume_linear).is_less(0.2)   # 0에서 커지기 시작
	AudioManager.play_bgm(a)   # 같은 곡이면 그대로
	assert_int(AudioManager._bgm.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size()).is_equal(1)
	AudioManager.play_bgm(b)
	# 교차 페이드: 이전 곡과 새 곡이 잠시 함께 재생
	assert_int(AudioManager._bgm.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size()).is_equal(2)
	assert_str(AudioManager.current_bgm()).is_equal(b)
	await get_tree().create_timer(AudioManager.BGM_FADE_SEC + 0.3).timeout
	var after := AudioManager._bgm.filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_int(after.size()).is_equal(1)
	assert_float(after[0].volume_linear).is_equal_approx(1.0, 0.01)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(a))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(b))


# ---------------------------------------------------------------- 종료 확인

func test_close_button_asks_before_quitting() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/main/companion.gd")
	assert_str(src).contains("close.pressed.connect(_ask_quit)")
	assert_str(src).contains("_confirm.ask(\"종료\"")


func test_track_end_moves_to_next_track() -> void:
	var n := AudioManager.playlist().size()
	if n < 2:
		return
	AudioManager.start_playlist()
	var cur: AudioStreamPlayer = AudioManager._bgm[AudioManager._bgm_index]
	cur.seek(cur.stream.get_length() - 1.0)   # 끝나기 1초 전 → 다음 곡이 교차 페이드로 시작
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(AudioManager.current_track()).is_equal(1)
	assert_int(AudioManager._bgm.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size()).is_equal(2)


# ---------------------------------------------------------------- v0.31: 효과음 중 BGM 일시정지

func test_sfx_pauses_bgm_except_button_click() -> void:
	AudioManager._set_bgm_paused(false)
	AudioManager.play(&"button_click")
	assert_bool(AudioManager.is_bgm_paused()).is_false()   # 버튼 클릭은 멈추지 않음
	AudioManager.play(&"get_item")
	assert_bool(AudioManager.is_bgm_paused()).is_true()
	for p in AudioManager._bgm:
		assert_bool(p.stream_paused).is_true()
	# 효과음이 모두 끝나면 이어서
	for id in AudioManager._players:
		AudioManager._players[id].stop()
	AudioManager._on_sfx_finished()
	assert_bool(AudioManager.is_bgm_paused()).is_false()
	for p in AudioManager._bgm:
		assert_bool(p.stream_paused).is_false()


func test_bgm_stays_paused_while_another_sfx_plays() -> void:
	AudioManager.play(&"get_item")
	AudioManager.play(&"pokemon_catch")
	AudioManager._players[&"get_item"].stop()
	AudioManager._on_sfx_finished()   # get_item 은 끝났지만 pokemon_catch 가 아직 → 계속 멈춤
	assert_bool(AudioManager.is_bgm_paused()).is_true()
	AudioManager._players[&"pokemon_catch"].stop()
	AudioManager._on_sfx_finished()
	assert_bool(AudioManager.is_bgm_paused()).is_false()


# ---------------------------------------------------------------- v0.31: 포획 정보 창

func test_caught_panel_shows_until_confirmed() -> void:
	var panel = auto_free(preload("res://scenes/ui/caught_panel.gd").new())
	add_child(panel)
	var inst := PlayerState.add_caught({&"dex_id": 25, &"level": 7, &"gender": &"female", &"shiny": true, &"region": &"grassland"})
	panel.show_pokemon(inst, true)
	assert_bool(panel.visible).is_true()
	assert_bool(panel._header_row.get_node("Close").visible).is_false()   # 닫기 없음, 확인으로만
	assert_str(panel._name.text).contains("피카츄")
	assert_str(panel._name.text).contains("Lv7")
	var tags: Array = panel._status.get_children().filter(func(c): return c is Label).map(func(c): return c.text)
	assert_array(tags).contains(["색이 다른"])
	# "새로 등록!" 은 이름 바로 위 (v0.35)
	assert_bool(panel._new_label.visible).is_true()
	assert_int(panel._new_label.get_index()).is_equal(panel._name.get_index() - 1)
	panel.show_pokemon(inst, false)
	assert_bool(panel._new_label.visible).is_false()
	assert_object(panel._sprite.texture).is_not_null()
	assert_str(panel._stats[&"hp"].text).starts_with("HP ")
	var ok: Button = panel.content.get_child(1).get_child(0)
	assert_str(ok.text).is_equal("확인")
	ok.pressed.emit()
	assert_bool(panel.visible).is_false()
