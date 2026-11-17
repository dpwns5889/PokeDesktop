extends Node
## 효과음·배경음 재생. (기획서 5장)
##
## 효과음 (Assets/Audio/SFX, 파일 이름 = 쓰임새)
##   button_click     Button.mp3              모든 UI 버튼을 누를 때, HUD 볼 바꾸기
##   encounter        Encounter.mp3           인카운터 알림 (풀숲이 흔들릴 때)
##   attack           Attack.mp3              전투 중 과녁을 맞혔을 때
##   buy_item         BuyItem.mp3             상점에서 살 때
##   get_item         GetItem.mp3             아이템을 받을 때: 원정 보상, 박사에게 보내기 보상, 픽업
##   region_unlocked  NewRegionUnlocked.mp3   새 지역 해금
##   pokemon_evolved  PokemonEvolved.mp3      진화 완료
##   pokemon_levelup  PokemonLevelup.mp3      포켓몬 레벨업 (경험사탕·원정), 플레이어 레벨업 (M11: 같은 소리)
##   pokemon_catch    PokemonCatch.mp3        포획 성공 (M11)
##   pokemon_run      PokemonRun.mp3          야생 포켓몬이 도망침 (포획 실패, 90초 무반응) (M11)
##   shiny            ShinyPokemon.mp3        색이 다른 포켓몬 등장 (M11)
## 인카운터 파일이 없으면 코드로 합성한 2음 차임을 대신 쓴다.
##
## 소리마다 플레이어가 따로 있어서 서로 다른 소리는 겹쳐 나고, 같은 소리는 처음부터 다시 난다.
## 볼륨은 설정 sfx_volume, 인카운터 소리는 encounter_sound 로 끌 수 있다.
##
## BGM (M11): Assets/Audio/BGM 의 곡을 파일 이름 순서로 이어서 재생하는 플레이리스트. 마지막 곡 다음은 첫 곡(반복).
## 곡이 끝나기 BGM_FADE_SEC 전에 다음 곡이 교차 페이드로 시작한다. 지역과는 관계없다.
## 버스: Master ← SFX(효과음), BGM(배경음). BGM 볼륨은 설정 bgm_volume (0이면 끔).
## 효과음이 나는 동안(버튼 클릭·공격음 제외) BGM 은 일시정지했다가, 효과음이 모두 끝나면 이어서 재생한다 (v0.31).

const MIX_RATE := 22050
const SFX_DIR := "res://Assets/Audio/SFX/"
const SOUNDS := {
	&"button_click": "Button.mp3",
	&"encounter": "Encounter.mp3",
	&"attack": "Attack.mp3",
	&"buy_item": "BuyItem.mp3",
	&"get_item": "GetItem.mp3",
	&"region_unlocked": "NewRegionUnlocked.mp3",
	&"pokemon_evolved": "PokemonEvolved.mp3",
	&"pokemon_levelup": "PokemonLevelup.mp3",
	&"pokemon_catch": "PokemonCatch.mp3",
	&"pokemon_run": "PokemonRun.mp3",
	&"shiny": "ShinyPokemon.mp3",
}

const BGM_DIR := "res://Assets/Audio/BGM/"
const BGM_EXTS := ["ogg", "mp3", "wav"]
const BGM_FADE_SEC := 3.0
## BGM 을 멈추지 않는 효과음
const NO_BGM_PAUSE := [&"button_click", &"attack"]   # 버튼 클릭, 전투 중 과녁 명중음 (v0.32)
const SFX_BUS := &"SFX"
const BGM_BUS := &"BGM"

