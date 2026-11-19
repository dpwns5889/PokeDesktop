extends SceneTree
## 전투 바닥(포켓몬이 올라서는 타원 발판) 시트 → 게임에서 쓰는 사본. (기획서 6.1, 7.4, v0.35)
##
## 실행: <godot> --headless --path . -s res://tools/import_battle_ground.gd
## 이후:  <godot> --headless --path . --import
##
## 원본 assets/sprites/Ground.png (384×192): 128×64 칸이 3열 × 3행, 배경 투명. 번호는 왼쪽 위부터 가로로:
##   0 풀밭   1 물     2 모래
##   3 흙길   4 얼음   5 진흙
##   6 바위   7 눈     8 어두운 바위
## 지역마다 쓸 번호는 tools/source/regions_gen1.json 의 "battle_ground".
## assets/sprites 는 내보내기에서 빠지므로 assets/generated/ui/ground.png 로 복사해 쓴다.

const SRC := "res://assets/sprites/Ground.png"
const OUT := "res://assets/generated/ui/ground.png"
const CELL := Vector2i(128, 64)
const GRID := Vector2i(3, 3)


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		push_error("시트를 읽지 못했습니다: %s" % SRC)
		quit(1)
		return
	var want := CELL * GRID
	if img.get_size() != want:
		push_error("크기가 %s 입니다(예상 %s)." % [img.get_size(), want])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("전투 바닥 %d칸 저장 → %s" % [GRID.x * GRID.y, OUT])
	quit(0)
