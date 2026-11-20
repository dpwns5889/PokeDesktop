extends GdUnitTestSuite
## 생성된 스프라이트·아이콘 검증 (기획서 7.4).
## 실패하면 tools/import_battle_sprites.gd, tools/import_icons.gd 를 실행한 뒤 --import 하세요.

const CELL := PokemonSprites.CELL
const ICONS := [&"poke_ball", &"great_ball", &"ultra_ball", &"exp_candy_s", &"exp_candy_m",
	&"fire_stone", &"water_stone", &"thunder_stone", &"leaf_stone", &"moon_stone"]


func test_every_species_has_sheet_with_expected_size() -> void:
	for s in GameData.all_species():
		var where := "%d %s" % [s.dex_id, s.name_ko]
		assert_bool(PokemonSprites.has_sheet(s)).override_failure_message("시트 없음: " + where).is_true()
		var tex := PokemonSprites.load_sheet(s)
		var rows := 2 if s.has_gender_sprites else 1
		assert_vector(Vector2i(tex.get_size())).override_failure_message(where).is_equal(Vector2i(CELL * 4, CELL * rows))


func test_every_frame_has_pixels_and_transparent_background() -> void:
	for s in GameData.all_species():
		var img := PokemonSprites.load_sheet(s).get_image()
		var rows := img.get_height() / CELL
		for r in rows:
			for c in 4:
				var cell := img.get_region(Rect2i(c * CELL, r * CELL, CELL, CELL))
				var used := cell.get_used_rect()
				assert_bool(used.size.x > 0).override_failure_message("빈 프레임: %d (%d,%d)" % [s.dex_id, c, r]).is_true()
				# 모서리 픽셀은 배경이었으므로 투명해야 한다
				assert_float(cell.get_pixel(0, 0).a).override_failure_message("배경 남음: %d" % s.dex_id).is_equal(0.0)


func test_make_frames_returns_two_frame_idle() -> void:
	var pikachu := GameData.get_species(25)
	for female in [false, true]:
		for shiny in [false, true]:
			var frames := PokemonSprites.make_frames(pikachu, female, shiny)
			assert_int(frames.get_frame_count(&"idle")).is_equal(2)
	var female_frame := PokemonSprites.make_frames(pikachu, true).get_frame_texture(&"idle", 0) as AtlasTexture
	assert_float(female_frame.region.position.y).is_equal(float(CELL))


func test_v01_item_icons_exist() -> void:
	for id in ICONS:
		var path := "res://assets/generated/icons/%s.png" % id
		assert_bool(ResourceLoader.exists(path)).override_failure_message("아이콘 없음: " + path).is_true()


## 도감 아틀라스 아이콘 (v0.99, tools/import_atlas_icons.py). 151종 모두 일반·색다름 목록용 24×24, 큰 것(v0.100) 32×32 가 있어야 한다.
func test_atlas_icons_cover_all_species() -> void:
	for s in GameData.all_species():
		for shiny in [false, true]:
			for big in [false, true]:
				var icon := PokemonSprites.atlas_icon(s, false, shiny, big)
				assert_object(icon).override_failure_message("아이콘 없음: %d %s" % [s.dex_id, s.name_en]).is_not_null()
				var n := UiUtil.ICON_BIG if big else UiUtil.ICON_SIZE
				assert_vector(Vector2i(icon.get_size())).is_equal(Vector2i(n, n))
				if shiny:
					assert_str(icon.resource_path).ends_with("_shiny.png")


func test_atlas_icon_shiny_and_female_variants() -> void:
	var pika := GameData.get_species(25)
	assert_str(PokemonSprites.atlas_icon(pika, true).resource_path).ends_with("pikachu-female.png")
	assert_str(PokemonSprites.atlas_icon(pika, false, true).resource_path).ends_with("pikachu_shiny.png")
	assert_str(PokemonSprites.atlas_icon(GameData.get_species(1), true).resource_path).ends_with("bulbasaur.png")   # 암컷 그림 없으면 일반
