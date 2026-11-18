extends Node
## 창 배치(기본 위치: 우하단)·드래그·배율·always on top. (기획서 3장)
##
## 위치 규칙
## - 실행할 때마다 항상 주 모니터 우하단(기본 위치)에 연다. 옮긴 위치는 저장하지 않는다.
## - 도킹(docked): 기본 위치에 붙은 상태. 해상도·작업표시줄이 바뀌면 새 기본 위치로 따라간다.
## - 자유 위치: 실행 중 드래그로 옮긴 상태. 화면 밖으로 나가면 안으로 보정한다(종료하면 잊는다).
##
## 전체화면 앱일 때 숨기기 (v0.77, 설정 hide_on_fullscreen + 항상 위에 표시)
## Godot 에는 다른 앱의 창을 보는 API 가 없어서, PowerShell 감시 스크립트(FULLSCREEN_WATCH_PS1)를 띄워
## 맨 앞 창이 우리 창이 있는 모니터 전체를 덮는지 1초마다 본다. Godot 는 메인 창을 숨길 수 없어서("Can't change visibility of
## main window") 숨기기·다시 보이기도 스크립트가 Win32 ShowWindow 로 한다(다시 보일 때 포커스를 빼앗지 않음).
## 상태는 "1"/"0" 으로 알려 준다(바뀔 때만). 끌 때는 정지 파일을 만들면 창을 보이게 하고 끝난다. 숨긴 동안에도 게임은 그대로 흐른다.

signal scale_changed(scale: int)
signal docked_changed(docked: bool)
signal move_mode_changed(on: bool)

const WATCH_INTERVAL_SEC := 1.0

## 개발(디버그) 빌드에서 시작할 때의 배율: 640×400. 실행 인자 `-- --window-scale=N` 으로 바꿀 수 있다.
const DEBUG_START_SCALE := 2

var current_scale: int = 1
var docked: bool = true
## 창 옮기기 모드 (v0.60): 켜져 있을 때만 배경을 잡고 창을 끌 수 있다. 저장하지 않음(실행할 때마다 꺼짐).
var move_mode := false:
	set(v):
		if move_mode == v:
			return
		move_mode = v
		move_mode_changed.emit(v)
## 이번 실행에서 요청된 배율(0 = 자동). 화면 구성이 바뀌어 다시 맞출 때 쓴다.
var _requested_scale: int = 0

var _last_position := Vector2i.ZERO
var _last_screens: Array[Rect2i] = []

## 전체화면 감시 프로세스 (-1 = 안 돌아감), 그 출력을 읽는 스레드, 지금 숨겼는가
var _fs_pid := -1
var _fs_thread: Thread
var _fs_stop_file := ""
var _fs_seq := 0
var fullscreen_hidden := false

## 맨 앞 창(바탕화면·작업표시줄·우리 창 제외)이 우리 창과 같은 모니터 전체를 덮으면 "1". 부모(게임)가 끝나면 스스로 끝난다.
const FULLSCREEN_WATCH_PS1 := r"""param([int]$ParentPid, [long]$Hwnd, [string]$StopFile)
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class FsWatch {
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
	[DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
	[DllImport("user32.dll")] static extern IntPtr GetShellWindow();
	[DllImport("user32.dll")] static extern IntPtr GetDesktopWindow();
	[DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint f);
	[DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
	[DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] static extern bool SetProcessDPIAware();
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
	public static void Init() { SetProcessDPIAware(); }
	public static bool IsFullscreen(IntPtr mine) {
		IntPtr fg = GetForegroundWindow();
		if (fg == IntPtr.Zero || fg == mine || fg == GetShellWindow() || fg == GetDesktopWindow()) return false;
		StringBuilder cls = new StringBuilder(64);
		GetClassName(fg, cls, 64);
		string c = cls.ToString();
		if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd") return false;
		IntPtr mon = MonitorFromWindow(fg, 2);
		if (mon != MonitorFromWindow(mine, 2)) return false;
		MONITORINFO mi = new MONITORINFO();
		mi.cbSize = Marshal.SizeOf(mi);
		if (!GetMonitorInfo(mon, ref mi)) return false;
		RECT r;
		if (!GetWindowRect(fg, out r)) return false;
		return r.L <= mi.rcMonitor.L && r.T <= mi.rcMonitor.T && r.R >= mi.rcMonitor.R && r.B >= mi.rcMonitor.B;
	}
}
"@
[FsWatch]::Init()
$mine = [IntPtr]$Hwnd
$last = ''
while ($true) {
	if (-not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { break }
	if (Test-Path -LiteralPath $StopFile) {
		if ($last -eq '1') { [void][FsWatch]::ShowWindow($mine, 4) }
		Remove-Item -LiteralPath $StopFile -ErrorAction SilentlyContinue
		break
	}
	$v = '0'
	if ([FsWatch]::IsFullscreen($mine)) { $v = '1' }
	if ($v -ne $last) {
		if ($v -eq '1') { [void][FsWatch]::ShowWindow($mine, 0) } elseif ($last -eq '1') { [void][FsWatch]::ShowWindow($mine, 4) }
		[Console]::Out.WriteLine($v); [Console]::Out.Flush(); $last = $v
	}
	Start-Sleep -Milliseconds 1000
}
"""


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
	EventBus.setting_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key in [&"hide_on_fullscreen", &"always_on_top"]:
			_sync_fullscreen_watch())
	_sync_fullscreen_watch()


