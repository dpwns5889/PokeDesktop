extends GdUnitTestSuite
## 진화 (기획서 4.9).

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	EvolutionManager.queue.clear()


func after_test() -> void:
	EvolutionManager.queue.clear()
	PlayerState.load_save_dict(_snapshot)


func _add(dex_id: int, level: int, traits: Array = [], gender := &"male") -> Dictionary:
	var inst := PlayerState.add_caught({&"dex_id": dex_id, &"level": level, &"gender": gender, &"region": &"grassland"})
	inst.traits = traits
	EvolutionManager.queue.clear()   # 포획 경험치로 생긴 다른 레벨업 영향 제거
	return inst


func _level_to(inst: Dictionary, level: int) -> void:
	PlayerState.add_pokemon_exp(inst, Formulas.total_exp(level) - Formulas.total_exp(inst.level) - int(inst.exp))


func test_reaching_level_requests_evolution() -> void:
	var p := _add(1, 15)         # 이상해씨 → Lv16 이상해풀
	var requested := []
	var cb := func(uid: String, to: int) -> void: requested.append([uid, to])
	EventBus.evolution_requested.connect(cb)
	_level_to(p, 16)
	EventBus.evolution_requested.disconnect(cb)
	assert_array(requested).contains_exactly([[p.uid, 2]])
	assert_int(EvolutionManager.current().to).is_equal(2)


func test_confirm_evolves_and_keeps_traits_and_registers_dex() -> void:
	var p := _add(1, 15, ["quick_feet", "pickup"], &"female")
	var exp_before := PlayerState.experience
	var lv_before := PlayerState.level
	_level_to(p, 16)
	var r := EvolutionManager.confirm_current()
	assert_bool(r.ok).is_true()
	assert_int(p.dex_id).is_equal(2)
	assert_int(p.level).is_equal(16)
	assert_array(p.traits).contains_exactly(["quick_feet", "pickup"])
	assert_str(p.gender).is_equal("female")
	assert_bool(PlayerState.is_caught(2)).is_true()
	assert_bool(PlayerState.experience != exp_before or PlayerState.level > lv_before).is_true()
	assert_dict(EvolutionManager.current()).is_empty()


func test_cancel_then_retry_on_next_level() -> void:
	var p := _add(1, 15)
	_level_to(p, 16)
	EvolutionManager.cancel_current()
	assert_bool(p.evolution_cancelled).is_true()
	assert_int(p.dex_id).is_equal(1)
	assert_dict(EvolutionManager.current()).is_empty()
	# 다음 레벨업 때 다시 시도
	_level_to(p, 17)
	assert_int(EvolutionManager.current().to).is_equal(2)
	assert_bool(p.evolution_cancelled).is_false()


func test_manual_request_after_cancel() -> void:
	var p := _add(1, 15)
	_level_to(p, 16)
	EvolutionManager.cancel_current()
	assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).is_true()
	assert_bool(EvolutionManager.confirm_current().ok).is_true()
	assert_int(p.dex_id).is_equal(2)


func test_cannot_evolve_below_level() -> void:
	var p := _add(1, 10)
	assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).is_false()


func test_trade_replacement_levels() -> void:
	var kadabra := _add(64, 35)
	_level_to(kadabra, 36)
	assert_int(EvolutionManager.current().to).is_equal(65)   # 후딘
	EvolutionManager.confirm_current()
	for pair in [[67, 40, 68], [75, 40, 76], [93, 38, 94]]:
		var p := _add(pair[0], pair[1] - 1)
		_level_to(p, pair[1])
		assert_int(EvolutionManager.current().to).override_failure_message(str(pair)).is_equal(pair[2])
		EvolutionManager.confirm_current()
		assert_int(p.dex_id).is_equal(pair[2])


