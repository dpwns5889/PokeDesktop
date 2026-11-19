extends GdUnitTestSuite
## 알림 창 가운데 정렬·상점 구매/판매 버튼 (기획서 6.1·4.12, v0.53)

const ConfirmPanel := preload("res://assets/scenes/ui/confirm_panel.gd")
const ShopPanel := preload("res://assets/scenes/ui/shop_panel.gd")


## v0.80 팝업 규칙: 알림이든 확인 창이든 문구·버튼은 창 가운데
func test_every_confirm_and_notice_is_centered() -> void:
	var p: ConfirmPanel = auto_free(ConfirmPanel.new())
	add_child(p)
	p.notify("새 지역 해금", "새로운 지역이 해금되었다!\n숲")
	_assert_centered(p)
	assert_bool(p._cancel.visible).is_false()
	p.ask("박사에게 보내기", "보낼까요?", "보내기", func() -> void: pass)
	_assert_centered(p)
	assert_bool(p._cancel.visible).is_true()
	assert_bool(p._bottom_gap.visible).is_true()   # 버튼을 조금 위로 (v0.58)


## v0.89: 새 지역 해금 팝업의 지역 이름은 대표 타입(main_types 첫 번째) 색. 색 문구도 가운데에 모은다
func test_region_name_is_colored_by_main_type() -> void:
	var forest := GameData.get_region(&"forest")
	var want := "[color=#%s]숲[/color]" % UiUtil.type_color(forest.main_types[0]).to_html(false)
	assert_str(UiUtil.region_bbcode(forest)).is_equal(want)
	assert_str(UiUtil.region_bbcode(GameData.get_region(&"volcano"))).contains(UiUtil.type_color(&"fire").to_html(false))
	var typeless := RegionData.new()
	typeless.name_ko = "이름뿐"
	assert_str(UiUtil.region_bbcode(typeless)).is_equal("이름뿐")
	var p: ConfirmPanel = auto_free(ConfirmPanel.new())
	add_child(p)
	var names := [UiUtil.region_bbcode(forest), UiUtil.region_bbcode(GameData.get_region(&"waterside"))]
	p.notify("새 지역 해금", "새로운 지역이 해금되었다!\n%s" % ", ".join(names), Callable(), true)
	assert_bool(p._rich_box.visible).is_true()
	assert_bool(p._message.visible).is_false()
	assert_int(p._rich_box.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)
	assert_int(p._button_row.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)
	assert_str(p._rich.text).starts_with("[center]").contains(want)
	# 보통 문구는 Label 그대로
	p.ask("확인", "보낼까요?", "보내기", func() -> void: pass)
	assert_bool(p._message.visible).is_true()
	assert_bool(p._rich_box.visible).is_false()


## v0.91: 모든 팝업의 확인 버튼 아래에 18px 여백 (경험치 바와 닿지 않게)
func test_popups_keep_bottom_gap_above_hud() -> void:
	var CaughtPanel := preload("res://assets/scenes/ui/caught_panel.gd")
	var RewardPanel := preload("res://assets/scenes/ui/expedition_reward_panel.gd")
	# 포획 정보 창만 내용이 많아 버튼을 조금 더 내렸다 (CaughtPanel.BOTTOM_GAP)
	for cls in [ConfirmPanel, CaughtPanel, RewardPanel]:
		var p: OverlayPanel = auto_free(cls.new())
		add_child(p)
		var gap := p.content.get_child(p.content.get_child_count() - 1)   # 맨 아래 = 여백
		assert_str(String(gap.name)).override_failure_message(str(cls.resource_path)).is_equal("BottomGap")
		var want := CaughtPanel.BOTTOM_GAP if cls == CaughtPanel else OverlayPanel.POPUP_BOTTOM_GAP
		assert_float(gap.custom_minimum_size.y).is_equal(float(want))
	assert_int(CaughtPanel.BOTTOM_GAP).is_less(OverlayPanel.POPUP_BOTTOM_GAP)
	assert_int(CaughtPanel.BOTTOM_GAP).is_greater(0)   # 그래도 경험치 바와 닿지는 않는다
	# 진화 연출: 다른 팝업과 버튼 바닥 높이가 같다 (패널은 안쪽 아래 여백 2px + 18px, 진화 연출은 그 합 20px)
	var EvoOverlay := preload("res://assets/scenes/ui/evolution_overlay.gd")
	assert_float(EvoOverlay.AREA.size.y - (EvoOverlay.BUTTON_Y + EvoOverlay.BUTTON_SIZE.y)).is_equal(float(OverlayPanel.POPUP_BOTTOM_GAP + 2))


