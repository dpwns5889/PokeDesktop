extends GdUnitTestSuite
## 원정 보상 팝업 (기획서 4.10·6.2, v0.59): 제목 = 원정지 + 성공/실패, 위 = 아이템 칸, 아래 = 레벨이 오른 포켓몬 칸, 확인으로 닫기

const RewardPanel := preload("res://scenes/ui/expedition_reward_panel.gd")

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _result(levels: Dictionary, exp_map: Dictionary, success := true) -> Dictionary:
	return {"ok": true, "success": success, "currency": 1200, "items": {&"great_ball": 3},
		"pokemon_exp": exp_map, "levels": levels, "player_exp": 10, "expedition": "grassland_walk"}


func test_popup_shows_item_and_pokemon_tiles_and_closes_on_ok() -> void:
	var inst := PlayerState.add_caught({&"dex_id": 25, &"level": 14, &"gender": &"male", &"region": &"grassland"})
	var other := PlayerState.add_caught({&"dex_id": 16, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	var p: RewardPanel = auto_free(RewardPanel.new())
	add_child(p)
	p.show_result(_result({inst.uid: 2}, {inst.uid: 300, other.uid: 300}))
	assert_bool(p.visible).is_true()
	assert_bool(p._header_row.get_node("Close").visible).is_false()   # 확인으로만 닫는다
	assert_str(p._title_label.text).is_equal("초원 산책")
	assert_str(p._result.text).is_equal("성공!")
	# 아이템 칸: 돈 + 슈퍼볼, 획득량은 칸 아래
	var items := RewardPanel.item_tiles(_result({}, {}))
	assert_int(items.size()).is_equal(2)
	assert_str(items[0].amount).is_equal("1,200")
	assert_object(items[0].icon).is_not_null()   # coin.png (v0.62)
	assert_bool(items[0].coin).is_false()
	assert_str(items[1].amount).is_equal("×3")
	assert_object(items[1].icon).is_not_null()
	assert_int(p._item_tiles.get_child_count()).is_equal(2)
	# 포켓몬 칸: 레벨이 오른 피카츄만
	assert_str(p._exp_label.text).contains("경험치 +300")
	var mons := RewardPanel.pokemon_tiles(_result({inst.uid: 2}, {}))
	assert_int(mons.size()).is_equal(1)
	assert_str(mons[0].amount).is_equal("+2")
	assert_str(mons[0].tip).is_equal("피카츄  Lv12 → Lv14")
	assert_int(p._mon_tiles.get_child_count()).is_equal(1)
	assert_bool(p._none_label.visible).is_false()
	p._ok.pressed.emit()
	assert_bool(p.visible).is_false()


func test_failure_and_no_level_up() -> void:
	var p: RewardPanel = auto_free(RewardPanel.new())
	add_child(p)
	p.show_result(_result({}, {}, false))
	assert_str(p._result.text).contains("실패")
	assert_bool(p._none_label.visible).is_true()
	assert_bool(p._mon_tiles.visible).is_false()
