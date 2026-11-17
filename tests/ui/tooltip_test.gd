extends GdUnitTestSuite
## 툴팁이 창 밖으로 잘리지 않게 줄바꿈 (v0.36)

const W := 10.0   # 테스트용: 글자 하나 = 10px


func _measure(s: String) -> float:
	return s.length() * W


func test_short_text_unchanged() -> void:
	assert_str(UiUtil.wrap_text("짧은 설명", 200.0, _measure)).is_equal("짧은 설명")


func test_wraps_only_at_spaces_and_fits() -> void:
	var text := "색이 다른 포켓몬만 가진다. 원정 전투력 ×1.2, 원정 보상 ×1.2."
	var out := UiUtil.wrap_text(text, 120.0, _measure)
	for line in out.split("\n"):
		assert_float(_measure(line)).override_failure_message(line).is_less_equal(120.0)
	# 단어(띄어쓰기 단위)는 쪼개지지 않는다
	assert_str(out.replace("\n", " ")).is_equal(text)
	assert_str(out).contains("전투력")


func test_keeps_existing_newlines() -> void:
	var out := UiUtil.wrap_text("색이다른\n원정 전투력 ×1.2, 원정 보상 ×1.2.", 120.0, _measure)
	assert_str(out.split("\n")[0]).is_equal("색이다른")


func test_tooltip_label_gets_wrapped() -> void:
	var label: Label = auto_free(Label.new())
	label.theme_type_variation = &"TooltipLabel"
	label.text = "이것은 아주 긴 툴팁 설명입니다. " .repeat(4)
	add_child(label)
	UiUtil.fit_tooltip(label)
	assert_str(label.text).contains("\n")
	var font := label.get_theme_font(&"font", &"TooltipLabel")
	var size := label.get_theme_font_size(&"font_size", &"TooltipLabel")
	for line in label.text.split("\n"):
		assert_float(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x).is_less_equal(UiUtil.TOOLTIP_MAX_WIDTH)