func _assert_centered(p: ConfirmPanel) -> void:
	assert_int(p._message.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
	assert_int(p._message.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_CENTER)
	assert_int(p._button_row.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)


func test_shop_mode_buttons() -> void:
	var p = auto_free(ShopPanel.new())
	add_child(p)
	assert_int(p._mode.selected).is_equal(p.Mode.BUY)   # 처음엔 구매
	assert_bool(p._selling()).is_false()
	p._set_mode(p.Mode.SELL)
	assert_bool(p._selling()).is_true()
	p._set_mode(p.Mode.UPGRADE)
	assert_bool(p._selling()).is_false()
	assert_bool(p._upgrading()).is_true()


## v0.66: 팔면 "팔았다" 문구 없이 구매와 같은 소리 (문구가 판매 버튼을 밀어내 잘리게 했다)
func test_sell_plays_buy_sound_without_message() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.add_item(&"great_ball", 3)
	var p = auto_free(ShopPanel.new())
	add_child(p)
	p.open_panel()
	p._set_mode(p.Mode.SELL)
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
	var SP := preload("res://assets/scenes/ui/storage_panel.gd")
	var p = auto_free(SP.new())
	add_child(p)
	p._show_message("12마리를 보냈다! 경험사탕 M 3, 경험사탕 S 9 — 아주 긴 결과 문구가 붙어도 칸을 넓히지 않는다")
	assert_int(p._message.autowrap_mode).is_not_equal(TextServer.AUTOWRAP_OFF)
	assert_float(p._message.get_combined_minimum_size().x).is_less(60.0)
	# v0.85: 보관함을 다시 열면 지난 결과 문구는 사라진다
	p.open_panel()
	assert_bool(p._message.visible).is_false()
	assert_str(p._message.text).is_empty()


## v0.71: 별 버튼으로 즐겨찾기 (v0.72: 정보 칸 오른쪽 끝에 붙여 2배 크기). 즐겨찾기한 포켓몬은 파티·원정 목록 맨 위
func test_favorite_star_and_list_order() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	var strong := PlayerState.add_caught({&"dex_id": 16, &"level": 30, &"gender": &"male", &"region": &"grassland"})
	var weak := PlayerState.add_caught({&"dex_id": 19, &"level": 3, &"gender": &"female", &"region": &"grassland"})
	var SP := preload("res://assets/scenes/ui/storage_panel.gd")
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
	var PP := preload("res://assets/scenes/ui/party_panel.gd")
	var pp = auto_free(PP.new())
	add_child(pp)
	pp.refresh()
	assert_str(pp._pick_uids[0]).is_equal(weak.uid)
	assert_str(pp._pick_list.get_item_text(0)).starts_with("★")
	# 원정: 전투력이 낮아도 즐겨찾기가 먼저
	var EP := preload("res://assets/scenes/ui/expedition_panel.gd")
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
	var SP := preload("res://assets/scenes/ui/storage_panel.gd")
	var sp = auto_free(SP.new())
	add_child(sp)
	sp.open_panel()
	for sort in [0, 1, 2]:
		sp._sort.select(sort)
		sp.refresh()
		assert_array(sp._uids).contains_exactly([mid.uid, low.uid, top.uid])
	PlayerState.load_save_dict(snap)


## v0.93: 업그레이드 모드에는 보관함 확장과 상점 계약이 있고, 구매 모드 목록에서는 빠진다
func test_shop_upgrade_mode_lists_storage_and_contracts() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.unlock_region(&"cave")
	var p = auto_free(ShopPanel.new())
	add_child(p)
	p.open_panel()
	var contract := StringName(ShopPanel.CONTRACT_PREFIX + "great_ball_discount")
	# 구매: 아이템만
	assert_bool(p._ids.has(ShopPanel.STORAGE_ROW)).is_false()
	assert_bool(p._ids.has(contract)).is_false()
	# 업그레이드: 보관함 확장 → 슈퍼볼 계약 (하이퍼볼 계약은 슈퍼볼 계약 뒤)
	p._set_mode(p.Mode.UPGRADE)
	assert_array(p._ids).contains_exactly([ShopPanel.STORAGE_ROW, contract])
	assert_str(p._button.text).is_equal("확장")   # 첫 줄 = 보관함 확장
	p._list.select(1)
	p._update_order()
	assert_str(p._button.text).is_equal("계약")
	PlayerState.currency = 1_000_000
	p._on_order()   # 슈퍼볼 계약을 맺는다
	assert_bool(ShopManager.has_contract(&"great_ball_discount")).is_true()
	assert_array(p._ids).contains_exactly([ShopPanel.STORAGE_ROW, StringName(ShopPanel.CONTRACT_PREFIX + "ultra_ball_sale")])
	PlayerState.load_save_dict(snap)


## v0.93: 소지금은 제목 줄에 "소지금: ~원" 형식, 모드 드롭다운은 왼쪽 열 맨 위
func test_shop_money_in_header_and_mode_in_left_column() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.currency = 1234
	var p = auto_free(ShopPanel.new())
	add_child(p)
	p.open_panel()
	assert_str(p._money.text).is_equal("소지금: 1,234원")
	assert_object(p._money.get_parent()).is_same(p._header_row)
	assert_object(p._mode.get_parent()).is_same(p._list.get_parent())   # 왼쪽 열(목록과 같은 열)
	assert_int(p._mode.get_index()).is_equal(0)   # 맨 위
	PlayerState.load_save_dict(snap)


## v0.91: 포획 정보 창은 한 줄씩 — 새로 등록! / 이름·성별·레벨·타입 / 특성 1·2·3 (능력치는 뺌)
func test_caught_panel_rows_top_to_bottom() -> void:
	var snap := PlayerState.to_save_dict()
	PlayerState.reset()
	var CaughtPanel := preload("res://assets/scenes/ui/caught_panel.gd")
	var p = auto_free(CaughtPanel.new())
	add_child(p)
	var inst := PlayerState.add_caught({&"dex_id": 6, &"level": 12, &"gender": &"male", &"region": &"grassland"})   # 리자몽: 불꽃·비행
	var ids: Array[String] = []
	for t in GameData.all_traits():
		if ids.size() < 3 and (t.tier == &"normal" or t.tier == &"rare"):
			ids.append(String(t.id))
	inst["traits"] = ids
	p.show_pokemon(inst, true)
	# 위에서 아래로: 새로 등록! → (이름·타입 한 줄) → 특성들, 능력치 칸 없음
	var info: Node = p._new_label.get_parent()
	assert_int(info.get_child_count()).is_equal(3)
	assert_int(p._new_label.get_index()).is_equal(0)
	assert_int(p._traits.get_index()).is_equal(2)
	var line: Node = info.get_child(1)
	assert_object(p._name.get_parent()).is_same(line)   # 이름과 타입이 같은 줄
	assert_object(p._status.get_parent()).is_same(line)
	assert_bool(p._traits is VBoxContainer).is_true()   # 특성은 세로로 한 줄씩
	assert_int(p._traits.get_child_count()).is_equal(3)
	# 특성 상자는 정보 칸(214)보다 좁다 (v0.91)
	for b in p._traits.get_children():
		assert_float(b.custom_minimum_size.x).is_equal(CaughtPanel.TRAIT_BADGE_WIDTH)
	assert_float(CaughtPanel.TRAIT_BADGE_WIDTH).is_less(float(CaughtPanel.INFO_WIDTH))
	# 타입 1, 타입 2 가 같은 줄
	assert_int(p._status.get_children().filter(func(c: Node) -> bool: return c is TypeBadge).size()).is_equal(2)
	PlayerState.load_save_dict(snap)
