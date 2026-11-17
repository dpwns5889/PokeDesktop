extends GdUnitTestSuite
## EncounterManager 상태 흐름 테스트. 실제 시계 대신 tick(now)에 가짜 시각을 넣는다. (기획서 4.2)

const T0 := 1_000_000.0
const Manager := preload("res://scripts/autoload/encounter_manager.gd")

var _m: Node
var _saved_ball: StringName
var _saved_inventory: Dictionary
var _saved_pokemon_count: int
var _saved_state: Dictionary


func before_test() -> void:
	_saved_ball = PlayerState.selected_ball
	_saved_inventory = PlayerState.inventory.duplicate()
	_saved_pokemon_count = PlayerState.pokemon.size()
	_saved_state = PlayerState.to_save_dict()
	PlayerState.selected_ball = &"poke_ball"
	_m = auto_free(Manager.new())
	_m.set_process(false)
	_m.rng.seed = 42
	_m.start(T0)


func after_test() -> void:
	PlayerState.load_save_dict(_saved_state)


func _advance_to_appeared() -> float:
	var t := T0 + Formulas.MAX_ENCOUNTER_INTERVAL_SEC + 1.0
	_m.tick(t)
	assert_int(_m.state).is_equal(Manager.State.PREVIEW)
	t += Formulas.ENCOUNTER_PREVIEW_SEC
	_m.tick(t)
	assert_int(_m.state).is_equal(Manager.State.APPEARED)
	return t


func test_interval_within_range() -> void:
	var lo := T0 + Formulas.encounter_interval_range(GameData.get_region(PlayerState.current_region)).x
	_m.tick(lo - 1.0)
	assert_int(_m.state).is_equal(Manager.State.WAITING)


func test_no_reaction_means_flee_then_waiting() -> void:
	var t := _advance_to_appeared()
	t += Formulas.ENCOUNTER_APPEAR_SEC
	_m.tick(t)
	assert_int(_m.state).is_equal(Manager.State.RESULT)
	assert_str(String(_m.last_result)).is_equal("fled")
	t += Formulas.ENCOUNTER_RESULT_SEC
	_m.tick(t)
	assert_int(_m.state).is_equal(Manager.State.WAITING)
	assert_dict(_m.current).is_empty()


func test_battle_success_adds_pokemon() -> void:
	_advance_to_appeared()
	var dex: int = _m.current[&"dex_id"]
	var params: Dictionary = _m.begin_battle()
	assert_bool(params.has(&"fill")).is_true()
	assert_int(_m.state).is_equal(Manager.State.BATTLE)
	_m.finish_battle(true)
	assert_int(_m.state).is_equal(Manager.State.RESULT)
	assert_int(PlayerState.pokemon.size()).is_equal(_saved_pokemon_count + 1)
	assert_int(PlayerState.pokemon.back().dex_id).is_equal(dex)


func test_battle_failure_means_flee() -> void:
	_advance_to_appeared()
	_m.begin_battle()
	_m.finish_battle(false)
	assert_str(String(_m.last_result)).is_equal("fled")
	assert_int(PlayerState.pokemon.size()).is_equal(_saved_pokemon_count)


func test_selected_ball_consumed_on_battle_start() -> void:
	PlayerState.inventory = {&"great_ball": 2}
	PlayerState.selected_ball = &"great_ball"
	_advance_to_appeared()
	var params: Dictionary = _m.begin_battle()
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(1)
	assert_float(params[&"fill"]).is_equal_approx(Formulas.CAPTURE_BASE_FILL * 1.5, 0.0001)


func test_timer_pauses_without_selected_ball_and_resumes_with_remaining_time() -> void:
	PlayerState.inventory = {}
	PlayerState.selected_ball = &"great_ball"
	_m.tick(T0 + 10.0)
	assert_int(_m.state).is_equal(Manager.State.PAUSED)
	var remaining: float = _m.seconds_until_next()
	# 정지한 동안 시간이 아무리 흘러도 인카운터는 일어나지 않는다
	_m.tick(T0 + 100000.0)
	assert_int(_m.state).is_equal(Manager.State.PAUSED)
	# 몬스터볼로 바꾸면 남은 시간부터 재개
	PlayerState.selected_ball = &"poke_ball"
	_m.tick(T0 + 100000.0)
	assert_int(_m.state).is_equal(Manager.State.WAITING)
	_m.tick(T0 + 100000.0 + remaining - 1.0)
	assert_int(_m.state).is_equal(Manager.State.WAITING)
	_m.tick(T0 + 100000.0 + remaining + 0.1)
	assert_int(_m.state).is_equal(Manager.State.PREVIEW)


func test_storage_full_blocks_battle_but_not_encounter() -> void:
	var cap := PlayerState.storage_capacity
	PlayerState.storage_capacity = PlayerState.storage_count()   # 가득
	_advance_to_appeared()
	assert_dict(_m.begin_battle()).is_empty()
	assert_str(String(_m.block_reason)).is_equal("storage_full")
	assert_int(_m.state).is_equal(Manager.State.APPEARED)
	PlayerState.storage_capacity = cap


func test_appearing_marks_dex_seen() -> void:
	_advance_to_appeared()
	assert_bool(PlayerState.dex[_m.current[&"dex_id"]].seen).is_true()


func test_buying_ball_resumes_timer() -> void:
	PlayerState.inventory = {}
	PlayerState.selected_ball = &"great_ball"
	_m.tick(T0 + 1.0)
	assert_int(_m.state).is_equal(Manager.State.PAUSED)
	PlayerState.add_item(&"great_ball", 3)
	_m.tick(T0 + 2.0)
	assert_int(_m.state).is_equal(Manager.State.WAITING)


func test_region_intervals() -> void:
	# 초반 지역은 30초~2분 (기획서 4.2, v0.24). 뒤 지역일수록 길어지고, 모두 상한 안.
	var r := Formulas.encounter_interval_range(GameData.get_region(&"grassland"))
	assert_float(r.x).is_equal(30.0)
	assert_float(r.y).is_equal(120.0)
	var prev := 0.0
	for region in GameData.all_regions():
		var iv := Formulas.encounter_interval_range(region)
		assert_float(iv.x).is_greater(0.0)
		assert_float(iv.y).is_less_equal(Formulas.MAX_ENCOUNTER_INTERVAL_SEC)
		assert_float(iv.y).override_failure_message(String(region.id)).is_greater_equal(prev)
		prev = iv.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var t := Formulas.roll_encounter_interval(rng, GameData.get_region(&"grassland"))
		assert_float(t).is_between(30.0, 120.0)
	# 지역이 없으면 기본값
	assert_that(Formulas.encounter_interval_range(null)).is_equal(Formulas.DEFAULT_ENCOUNTER_INTERVAL)
