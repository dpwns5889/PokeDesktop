extends GdUnitTestSuite
## 게임에 표시되는 문자열의 모든 글자가 기본 폰트(pokemon-dppt.ttf)에 있는지 확인한다. (기획서 2.5)
## 실패하면: 문구를 바꾸거나, 대체 폰트를 지정한다.

const FONT_PATH := "res://Assets/Fonts/pokemon-dppt.ttf"
## 화면에 표시되는 문자열이 들어 있는 곳. (autoload 의 경고 메시지 등은 표시되지 않으므로 제외)
const UI_DIRS := ["res://scenes", "res://scripts/ui"]
## 화면에 보이지 않는 글자만 쓰는 파일 (field_map.gd = 맵 배치 글자 "=", "|" 등, v0.68)
const NON_UI_FILES := ["field_map.gd"]

var _font: FontFile
var _bbcode_tag := RegEx.create_from_string("\\[/?[a-z_]+[^\\]]*\\]")


func before() -> void:
	_font = load(FONT_PATH)


func test_species_and_type_names() -> void:
	var texts: Array[String] = []
	for s in GameData.all_species():
		texts.append(s.name_ko)
	for t in GameData.type_ids():
		texts.append(GameData.type_name(t))
	_assert_all_glyphs(texts, "종/타입 이름")


func test_ui_strings_in_scenes_and_scripts() -> void:
	var texts: Array[String] = []
	for dir in UI_DIRS:
		_collect_ui_strings(dir, texts)
	assert_array(texts).is_not_empty()
	_assert_all_glyphs(texts, "UI 문자열")


func _assert_all_glyphs(texts: Array[String], label: String) -> void:
	var missing := {}
	for text in texts:
		for i in text.length():
			var code := text.unicode_at(i)
			if code > 32 and not _font.has_char(code):
				missing[text[i]] = text
	assert_dict(missing).override_failure_message("%s: 폰트에 없는 글자 %s" % [label, missing]).is_empty()


func _collect_ui_strings(dir: String, out: Array[String]) -> void:
	var re := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for sub in DirAccess.get_directories_at(dir):
		_collect_ui_strings(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		var is_scene := file.ends_with(".tscn")
		if not (is_scene or file.ends_with(".gd")):
			continue
		if NON_UI_FILES.has(file):
			continue
		for line in FileAccess.get_file_as_string(dir.path_join(file)).split("\n"):
			var l := line.strip_edges()
			if l.begins_with("#"):
				continue
			if is_scene and not l.begins_with("text ="):
				continue
			for m in re.search_all(l):
				# BBCode 태그([color=...] 등)는 화면에 보이지 않으므로 뺀다
				var s := _bbcode_tag.sub(m.get_string(1).c_unescape(), "", true)
				if not s.begins_with("res://") and not s.contains("%"):
					out.append(s)
				elif s.contains("%"):
					out.append(s.replace("%d", "").replace("%s", ""))
