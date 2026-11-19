extends GdUnitTestSuite
## 향긋한 허브 (기획서 4.2, 4.11, v0.87): 상점 Lv10부터 2,000원, 쓰면 30분 동안 인카운터 간격 ×0.5
## 아이템 인카운터 수량(v0.88)도 여기서 본다.

const Manager := preload("res://assets/scripts/autoload/encounter_manager.gd")
const T0 := 2_000_000_000

var _snapshot: Dictionary
var _m: Node


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	_m = auto_free(Manager.new())
	_m.set_process(false)
	_m.rng.seed = 5
	_m.start(float(T0))


func after_test() -> void:
	PlayerState.load_save_dict(_snapshot)


func test_item_is_shop_only_2000_from_lv10() -> void:
	var honey := GameData.get_item(&"sweet_honey")
	assert_object(honey).is_not_null()
	assert_str(honey.name_ko).is_equal("향긋한 허브")
	assert_str(String(honey.category)).is_equal("boost")
	assert_int(honey.buy_price).is_equal(2000)
	assert_int(honey.sell_price).is_equal(600)
	assert_array(honey.sources).contains_exactly([&"shop"])
	assert_object(honey.load_icon()).is_not_null()
	for x in GameData.all_expeditions():
		for r in x.reward_table:
			assert_str(String(r.item)).is_not_equal("sweet_honey")
	PlayerState.currency = 100000
	PlayerState.level = 9
	assert_bool(ShopManager.buy(&"sweet_honey").ok).is_false()
	PlayerState.level = 10
	assert_bool(ShopManager.buy(&"sweet_honey").ok).is_true()


func test_use_lasts_30_min_extends_and_halves_interval() -> void:
	assert_str(PlayerState.use_sweet_honey(T0)).contains("없습니다")
	assert_float(PlayerState.interval_multiplier(T0)).is_equal(1.0)
	PlayerState.add_item(&"sweet_honey", 2)
	assert_str(PlayerState.use_sweet_honey(T0)).is_empty()
	assert_int(PlayerState.item_seconds_left("sweet_honey", T0)).is_equal(30 * 60)
	assert_float(PlayerState.interval_multiplier(T0)).is_equal(0.5)
	assert_str(PlayerState.use_sweet_honey(T0 + 60)).is_empty()   # 연장
	assert_int(PlayerState.item_seconds_left("sweet_honey", T0 + 60)).is_equal(59 * 60)
	assert_float(PlayerState.interval_multiplier(T0 + 60 * 60)).is_equal(1.0)


func test_next_interval_is_halved_and_stacks_with_stench() -> void:
	# 초원 30초~2분: 켜져 있으면 15~60초
	PlayerState.set_current_region(&"grassland")
	PlayerState.add_item(&"sweet_honey", 1)
	PlayerState.use_sweet_honey(T0)
	for i in 30:
		_m._schedule_next(float(T0))
		var left: float = _m._deadline - float(T0)
		assert_float(left).is_between(15.0, 60.0)


func test_using_halves_remaining_wait_once() -> void:
	PlayerState.add_item(&"sweet_honey", 2)
	_m._deadline = float(T0) + 100.0
	assert_str(_m.use_sweet_honey(float(T0))).is_empty()
	assert_float(_m._deadline).is_equal_approx(float(T0) + 50.0, 0.001)
	# 이미 켜져 있을 때 또 쓰면 연장만, 남은 시간은 다시 줄이지 않는다
	assert_str(_m.use_sweet_honey(float(T0))).is_empty()
	assert_float(_m._deadline).is_equal_approx(float(T0) + 50.0, 0.001)
	assert_int(PlayerState.item_seconds_left("sweet_honey", T0)).is_equal(60 * 60)


func test_using_while_paused_halves_paused_remaining() -> void:
	PlayerState.add_item(&"sweet_honey", 1)
	_m.state = Manager.State.PAUSED
	_m._paused_remaining = 80.0
	assert_str(_m.use_sweet_honey(float(T0))).is_empty()
	assert_float(_m._paused_remaining).is_equal_approx(40.0, 0.001)


func test_failed_use_does_not_change_timer() -> void:
	_m._deadline = float(T0) + 100.0
	assert_str(_m.use_sweet_honey(float(T0))).contains("없습니다")
	assert_float(_m._deadline).is_equal_approx(float(T0) + 100.0, 0.001)


func test_region_change_redraw_uses_halved_limit() -> void:
	PlayerState.set_current_region(&"grassland")
	PlayerState.add_item(&"sweet_honey", 1)
	PlayerState.use_sweet_honey(int(Time.get_unix_time_from_system()))
	var now := Time.get_unix_time_from_system()
	_m._deadline = now + 100.0   # 초원 최대 120초의 절반(60초)보다 길다 → 다시 뽑는다
	_m._on_region_changed(&"grassland")
	assert_float(_m._deadline - now).is_less_equal(60.0 + 1.0)


func test_saved_and_shown_as_buff() -> void:
	PlayerState.add_item(&"sweet_honey", 1)
	var now := int(Time.get_unix_time_from_system())
	PlayerState.use_sweet_honey(now)
	var d := PlayerState.to_save_dict()
	PlayerState.reset()
	PlayerState.load_save_dict(d)
	assert_int(PlayerState.item_seconds_left("sweet_honey", now)).is_equal(30 * 60)
	var texts := EncounterManager.active_buffs().map(func(b: Dictionary) -> String: return b.text)
	assert_array(texts).contains(["향긋한 허브 30분"])


## 아이템 인카운터 수량 (v0.88): 슈퍼볼은 1~3개, 나머지는 1개
func test_item_encounter_count() -> void:
	var region := GameData.get_region(&"grassland")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen_counts := {}
	for i in 4000:
		var f := EncounterLogic.roll_item_encounter(region, 10.0, rng)   # 100% 로 굴린다
		assert_bool(f.is_empty()).is_false()
		if f[&"id"] == &"great_ball":
			seen_counts[f[&"count"]] = true
			assert_int(f[&"count"]).is_between(1, 3)
		else:
			assert_int(f[&"count"]).is_equal(1)
	assert_array(seen_counts.keys()).contains_exactly_in_any_order([1, 2, 3])


func test_item_found_gives_count() -> void:
	var got := []
	var cb := func(id: StringName, count: int) -> void: got.append([id, count])
	EventBus.item_found.connect(cb)
	_m.current = {&"item": &"great_ball", &"count": 3}
	_m._found_item(float(T0))
	assert_int(PlayerState.item_count(&"great_ball")).is_equal(3)
	assert_array(got).contains_exactly([[&"great_ball", 3]])
	EventBus.item_found.disconnect(cb)
