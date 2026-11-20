extends Node
## 개발용 화면 캡처 (기획서 4.2, 6.2): 메인 화면을 띄워 상태를 만든 뒤 게임 화면(뷰포트)을 PNG 로 저장한다.
## 실제 모니터에서 창이 잘려도 상관없다(화면을 찍는 게 아니라 뷰포트를 저장).
##
## 실행: <godot> --path . res://tools/capture_popups.tscn -- item caught3
##   item     아이템 인카운터 (슈퍼볼 ×2 발견)
##   caught3  특성이 3개인 포켓몬의 포획 정보 창 (caught3_scrolled = 스크롤을 끝까지 내린 모습도 저장)
##   caught3long  이름이 가장 긴 특성 3개로 (상자 끝이 잘리는 모습)
##   expedition  원정 패널에서 설산 등반·초원 산책을 고른 모습 (원정지 이름 색)
##   wipe     설정 맨 위(settings_top)와 맨 아래 "저장된 데이터 삭제" 버튼과 확인 창
##   legend   전설 울음소리 알림 팝업 (v0.97): 프리져 조건을 채운 상태 → 설산 / 뮤츠·뮤 → 유령탑
##   stone    보관함에서 이브이에게 진화의 돌 사용 (보관함 → 진화 창 → 진화 뒤)
##   caughtbig  타입 2개·그림이 가장 큰 종·색이 다른·Lv100·가장 긴 특성 3개 (가장 넓은 경우)
## 결과: tools/previews/capture_<이름>.png (기준 해상도 그대로, 저작권 스프라이트가 들어 있어 git 제외)
## 주의: 사용자 세이브를 읽고 자동 저장할 수 있으니, 실행 전후로 세이브를 백업·복원한다 (CLAUDE.md).

const OUT := "res://tools/previews/capture_%s.png"

var _main: Node