var _players: Dictionary = {}   # id -> AudioStreamPlayer
## BGM 플레이어 두 개를 번갈아 쓴다 (교차 페이드)
var _bgm: Array[AudioStreamPlayer] = []
var _bgm_index := 0
var _bgm_path := ""
var _bgm_tweens: Array[Tween] = []
## 플레이리스트 (파일 경로, 이름 순)와 지금 곡 번호. -1 = 재생 안 함
var _playlist: Array[String] = []
var _track := -1
var _advancing := false
## 효과음 때문에 BGM 이 일시정지 중인가
var _bgm_paused := false


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(BGM_BUS)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BGM_BUS
		p.volume_linear = 0.0
		add_child(p)
		_bgm.append(p)
	_apply_bgm_volume()
	EventBus.setting_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key == &"bgm_volume":
			_apply_bgm_volume())
	_playlist = find_playlist()
	print("BGM 플레이리스트 %d곡" % _playlist.size())
	start_playlist.call_deferred()

	for id in SOUNDS:
		var path: String = SFX_DIR + SOUNDS[id]
		if ResourceLoader.exists(path):
			_add_player(id, load(path))
		elif id == &"encounter":
			_add_player(id, _make_chime([659.25, 987.77], 0.13))   # 대체음
		else:
			push_warning("효과음 파일이 없습니다: " + path)

	# 이벤트 → 효과음
	EventBus.items_received.connect(func(_items: Dictionary, source: StringName) -> void:
		play(&"buy_item" if source == &"shop" else &"get_item"))
	EventBus.region_unlocked.connect(func(_id: StringName) -> void: play(&"region_unlocked"))
	EventBus.pokemon_evolved.connect(func(_u: String, _f: int, _t: int) -> void: play(&"pokemon_evolved"))
	EventBus.pokemon_leveled_up.connect(func(_u: String, _l: int) -> void: play(&"pokemon_levelup"))
	EventBus.player_leveled_up.connect(func(_l: int) -> void: play(&"pokemon_levelup"))   # M11: 포켓몬과 같은 소리
	EventBus.battle_finished.connect(func(success: bool) -> void:
		if success:
			play(&"pokemon_catch"))
	EventBus.encounter_fled.connect(func(_e: Dictionary) -> void: play(&"pokemon_run"))
	EventBus.encounter_appeared.connect(func(e: Dictionary) -> void:
		if e.get(&"shiny", false):
			play(&"shiny"))
	# 모든 UI 버튼: 이후에 만들어지는 버튼까지 자동으로 연결
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	_update_playlist()


func play(id: StringName) -> void:
	if id == &"encounter" and not Settings.get_value(&"encounter_sound"):
		return
	var p: AudioStreamPlayer = _players.get(id)
	if p == null:
		return
	p.volume_db = linear_to_db(clampf(Settings.get_value(&"sfx_volume"), 0.0, 1.0))
	p.play()
	if not NO_BGM_PAUSE.has(id):
		_set_bgm_paused(true)


## 효과음이 나는 동안 BGM 일시정지 / 모두 끝나면 이어서 (v0.31)
func _set_bgm_paused(on: bool) -> void:
	_bgm_paused = on
	for p in _bgm:
		p.stream_paused = on


func is_bgm_paused() -> bool:
	return _bgm_paused


func _on_sfx_finished() -> void:
	for id in _players:
		if not NO_BGM_PAUSE.has(id) and _players[id].playing:
			return
	_set_bgm_paused(false)


## 효과음이 준비돼 있는가 (테스트·확인용)
func has_sound(id: StringName) -> bool:
	return _players.has(id)


