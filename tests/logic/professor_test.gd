extends GdUnitTestSuite
## 박사에게 보내기, 경험사탕 사용 (기획서 4.8).

const S := &"exp_candy_s"
const M := &"exp_candy_m"

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _add(dex_id: int, level: int, traits: Array = []) -> String:
	var inst := PlayerState.add_caught({&"dex_id": dex_id, &"level": level, &"gender": &"male", &"region": &"grassland"})
	inst.traits = traits
	return inst.uid


# ---------------------------------------------------------------- 보내기

func test_transfer_gives_level_based_candies() -> void:
	var uid := _add(16, 20)
	var r := ProfessorManager.transfer([uid])
	assert_bool(r.ok).is_true()
	assert_dict(r.rewards).is_equal({S: 0, M: 1})        # 기획서 4.8.2 표: Lv20 → M1 (M10 비율 0.18)
	assert_int(PlayerState.item_count(M)).is_equal(1)
	assert_int(PlayerState.item_count(S)).is_equal(0)
	assert_bool(PlayerState.find_pokemon(uid).is_empty()).is_true()
	# 도감 기록은 남는다
	assert_bool(PlayerState.is_caught(16)).is_true()


func test_cannot_transfer_locked_or_busy() -> void:
	var locked := _add(16, 5)
	ProfessorManager.set_locked(locked, true)
	var r := ProfessorManager.transfer([locked])
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("잠금")
	var party: Array = []
	for i in 5:
		party.append(_add(16, 30))
	assert_bool(ExpeditionManager.start(&"grassland_walk", party, 2_000_000_000.0).ok).is_true()
	assert_str(ProfessorManager.transfer([party[0]]).reason).contains("원정")
	# 하나라도 안 되면 아무것도 보내지 않는다
	var free := _add(19, 5)
	assert_bool(ProfessorManager.transfer([free, locked]).ok).is_false()
	assert_bool(PlayerState.find_pokemon(free).is_empty()).is_false()


func test_duplicate_candidates_keep_best_and_skip_protected() -> void:
	var best := _add(16, 12)
	var dup1 := _add(16, 5)
	var dup2 := _add(16, 3, ["swift"])        # 특성 있음 → 남김
	var dup3 := _add(16, 4)
	ProfessorManager.set_locked(dup3, true)   # 잠금 → 남김
	var single := _add(25, 5)                 # 1마리뿐 → 남김
	var c := ProfessorManager.duplicate_candidates(true)
	assert_array(c).contains_exactly([dup1])
	assert_bool(c.has(best)).is_false()
	assert_bool(c.has(single)).is_false()
	# 특성 있는 개체도 보내는 옵션
	assert_array(ProfessorManager.duplicate_candidates(false)).contains_exactly_in_any_order([dup1, dup2])


func test_bulk_transfer() -> void:
	_add(16, 10)
	for i in 3:
		_add(16, 5)
	var c := ProfessorManager.duplicate_candidates()
	var r := ProfessorManager.transfer(c)
	assert_int(r.count).is_equal(3)
	assert_int(PlayerState.storage_count()).is_equal(1)
	assert_int(PlayerState.pokemon[0].level).is_equal(10)


# ---------------------------------------------------------------- 경험사탕

func test_use_candy_levels_up_and_consumes() -> void:
	var uid := _add(16, 5)
	PlayerState.add_item(S, 3)
	var r := ProfessorManager.use_candy(uid, S, 2)
	assert_bool(r.ok).is_true()
	assert_int(r.used).is_equal(2)
	assert_int(PlayerState.item_count(S)).is_equal(1)
	# Lv5 → 다음 레벨까지 112, 사탕 S 2개 = 200 → Lv6, 남은 88
	assert_int(PlayerState.find_pokemon(uid).level).is_equal(6)
	assert_int(PlayerState.find_pokemon(uid).exp).is_equal(88)


func test_candy_blocked_on_expedition_and_at_max() -> void:
	var party: Array = []
	for i in 5:
		party.append(_add(16, 30))
	ExpeditionManager.start(&"grassland_walk", party, 2_000_000_000.0)
	PlayerState.add_item(S, 5)
	assert_bool(ProfessorManager.use_candy(party[0], S).ok).is_false()
	var top := PlayerState.find_pokemon(_add(19, 5))
	top.level = 100
	assert_str(ProfessorManager.use_candy(top.uid, S).reason).contains("최대")


func test_use_candies_to_next_level_prefers_small() -> void:
	var uid := _add(16, 5)      # 다음 레벨까지 112
	PlayerState.add_item(S, 5)
	PlayerState.add_item(M, 2)
	var r := ProfessorManager.use_candies_to_next_level(uid)
	assert_bool(r.ok).is_true()
	assert_int(PlayerState.find_pokemon(uid).level).is_equal(6)
	assert_int(PlayerState.item_count(S)).is_equal(3)       # S 2개 사용
	assert_int(PlayerState.item_count(M)).is_equal(2)       # M은 쓰지 않음


func test_use_candies_to_next_level_uses_medium_when_small_runs_out() -> void:
	var uid := _add(16, 30)     # 다음 레벨까지 800
	PlayerState.add_item(S, 1)
	PlayerState.add_item(M, 1)
	var r := ProfessorManager.use_candies_to_next_level(uid)
	assert_bool(r.ok).is_true()
	assert_int(PlayerState.find_pokemon(uid).level).is_equal(31)
	assert_int(PlayerState.item_count(M)).is_equal(0)


## M8 완료 기준: 중복 개체 → 경험사탕 → Lv100까지 레벨업 가능
func test_duplicates_to_candies_to_level_100() -> void:
	var keep := _add(150, 70)
	# 높은 레벨 중복을 여러 번 보내 사탕을 모은다 (Lv100 1마리 = M 68개)
	for i in 4:
		ProfessorManager.transfer([_add(150, 100)])
	assert_int(PlayerState.item_count(M)).is_greater(150)   # Lv70→100 에 약 186개 필요
	while PlayerState.find_pokemon(keep).level < 100 and PlayerState.item_count(M) > 0:
		ProfessorManager.use_candy(keep, M, 10)
	assert_int(PlayerState.find_pokemon(keep).level).is_equal(100)
	assert_bool(ProfessorManager.use_candy(keep, M).ok).is_false()
