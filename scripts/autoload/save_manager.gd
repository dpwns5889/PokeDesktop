extends Node
## 세이브 로드/저장/마이그레이션/자동 저장. (기획서 7.5)
##
## - 쓰기: save.json.tmp 에 쓰고 성공하면, 기존 save.json 을 save.json.bak 으로 옮긴 뒤 tmp 를 save.json 으로 바꾼다.
## - 읽기: save.json → 실패하면 save.json.bak → 둘 다 실패하면 새 게임. 손상된 파일은 save.json.corrupt-<시각> 으로 보관.
## - 자동 저장: 상태가 바뀌면 다음 프레임에 저장(여러 변경을 한 번에), 그리고 60초마다, 종료 직전.
## - 헤드리스(테스트) 실행에서는 자동으로 읽거나 쓰지 않는다 → 테스트가 실제 세이브를 건드리지 않는다.

const SAVE_VERSION := 2
const SAVE_FILE := "save.json"
const AUTOSAVE_INTERVAL_SEC := 60.0

## 세이브 폴더. 테스트에서 바꿔 쓴다.
var save_dir := "user://"
## 마지막 로드 결과: &"loaded" / &"loaded_backup" / &"new" / &"recovered_new"
var last_load_result: StringName = &""

var _enabled := true
var _dirty := false


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	load_game()
	PlayerState.changed.connect(request_save)
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_INTERVAL_SEC
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _enabled:
		save_game()


func save_path() -> String:
	return save_dir.path_join(SAVE_FILE)


## 다음 프레임에 저장 (같은 프레임의 여러 변경을 한 번에).
func request_save() -> void:
	if not _enabled or _dirty:
		return
	_dirty = true
	save_game.call_deferred()


func save_game() -> bool:
	_dirty = false
	var data := PlayerState.to_save_dict()
	data["save_version"] = SAVE_VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	return write_save(JSON.stringify(data, "\t"))


## 문자열을 안전하게 세이브 파일로 쓴다 (tmp → 교체, 이전 파일은 .bak).
func write_save(text: String) -> bool:
	var path := save_path()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("세이브 쓰기 실패: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("세이브 교체 실패: %s" % error_string(err))
		return false
	return true


## 세이브를 읽어 PlayerState 에 적용한다.
func load_game() -> StringName:
	var path := save_path()
	var main := _read_save(path)
	if not main.is_empty():
		PlayerState.load_save_dict(main)
		last_load_result = &"loaded"
		return last_load_result

	var had_main := FileAccess.file_exists(path)
	if had_main:
		_quarantine(path)
	var backup := _read_save(path + ".bak")
	if not backup.is_empty():
		PlayerState.load_save_dict(backup)
		last_load_result = &"loaded_backup"
		push_warning("세이브가 손상되어 백업에서 복구했습니다.")
		write_save(JSON.stringify(_with_version(PlayerState.to_save_dict()), "\t"))
		return last_load_result

	if FileAccess.file_exists(path + ".bak"):
		_quarantine(path + ".bak")
	PlayerState.reset()
	last_load_result = &"recovered_new" if had_main else &"new"
	if had_main:
		push_warning("세이브와 백업이 모두 손상되어 새 게임을 시작합니다. 손상 파일은 보관했습니다.")
	return last_load_result


## 읽고 검증·마이그레이션까지. 실패하면 빈 Dictionary.
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var d: Dictionary = parsed
	if not d.has("save_version") or not d.has("player"):
		return {}
	return migrate(d)


## 버전별 마이그레이션. 세이브 형식이 바뀌면 SAVE_VERSION 을 올리고 _migrate_vN_to_vN+1 을 추가한다 (기획서 7.5 표에도 한 줄).
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("save_version", 0))
	if v > SAVE_VERSION:
		push_warning("더 새로운 버전의 세이브(%d)입니다. 알 수 없는 항목은 무시됩니다." % v)
	if v <= 1:
		d = _migrate_v1_to_v2(d)
	d["save_version"] = SAVE_VERSION
	return d


## v1 → v2 (v0.77): 잠금 → 즐겨찾기(v0.71 변경), 도감에 색이 다른 포획 수(지금 보관함의 색이 다른 개체로 채움)
static func _migrate_v1_to_v2(d: Dictionary) -> Dictionary:
	var dex: Dictionary = d.get("dex", {}) if d.get("dex") is Dictionary else {}
	for p in d.get("pokemon", []):
		if not p is Dictionary:
			continue
		p["favorite"] = bool(p.get("favorite", false)) or bool(p.get("locked", false))
		p.erase("locked")
		if bool(p.get("shiny", false)) and p.has("dex_id"):
			var key := str(int(p.dex_id))
			if dex.get(key) is Dictionary:
				dex[key]["shiny"] = int(dex[key].get("shiny", 0)) + 1
	return d


func _with_version(d: Dictionary) -> Dictionary:
	d["save_version"] = SAVE_VERSION
	d["saved_at"] = int(Time.get_unix_time_from_system())
	return d


## 저장된 진행을 모두 지우고 새 게임 상태로 만든다 (개발용).
## save.json, .bak, .tmp, 손상 보관 파일을 지운다. 설정(settings.cfg: 창 위치·배율 등)은 유지한다.
func reset_save() -> void:
	for f in DirAccess.get_files_at(save_dir):
		if f.begins_with(SAVE_FILE):
			DirAccess.remove_absolute(save_dir.path_join(f))
	PlayerState.reset()
	last_load_result = &"new"
	EncounterManager.reset_to_waiting()
	EventBus.game_reset.emit()


func _quarantine(path: String) -> void:
	var dest := "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(path, dest)
