class_name PokemonSprites
extends RefCounted
## 종별 전투 스프라이트 시트를 불러와 SpriteFrames를 만든다. (기획서 7.4)
##
## 시트 배치 (tools/import_battle_sprites.gd 가 생성):
##   열: 0 일반 프레임1 | 1 일반 프레임2 | 2 색이 다름 프레임1 | 3 색이 다름 프레임2
##   행: 0 수컷/공통 | 1 암컷 (has_gender_sprites 인 종만)
## 스프라이트가 없으면(저장소만 받은 경우 등) 플레이스홀더를 쓴다.

const CELL := 80
const SHEET_DIR := "res://assets/generated/sprites/gen%d"
const ANIM_FPS := 3.0

static var _placeholder: Texture2D


static func sheet_path(species: PokemonSpecies) -> String:
	return (SHEET_DIR % species.generation) + "/%04d.png" % species.dex_id


static func has_sheet(species: PokemonSpecies) -> bool:
	return ResourceLoader.exists(sheet_path(species))


static func load_sheet(species: PokemonSpecies) -> Texture2D:
	var path := sheet_path(species)
	if ResourceLoader.exists(path):
		return load(path)
	return _get_placeholder()


## 대기 애니메이션 "idle" 하나를 가진 SpriteFrames.
static func make_frames(species: PokemonSpecies, female: bool = false, shiny: bool = false) -> SpriteFrames:
	var sheet := load_sheet(species)
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", ANIM_FPS)
	frames.set_animation_loop(&"idle", true)
	if sheet == _placeholder:
		frames.add_frame(&"idle", sheet)
		return frames
	var row := 1 if (female and species.has_gender_sprites) else 0
	var col0 := 2 if shiny else 0
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(CELL * (col0 + i), CELL * row, CELL, CELL)
		frames.add_frame(&"idle", at)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	return frames


# ---------------------------------------------------------------- 오버월드(필드) 앞모습 (v0.28)

const OW_CELL := 32
const OW_DIR := "res://assets/generated/overworld/gen%d"


static func overworld_path(species: PokemonSpecies) -> String:
	return (OW_DIR % species.generation) + "/%04d.png" % species.dex_id


## 오버월드 앞모습 걷기 2프레임 (tools/import_overworld.gd 가 만든 64×32, 암컷 모습이 있으면 64×64).
## 파일이 없으면 빈 배열 → 호출하는 쪽이 아이콘 등으로 대신한다.
static func overworld_frames(species: PokemonSpecies, female: bool = false) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if species == null:
		return out
	var path := overworld_path(species)
	if not ResourceLoader.exists(path):
		return out
	var tex: Texture2D = load(path)
	var row := 1 if female and tex.get_height() >= OW_CELL * 2 else 0
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(OW_CELL * i, OW_CELL * row, OW_CELL, OW_CELL)
		out.append(at)
	return out


## 오버월드 걷기 시트 64×128 (v0.45, M12): 행 0 아래 / 1 위 / 2 왼쪽 / 3 오른쪽, 열 = 걷기 2프레임.
## 암컷 모습이 있는 종은 <dex>_f.png. 파일이 없으면 null.
static func overworld_walk_sheet(species: PokemonSpecies, female: bool = false) -> Texture2D:
	if species == null:
		return null
	var base := (OW_DIR % species.generation) + "/walk/%04d" % species.dex_id
	if female and ResourceLoader.exists(base + "_f.png"):
		return load(base + "_f.png")
	if ResourceLoader.exists(base + ".png"):
		return load(base + ".png")
	return null


## UI 아이콘 (v0.99, v0.100): 도감 아틀라스에서 잘라 만든 24×24(목록) 또는 32×32(big, 도감·엔트리 상자) (tools/import_atlas_icons.py).
## 암컷·색이 다른 그림이 없으면 일반 그림으로, 종 자체가 아틀라스에 없으면 null (호출하는 쪽이 오버월드 아이콘으로 대신).
const ICON_DIR := "res://assets/generated/icons/pokemon24/"
const ICON_DIR_BIG := "res://assets/generated/icons/pokemon/"


static func atlas_icon(species: PokemonSpecies, female: bool = false, shiny: bool = false, big: bool = false) -> Texture2D:
	if species == null:
		return null
	var names: Array[String] = [species.name_en]
	if female:
		names.push_front(species.name_en + "-female")
	var suffixes: Array[String] = [""]
	if shiny:
		suffixes.push_front("_shiny")
	for suffix in suffixes:
		for n in names:
			var path: String = (ICON_DIR_BIG if big else ICON_DIR) + n + suffix + ".png"
			if ResourceLoader.exists(path):
				return load(path)
	return null


static func _get_placeholder() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(24, 24, 32, 32), Color(0.3, 0.3, 0.35, 0.8))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder
