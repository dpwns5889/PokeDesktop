extends Node
## 창 배치(기본 위치: 우하단)·드래그·배율·always on top. (기획서 3장)
##
## 위치 규칙
## - 실행할 때마다 항상 주 모니터 우하단(기본 위치)에 연다. 옮긴 위치는 저장하지 않는다.
## - 도킹(docked): 기본 위치에 붙은 상태. 해상도·작업표시줄이 바뀌면 새 기본 위치로 따라간다.
## - 자유 위치: 실행 중 드래그로 옮긴 상태. 화면 밖으로 나가면 안으로 보정한다(종료하면 잊는다).

signal scale_changed(scale: int)
signal docked_changed(docked: bool)

const WATCH_INTERVAL_SEC := 1.0

## 개발(디버그) 빌드에서 시작할 때의 배율: 640×400. 실행 인자 `-- --window-scale=N` 으로 바꿀 수 있다.
const DEBUG_START_SCALE := 2

var current_scale: int = 1
var docked: bool = true
## 이번 실행에서 요청된 배율(0 = 자동). 화면 구성이 바뀌어 다시 맞출 때 쓴다.
var _requested_scale: int = 0

var _last_position := Vector2i.ZERO
var _last_screens: Array[Rect2i] = []


func _ready() -> void:
	# 툴팁이 창 밖으로 잘리지 않게: 새 툴팁 라벨이 생기면 최대 폭에서 줄을 바꾼다 (v0.36)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is Label and (node as Label).theme_type_variation == &"TooltipLabel":
			UiUtil.fit_tooltip(node))
	# 헤드리스(테스트)에서는 실제 창이 없으므로 아무것도 하지 않는다.
	if DisplayServer.get_name() == "headless":
		return
	_apply_initial_layout()
	var timer := Timer.new()
	timer.wait_time = WATCH_INTERVAL_SEC
	timer.autostart = true
	timer.timeout.connect(_watch)
	add_child(timer)


# ---------------------------------------------------------------- 공개 API

## 배율 설정. 0 = 자동. 왼쪽 아래 모서리를 고정한 채 크기가 바뀐다.
func set_scale(requested: int) -> void:
	Settings.set_value(&"window_scale", requested)
	_requested_scale = requested
	_apply_scale(requested)


func set_always_on_top(enabled: bool) -> void:
	_window().always_on_top = enabled
	Settings.set_value(&"always_on_top", enabled)


func is_always_on_top() -> bool:
	return _window().always_on_top


## 기본 위치(우하단)로 되돌리기.
func reset_position() -> void:
	_set_docked(true)
	_snap_to_dock()


## 배경을 누른 순간 호출 → OS 창 드래그 시작. 끝난 위치는 _watch()가 감지한다(저장하지 않음).
func begin_drag() -> void:
	_window().start_drag()


## Ctrl+휠 등으로 배율을 한 단계씩 바꾼다.
func step_scale(delta: int) -> void:
	set_scale(clampi(current_scale + delta, WindowLayout.MIN_SCALE, WindowLayout.MAX_SCALE))


# ---------------------------------------------------------------- 내부

func _window() -> Window:
	return get_tree().root


func _current_usable() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_window().current_screen)


func _screen_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for i in DisplayServer.get_screen_count():
		rects.append(DisplayServer.screen_get_usable_rect(i))
	return rects


func _apply_initial_layout() -> void:
	var win := _window()
	win.always_on_top = Settings.get_value(&"always_on_top")
	_requested_scale = Settings.get_value(&"window_scale")
	if OS.is_debug_build():
		# 테스트 실행은 항상 같은 크기(640×400)로 시작 — 저장된 배율은 바꾸지 않는다
		_requested_scale = DEBUG_START_SCALE
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--window-scale="):
				_requested_scale = int(arg.trim_prefix("--window-scale="))
	_apply_scale(_requested_scale, false)

	# 항상 주 모니터 기본 위치(우하단)에서 시작 (옮긴 위치는 기억하지 않는다)
	win.current_screen = DisplayServer.get_primary_screen()
	docked = true
	_snap_to_dock()
	_last_screens = _screen_rects()


func _apply_scale(requested: int, keep_anchor: bool = true) -> void:
	var win := _window()
	var usable := _current_usable()
	var wanted := requested
	if wanted <= 0:
		wanted = WindowLayout.auto_scale(DisplayServer.screen_get_size(win.current_screen))
	current_scale = WindowLayout.clamp_scale(wanted, usable)

	var old_size := win.size
	var new_size := WindowLayout.window_size(current_scale)
	win.size = new_size
	if keep_anchor:
		if docked:
			_snap_to_dock()
		else:
			var pos := WindowLayout.rescale_keep_bottom_right(win.position, old_size, new_size)
			win.position = WindowLayout.clamp_into(pos, new_size, usable)
			_last_position = win.position
	scale_changed.emit(current_scale)


func _snap_to_dock() -> void:
	var win := _window()
	win.position = WindowLayout.dock_position(_current_usable(), win.size)
	_last_position = win.position


func _set_docked(value: bool) -> void:
	if docked != value:
		docked = value
		docked_changed.emit(docked)


## 주기적으로 확인: 사용자가 창을 옮겼는지, 화면 구성(해상도·작업표시줄)이 바뀌었는지.
func _watch() -> void:
	# 드래그 중에는 위치를 건드리지 않는다(OS 드래그와 충돌 방지).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var win := _window()
	var screens := _screen_rects()
	var screens_changed := screens != _last_screens
	_last_screens = screens

	# 1) 사용자가 드래그로 옮김
	if win.position != _last_position:
		var usable := _current_usable()
		if WindowLayout.is_near_dock(win.position, win.size, usable):
			_set_docked(true)
			_snap_to_dock()
		else:
			_set_docked(false)
			_last_position = win.position

	# 2) 화면 구성 변경 또는 화면 밖으로 나감
	var idx := WindowLayout.screen_index_for(win.position, win.size, screens)
	if idx == -1:
		win.current_screen = DisplayServer.get_primary_screen()
		_set_docked(true)
		_apply_scale(_requested_scale)
		_snap_to_dock()
	elif screens_changed:
		_apply_scale(_requested_scale)  # 화면이 작아졌으면 배율도 줄임
		if docked:
			_snap_to_dock()
		else:
			win.position = WindowLayout.clamp_into(win.position, win.size, screens[idx])
			_last_position = win.position
	elif not docked:
		var clamped := WindowLayout.clamp_into(win.position, win.size, screens[idx])
		if clamped != win.position:
			win.position = clamped
			_last_position = win.position