func _add_player(id: StringName, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SFX_BUS
	add_child(p)
	_players[id] = p
	p.finished.connect(_on_sfx_finished)


# ---------------------------------------------------------------- BGM 플레이리스트 (M11)

## BGM 폴더의 곡 경로 목록 (파일 이름 자연 정렬: "2." < "10.").
## 내보낸 exe 에서도 동작하도록 ResourceLoader.list_directory 를 쓴다(원본 파일 대신 .import 만 있는 경우).
func find_playlist() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(BGM_DIR):
		return out
	for name in ResourceLoader.list_directory(BGM_DIR):
		if name.ends_with("/"):
			continue
		if BGM_EXTS.has(name.get_extension().to_lower()):
			out.append(BGM_DIR + name)
	out.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return out


func playlist() -> Array[String]:
	return _playlist


## 지금 곡 번호 (-1 = 재생 안 함)
func current_track() -> int:
	return _track


## 지금 나오는(또는 나오기 시작한) BGM 파일. 없으면 ""
func current_bgm() -> String:
	return _bgm_path


## 플레이리스트 처음부터 (곡이 없으면 아무것도 안 함)
func start_playlist() -> void:
	if _playlist.is_empty():
		return
	_play_track(0)


## 다음 곡으로 (마지막 곡 다음은 첫 곡)
func next_track() -> void:
	if _playlist.is_empty():
		return
	_play_track((_track + 1) % _playlist.size())


func _play_track(i: int) -> void:
	_track = i
	_crossfade_to(_playlist[i])


## 곡이 끝나기 BGM_FADE_SEC 전이면 다음 곡을 교차 페이드로 시작. 이미 멈췄으면(길이를 모르는 곡 등) 바로 다음 곡.
func _update_playlist() -> void:
	if _track < 0 or _playlist.is_empty() or _advancing or _bgm_paused:
		return
	var cur := _bgm[_bgm_index]
	if cur.stream == null:
		return
	var length := cur.stream.get_length()
	var near_end := length > BGM_FADE_SEC * 2.0 and cur.playing and cur.get_playback_position() >= length - BGM_FADE_SEC
	if near_end or not cur.playing:
		_advancing = true
		next_track()
		_advancing = false


## path 의 곡 하나를 직접 튼다(플레이리스트는 멈춤 — 다시 돌리려면 start_playlist). 교차 페이드.
## 같은 곡이 이미 나오면 그대로, "" 이면 줄여서 끈다.
func play_bgm(path: String) -> void:
	_track = -1
	if path == _bgm_path and path != "" and _bgm[_bgm_index].playing:
		return
	_crossfade_to(path)


func _crossfade_to(path: String) -> void:
	_bgm_path = path
	for t in _bgm_tweens:
		if t and t.is_valid():
			t.kill()
	_bgm_tweens.clear()
	var old := _bgm[_bgm_index]
	if old.playing:
		var out := create_tween()
		out.tween_property(old, ^"volume_linear", 0.0, BGM_FADE_SEC)
		out.tween_callback(old.stop)
		_bgm_tweens.append(out)
	if path == "":
		return
	var stream: AudioStream = load(path)
	_no_loop(stream)   # 한 곡이 끝나면 플레이리스트가 다음 곡으로 넘긴다
	_bgm_index = 1 - _bgm_index
	var next := _bgm[_bgm_index]
	next.stop()
	next.stream = stream
	next.volume_linear = 0.0
	next.play()
	next.stream_paused = _bgm_paused   # 효과음 중이면 효과음이 끝난 뒤 시작
	var fade_in := create_tween()
	fade_in.tween_property(next, ^"volume_linear", 1.0, BGM_FADE_SEC)
	_bgm_tweens.append(fade_in)


func _no_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


## BGM 버스 볼륨 = 설정 bgm_volume (0~1, 0이면 무음)
func _apply_bgm_volume() -> void:
	var idx := AudioServer.get_bus_index(BGM_BUS)
	var v := clampf(float(Settings.get_value(&"bgm_volume")), 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))
	AudioServer.set_bus_mute(idx, v <= 0.0)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b: BaseButton = node
		b.pressed.connect(func() -> void: play(&"button_click"))


## 짧은 음을 차례로 이어 붙인 16비트 모노 WAV (인카운터 파일이 없을 때의 대체음).
func _make_chime(freqs: Array, note_sec: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var n := int(MIX_RATE * note_sec)
	data.resize(freqs.size() * n * 2)
	var idx := 0
	for f in freqs:
		for i in n:
			var t := float(i) / MIX_RATE
			var env := exp(-t * 18.0) * minf(1.0, i / 60.0)   # 짧은 어택 + 감쇠
			var v := sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.15
			data.encode_s16(idx, int(clampf(v * env, -1.0, 1.0) * 32767.0))
			idx += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
