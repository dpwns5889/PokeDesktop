extends GdUnitTestSuite
## 알림 창 가운데 정렬·상점 구매/판매 버튼 (기획서 6.1·4.12, v0.53)

const ConfirmPanel := preload("res://scenes/ui/confirm_panel.gd")
const ShopPanel := preload("res://scenes/ui/shop_panel.gd")


func test_notice_is_centered_but_confirm_is_not() -> void:
	var p: ConfirmPanel = auto_free(ConfirmPanel.new())
	add_child(p)
	p.notify("새 지역 해금", "새로운 지역이 해금되었다!\n숲")
	assert_int(p._message.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
	assert_int(p._message.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_CENTER)
	assert_int(p._button_row.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)
	# 게임 종료 확인 (v0.57): 가운데
	p.ask("종료", "게임을 종료할까요?", "종료", func() -> void: pass, true)
	assert_int(p._message.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
	assert_int(p._button_row.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)
	assert_bool(p._cancel.visible).is_true()
	assert_bool(p._bottom_gap.visible).is_true()   # 버튼을 조금 위로 (v0.58)
	# 그 밖의 확인 창: 왼쪽 위 문구 + 오른쪽 버튼
	p.ask("박사에게 보내기", "보낼까요?", "보내기", func() -> void: pass)
	assert_int(p._message.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_LEFT)
	assert_int(p._button_row.alignment).is_equal(BoxContainer.ALIGNMENT_END)


func test_shop_mode_buttons() -> void:
	var p = auto_free(ShopPanel.new())
	add_child(p)
	assert_bool(p._buy_tab.button_pressed).is_true()
	assert_bool(p._selling()).is_false()
	p._sell_tab.button_pressed = true
	assert_bool(p._buy_tab.button_pressed).is_false()
	assert_bool(p._selling()).is_true()


## v0.66: 팔면 "팔았다" 문구 없이 구매와 같은 소리 (문구가 판매 버튼을 밀어내 잘리게 했다)
func test_sell_plays_buy_sound_without_message() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.add_item(&"great_ball", 3)
	var p = auto_free(ShopPanel.new())
	add_child(p)
	p.open_panel()
	p._sell_tab.button_pressed = true
	p._list.select(p._ids.find(&"great_ball"))
	p._update_order()
	var snd: AudioStreamPlayer = AudioManager._players[&"buy_item"]
	snd.stop()
	p._on_order()
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(2)
	assert_str(p._message.text).is_empty()
	assert_bool(p._message.visible).is_false()
	assert_bool(snd.playing).is_true()
	snd.stop()
	PlayerState.load_save_dict(snap)


## v0.66: 보관함 "중복 보내기" 결과처럼 긴 문구도 줄바꿈되어 오른쪽 칸(버튼 줄)을 패널 밖으로 밀지 않는다
func test_storage_long_message_wraps() -> void:
	var SP := preload("res://scenes/ui/storage_panel.gd")
	var p = auto_free(SP.new())
	add_child(p)
	p._show_message("12마리를 보냈다! 경험사탕 M 3, 경험사탕 S 9 — 아주 긴 결과 문구가 붙어도 칸을 넓히지 않는다")
	assert_int(p._message.autowrap_mode).is_not_equal(TextServer.AUTOWRAP_OFF)
	assert_float(p._message.get_combined_minimum_size().x).is_less(60.0)


## v0.71: 별 버튼으로 즐겨찾기 (v0.72: 정보 칸 오른쪽 끝에 붙여 2배 크기). 즐겨찾기한 포켓몬은 파티·원정 목록 맨 위
func test_favorite_star_and_list_order() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	var strong := PlayerState.add_caught({&"dex_id": 16, &"level": 30, &"gender": &"male", &"region": &"grassland"})
	var weak := PlayerState.add_caught({&"dex_id": 19, &"level": 3, &"gender": &"female", &"region": &"grassland"})
	var SP := preload("res://scenes/ui/storage_panel.gd")
	var sp = auto_free(SP.new())
	add_child(sp)
	sp.open_panel()
	sp._on_selected(sp._uids.find(weak.uid))
	await get_tree().process_frame
	await get_tree().process_frame
	var head: Control = sp._fav.get_parent()
	assert_float(sp._fav.position.x + sp._fav.size.x).is_equal_approx(head.size.x, 0.5)   # 오른쪽 끝에 붙음
	assert_float(sp._fav.position.x).is_greater(sp._name.global_position.x - head.global_position.x + sp._name.get_content_width())
	assert_int(sp._fav.get_theme_font_size(&"font_size")).is_equal(32)   # 기본 16의 2배
	assert_float(sp._fav.position.y).is_equal(0.0)   # 위에 붙음
	sp._fav.pressed.emit()
	assert_bool(PlayerState.find_pokemon(weak.uid).favorite).is_true()
	# 파티: 레벨이 낮아도 즐겨찾기가 먼저
	var PP := preload("res://scenes/ui/party_panel.gd")
	var pp = auto_free(PP.new())
	add_child(pp)
	pp.refresh()
	assert_str(pp._pick_uids[0]).is_equal(weak.uid)
	assert_str(pp._pick_list.get_item_text(0)).starts_with("★")
	# 원정: 전투력이 낮아도 즐겨찾기가 먼저
	var EP := preload("res://scenes/ui/expedition_panel.gd")
	var ep = auto_free(EP.new())
	add_child(ep)
	ep._target = &"grassland_walk"
	ep._refresh_party()
	assert_str(ep._party_uids[0]).is_equal(weak.uid)
	assert_str(ep._party_uids[1]).is_equal(strong.uid)
	PlayerState.load_save_dict(snap)


## v0.73: 보관함은 정렬 기준과 상관없이 파티(엔트리) 포켓몬이 맨 위, 파티 순서대로
func test_storage_party_first() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	var low := PlayerState.add_caught({&"dex_id": 150, &"level": 2, &"gender": &"male", &"region": &"grassland"})
	var mid := PlayerState.add_caught({&"dex_id": 120, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	var top := PlayerState.add_caught({&"dex_id": 1, &"level": 50, &"gender": &"male", &"region": &"grassland"})
	PlayerState.entries = [mid.uid, low.uid] as Array[String]
	var SP := preload("res://scenes/ui/storage_panel.gd")
	var sp = auto_free(SP.new())
	add_child(sp)
	sp.open_panel()
	for sort in [0, 1, 2]:
		sp._sort.select(sort)
		sp.refresh()
		assert_array(sp._uids).contains_exactly([mid.uid, low.uid, top.uid])
	PlayerState.load_save_dict(snap)
