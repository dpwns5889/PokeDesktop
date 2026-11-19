extends OverlayPanel
## 확인 패널 (예: 개발용 저장 초기화). 별도 OS 창 대신 메인 창 안에 뜬다.
## ask(제목, 문구, 확인 버튼 문구, 확인 시 호출할 Callable) — 취소/확인
## notify(제목, 문구, 확인 시 호출할 Callable) — 알림: "확인" 버튼 하나뿐 (예: 새 지역 해금, v0.24)
## v0.80: 팝업 규칙(기획서 6.1) — 확인 창·알림 모두 문구와 버튼을 창 가운데에 모은다.

var _message: Label
## 색이 든 문구(BBCode)용. 문구는 [center] 로 가운데 정렬 (v0.89)
var _rich: RichTextLabel
var _rich_box: VBoxContainer
var _ok: Button
var _button_row: HBoxContainer
## 가운데 정렬일 때 버튼 아래 여백 → 버튼이 창 맨 아래보다 조금 위에 온다 (v0.58)
var _bottom_gap: Control
const CENTERED_BOTTOM_GAP := 18
var _cancel: Button
## 지금 알림(notify)으로 떠 있는지
var is_notice := false
var _title_text := "확인"
var _on_ok: Callable


func _panel_title() -> String:
	return _title_text


func _build_content(box: VBoxContainer) -> void:
	_message = Label.new()
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_message)
	# 문구에 색을 넣을 때(BBCode, v0.89)는 Label 대신 이 줄을 쓴다. 세로 가운데는 VBox 정렬로 맞춘다
	_rich_box = VBoxContainer.new()
	_rich_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_rich_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_box.visible = false
	box.add_child(_rich_box)
	_rich = UiUtil.rich_label()
	_rich.mouse_filter = Control.MOUSE_FILTER_PASS
	_rich_box.add_child(_rich)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row = row
	box.add_child(row)
	_cancel = Button.new()
	_cancel.text = "취소"
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(close_panel)
	row.add_child(_cancel)
	_ok = Button.new()
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_confirm)
	row.add_child(_ok)
	_bottom_gap = Control.new()
	_bottom_gap.custom_minimum_size.y = CENTERED_BOTTOM_GAP
	_bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bottom_gap)


## bbcode = true 면 message 를 BBCode 로 읽는다(색 넣기, v0.89). 이때 message 에 [ ] 가 있으면 태그로 읽히니 주의
func ask(title_text: String, message: String, ok_text: String, on_ok: Callable, bbcode := false) -> void:
	_set_notice(false)
	_title_text = title_text
	_title_label.text = title_text
	_message.visible = not bbcode
	_rich_box.visible = bbcode
	_message.text = "" if bbcode else message
	_rich.text = "[center]%s[/center]" % message if bbcode else ""
	_ok.text = ok_text
	_on_ok = on_ok
	open_panel()


## 알림: 확인 버튼만 있고 제목 줄의 "닫기"도 숨긴다 → 사용자가 확인을 눌러야만 on_ok 가 불린다.
func notify(title_text: String, message: String, on_ok: Callable = Callable(), bbcode := false) -> void:
	ask(title_text, message, "확인", on_ok, bbcode)
	_set_notice(true)


## 알림: 취소·닫기 없이 "확인"만
func _set_notice(on: bool) -> void:
	is_notice = on
	_cancel.visible = not on
	_header_row.get_node("Close").visible = not on


func _confirm() -> void:
	close_panel()
	if _on_ok.is_valid():
		_on_ok.call()
