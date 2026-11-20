class_name UiUtil
extends RefCounted
## 패널들이 같이 쓰는 표시 도우미: 포켓몬 아이콘, 날짜, 타입 색, 성별 색.

const GENDER_MARK := {"male": "♂", "female": "♀", "none": ""}
## 툴팁 최대 폭 (기준 해상도). 창 폭 320 보다 충분히 작게 → Godot 가 창 안으로 옮길 수 있다 (v0.36)
const TOOLTIP_MAX_WIDTH := 200.0
const STAT_NAMES := {&"hp": "HP", &"atk": "공격", &"def": "방어", &"spa": "특공", &"spd": "특방", &"spe": "스피드"}

## 툴팁 라벨이 TOOLTIP_MAX_WIDTH 보다 넓으면 그 폭 안에서 줄을 바꾼다 (v0.36).
## 툴팁이 창보다 넓으면 창 안으로 옮겨도 오른쪽이 잘리기 때문. 짧은 툴팁은 그대로 둔다.
## 한국어가 음절 중간에서 끊기지 않도록 띄어쓰기 자리에서만 줄을 바꾼다(자동 줄바꿈 대신 직접 \n 을 넣음).
## WindowManager 가 새로 생기는 모든 툴팁 라벨(theme_type_variation = TooltipLabel)에 부른다.
static func fit_tooltip(label: Label) -> void:
	if label.text.is_empty():
		return
	var font := label.get_theme_font(&"font", &"TooltipLabel")
	var size := label.get_theme_font_size(&"font_size", &"TooltipLabel")
	var measure := func(s: String) -> float:
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if font else s.length() * 9.0
	label.text = wrap_text(label.text, TOOLTIP_MAX_WIDTH, measure)


## 띄어쓰기 자리에서만 줄을 바꿔 각 줄이 max_width 를 넘지 않게 한다(한 단어가 더 길면 그 단어만 한 줄).
## 원래 줄바꿈은 그대로 둔다. measure = Callable(String) -> float (글자 폭)
static func wrap_text(text: String, max_width: float, measure: Callable) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		if measure.call(para) <= max_width:
			out.append(para)
			continue
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line.is_empty() else line + " " + word
			if line.is_empty() or measure.call(trial) <= max_width:
				line = trial
			else:
				out.append(line)
				line = word
		out.append(line)
	return "\n".join(out)


## 타입 대표 색 (다른 세대 타입도 미리 포함)
const TYPE_COLORS := {
	&"normal": Color("a8a878"), &"fire": Color("f08030"), &"water": Color("6890f0"),
	&"electric": Color("f8d030"), &"grass": Color("78c850"), &"ice": Color("98d8d8"),
	&"fighting": Color("c03028"), &"poison": Color("a040a0"), &"ground": Color("e0c068"),
	&"flying": Color("a890f0"), &"psychic": Color("f85888"), &"bug": Color("a8b820"),
	&"rock": Color("b8a038"), &"ghost": Color("705898"), &"dragon": Color("7038f8"),
	&"dark": Color("705848"), &"steel": Color("b8b8d0"), &"fairy": Color("ee99ac"),
}

## 성별 색: 수컷 파랑, 암컷 분홍. 어두운 배경(패널)용과 밝은 배경(메인 장면)용.
const MALE_ON_DARK := Color("6aa8ff")
const FEMALE_ON_DARK := Color("ff8ac4")
const MALE_ON_LIGHT := Color("2a5fd0")
const FEMALE_ON_LIGHT := Color("d6337f")


## UI 아이콘 크기 (v0.55): 오버월드 앞모습(32×32 칸)에서 그림 부분을 24×24 로 잘라 1:1 로 보인다.
const ICON_SIZE := 24
static var _icon_cache := {}


## 포켓몬 아이콘 (목록·도감 등). v0.99: 도감 아틀라스 그림(색이 다른·암컷 포함). 아틀라스에 없는 종은
## v0.55 방식 — 오버월드 앞모습 첫 프레임을 그림 아래 가운데 기준 24×24 로 자른 것. 그것도 없으면 전투 스프라이트 첫 프레임.
static func pokemon_icon(s: PokemonSpecies, female: bool = false, shiny: bool = false) -> Texture2D:
	if s == null:
		return null
	var key := "%d:%s:%s" % [s.dex_id, female, shiny]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var atlas := PokemonSprites.atlas_icon(s, female, shiny)   # v0.99: 도감 아틀라스 그림 우선
	if atlas:
		_icon_cache[key] = atlas
		return atlas
	var frames := PokemonSprites.overworld_frames(s, female)
	var at := AtlasTexture.new()
	if frames.is_empty():
		at.atlas = PokemonSprites.load_sheet(s)
		at.region = Rect2(0, 0, PokemonSprites.CELL, PokemonSprites.CELL)
	else:
		var f: AtlasTexture = frames[0]
		at.atlas = f.atlas
		at.region = icon_region(f)
	_icon_cache[key] = at
	return at


