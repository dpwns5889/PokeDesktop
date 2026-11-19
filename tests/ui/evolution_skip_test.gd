extends GdUnitTestSuite
## 진화 연출 "넘기기" (기획서 4.9, v0.83)

const EvolutionOverlay := preload("res://assets/scenes/ui/evolution_overlay.gd")

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	EvolutionManager.queue.clear()


func after_test() -> void:
	EvolutionManager.queue.clear()
	PlayerState.load_save_dict(_snapshot)


func test_skip_evolves_right_away_and_buttons_stay_centered() -> void:
	var o: EvolutionOverlay = auto_free(EvolutionOverlay.new())
	add_child(o)
	var p := PlayerState.add_caught({&"dex_id": 1, &"level": 16, &"gender": &"male", &"region": &"grassland"})
	EvolutionManager.queue.clear()
	assert_bool(EvolutionManager.request_level_evolution(p.uid).ok).is_true()
	o._show_current()
	assert_bool(o._skip.visible).is_true()
	# 깜빡이는 동안 [취소][넘기기] 가 창 가운데를 기준으로 나란히
	var mid := (o._button.position.x + o._skip.position.x + o._skip.size.x) / 2.0
	assert_float(mid).is_equal_approx(o.AREA.size.x / 2.0, 0.5)
	o._on_skip()
	assert_int(int(PlayerState.find_pokemon(p.uid).dex_id)).is_equal(2)   # 이상해풀
	assert_bool(o._skip.visible).is_false()
	assert_str(o._button.text).is_equal("확인")
	assert_float(o._button.position.x + o._button.size.x / 2.0).is_equal_approx(o.AREA.size.x / 2.0, 0.5)
