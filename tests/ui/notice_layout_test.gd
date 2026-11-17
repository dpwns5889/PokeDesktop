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
