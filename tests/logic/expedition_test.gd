extends GdUnitTestSuite
## 특성·원정 (기획서 4.6, 4.10). 수치는 임시값이므로 규칙(방향·경계)을 위주로 검사한다.

const T0 := 2_000_000_000.0

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.rng.seed = 7
	ExpeditionManager.rng.seed = 7


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


## 특성 없는 개체를 직접 넣는다 (무작위 특성 영향 제거)
func _add(dex_id: int, level: int, traits: Array = []) -> String:
	var inst := PlayerState.add_caught({&"dex_id": dex_id, &"level": level, &"gender": &"male", &"region": &"grassland"})
	inst.traits = traits
	return inst.uid


func _x(id: StringName) -> ExpeditionData:
	return GameData.get_expedition(id)


# ---------------------------------------------------------------- 데이터

func test_expedition_data() -> void:
	var xs := GameData.all_expeditions()
	assert_int(xs.size()).is_equal(9)
	assert_str(String(xs[0].id)).is_equal("grassland_walk")
	assert_int(xs[0].duration_sec).is_equal(300)   # v0.32: 초원 5분, 숲 15분, 물가 30분, 동굴 1시간
	var mins := xs.slice(0, 4).map(func(x: ExpeditionData) -> int: return x.duration_sec / 60)
	assert_array(mins).contains_exactly([5, 15, 30, 60])
	assert_array(xs[0].unlock_conditions).is_empty()
	for x in xs:
		for r in x.reward_table:
			assert_object(GameData.get_item(StringName(r.item))).override_failure_message("%s: %s" % [x.id, r.item]).is_not_null()
		for c in x.unlock_conditions:
			if c.type == "region_unlocked":
				assert_object(GameData.get_region(StringName(c.value))).is_not_null()
		assert_int(x.currency_reward.x).is_less_equal(x.currency_reward.y)


func test_traits_data() -> void:
	assert_object(GameData.get_trait(&"legend")).is_not_null()
	# v0.28 개편: 49종(고정 2 포함), 모두 발동 위치가 원정 또는 전투, 옛 특성 없음
	var all := GameData.all_traits()
	assert_int(all.size()).is_equal(49)
	for t in all:
		assert_bool(t.trigger in [&"expedition", &"battle"]).override_failure_message(String(t.id)).is_true()
		for e in t.effects:
			assert_bool(e.get("kind") != "stat_mult" and e.get("kind") != "party_power_mult").override_failure_message(String(t.id)).is_true()
			if e.get("kind") == "power_mult":
				assert_str(String(e.get("scope", "self"))).override_failure_message(String(t.id)).is_equal("self")
		for x in t.exclusive_with:
			assert_object(GameData.get_trait(x)).override_failure_message("%s → %s" % [t.id, x]).is_not_null()
	assert_object(GameData.get_trait(&"sturdy")).is_null()
	# 이름이 겹치지 않는다
	var names := {}
	for t in all:
		assert_bool(names.has(t.name_ko)).override_failure_message(t.name_ko).is_false()
		names[t.name_ko] = true
	assert_int(GameData.get_trait(&"legend").weight).is_equal(0)   # 무작위로는 안 나옴
	assert_object(GameData.trait_roll_config()).is_not_null()
	var pool := GameData.random_trait_pool()
	assert_bool(pool.any(func(t: TraitData) -> bool: return t.id == &"legend")).is_false()
	for tier in [&"normal", &"rare", &"negative"]:
		assert_bool(pool.any(func(t: TraitData) -> bool: return t.tier == tier)).override_failure_message(String(tier)).is_true()


# ---------------------------------------------------------------- 특성

func test_roll_traits_distribution_and_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := [0, 0, 0, 0]
	for i in 2000:
		var ts := ExpeditionLogic.roll_traits(rng, GameData.trait_roll_config(), GameData.random_trait_pool())
		counts[ts.size()] += 1
		# 중복 없음, 배타 특성 동시 금지
		var uniq := {}
		for t in ts:
			uniq[t] = true
		assert_int(uniq.size()).is_equal(ts.size())
		assert_bool(ts.has("quick_feet") and ts.has("truant")).is_false()
		assert_bool(ts.has("legend")).is_false()
	assert_int(counts[0]).is_between(850, 1150)   # 가중치 50%
	assert_int(counts[3]).is_less(150)