func _exit_tree() -> void:
	_stop_fullscreen_watch(true)


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


# ---------------------------------------------------------------- 전체화면 앱일 때 숨기기 (v0.77)

## 설정에 맞춰 감시를 켜거나 끈다 (항상 위에 표시가 꺼져 있으면 전체화면 앱이 알아서 덮으므로 감시하지 않음)
func _sync_fullscreen_watch() -> void:
	var want: bool = OS.get_name() == "Windows" and Settings.get_value(&"hide_on_fullscreen") and _window().always_on_top
	if want and _fs_pid < 0:
		_start_fullscreen_watch()
	elif not want and _fs_pid >= 0:
		_stop_fullscreen_watch()


func _start_fullscreen_watch() -> void:
	var path := ProjectSettings.globalize_path("user://fullscreen_watch.ps1")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("전체화면 감시 스크립트를 쓰지 못했습니다: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(FULLSCREEN_WATCH_PS1)
	f.close()
	var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	_fs_seq += 1
	_fs_stop_file = ProjectSettings.globalize_path("user://fullscreen_watch_%d_%d.stop" % [OS.get_process_id(), _fs_seq])
	var info := OS.execute_with_pipe("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden", "-File", path, "-ParentPid", str(OS.get_process_id()), "-Hwnd", str(hwnd),
		"-StopFile", _fs_stop_file])
	if info.is_empty():
		push_warning("전체화면 감시를 시작하지 못했습니다 (PowerShell 없음?)")
		return
	_fs_pid = int(info.pid)
	_fs_thread = Thread.new()
	_fs_thread.start(_read_fullscreen_pipe.bind(info.stdio))


## 끄기: 정지 파일 → 스크립트가 숨긴 창을 다시 보이게 하고 끝난다(1초 안). 게임 종료 때(kill)는 바로 끝낸다.
func _stop_fullscreen_watch(kill: bool = false) -> void:
	if _fs_pid < 0:
		return
	if kill:
		OS.kill(_fs_pid)
	else:
		var f := FileAccess.open(_fs_stop_file, FileAccess.WRITE)
		if f:
			f.close()
		else:
			OS.kill(_fs_pid)
	_fs_pid = -1
	if _fs_thread:
		_fs_thread.wait_to_finish()   # 프로세스가 끝나면 파이프가 닫혀 읽기가 끝난다
		_fs_thread = null
	fullscreen_hidden = false


## 스레드: 감시 스크립트의 줄을 읽어 메인 스레드로 넘긴다. 프로세스가 끝나면 끝난다.
func _read_fullscreen_pipe(pipe: FileAccess) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line := pipe.get_line().strip_edges()
		if line == "1" or line == "0":
			_set_fullscreen_hidden.call_deferred(line == "1")


func _set_fullscreen_hidden(on: bool) -> void:
	fullscreen_hidden = on
