extends GdUnitTestSuite
## 전투 칸 아래 버전 표시 (기획서 6.1, v0.64). 버전은 project.godot 한 곳에 두고 기획서 문서 버전과 같아야 한다.

const Companion := preload("res://scenes/main/companion.gd")


func test_version_matches_design_doc() -> void:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	assert_str(v).is_not_empty()
	assert_str(Companion.version_text()).is_equal("v" + v)
	var doc := FileAccess.get_file_as_string("res://docs/GAME_DESIGN.md")
	var re := RegEx.create_from_string("문서 버전: ([0-9.]+)")
	var m := re.search(doc)
	assert_object(m).is_not_null()
	assert_str(m.get_string(1)).override_failure_message("project.godot 버전과 기획서 문서 버전이 다르다").is_equal(v)


## v0.66: 왼쪽 아래 알림은 마지막 몇 초 동안 천천히 흐려지며 사라진다
func test_notice_fades_out() -> void:
	assert_float(Companion.notice_alpha(0.0)).is_equal(1.0)
	assert_float(Companion.notice_alpha(Companion.NOTICE_SEC - Companion.NOTICE_FADE_SEC)).is_equal(1.0)
	var mid := Companion.notice_alpha(Companion.NOTICE_SEC - Companion.NOTICE_FADE_SEC * 0.5)
	assert_float(mid).is_equal_approx(0.5, 0.001)
	assert_float(Companion.notice_alpha(Companion.NOTICE_SEC)).is_equal(0.0)