func test_caught_pokemon_get_random_traits_and_legend_keeps_fixed() -> void:
	var with_traits := 0
	for i in 200:
		var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 3, &"gender": &"male", &"region": &"grassland"})
		if inst.traits.size() > 0:
			with_traits += 1
		assert_bool(inst.traits.has("legend")).is_false()
	assert_int(with_traits).is_between(60, 140)   # 약 절반
	var mew := PlayerState.add_caught({&"dex_id": 151, &"level": 30, &"gender": &"none", &"region": &"ghost_tower"})
	assert_bool(mew.traits.has("legend")).is_true()


func test_traits_do_not_change_stats() -> void:
	var base := PlayerState.find_pokemon(_add(25, 50))
	var hustle := PlayerState.find_pokemon(_add(25, 50, ["hustle", "legend"]))
	assert_dict(PlayerState.stats_of(hustle)).is_equal(PlayerState.stats_of(base))


func test_self_power_traits_with_conditions() -> void:
	var volcano := _x(&"volcano_survey")
	var grass := _x(&"grassland_walk")
	var charmander := PlayerState.find_pokemon(_add(4, 30))
	var charmander_blaze := PlayerState.find_pokemon(_add(4, 30, ["blaze"]))
	var pikachu := PlayerState.find_pokemon(_add(25, 30))
	var pikachu_blaze := PlayerState.find_pokemon(_add(25, 30, ["blaze"]))
	# 맹화: 자신이 불꽃 타입일 때만 ×1.2
	assert_float(ExpeditionLogic.pokemon_power(charmander_blaze, volcano)).is_equal_approx(ExpeditionLogic.pokemon_power(charmander, volcano) * 1.2, 0.01)
	assert_float(ExpeditionLogic.pokemon_power(pikachu_blaze, volcano)).is_equal_approx(ExpeditionLogic.pokemon_power(pikachu, volcano), 0.01)
	# 불꽃몸: 화산 조사에서만
	var flame := PlayerState.find_pokemon(_add(25, 30, ["flame_body"]))
	assert_float(ExpeditionLogic.pokemon_power(flame, volcano)).is_equal_approx(ExpeditionLogic.pokemon_power(pikachu, volcano) * 1.2, 0.01)
	assert_float(ExpeditionLogic.pokemon_power(flame, grass)).is_equal_approx(ExpeditionLogic.pokemon_power(pikachu, grass), 0.01)
	# 슬로스타트: 1시간 이하 원정에서만 ×0.5
	var slow := PlayerState.find_pokemon(_add(25, 30, ["slow_start"]))
	assert_float(ExpeditionLogic.pokemon_power(slow, grass)).is_equal_approx(ExpeditionLogic.pokemon_power(pikachu, grass) * 0.5, 0.01)
	assert_float(ExpeditionLogic.pokemon_power(slow, volcano)).is_equal_approx(ExpeditionLogic.pokemon_power(pikachu, volcano), 0.01)
	# 내열: 화산에서 불리(풀) 보정 무시 / 주눅: 불리 보정 ×0.7
	var oddish := PlayerState.find_pokemon(_add(43, 30))
	var oddish_heat := PlayerState.find_pokemon(_add(43, 30, ["heatproof"]))
	var oddish_rattled := PlayerState.find_pokemon(_add(43, 30, ["rattled"]))
	var raw := ExpeditionLogic.pokemon_power(oddish, volcano) / 0.85
	assert_float(ExpeditionLogic.pokemon_power(oddish_heat, volcano)).is_equal_approx(raw, 0.01)
	assert_float(ExpeditionLogic.pokemon_power(oddish_rattled, volcano)).is_equal_approx(raw * 0.7, 0.01)


