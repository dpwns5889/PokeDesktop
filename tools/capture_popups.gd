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
##   icons    큰 아이콘: 도감(일반·색다름)·메인 엔트리 상자·파티 (v0.100)
##   items    32px 아이템 아이콘: 가방·상점(구매)·원정 보상 팝업·파티 빈 자리 (v0.101)
##   panels   모든 패널을 차례로 + 보관함 필터(일부 켬) — UI 스킨 확인용 (panel_<id>.png)
##   popups   스크롤이 생기는 원정 편성(자동 선택)·원정 보상(칸 많이) — 포획 정보는 caughtbig 로
##   shopui   상점 모드 드롭다운을 연 모습(라디오·목록 바탕)과 수량 칸 + 설정 슬라이더 (UI 스킨)
## 결과: tools/previews/capture_<이름>.png (기준 해상도 그대로, 저작권 스프라이트가 들어 있어 git 제외)
## 세이브: 읽기만 하고 쓰기는 user://capture_saves 로 돌려서 실제 save.json 은 바뀌지 않는다.

const OUT := "res://tools/previews/capture_%s.png"

var _main: Node


func _ready() -> void:
	# 세이브는 읽기만 하고 쓰기는 임시 폴더로 돌린다 → 실제 save.json 이 덮이지 않는다 (기획서 7.5)
	SaveManager.save_dir = "user://capture_saves"
	DirAccess.make_dir_recursive_absolute(SaveManager.save_dir)
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
			"icons":
				await _capture_icons()
			"items":
				await _capture_items()
			"legend":
				await _capture_legend()
			"panels":
				await _capture_panels()
			"shopui":
				await _capture_shop_ui()
			"popups":
				await _capture_scroll_popups()
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
	_main._confirm.hide()   # 포획 정보 창이 닫히며 뜬 지역 해금 알림이 보관함을 가리지 않게
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
	for s: HSlider in panel.find_children("*", "HSlider", true, false):
		s.set_value_no_signal(60)   # 슬라이더 채움 모양 확인용 (신호 없이 → 설정 저장 안 됨)
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


## 32px 아이템 아이콘 (v0.101): 가방·상점 목록(24px)과 설명 머리(32px), 원정 보상 칸, 파티 빈 자리
func _capture_items() -> void:
	PlayerState.reset()
	PlayerState.level = 40
	PlayerState.add_currency(50000)
	for item in GameData.all_items():
		PlayerState.add_item(item.id, 3)
	await _frames(30)
	_main._caught.hide()
	_main._confirm.hide()
	for id in [&"bag", &"shop"]:
		_main._toggle_panel(id)
		await _frames(6)
		var panel = _main._panels[id]
		var pick := maxi(0, panel._ids.find(&"forget_berry"))   # 깜빡열매(v0.102)가 목록에 있으면 그것을 고른다
		panel._list.select(pick)
		panel._list.ensure_current_is_visible()
		panel._list.item_selected.emit(pick)
		await _save("items_" + String(id))
		_main._toggle_panel(id)
		await _frames(4)
	var r := {"expedition": &"grassland_walk", "success": true, "currency": 1200, "items": {&"great_ball": 2, &"fire_stone": 1, &"exp_candy_s": 3}, "pokemon_exp": {}, "levels": {}}
	_main._toggle_panel(&"expedition")
	await _frames(6)
	_main._panels[&"expedition"]._reward.show_result(r)
	await _frames(6)
	await _save("items_reward")
	_main._panels[&"expedition"]._reward.close_panel()
	_main._toggle_panel(&"expedition")
	_main._toggle_panel(&"party")
	await _save("items_party")


## 모든 패널 + 보관함 필터 화면 (UI 스킨 확인)
func _capture_panels() -> void:
	PlayerState.level = maxi(PlayerState.level, 40)
	await _frames(10)
	_main._caught.hide()
	_main._confirm.hide()
	for id: StringName in _main._panels:
		_main._toggle_panel(id)
		await _frames(6)
		_main._confirm.hide()
		await _save("panel_" + String(id))
		if id == &"storage":
			var panel = _main._panels[id]
			panel._filter_button.button_pressed = true
			for i in [0, 3, 5]:   # 상태 하나·타입 둘을 켠 모습
				if i < panel._filter_toggles.size():
					panel._filter_toggles[i].button_pressed = true
			await _save("panel_storage_filter")
			panel._filter_button.button_pressed = false
		_main._toggle_panel(id)
		await _frames(4)


