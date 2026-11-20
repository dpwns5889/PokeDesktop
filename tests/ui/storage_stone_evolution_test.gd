extends GdUnitTestSuite
## 보관함에서 이브이에게 진화의 돌 사용 (기획서 4.9)

const StoragePanel := preload("res://assets/scenes/ui/storage_panel.gd")
const EvolutionOverlay := preload("res://assets/scenes/ui/evolution_overlay.gd")

var _snapshot: Dictionary


func before_test() -> void:
	_snapshot = PlayerState.to_save_dict()
	PlayerState.reset()
	EvolutionManager.queue.clear()


func after_test() -> void:
	EvolutionManager.queue.clear()
	PlayerState.load_save_dict(_snapshot)


func test_eevee_shows_one_button_per_owned_stone_and_evolves_on_confirm() -> void:
	var p := PlayerState.add_caught({&"dex_id": 133, &"level": 20, &"gender": &"male", &"region": &"grassland"})
	for id in [&"water_stone", &"fire_stone", &"thunder_stone"]:
		PlayerState.add_item(id, 1)
	var panel: StoragePanel = auto_free(StoragePanel.new())
	add_child(panel)
	panel._update_evolution_buttons(p)
	assert_bool(panel._evo_box.visible).is_true()
	assert_int(panel._evo_box.get_child_count()).is_equal(3)
	# 불의 돌 버튼 → 진화 창
	var fire: Button
	for b: Button in panel._evo_box.get_children():
		if b.text == GameData.get_item(&"fire_stone").name_ko:
			fire = b
	assert_object(fire).is_not_null()
	fire.pressed.emit()
	assert_int(EvolutionManager.queue.size()).is_equal(1)
	assert_int(PlayerState.item_count(&"fire_stone")).is_equal(1)   # 확인 전엔 소모 안 됨
	var o: EvolutionOverlay = auto_free(EvolutionOverlay.new())
	add_child(o)
	o._show_current()
	o._on_skip()
	o._on_button()   # 확인
	assert_int(int(PlayerState.find_pokemon(p.uid).dex_id)).is_equal(136)   # 부스터
	assert_int(PlayerState.item_count(&"fire_stone")).is_equal(0)
	assert_int(PlayerState.item_count(&"water_stone")).is_equal(1)


func test_no_stone_no_buttons() -> void:
	var p := PlayerState.add_caught({&"dex_id": 133, &"level": 20, &"gender": &"male", &"region": &"grassland"})
	var panel: StoragePanel = auto_free(StoragePanel.new())
	add_child(panel)
	panel._update_evolution_buttons(p)
	assert_bool(panel._evo_box.visible).is_false()