func test_stone_evolution_consumes_stone_only_on_confirm() -> void:
	var pika := _add(25, 10)
	assert_bool(EvolutionManager.request_item_evolution(pika.uid, &"thunder_stone").ok).is_false()  # 돌 없음
	PlayerState.add_item(&"thunder_stone", 1)
	assert_array(EvolutionManager.stone_options(pika)).has_size(1)
	assert_bool(EvolutionManager.request_item_evolution(pika.uid, &"fire_stone").ok).is_false()     # 다른 돌
	assert_bool(EvolutionManager.request_item_evolution(pika.uid, &"thunder_stone").ok).is_true()
	# 취소하면 돌은 그대로
	EvolutionManager.cancel_current()
	assert_int(PlayerState.item_count(&"thunder_stone")).is_equal(1)
	assert_bool(pika.evolution_cancelled).is_false()     # 돌 진화 취소는 레벨 진화에 영향 없음
	EvolutionManager.request_item_evolution(pika.uid, &"thunder_stone")
	assert_bool(EvolutionManager.confirm_current().ok).is_true()
	assert_int(pika.dex_id).is_equal(26)
	assert_int(PlayerState.item_count(&"thunder_stone")).is_equal(0)


func test_eevee_branches() -> void:
	for pair in [[&"water_stone", 134], [&"thunder_stone", 135], [&"fire_stone", 136]]:
		var eevee := _add(133, 20)
		PlayerState.add_item(pair[0], 1)
		EvolutionManager.request_item_evolution(eevee.uid, pair[0])
		EvolutionManager.confirm_current()
		assert_int(eevee.dex_id).is_equal(pair[1])


func test_no_evolution_while_on_expedition() -> void:
	var party: Array = []
	for i in 5:
		party.append(_add(16, 17).uid)     # 구구 Lv18 → 피죤
	assert_bool(ExpeditionManager.start(&"grassland_walk", party, 2_000_000_000.0).ok).is_true()
	var p := PlayerState.find_pokemon(party[0])
	PlayerState.add_pokemon_exp(p, 10_000)    # 원정 중 레벨업 (예: 다른 경로)
	assert_dict(EvolutionManager.current()).is_empty()
	assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).is_false()
	# 귀환(보상) 처리에서 레벨이 오르면 그때 진화 요청
	EvolutionManager.queue.clear()
	ExpeditionManager.claim(0, 2_000_000_000.0 + 3600)
	assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).is_true()


func test_queue_shows_one_at_a_time_and_chains() -> void:
	var a := _add(1, 15)
	var b := _add(4, 15)
	_level_to(a, 16)
	_level_to(b, 16)
	assert_int(EvolutionManager.queue.size()).is_equal(2)
	assert_str(EvolutionManager.current().uid).is_equal(a.uid)
	EvolutionManager.confirm_current()
	assert_str(EvolutionManager.current().uid).is_equal(b.uid)
	EvolutionManager.confirm_current()
	# 연속 진화: Lv40 이상해씨는 이상해풀 → 바로 이상해꽃
	var c := _add(1, 15)
	_level_to(c, 40)
	EvolutionManager.confirm_current()
	assert_int(c.dex_id).is_equal(2)
	assert_int(EvolutionManager.current().to).is_equal(3)
	EvolutionManager.confirm_current()
	assert_int(c.dex_id).is_equal(3)


## M9 완료 기준: 1세대 진화 경로 전부 가능
func test_every_gen1_evolution_path_works() -> void:
	var done := 0
	for s in GameData.all_species():
		for e in s.evolutions:
			EvolutionManager.queue.clear()
			var p := _add(s.dex_id, 5)
			if e.method == &"level":
				p.level = int(e.value)
				assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).override_failure_message("%d→%d" % [s.dex_id, e.to]).is_true()
			else:
				PlayerState.add_item(StringName(e.item), 1)
				assert_bool(EvolutionManager.request_item_evolution(p.uid, StringName(e.item)).ok).override_failure_message("%d→%d" % [s.dex_id, e.to]).is_true()
			var r := EvolutionManager.confirm_current()
			assert_bool(r.ok).override_failure_message("%d→%d" % [s.dex_id, e.to]).is_true()
			assert_int(p.dex_id).is_equal(e.to)
			done += 1
	assert_int(done).is_greater(70)
