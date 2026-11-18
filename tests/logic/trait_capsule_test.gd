extends GdUnitTestSuite
## 특성 캡슐·깜빡열매 (기획서 v0.79)

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _add(traits: Array) -> String:
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	inst.traits = traits
	return inst.uid


func _unlock() -> void:
	PlayerState.level = GameData.capsule_template().unlock_level


func test_capsule_items_exist_for_normal_and_rare_only() -> void:
	var pickup := GameData.get_item(GameData.capsule_id(&"pickup"))
	assert_object(pickup).is_not_null()
	assert_str(pickup.name_ko).is_equal("특성 캡슐 (픽업)")
	assert_bool(pickup.can_sell()).is_true()
	assert_bool(pickup.can_buy()).is_false()
	assert_object(GameData.get_item(GameData.capsule_id(&"truant"))).is_null()   # 부정
	assert_object(GameData.get_item(GameData.capsule_id(&"legend"))).is_null()   # 고정
	assert_object(GameData.get_item(&"trait_capsule")).is_null()   # 템플릿은 목록에 없음


func test_odds_need_unlock_and_split_by_trait_count() -> void:
	var p := PlayerState.find_pokemon(_add(["pickup", "ball_fetch", "truant"]))
	assert_bool(ProfessorManager.capsule_odds(p).is_empty()).is_true()   # Lv1: 해금 전
	_unlock()
	var odds := ProfessorManager.capsule_odds(p)
	assert_float(odds[&"pickup"]).is_equal_approx(0.10 / 2, 0.0001)   # 희귀, 담길 특성 2개
	assert_float(odds[&"ball_fetch"]).is_equal_approx(0.25 / 2, 0.0001)
	assert_bool(odds.has(&"truant")).is_false()


func test_capsule_drops_only_on_single_transfer() -> void:
	_unlock()
	var got := 0
	for i in 200:
		var r := ProfessorManager.transfer([_add(["ball_fetch"])])
		if r.capsule != &"":
			got += 1
	assert_int(got).is_between(25, 80)   # 25% (기대 50)
	assert_int(PlayerState.item_count(GameData.capsule_id(&"ball_fetch"))).is_equal(got)
	# 두 마리 이상 = 중복 보내기: 캡슐 없음
	for i in 50:
		assert_str(String(ProfessorManager.transfer([_add(["ball_fetch"]), _add(["ball_fetch"])]).capsule)).is_empty()


func test_capsule_adds_replaces_exclusive_and_needs_choice_at_three() -> void:
	var cap := GameData.capsule_id(&"pickup")
	PlayerState.add_item(cap, 3)
	var a := _add([])
	assert_bool(ProfessorManager.use_capsule(a, cap).ok).is_true()
	assert_array(PlayerState.find_pokemon(a).traits).contains_exactly(["pickup"])
	assert_bool(ProfessorManager.use_capsule(a, cap).ok).is_false()   # 이미 있음
	# 같이 안 붙는 특성(악취)은 그 자리에서 바뀐다
	var b := _add(["ball_fetch", "stench"])
	var r := ProfessorManager.use_capsule(b, cap)
	assert_str(r.replaced).is_equal("stench")
	assert_array(PlayerState.find_pokemon(b).traits).contains_exactly(["ball_fetch", "pickup"])
	# 3개면 바꿀 특성을 골라야 한다 (고정 특성은 세지 않음)
	var c := _add(["legend", "ball_fetch", "static", "harvest"])
	assert_bool(ProfessorManager.capsule_plan(PlayerState.find_pokemon(c), &"pickup").choose).is_true()
	assert_bool(ProfessorManager.use_capsule(c, cap).ok).is_false()
	assert_bool(ProfessorManager.use_capsule(c, cap, "legend").ok).is_false()
	assert_bool(ProfessorManager.use_capsule(c, cap, "static").ok).is_true()
	assert_array(PlayerState.find_pokemon(c).traits).contains_exactly(["legend", "ball_fetch", "pickup", "harvest"])
	assert_int(PlayerState.item_count(cap)).is_equal(0)


func test_forget_berry_removes_one_negative_trait() -> void:
	var uid := _add(["truant", "ball_fetch"])
	assert_bool(ProfessorManager.use_forget_berry(uid, "truant").ok).is_false()   # 열매 없음
	PlayerState.add_item(ProfessorManager.FORGET_BERRY, 1)
	assert_bool(ProfessorManager.use_forget_berry(uid, "ball_fetch").ok).is_false()   # 부정 특성이 아님
	assert_bool(ProfessorManager.use_forget_berry(uid, "truant").ok).is_true()
	assert_array(PlayerState.find_pokemon(uid).traits).contains_exactly(["ball_fetch"])
	assert_int(PlayerState.item_count(ProfessorManager.FORGET_BERRY)).is_equal(0)


## v0.82: 향로 2종 Lv15, 행복의 알 Lv25부터 상점에
func test_shop_unlock_levels() -> void:
	PlayerState.currency = 100000
	PlayerState.level = 14
	for id in [&"incense", &"shiny_incense", &"lucky_egg"]:
		assert_bool(ShopManager.buy(id).ok).override_failure_message(String(id)).is_false()
	PlayerState.level = 15
	assert_bool(ShopManager.buy(&"incense").ok).is_true()
	assert_bool(ShopManager.buy(&"shiny_incense").ok).is_true()
	assert_bool(ShopManager.buy(&"lucky_egg").ok).is_false()
	PlayerState.level = 25
	assert_bool(ShopManager.buy(&"lucky_egg").ok).is_true()


func test_forget_berry_on_sale_from_unlock_level() -> void:
	PlayerState.currency = 100000
	assert_bool(ShopManager.buy(ProfessorManager.FORGET_BERRY).ok).is_false()
	_unlock()
	assert_bool(ShopManager.buy(ProfessorManager.FORGET_BERRY).ok).is_true()
