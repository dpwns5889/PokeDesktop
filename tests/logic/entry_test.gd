extends GdUnitTestSuite
## 엔트리 (기획서 4.13): 최대 3마리, 원정·박사 보내기와의 관계, 저장, 전투 보너스

const T0 := 2_000_000_000.0

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func _add(dex_id: int, level: int) -> String:
	var inst := PlayerState.add_caught({&"dex_id": dex_id, &"level": level, &"gender": &"male", &"region": &"grassland"})
	inst.traits = []
	return inst.uid


func test_add_and_remove_up_to_three() -> void:
	var u: Array[String] = []
	for i in 4:
		u.append(_add(16, 10))
	for i in 3:
		assert_str(PlayerState.add_entry(u[i])).is_empty()
	assert_str(PlayerState.add_entry(u[3])).contains("3마리")
	assert_str(PlayerState.add_entry(u[0])).contains("이미")
	assert_int(PlayerState.entries.size()).is_equal(3)
	PlayerState.remove_entry(u[1])
	assert_bool(PlayerState.is_entry(u[1])).is_false()
	assert_str(PlayerState.add_entry(u[3])).is_empty()
	assert_array(PlayerState.entry_pokemon().map(func(p): return p.uid)).contains_exactly([u[0], u[2], u[3]])


func test_entries_cannot_go_on_expedition_and_vice_versa() -> void:
	var party: Array = []
	for i in 6:
		party.append(_add(16, 30))
	PlayerState.add_entry(party[0])
	var r := ExpeditionManager.start(&"grassland_walk", party, T0)
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("엔트리")
	# 엔트리는 자동 선택에서도 빠진다
	assert_bool(ExpeditionManager.auto_select(&"grassland_walk").has(party[0])).is_false()
	# 원정 중인 포켓몬은 엔트리에 넣을 수 없다
	var rest: Array = party.slice(1)
	assert_bool(ExpeditionManager.start(&"grassland_walk", rest, T0).ok).is_true()
	assert_str(PlayerState.add_entry(rest[0])).contains("원정")


func test_entries_cannot_be_transferred() -> void:
	var a := _add(16, 10)
	var b := _add(16, 5)
	PlayerState.add_entry(a)
	PlayerState.add_entry(b)
	var r := ProfessorManager.transfer([a])
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("엔트리")
	# 중복 보내기 후보에서도 빠진다
	assert_bool(ProfessorManager.duplicate_candidates(false).has(b)).is_false()


func test_entries_survive_save_and_drop_invalid() -> void:
	var a := _add(16, 10)
	var b := _add(19, 10)
	PlayerState.add_entry(a)
	PlayerState.add_entry(b)
	var d = JSON.parse_string(JSON.stringify(PlayerState.to_save_dict()))
	d.entries.append("없는-uid")
	d.entries.append(a)   # 중복
	PlayerState.reset()
	PlayerState.load_save_dict(d)
	assert_array(PlayerState.entries).contains_exactly([a, b])


func _stats_all(base: int, level: int) -> Dictionary:
	# v0.55: 기준은 개체치 최대 (최대 보너스엔 개체치도 필요)
	return Formulas.calc_stats({"hp": base, "atk": base, "def": base, "spa": base, "spd": base, "spe": base}, level, {}, Formulas.max_ivs())


func test_battle_bonus_rules() -> void:
	# 엔트리 없음 → 보너스 0
	var none := Formulas.entry_battle_bonus([])
	for k in none:
		assert_float(none[k]).is_equal(0.0)
	# 기준(종족값 80, Lv80) 3마리 → 정확히 최대 (v0.27)
	var ref := _stats_all(80, 80)
	var full := Formulas.entry_battle_bonus([ref, ref, ref])
	for k in full:
		assert_float(full[k]).override_failure_message(String(k)).is_equal_approx(Formulas.ENTRY_BONUS_MAX, 0.0001)
	# Lv79 3마리는 아직 최대가 아니다
	var lv79 := _stats_all(80, 79)
	assert_float(Formulas.entry_battle_bonus([lv79, lv79, lv79])[&"attack"]).is_less(Formulas.ENTRY_BONUS_MAX)
	# 레벨별 대략값: Lv20 ≈ 3.7%, Lv40 ≈ 9%, Lv60 ≈ 16%
	for pair in [[20, 0.037], [40, 0.093], [60, 0.165]]:
		var st := _stats_all(80, pair[0])
		assert_float(Formulas.entry_battle_bonus([st, st, st])[&"attack"]).override_failure_message(str(pair[0])).is_equal_approx(pair[1], 0.006)
	# 1마리만 Lv80이면 최대의 약 1/5 (곡선)
	assert_float(Formulas.entry_battle_bonus([ref])[&"attack"]).is_less(0.06)
	# 종족값이 높으면 더 일찍 최대, 넘쳐도 25%에서 멈춤
	var strong := _stats_all(120, 70)
	assert_float(Formulas.entry_battle_bonus([strong, strong, strong])[&"speed"]).is_equal(Formulas.ENTRY_BONUS_MAX)
	# 전투 파라미터에 반영: 게이지↑, 과녁 시간↑, 감점↓, 제한 시간↑
	var base := Formulas.capture_params(45, 10, false, 1.0)
	var boosted := Formulas.capture_params(45, 10, false, 1.0, full)
	assert_float(boosted[&"fill"]).is_greater(base[&"fill"])
	assert_float(boosted[&"target_life"]).is_greater(base[&"target_life"])
	assert_float(boosted[&"penalty"]).is_less(base[&"penalty"])
	assert_float(boosted[&"decay_per_sec"]).is_less(base[&"decay_per_sec"])
	assert_float(boosted[&"time_limit"]).is_equal_approx(Formulas.CAPTURE_TIME_LIMIT_SEC * 1.25, 0.001)


func test_encounter_manager_uses_entries() -> void:
	assert_float(EncounterManager.entry_bonus()[&"attack"]).is_equal(0.0)
	assert_array(EncounterManager.entry_buffs()).is_empty()
	for i in 3:
		PlayerState.add_entry(_add(18, 40))
	assert_float(EncounterManager.entry_bonus()[&"attack"]).is_greater(0.0)
	var buffs := EncounterManager.entry_buffs()
	assert_int(buffs.size()).is_greater(0)
	assert_str(buffs[0].text).contains("%")
