extends GdUnitTestSuite
## 풀숲 위 말풍선 (기획서 6.1, v0.33)


func _bubble() -> EmoteBubble:
	var b: EmoteBubble = auto_free(EmoteBubble.new())
	add_child(b)
	return b


func test_sheet_has_six_frames() -> void:
	var b := _bubble()
	assert_bool(b.has_frames()).is_true()
	assert_int(b._frames.size()).is_equal(6)
	assert_vector(b._frames[0].get_size()).is_equal(Vector2(16, 16))


func test_question_alternates_two_frames() -> void:
	var b := _bubble()
	b.show_question()
	assert_bool(b.visible).is_true()
	assert_int(b.current_frame()).is_equal(4)
	b._process(EmoteBubble.QUESTION_SEC)
	assert_int(b.current_frame()).is_equal(5)
	b._process(EmoteBubble.QUESTION_SEC)
	assert_int(b.current_frame()).is_equal(4)
	b.show_waiting()   # 재개하면 다시 점
	assert_int(b.current_frame()).is_equal(0)


func test_waiting_cycles_dots() -> void:
	var b := _bubble()
	b.show_waiting()
	assert_bool(b.visible).is_true()
	assert_int(b.current_frame()).is_equal(0)          # "."
	b._process(EmoteBubble.DOT_SEC)
	assert_int(b.current_frame()).is_equal(1)          # ".."
	b._process(EmoteBubble.DOT_SEC)
	assert_int(b.current_frame()).is_equal(2)          # "..."
	b._process(EmoteBubble.DOT_SEC)
	assert_int(b.current_frame()).is_equal(0)          # 다시 "."
	assert_vector(b.scale).is_equal(Vector2.ONE)


func test_alert_pops_to_double() -> void:
	var b := _bubble()
	b.show_waiting()
	b.show_alert()
	assert_int(b.current_frame()).is_equal(EmoteBubble.ALERT_FRAME)   # "!"
	assert_float(b.scale.x).is_less(1.0)                              # 작게 시작해서
	await get_tree().create_timer(EmoteBubble.POP_SEC + 0.1).timeout
	assert_vector(b.scale).is_equal_approx(Vector2(2.0, 2.0), Vector2(0.01, 0.01))   # 2배 (v0.34)


func test_hide_and_back_to_waiting_resets_scale() -> void:
	var b := _bubble()
	b.show_alert()
	b.hide_bubble()
	assert_bool(b.visible).is_false()
	b.show_waiting()
	assert_vector(b.scale).is_equal(Vector2.ONE)
	assert_int(b.current_frame()).is_equal(0)
