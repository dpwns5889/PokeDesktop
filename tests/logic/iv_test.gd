extends GdUnitTestSuite
## 개체치 (기획서 4.7.1, v0.55)


func test_iv_changes_stats_like_original_formula() -> void:
	# ((2×종족값 + 개체치) × 레벨 / 100) + 5, HP 는 + 레벨 + 10
	assert_int(Formulas.calc_stat(100, 50, false, 0)).is_equal(105)
	assert_int(Formulas.calc_stat(100, 50, false, 31)).is_equal(120)
	assert_int(Formulas.calc_stat(100, 50, true, 31)).is_equal(175)
	var base := {"hp": 45, "atk": 49, "def": 49, "spa": 65, "spd": 65, "spe": 45}
	var low := Formulas.calc_stats(base, 30, {}, {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var high := Formulas.calc_stats(base, 30, {}, Formulas.max_ivs())
	for k in Formulas.STAT_KEYS:
		assert_int(high[k]).is_greater(low[k])
	# 같은 레벨이어도 개체마다 다르다
	assert_dict(Formulas.calc_stats(base, 30)).is_equal(low)


func test_roll_ivs_range_and_grades() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for i in 300:
		var ivs := Formulas.roll_ivs(rng)
		assert_int(ivs.size()).is_equal(6)
		for k in ivs:
			assert_int(ivs[k]).is_between(0, Formulas.IV_MAX)
			seen[ivs[k]] = true
	assert_bool(seen.has(0) and seen.has(31)).is_true()
	assert_int(Formulas.iv_grade(31)).is_equal(2)
	assert_int(Formulas.iv_grade(25)).is_equal(1)
	assert_int(Formulas.iv_grade(24)).is_equal(0)
	assert_int(Formulas.iv_grade(10)).is_equal(0)
	assert_int(Formulas.iv_grade(9)).is_equal(-1)
	assert_int(Formulas.iv_grade(0)).is_equal(-1)


func test_caught_pokemon_have_ivs_and_old_saves_get_them() -> void:
	var inst := PlayerState.add_caught({&"dex_id": 16, &"level": 5, &"gender": &"male", &"region": &"grassland"})
	assert_int(inst.ivs.size()).is_equal(6)
	var st := PlayerState.stats_of(inst)
	assert_int(st[&"atk"]).is_equal(Formulas.calc_stat(45, 5, false, int(inst.ivs["atk"])))
	# v0.55 이전 세이브(개체치 없음) → 불러올 때 뽑고, 범위 밖 값은 자른다
	var fixed: Dictionary = PlayerState._valid_ivs(null)
	assert_int(fixed.size()).is_equal(6)
	var clipped: Dictionary = PlayerState._valid_ivs({"hp": 99, "atk": -4, "def": 10})
	assert_int(clipped["hp"]).is_equal(31)
	assert_int(clipped["atk"]).is_equal(0)
	assert_int(clipped["def"]).is_equal(10)
	PlayerState.pokemon.erase(inst)


func test_entry_reference_uses_max_ivs() -> void:
	var ref := Formulas.entry_reference_stats()
	assert_int(ref[&"atk"]).is_equal(Formulas.calc_stat(Formulas.ENTRY_REF_BASE, Formulas.ENTRY_REF_LEVEL, false, Formulas.IV_MAX))


func test_storage_stat_marks() -> void:
	var SP := preload("res://scenes/ui/storage_panel.gd")
	assert_str(SP.stat_bbcode(&"atk", 50, 31)).contains("★★")
	assert_str(SP.stat_bbcode(&"atk", 50, 27)).contains("★")
	assert_str(SP.stat_bbcode(&"atk", 50, 27)).not_contains("★★")
	assert_str(SP.stat_bbcode(&"atk", 50, 3)).contains(SP.IV_LOW_COLOR)
	assert_str(SP.stat_bbcode(&"atk", 50, 15)).is_equal("공격 50")