func _ready() -> void:
	EncounterManager.set_process(false)   # 실제 타이머가 끼어들지 않게
	_main = (load("res://assets/scenes/main/companion.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await _frames(20)
	var wants := OS.get_cmdline_user_args()
	for w in wants:
		match w:
			"item":
				await _capture_item()
			"caught3":
				await _capture_caught3(false)
			"caught3long":
				await _capture_caught3(true)
			"caughtbig":
				await _capture_caught3(true, _biggest_dual_type())
			"stone":
				await _capture_stone()
			"wipe":
				await _capture_wipe()
			"legend":
				await _capture_legend()
			"expedition":
				await _capture_expedition(&"snow_climb", "expedition_snow")
				await _capture_expedition(&"grassland_walk", "expedition_grass")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	await _frames(6)
	var img := get_tree().root.get_texture().get_image()
	var path := OUT % name
	img.save_png(ProjectSettings.globalize_path(path))
	print("저장: %s (%dx%d)" % [path, img.get_width(), img.get_height()])


## 아이템 인카운터: 흔들림 뒤 아이템을 얻고 그림·제목·알림이 보이는 순간
func _capture_item() -> void:
	EncounterManager.state = EncounterManager.State.WAITING
	EncounterManager.current = {&"item": &"great_ball", &"count": 2}
	EncounterManager.state = EncounterManager.State.PREVIEW
	EventBus.encounter_started.emit(EncounterManager.current)
	await _frames(10)
	EncounterManager._found_item(Time.get_unix_time_from_system())
	await get_tree().create_timer(0.8).timeout
	await _save("item")
	EncounterManager.reset_to_waiting()
	await _frames(10)


## 원정 패널에서 원정지 하나를 고른 모습 (설명 맨 위 원정지 이름 색, v0.94)
func _capture_expedition(id: StringName, tag: String) -> void:
	_main._toggle_panel(&"expedition")
	await _frames(6)
	var panel = _main._panels[&"expedition"]
	for i in panel._rows.size():
		if panel._rows[i].get("id", &"") == id:
			panel._list.select(i)
			panel._show_list_detail()
	await _save(tag)
	_main._toggle_panel(&"expedition")
	await _frames(4)


## 타입이 2개인 종 중 색이 다른 전투 모습이 가장 큰(투명 여백을 뺀 넓이) 종
func _biggest_dual_type() -> int:
	var best := 0
	var best_area := -1
	for s in GameData.all_species():
		if s.types.size() < 2:
			continue
		var at := PokemonSprites.make_frames(s, false, true).get_frame_texture(&"idle", 0) as AtlasTexture
		if at == null:
			continue
		var img := at.atlas.get_image()
		if img.is_compressed():
			img.decompress()
		var r := img.get_region(Rect2i(at.region)).get_used_rect()
		if r.size.x * r.size.y > best_area:
			best_area = r.size.x * r.size.y
			best = s.dex_id
	print("가장 큰 2타입 종: %d (%s, 넓이 %d)" % [best, GameData.get_species(best).name_ko, best_area])
	return best


## 특성이 3개인 포켓몬의 포획 정보 창
func _capture_caught3(longest: bool, big_dex: int = 0) -> void:
	var picks: Array[StringName] = []
	var pool: Array[TraitData] = GameData.all_traits().filter(func(t: TraitData) -> bool: return t.tier == &"normal" or t.tier == &"rare")
	if longest:
		pool.sort_custom(func(a: TraitData, b: TraitData) -> bool: return a.name_ko.length() > b.name_ko.length())
	for t in pool:
		if picks.size() < 3:
			picks.append(t.id)
	var dex := big_dex if big_dex > 0 else 25
	var inst := PlayerState.add_caught({&"dex_id": dex, &"level": 100 if big_dex > 0 else 12, &"gender": &"male", &"shiny": big_dex > 0, &"region": &"grassland"})
	inst["traits"] = picks
	_main._caught.show_pokemon(inst, true)
	await _frames(10)
	var tag := "caughtbig" if big_dex > 0 else ("caught3long" if longest else "caught3")
	await _save(tag)
	_main._caught._scroll.scroll_vertical = 9999   # 끝까지 내리면 특성이 보인다
	await _frames(6)
	await _save(tag + "_scrolled")
	_main._caught.close_panel()


## 보관함에서 이브이를 고르고 불의 돌로 진화시키는 과정
func _capture_stone() -> void:
	var p := PlayerState.add_caught({&"dex_id": 133, &"level": 20, &"gender": &"male", &"region": &"grassland"})
	for id in [&"water_stone", &"fire_stone", &"thunder_stone"]:
		PlayerState.add_item(id, 1)
	_main._caught.close_panel()   # add_caught 가 띄운 포획 정보 창
	await _frames(4)
	_main._toggle_panel(&"storage")
	await _frames(6)
	var panel = _main._panels[&"storage"]
	var idx: int = panel._uids.find(p.uid)
	panel._list.select(idx)
	panel._on_selected(idx)
	await _save("stone_storage")
	panel._info_scroll.scroll_vertical = 9999
	await _frames(6)
	await _save("stone_storage_scrolled")
	panel._info_scroll.scroll_vertical = 0
	for b: Button in panel._evo_box.get_children():
		if b.text == GameData.get_item(&"fire_stone").name_ko:
			b.pressed.emit()
	await _frames(10)
	await _save("stone_overlay")
	var o: Node
	for c in _main.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("evolution_overlay.gd"):
			o = c
	if o:
		o._on_skip()
		await _frames(6)
		await _save("stone_done")


## 설정 맨 아래 삭제 버튼과 눌렀을 때 확인 창 (확인은 누르지 않는다)
func _capture_wipe() -> void:
	_main._toggle_panel(&"settings")
	await _frames(6)
	var panel = _main._panels[&"settings"]
	await _save("settings_top")   # 맨 위: 구역 들여쓰기 (v0.96)
	panel.find_children("*", "ScrollContainer", true, false)[0].scroll_vertical = 9999
	await _frames(6)
	await _save("wipe_settings")
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == "저장된 데이터 삭제":
			b.pressed.emit()
	await _frames(8)
	await _save("wipe_confirm")


## 전설 울음소리 알림 (v0.97): 프리져 조건만 채운 상태(설산), 그다음 뮤츠·뮤 조건까지 채운 상태(유령탑)
func _capture_legend() -> void:
	PlayerState.reset()   # 사용자 세이브와 상관없이 같은 상태에서 시작
	PlayerState.level = 40
	for id in range(1, 101):
		if not [144, 145, 146, 150, 151].has(id):
			PlayerState.add_caught({&"dex_id": id, &"level": 5, &"gender": &"male", &"shiny": false, &"region": &"grassland"})
	PlayerState.mark_legend_noticed([145, 146, 150, 151])   # 프리져만 알림 대기
	await _show_legend_notice("legend_notice")
	_main._confirm._confirm()
	await _frames(10)
	for id in range(101, 150):
		PlayerState.add_caught({&"dex_id": id, &"level": 5, &"gender": &"male", &"shiny": false, &"region": &"grassland"})
	PlayerState.legend_noticed = [144, 145, 146]
	await _show_legend_notice("legend_notice_ghost")


func _show_legend_notice(tag: String) -> void:
	await _frames(30)   # 포획 정보 창이 늦게 뜨므로 기다렸다가 닫는다(떠 있으면 알림이 미뤄진다)
	_main._caught.hide()
	_main._unlock_names.clear()   # 지역 해금 알림이 먼저 뜨지 않게
	_main._show_unlock_notice()
	await _frames(20)
	await _save(tag)