func test_party_traits_count_once_and_are_capped() -> void:
	var x := _x(&"cave_dig")
	var one: Array[Dictionary] = []
	var two: Array[Dictionary] = []
	for i in 5:
		one.append(PlayerState.find_pokemon(_add(16, 30, ["quick_feet"] if i == 0 else [])))
		two.append(PlayerState.find_pokemon(_add(16, 30, ["quick_feet"] if i < 2 else [])))
	var m1 := ExpeditionLogic.party_mods(one, x)
	var m2 := ExpeditionLogic.party_mods(two, x)
	assert_float(m1.duration_mult).is_equal_approx(0.95, 0.0001)
	assert_float(m2.duration_mult).is_equal_approx(0.95, 0.0001)   # 같은 특성은 1번만
	# 다른 특성끼리는 곱한다
	var mixed: Array[Dictionary] = [PlayerState.find_pokemon(_add(16, 30, ["quick_feet"])),
		PlayerState.find_pokemon(_add(16, 30, ["speed_boost"]))]
	assert_float(ExpeditionLogic.party_mods(mixed, x).duration_mult).is_equal_approx(0.95 * 0.85, 0.0001)
	# 일찍기상: 1시간 이하 원정에서만
	var early: Array[Dictionary] = [PlayerState.find_pokemon(_add(16, 30, ["early_bird"]))]
	assert_float(ExpeditionLogic.party_mods(early, _x(&"power_plant_patrol")).duration_mult).is_equal(1.0)   # 2시간
	assert_float(ExpeditionLogic.party_mods(early, _x(&"grassland_walk")).duration_mult).is_equal_approx(0.9, 0.0001)
	assert_float(ExpeditionLogic.party_mods(early, x).duration_mult).is_equal_approx(0.9, 0.0001)   # 동굴 발굴 = 1시간 (v0.32)
	# 보상: 전설 ×1.3, 대운 ×1.1 → 요구치 초과 1.5배와 합쳐도 최대 ×2.0
	var rich: Array[Dictionary] = [PlayerState.find_pokemon(_add(16, 30, ["legend", "super_luck"]))]
	var rm := ExpeditionLogic.party_mods(rich, x)
	assert_float(rm.reward_mult).is_equal_approx(1.43, 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 30:
		var r := ExpeditionLogic.roll_rewards(x, 3.0, rm, true, rng)
		assert_int(r.currency).is_less_equal(int(round(x.currency_reward.y * ExpeditionLogic.MAX_REWARD_MULT)))
		assert_int(r.currency).is_greater_equal(int(round(x.currency_reward.x * ExpeditionLogic.MAX_REWARD_MULT)))


func test_bonus_item_only_on_success() -> void:
	var x := _x(&"cave_dig")
	var mods := {"bonus_items": [{"item": "exp_candy_s", "chance": 1.0, "min": 2, "max": 2}]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var plain := ExpeditionLogic.roll_rewards(x, 1.0, {}, true, rng)
	rng.seed = 2
	var win := ExpeditionLogic.roll_rewards(x, 1.0, mods, true, rng)
	assert_int(int(win.items.get(&"exp_candy_s", 0))).is_equal(int(plain.items.get(&"exp_candy_s", 0)) + 2)
	var lose := ExpeditionLogic.roll_rewards(x, 0.8, mods, false, rng)
	assert_int(int(lose.items.get(&"exp_candy_s", 0))).is_less_equal(4)


func test_auto_select_puts_harmful_traits_last() -> void:
	var x := _x(&"grassland_walk")
	var mons: Array[Dictionary] = []
	var lazy := PlayerState.find_pokemon(_add(18, 60, ["truant"]))   # 가장 강하지만 원정 시간 ↑
	mons.append(lazy)
	for i in 8:
		mons.append(PlayerState.find_pokemon(_add(18, 40)))
	var pick := ExpeditionLogic.auto_select(mons, x)
	assert_bool(pick.has(lazy.uid)).is_false()
	# 그것 없이 못 채우면 넣는다
	var few: Array[Dictionary] = [lazy]
	for i in 4:
		few.append(PlayerState.find_pokemon(_add(16, 2)))
	assert_bool(ExpeditionLogic.auto_select(few, _x(&"deep_cave_expedition")).has(lazy.uid)).is_true()


# ---------------------------------------------------------------- 전투력

func test_type_bonus() -> void:
	var water := _x(&"waterside_fishing")
	assert_float(ExpeditionLogic.type_bonus([&"water"] as Array[StringName], water)).is_equal(1.25)
	assert_float(ExpeditionLogic.type_bonus([&"fire"] as Array[StringName], water)).is_equal(0.85)
	assert_float(ExpeditionLogic.type_bonus([&"normal"] as Array[StringName], water)).is_equal(1.0)
	# 복합 타입: 하나라도 추천이면 보너스
	assert_float(ExpeditionLogic.type_bonus([&"fire", &"water"] as Array[StringName], water)).is_equal(1.25)


func test_power_grows_with_level_and_party_size() -> void:
	var x := _x(&"grassland_walk")
	var p5 := ExpeditionLogic.pokemon_power(PlayerState.find_pokemon(_add(16, 5)), x)
	var p20 := ExpeditionLogic.pokemon_power(PlayerState.find_pokemon(_add(16, 20)), x)
	assert_float(p20).is_greater(p5 * 2.0)
	var four: Array = []
	for i in 4:
		four.append(_add(19, 10))
	var six := four.duplicate()
	six.append(_add(19, 10))
	six.append(_add(19, 10))
	var s4 := ExpeditionManager.preview(&"grassland_walk", four)
	var s6 := ExpeditionManager.preview(&"grassland_walk", six)
	# 인원 보너스 없음 (v0.24): 같은 개체 6마리 = 4마리의 1.5배
	assert_float(float(s6.power)).is_equal_approx(s4.power * 1.5, 2.0)


func test_success_chance_rules() -> void:
	assert_float(ExpeditionLogic.success_chance(1.2)).is_equal(1.0)
	assert_float(ExpeditionLogic.success_chance(1.0)).is_equal(1.0)
	assert_float(ExpeditionLogic.success_chance(0.85)).is_equal_approx(0.5, 0.001)
	assert_float(ExpeditionLogic.success_chance(0.69)).is_equal(0.0)
	assert_float(ExpeditionLogic.success_chance(0.85, 0.1)).is_equal_approx(0.6, 0.001)


func test_party_traits_change_duration_and_rewards() -> void:
	var x := _x(&"grassland_walk")
	var plain: Array[Dictionary] = []
	var fast: Array[Dictionary] = []
	for i in 4:
		plain.append(PlayerState.find_pokemon(_add(16, 10)))
		fast.append(PlayerState.find_pokemon(_add(16, 10, ["speed_boost"] if i == 0 else [])))
	var a := ExpeditionLogic.party_summary(plain, x)
	var b := ExpeditionLogic.party_summary(fast, x)
	assert_int(b.duration_sec).is_less(a.duration_sec)
	assert_int(a.duration_sec).is_equal(x.duration_sec)


func test_rewards_success_vs_failure() -> void:
	var x := _x(&"cave_dig")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var win := ExpeditionLogic.roll_rewards(x, 1.0, {}, true, rng)
	assert_int(win.currency).is_between(x.currency_reward.x, x.currency_reward.y)
	var n_items := 0
	for id in win.items:
		n_items += 1
	assert_int(n_items).is_greater(0)
	var lose := ExpeditionLogic.roll_rewards(x, 0.8, {}, false, rng)
	assert_int(lose.currency).is_less_equal(int(round(x.currency_reward.y * 0.3)))
	# 요구치를 넘긴 만큼 보너스 (상한 1.5배)
	var big := ExpeditionLogic.roll_rewards(x, 3.0, {}, true, rng)
	assert_int(big.currency).is_between(int(x.currency_reward.x * 1.5), int(x.currency_reward.y * 1.5))


# ---------------------------------------------------------------- 진행 (매니저)

func _strong_party(n := 5) -> Array:
	var uids: Array = []
	for i in n:
		uids.append(_add(16, 30))
	return uids


func test_start_validations() -> void:
	# 파티를 먼저 만든다 (포획 경험치로 레벨이 올라 지역이 해금되므로, 그 뒤 상태를 되돌린다)
	var party5 := _strong_party()
	var party4 := _strong_party(4)
	var spare := _strong_party(5)
	var weak: Array = []
	for i in 5:
		weak.append(_add(10, 2))
	PlayerState.level = 1
	PlayerState.unlocked_regions = [&"grassland"] as Array[StringName]

	assert_bool(ExpeditionManager.start(&"forest_trip", party5, T0).ok).is_false()      # 잠김
	var few := ExpeditionManager.start(&"grassland_walk", party4, T0)                   # 4마리
	assert_bool(few.ok).is_false()
	assert_str(few.reason).contains("5마리 이상")
	# 숲 탐험에 Lv2 캐터피 5마리 → 요구치의 70% 미만
	PlayerState.unlock_region(&"forest")
	var r := ExpeditionManager.start(&"forest_trip", weak, T0)
	assert_bool(r.ok).is_false()
	assert_str(r.reason).contains("전투력")
	assert_bool(ExpeditionManager.start(&"grassland_walk", party5, T0).ok).is_true()
	# 원정 중인 포켓몬은 다시 못 보냄 + 슬롯 1개뿐 (Lv1)
	assert_bool(PlayerState.is_busy(party5[0])).is_true()
	var again := ExpeditionManager.start(&"forest_trip", party5, T0)
	assert_bool(again.ok).is_false()
	var slot := ExpeditionManager.start(&"forest_trip", spare, T0)
	assert_bool(slot.ok).is_false()
	assert_str(slot.reason).contains("동시에")


func test_no_max_party_size() -> void:
	var big := _strong_party(14)
	var r := ExpeditionManager.start(&"grassland_walk", big, T0)
	assert_bool(r.ok).is_true()
	assert_int(PlayerState.expeditions[0].party.size()).is_equal(14)


func test_auto_select_minimum_party_over_requirement() -> void:
	var x := _x(&"forest_trip")
	var weak: Array[Dictionary] = []
	for i in 30:
		weak.append(PlayerState.find_pokemon(_add(16, 8)))
	var strong := PlayerState.find_pokemon(_add(18, 40))   # 피죤투 Lv40: 가장 먼저 뽑혀야 함
	var all: Array[Dictionary] = weak.duplicate()
	all.append(strong)
	var pick := ExpeditionLogic.auto_select(all, x)
	assert_int(pick.size()).is_greater_equal(x.min_party)
	assert_str(pick[0]).is_equal(strong.uid)
	var party: Array[Dictionary] = []
	for u in pick:
		party.append(PlayerState.find_pokemon(u))
	assert_float(ExpeditionLogic.party_summary(party, x).ratio).is_greater_equal(1.0)
	# 한 마리 빼면 요구치 미달 (최소 인원)
	if party.size() > x.min_party:
		party.pop_back()
		assert_float(ExpeditionLogic.party_summary(party, x).ratio).is_less(1.0)


func test_auto_select_minimum_five_even_if_strong() -> void:
	var x := _x(&"grassland_walk")
	var mons: Array[Dictionary] = []
	for i in 8:
		mons.append(PlayerState.find_pokemon(_add(18, 60)))
	assert_int(ExpeditionLogic.auto_select(mons, x).size()).is_equal(5)


func test_auto_select_takes_everyone_when_not_enough() -> void:
	var x := _x(&"deep_cave_expedition")
	var mons: Array[Dictionary] = []
	for i in 3:
		mons.append(PlayerState.find_pokemon(_add(10, 2)))
	assert_int(ExpeditionLogic.auto_select(mons, x).size()).is_equal(3)


func test_manager_auto_select_skips_busy() -> void:
	var first := _strong_party()
	ExpeditionManager.start(&"grassland_walk", first, T0)
	_strong_party()
	var pick := ExpeditionManager.auto_select(&"grassland_walk")
	for u in first:
		assert_bool(pick.has(u)).is_false()
	assert_int(pick.size()).is_equal(5)


func test_slots_by_player_level() -> void:
	PlayerState.level = 1
	assert_int(ExpeditionManager.max_slots()).is_equal(1)
	PlayerState.level = 15
	assert_int(ExpeditionManager.max_slots()).is_equal(2)
	PlayerState.level = 30
	assert_int(ExpeditionManager.max_slots()).is_equal(3)


func test_time_passes_and_claim_gives_rewards() -> void:
	var party := _strong_party()
	var money := PlayerState.currency
	var r := ExpeditionManager.start(&"grassland_walk", party, T0)
	assert_bool(r.ok).is_true()
	var entry: Dictionary = PlayerState.expeditions[0]
	var dur := GameData.get_expedition(&"grassland_walk").duration_sec
	assert_int(ExpeditionManager.seconds_left(entry, T0 + 100)).is_equal(dur - 100)
	assert_bool(ExpeditionManager.claim(0, T0 + 100).ok).is_false()      # 아직
	# 앱이 꺼져 있던 동안에도 진행 = 시각만 비교
	assert_int(ExpeditionManager.check_finished(T0 + dur)).is_equal(1)
	assert_bool(entry.notified).is_true()
	var lv_before: int = PlayerState.find_pokemon(party[0]).level
	var res := ExpeditionManager.claim(0, T0 + dur)
	assert_bool(res.ok).is_true()
	assert_bool(res.success).is_true()        # 전투력 충분 → 성공 확률 100%
	assert_int(PlayerState.currency).is_greater(money)
	assert_array(PlayerState.expeditions).is_empty()
	assert_bool(PlayerState.is_busy(party[0])).is_false()
	assert_int(PlayerState.find_pokemon(party[0]).exp + PlayerState.find_pokemon(party[0]).level).is_greater(lv_before)


func test_clock_rollback_does_not_extend() -> void:
	ExpeditionManager.start(&"grassland_walk", _strong_party(), T0)
	var entry: Dictionary = PlayerState.expeditions[0]
	assert_int(ExpeditionManager.seconds_left(entry, T0 - 99999)).is_equal(GameData.get_expedition(&"grassland_walk").duration_sec)


func test_cancel_returns_party_without_reward() -> void:
	var party := _strong_party()
	var money := PlayerState.currency
	ExpeditionManager.start(&"grassland_walk", party, T0)
	assert_bool(ExpeditionManager.cancel(0).ok).is_true()
	assert_bool(PlayerState.is_busy(party[0])).is_false()
	assert_int(PlayerState.currency).is_equal(money)


func test_expeditions_survive_save_roundtrip() -> void:
	var party := _strong_party()
	ExpeditionManager.start(&"grassland_walk", party, T0)
	var d = JSON.parse_string(JSON.stringify(PlayerState.to_save_dict()))
	PlayerState.reset()
	PlayerState.load_save_dict(d)
	assert_int(PlayerState.expeditions.size()).is_equal(1)
	assert_int(PlayerState.expeditions[0].end_at).is_equal(int(T0) + GameData.get_expedition(&"grassland_walk").duration_sec)
	assert_bool(PlayerState.is_busy(party[0])).is_true()


func test_pokemon_exp_levels_up_to_100() -> void:
	var inst := PlayerState.find_pokemon(_add(16, 5))
	var gained := PlayerState.add_pokemon_exp(inst, Formulas.exp_to_next(5) + Formulas.exp_to_next(6))
	assert_int(gained).is_equal(2)
	assert_int(inst.level).is_equal(7)
	PlayerState.add_pokemon_exp(inst, 10_000_000)
	assert_int(inst.level).is_equal(100)
	assert_int(inst.exp).is_equal(0)
