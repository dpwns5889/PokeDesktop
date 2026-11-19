extends SceneTree
## 말풍선 감정 표현 시트 → 게임에서 쓰는 사본. (기획서 6.1, 7.4, v0.33)
##
## 실행: <godot> --headless --path . -s res://tools/import_emote.gd
## 이후:  <godot> --headless --path . --import
##
## 원본 assets/sprites/Emote.png (96×16, v0.34): 16×16 칸 6개 = [ . | .. | ... | ! | ?1 | ?2 ]  (배경 투명)
## assets/sprites 는 내보내기에서 빠지므로(원본 보관용) assets/generated/ui/emote.png 로 복사해 쓴다.

const SRC := "res://assets/sprites/Emote.png"
const OUT := "res://assets/generated/ui/emote.png"
const CELL := 16
const FRAMES := 6


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		push_error("시트를 읽지 못했습니다: %s" % SRC)
		quit(1)
		return
	if img.get_width() != CELL * FRAMES or img.get_height() != CELL:
		push_error("크기가 %d×%d 입니다(예상 %d×%d)." % [img.get_width(), img.get_height(), CELL * FRAMES, CELL])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("말풍선 %d칸 저장 → %s" % [FRAMES, OUT])
	quit(0)