## 개체(포켓몬 딕셔너리)의 성별·색이 다름에 맞는 아이콘 (v0.99)
static func individual_icon(p: Dictionary) -> Texture2D:
	return pokemon_icon(GameData.get_species(p.dex_id), String(p.get("gender", "")) == "female", bool(p.get("shiny", false)))


## 오버월드 칸(32×32) 안에서 그림 아래 가운데를 기준으로 24×24 영역
static func icon_region(frame: AtlasTexture) -> Rect2:
	var cell := frame.region
	var used := Rect2i(0, 0, int(cell.size.x), int(cell.size.y))
	var img := frame.atlas.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r := img.get_region(Rect2i(cell)).get_used_rect()
		if r.size != Vector2i.ZERO:
			used = r
	var n := float(ICON_SIZE)
	var x := clampf(roundf(used.position.x + used.size.x / 2.0 - n / 2.0), 0.0, cell.size.x - n)
	var y := clampf(float(used.end.y) - n, 0.0, cell.size.y - n)
	return Rect2(cell.position + Vector2(x, y), Vector2(n, n))


## 유닉스 시각 → "11/16 14:05" (시스템 시간대)
static func date_text(unix: int) -> String:
	if unix <= 0:
		return "-"
	var bias_sec := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_sec)
	return "%d/%d %02d:%02d" % [d.month, d.day, d.hour, d.minute]


static func type_color(t: StringName) -> Color:
	return TYPE_COLORS.get(t, Color(0.6, 0.6, 0.6))


## RichTextLabel 용: 타입 이름을 대표 색으로
static func type_bbcode(t: StringName) -> String:
	return "[color=#%s]%s[/color]" % [type_color(t).to_html(false), GameData.type_name(t)]


## RichTextLabel 용: 지역 이름을 지역 대표 타입(main_types 첫 번째)의 색으로 (기획서 4.4, v0.89). 타입이 없으면 색 없이
static func region_bbcode(region: RegionData) -> String:
	if region.main_types.is_empty():
		return region.name_ko
	return "[color=#%s]%s[/color]" % [type_color(region.main_types[0]).to_html(false), region.name_ko]


## RichTextLabel 용: 원정지 이름을 그 원정지 지역의 대표 타입 색으로 (기획서 6.2, v0.94).
## 지역 = 해금 조건의 지역(region_unlocked), 조건이 없으면 초원
static func expedition_bbcode(x: ExpeditionData) -> String:
	var region_id: StringName = &"grassland"
	for c in x.unlock_conditions:
		if c.get("type") == "region_unlocked":
			region_id = StringName(c.value)
	var r := GameData.get_region(region_id)
	if r == null or r.main_types.is_empty():
		return x.name_ko
	return "[color=#%s]%s[/color]" % [type_color(r.main_types[0]).to_html(false), x.name_ko]


static func types_bbcode(types: Array, sep := " / ") -> String:
	return sep.join(types.map(func(t) -> String: return type_bbcode(StringName(t))))


## 성별 기호 색. 무성이면 빈 문자열(표시하지 않음).
static func gender_bbcode(gender: String, dark_bg := true) -> String:
	match gender:
		"male":
			return "[color=#%s]♂[/color]" % (MALE_ON_DARK if dark_bg else MALE_ON_LIGHT).to_html(false)
		"female":
			return "[color=#%s]♀[/color]" % (FEMALE_ON_DARK if dark_bg else FEMALE_ON_LIGHT).to_html(false)
	return ""


## 한 줄짜리 RichTextLabel (bbcode, 내용 높이에 맞춤, 클릭은 통과)
static func rich_label(fit_height := true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit_height
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## 컨테이너에 타입 상자들을 붙인다
static func add_type_badges(container: Container, types: Array) -> void:
	for t in types:
		var b := TypeBadge.new()
		container.add_child(b)
		b.setup(StringName(t))