## 스크롤이 생기는 원정 편성·원정 보상 (UI 스킨 스크롤바)
func _capture_scroll_popups() -> void:
	for i in 10:
		PlayerState.add_caught({&"dex_id": 16 + i, &"level": 10 + i, &"gender": &"male", &"region": &"grassland"})
	await _frames(4)
	_main._caught.close_panel()
	await _frames(4)
	_main._confirm.hide()
	_main._toggle_panel(&"expedition")
	await _frames(6)
	var panel = _main._panels[&"expedition"]
	for i in panel._rows.size():
		if panel._rows[i].get("id", &"") == &"grassland_walk":
			panel._list.select(i)
	panel._on_action()   # 파티 편성 화면으로
	await _frames(6)
	panel._on_auto()
	await _save("popup_formation")
	panel._view = 0
	panel.refresh()
	var items := {}
	for id in [&"great_ball", &"ultra_ball", &"fire_stone", &"water_stone", &"thunder_stone", &"leaf_stone",
			&"exp_candy_s", &"exp_candy_m", &"rare_candy", &"nugget", &"pearl", &"big_pearl"]:
		if GameData.get_item(id):
			items[id] = 2
	var r := {"expedition": &"grassland_walk", "success": true, "currency": 1200, "items": items,
		"pokemon_exp": {}, "levels": {}}
	panel._reward.show_result(r)
	await _frames(6)
	await _save("popup_reward")
	var sc: Array = panel._reward.find_children("*", "ScrollContainer", true, false)
	if sc:
		sc[0].scroll_vertical = 9999
		await _save("popup_reward_scrolled")
	panel._reward.close_panel()
	_main._toggle_panel(&"expedition")


## 상점 드롭다운 목록·수량 칸, 설정 슬라이더 (UI 스킨)
func _capture_shop_ui() -> void:
	await _frames(10)
	_main._caught.hide()
	_main._confirm.hide()
	_main._toggle_panel(&"shop")
	await _frames(6)
	var shop = _main._panels[&"shop"]
	shop._qty.set_value_no_signal(3)
	shop._mode.show_popup()
	var pm: PopupMenu = shop._mode.get_popup()
	pm.set_focused_item(1)   # 둘째 줄에 마우스를 올린 모습
	await _save("shopui_dropdown")
	pm.hide()
	_main._toggle_panel(&"shop")
	_main._toggle_panel(&"settings")
	await _frames(6)
	var panel = _main._panels[&"settings"]
	panel.find_children("*", "ScrollContainer", true, false)[0].scroll_vertical = 9999
	for s: HSlider in panel.find_children("*", "HSlider", true, false):
		s.set_value_no_signal(60)   # 신호 없이 → 설정 저장 안 됨
	await _save("shopui_slider")


## 큰 아이콘 (v0.100): 151종 모두 포획 + 일부 색다름 → 도감(일반·색다름 전환)과 메인 엔트리 상자 캡처
func _capture_icons() -> void:
	PlayerState.reset()
	for id in range(1, 152):
		var inst := PlayerState.add_caught({&"dex_id": id, &"level": 5, &"gender": &"male", &"shiny": id % 3 == 0, &"region": &"grassland"})
		if id in [25, 94, 145]:
			PlayerState.add_entry(String(inst.uid))
	await _frames(30)
	_main._caught.hide()
	PlayerState.mark_dex_complete_noticed()
	_main._confirm.hide()
	await _frames(10)
	_main._toggle_panel(&"dex")
	await _save("icons_dex")
	_main._panels[&"dex"]._shiny_view = true
	_main._panels[&"dex"].refresh()
	await _save("icons_dex_shiny")
	_main._close_panels()
	await _save("icons_main")
	_main._toggle_panel(&"party")
	await _save("icons_party")
