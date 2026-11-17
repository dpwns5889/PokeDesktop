extends Node
## 사용자 설정 (user://settings.cfg). 세이브 데이터와 분리한다. (기획서 6.3, 7.5)

const PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
	&"always_on_top": true,
	&"window_scale": 1,           # 1× = 448×200. 0 = 자동 (기획서 2.2)
	&"encounter_sound": true,
	&"sfx_volume": 0.7,
	&"bgm_volume": 0.5,           # M11: BGM(플레이리스트) 크기 (0 = 끔)
	&"entry_strip_open": true,    # v0.47: 메인 화면 왼쪽 아래 엔트리 상자 펼침/접힘
}

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("설정 파일을 읽지 못해 기본값을 사용합니다: %s" % error_string(err))
		_cfg = ConfigFile.new()
	# 이전 버전이 저장하던 창 위치는 더 이상 쓰지 않는다 (항상 좌하단에서 시작)
	if _cfg.has_section_key(SECTION, "window_position"):
		_cfg.erase_section_key(SECTION, "window_position")
		_cfg.save(PATH)


func get_value(key: StringName) -> Variant:
	return _cfg.get_value(SECTION, key, DEFAULTS.get(key))


## save = false 면 메모리에만 바꾼다 (슬라이더를 끄는 동안 등). 나중에 save_settings() 로 저장.
func set_value(key: StringName, value: Variant, save: bool = true) -> void:
	_cfg.set_value(SECTION, key, value)
	if save:
		save_settings()
	EventBus.setting_changed.emit(key, value)


func save_settings() -> void:
	var err := _cfg.save(PATH)
	if err != OK:
		push_error("설정 저장 실패: %s" % error_string(err))
