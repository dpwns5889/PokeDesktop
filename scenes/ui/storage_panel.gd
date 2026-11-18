extends OverlayPanel
## 보관함 패널. (기획서 4.7, 6.2)
## 왼쪽: 보유 포켓몬 목록(정렬, 아래까지 스크롤) / 오른쪽: 고른 포켓몬의 정보
## 오른쪽 — 위: 전투 모습(64×64) + 옆에 이름·성별·즐겨찾기 별 / 레벨 / 타입 (v0.55, 별 v0.71)
##   아래: 상태(원정 중·색이 다른·엔트리), 경험치, 능력치(개체치 표시: 최대 ★★, 높음 ★, 낮음 = 하늘색 값, v0.55), 특성 상자
## 오른쪽 아래 버튼(M8): 경험사탕 S·M(왼쪽 클릭 1개, 오른쪽 클릭 = 다음 레벨까지), 박사에게 보내기
## 제목 줄 "중복 보내기": 종마다 가장 좋은 1마리를 남기고 나머지를 박사에게 (즐겨찾기·원정 중·특성 있는 개체 제외)
## 목록 색: 원정 중 = 하늘색, 엔트리 = 연두색, 즐겨찾기 = 금색 + 앞에 ★ (v0.71, 잠금 대신). 필터는 이후 추가.

const SORTS := ["도감번호", "레벨", "포획일"]
const LIST_WIDTH := 150
const ENTRY_COLOR := Color(0.6, 0.95, 0.55)
const SHINY_COLOR := Color(1.0, 0.85, 0.35)
const FAVORITE_COLOR := Color(1, 0.85, 0.35)
## 전투 모습 칸 (v0.55)
const SPRITE_BOX := 64
## 개체치 표시 색 (v0.55)
const IV_STAR_COLOR := "#ffd34a"
const IV_LOW_COLOR := "#8fd3ff"

var _count: Label
var _sort: OptionButton
var _list: ItemList
var _uids: Array[String] = []
var _icon_cache: Dictionary = {}
var _selected_uid := ""

# 오른쪽 정보
var _info_scroll: ScrollContainer
var _hint: Label
var _info: VBoxContainer
var _name: RichTextLabel
var _sprite: TextureRect
var _level: Label
## 이름·성별 오른쪽의 즐겨찾기 별 버튼 (v0.71). 켜면 금색, 끄면 흐린 회색
var _fav: Button
var _types: HBoxContainer
var _status: HFlowContainer
var _exp_bar: ProgressBar
var _exp_label: Label
var _stat_labels: Dictionary = {}   # stat key -> RichTextLabel
var _traits_box: VBoxContainer
var _evo_box: HFlowContainer
# 오른쪽 아래 버튼
var _actions: HBoxContainer
var _candy_s: Button
var _candy_m: Button
var _send: Button
var _message: Label


func _panel_title() -> String:
	return "보관함"


func _ready() -> void:
	super()
	add_header_button("중복 보내기", _on_bulk_transfer)
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: _refresh_if_visible())
	EventBus.pokemon_evolved.connect(func(_u: String, _f: int, _t: int) -> void: _refresh_if_visible())
	EventBus.evolution_cancelled.connect(func(_u: String) -> void: _refresh_if_visible())
	PlayerState.changed.connect(_refresh_if_visible)


func _build_content(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 4)
	box.add_child(row)

	# 왼쪽: 목록 (아래 끝까지)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	row.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_count = Label.new()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	_sort = OptionButton.new()
	_sort.focus_mode = Control.FOCUS_NONE
	for s in SORTS:
		_sort.add_item(s)
	_sort.item_selected.connect(func(_i: int) -> void: refresh())
	top.add_child(_sort)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(UiUtil.ICON_SIZE, UiUtil.ICON_SIZE)   # v0.55 오버월드 아이콘 1:1
	_list.item_selected.connect(_on_selected)
	left.add_child(_list)

	# 오른쪽: 정보(내용이 길면 스크롤) + 아래 버튼 줄
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override(&"separation", 2)
	row.add_child(right_col)
	_info_scroll = ScrollContainer.new()
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(_info_scroll)
	_message = Label.new()
	_message.add_theme_color_override(&"font_color", Color(1, 0.85, 0.35))
	# 긴 결과 문구("12마리를 보냈다! 경험사탕 M 3, 경험사탕 S 9")가 한 줄이면 오른쪽 칸을 넓혀 버튼까지
	# 패널 밖으로 밀어냈다 → 칸 폭에 맞춰 줄바꿈 (v0.66)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.visible = false
	right_col.add_child(_message)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override(&"separation", 2)
	right_col.add_child(_actions)
	_candy_s = _small_button(_on_candy_input.bind(ProfessorManager.CANDY_S))
	_candy_m = _small_button(_on_candy_input.bind(ProfessorManager.CANDY_M))
	_send = _small_button(func(_e: InputEvent) -> void: pass)
	_send.text = "보내기"
	_send.tooltip_text = "박사에게 보내고 경험사탕을 받는다"
	_send.pressed.connect(_on_send)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 3)
	_info_scroll.add_child(right)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_hint)

	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override(&"separation", 3)
	right.add_child(_info)
	# 위: 전투 모습 + 이름·성별 / 레벨 / 타입 (v0.55)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	_info.add_child(head)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(SPRITE_BOX, SPRITE_BOX)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(_sprite)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override(&"separation", 1)
	head.add_child(side)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 3)
	side.add_child(name_row)
	_name = UiUtil.rich_label()
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼 → 별이 성별 바로 오른쪽에
	name_row.add_child(_name)
	_fav = Button.new()
	_fav.text = "★"
	_fav.flat = true
	_fav.focus_mode = Control.FOCUS_NONE
	_fav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fav.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		_fav.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_fav.pressed.connect(_on_favorite)
	name_row.add_child(_fav)
	_level = Label.new()
	side.add_child(_level)
	_types = HBoxContainer.new()
	_types.add_theme_constant_override(&"separation", 3)
	side.add_child(_types)
	_status = HFlowContainer.new()
	_status.add_theme_constant_override(&"h_separation", 6)
	_info.add_child(_status)
	# 진화 버튼 (M9): 레벨 진화 "진화하기", 가진 진화의 돌마다 돌 이름 버튼
	_evo_box = HFlowContainer.new()
	_evo_box.add_theme_constant_override(&"h_separation", 2)
	_info.add_child(_evo_box)

	var exp_row := HBoxContainer.new()
	_info.add_child(exp_row)
	_exp_bar = ProgressBar.new()
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(60, 6)
	_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.85, 1.0)
	_exp_bar.add_theme_stylebox_override(&"fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.16)
	_exp_bar.add_theme_stylebox_override(&"background", bg)
	exp_row.add_child(_exp_bar)
	_exp_label = Label.new()
	exp_row.add_child(_exp_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 8)
	stats.add_theme_constant_override(&"v_separation", 0)
	_info.add_child(stats)
	for k in Formulas.STAT_KEYS:
		var l := UiUtil.rich_label()
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		stats.add_child(l)
		_stat_labels[k] = l

	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override(&"separation", 2)
	_info.add_child(_traits_box)


func refresh() -> void:
	_count.text = "%d/%d" % [PlayerState.storage_count(), PlayerState.storage_capacity]
	var items: Array[Dictionary] = PlayerState.pokemon.duplicate()
	match _sort.selected:
		0: items.sort_custom(func(a, b): return a.dex_id < b.dex_id or (a.dex_id == b.dex_id and a.level > b.level))
		1: items.sort_custom(func(a, b): return a.level > b.level or (a.level == b.level and a.dex_id < b.dex_id))
		2: items.sort_custom(func(a, b): return a.caught_at > b.caught_at)
	_list.clear()
	_uids.clear()
	var keep := -1
	for p in items:
		var s := GameData.get_species(p.dex_id)
		var label := s.name_ko if s else "No.%d" % p.dex_id
		var fav: bool = p.get("favorite", false)
		var idx := _list.add_item("%s%s Lv%d" % ["★" if fav else "", label, p.level])
		if s:
			if not _icon_cache.has(s.dex_id):
				_icon_cache[s.dex_id] = UiUtil.pokemon_icon(s)
			_list.set_item_icon(idx, _icon_cache[s.dex_id])
		if PlayerState.is_busy(p.uid):
			_list.set_item_custom_fg_color(idx, Color(0.6, 0.85, 1))
		elif PlayerState.is_entry(p.uid):
			_list.set_item_custom_fg_color(idx, ENTRY_COLOR)
		elif fav:
			_list.set_item_custom_fg_color(idx, FAVORITE_COLOR)
		_uids.append(p.uid)
		if p.uid == _selected_uid:
			keep = idx
	if keep >= 0:
		_list.select(keep)
		_show_info(PlayerState.find_pokemon(_selected_uid))
	else:
		_selected_uid = ""
		_show_info({})


func _on_selected(index: int) -> void:
	_selected_uid = _uids[index]
	_show_message("")
	_show_info(PlayerState.find_pokemon(_selected_uid))


func _show_info(p: Dictionary) -> void:
	_update_actions(p)
	_update_evolution_buttons(p)
	_info.visible = not p.is_empty()
	_hint.visible = p.is_empty()
	if p.is_empty():
		_hint.text = "포켓몬을 누르면 정보를 볼 수 있다" if PlayerState.storage_count() > 0 else "아직 잡은 포켓몬이 없다"
		return
	var s := GameData.get_species(p.dex_id)
	# 성별: 수컷 파랑, 암컷 분홍, 무성은 표시하지 않음
	var g := UiUtil.gender_bbcode(p.gender)
	_name.text = "%s%s" % [s.name_ko if s else "?", (" " + g) if g != "" else ""]
	_level.text = "Lv%d" % p.level
	_update_favorite(p)
	_sprite.texture = battle_portrait(s, p.gender == "female", p.get("shiny", false))
	for c in _types.get_children():
		_types.remove_child(c)
		c.queue_free()
	if s:
		UiUtil.add_type_badges(_types, s.types)
	for c in _status.get_children():
		_status.remove_child(c)
		c.queue_free()
	if PlayerState.is_busy(p.uid):
		var busy := Label.new()
		busy.text = "원정 중"
		busy.add_theme_color_override(&"font_color", Color(0.6, 0.85, 1))
		_status.add_child(busy)
	if p.get("shiny", false):
		var shiny := Label.new()
		shiny.text = "색이 다른"
		shiny.add_theme_color_override(&"font_color", SHINY_COLOR)
		_status.add_child(shiny)
	if PlayerState.is_entry(p.uid):
		var entry := Label.new()
		entry.text = "엔트리"
		entry.add_theme_color_override(&"font_color", ENTRY_COLOR)
		_status.add_child(entry)

	if p.level >= Formulas.MAX_POKEMON_LEVEL:
		_exp_bar.max_value = 1
		_exp_bar.value = 1
		_exp_label.text = "최대"
	else:
		var need := Formulas.exp_to_next(p.level)
		_exp_bar.max_value = need
		_exp_bar.value = int(p.get("exp", 0))
		_exp_label.text = "%d/%d" % [p.get("exp", 0), need]

	var st := PlayerState.stats_of(p)
	var ivs: Dictionary = p.get("ivs", {})
	for k in Formulas.STAT_KEYS:
		_stat_labels[k].text = stat_bbcode(k, int(st.get(k, 0)), int(ivs.get(String(k), -1)))

	for c in _traits_box.get_children():
		c.queue_free()
	var traits: Array = p.get("traits", [])
	if traits.is_empty():
		var none := Label.new()
		none.text = "특성 없음"
		none.add_theme_color_override(&"font_color", Color(0.6, 0.62, 0.7))
		_traits_box.add_child(none)
	for t in traits:
		var td := GameData.get_trait(StringName(t))
		if td == null:
			continue
		var badge := TraitBadge.new()
		badge.setup(td)
		_traits_box.add_child(badge)
	_info_scroll.scroll_vertical = 0



## 능력치 한 칸 (v0.55): "공격 23★★" — 개체치 최대 ★★, 높음 ★, 낮음이면 값이 하늘색. iv < 0 = 모름(표시 없음)
static func stat_bbcode(key: StringName, value: int, iv: int) -> String:
	var v := str(value)
	var mark := ""
	if iv >= 0:
		match Formulas.iv_grade(iv):
			2:
				mark = "[color=%s]★★[/color]" % IV_STAR_COLOR
			1:
				mark = "[color=%s]★[/color]" % IV_STAR_COLOR
			-1:
				v = "[color=%s]%s[/color]" % [IV_LOW_COLOR, v]
	return "%s %s%s" % [UiUtil.STAT_NAMES[key], v, mark]


## 전투 모습 첫 프레임을 그림 부분 기준으로 잘라 SPRITE_BOX 칸에 1:1 로 (그림이 칸보다 크면 줄여서 맞춘다)
func battle_portrait(s: PokemonSpecies, female: bool, shiny: bool) -> Texture2D:
	if s == null:
		return null
	var frames := PokemonSprites.make_frames(s, female, shiny)
	var tex := frames.get_frame_texture(&"idle", 0)
	var at := tex as AtlasTexture
	if at == null:
		return tex
	var cell := at.region
	var used := Rect2(Vector2.ZERO, cell.size)
	var img := at.atlas.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r := img.get_region(Rect2i(cell)).get_used_rect()
		if r.size != Vector2i.ZERO:
			used = Rect2(r)
	var n := float(SPRITE_BOX)
	var region: Rect2
	if used.size.x <= n and used.size.y <= n:
		var x := clampf(roundf(used.get_center().x - n / 2.0), 0.0, cell.size.x - n)
		var y := clampf(roundf(used.get_center().y - n / 2.0), 0.0, cell.size.y - n)
		region = Rect2(Vector2(x, y), Vector2(n, n))
		_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		region = used
		_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var out := AtlasTexture.new()
	out.atlas = at.atlas
	out.region = Rect2(cell.position + region.position, region.size)
	return out


# ---------------------------------------------------------------- 버튼 (M8)

func _small_button(on_input: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override(&"h_separation", 1)
	b.expand_icon = false
	b.gui_input.connect(on_input)
	_actions.add_child(b)
	return b


func _update_actions(p: Dictionary) -> void:
	_actions.visible = not p.is_empty()
	if p.is_empty():
		return
	var busy := PlayerState.is_busy(p.uid)
	var maxed: bool = p.level >= Formulas.MAX_POKEMON_LEVEL
	for pair in [[_candy_s, ProfessorManager.CANDY_S], [_candy_m, ProfessorManager.CANDY_M]]:
		var b: Button = pair[0]
		var item := GameData.get_item(pair[1])
		var n := PlayerState.item_count(pair[1])
		b.icon = item.load_icon() if item else null
		# 개수가 길어지면 버튼 줄이 패널 오른쪽을 뚫었다 → 개수는 아이콘 위에 겹쳐 그린다 (v0.66)
		b.text = ""
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_candy_count_label(b).text = str(n)
		b.disabled = busy or maxed or n <= 0
		_candy_count_label(b).modulate.a = 0.5 if b.disabled else 1.0
		b.tooltip_text = "%s 주기\n왼쪽 클릭: 1개\n오른쪽 클릭: 다음 레벨까지" % (item.name_ko if item else "")
	_send.disabled = ProfessorManager.transfer_block_reason(p) != ""


## 사탕 버튼 위에 겹치는 개수 글자(오른쪽 아래, 테두리). 처음 부를 때 만든다.
func _candy_count_label(b: Button) -> Label:
	var l := b.get_node_or_null(^"Count") as Label
	if l:
		return l
	l = Label.new()
	l.name = "Count"
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_right = -2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_constant_override(&"outline_size", 3)
	l.add_theme_color_override(&"font_outline_color", Color(0.08, 0.09, 0.13))
	l.add_theme_constant_override(&"line_spacing", 0)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return l


## 사탕 버튼: 왼쪽 클릭 1개, 오른쪽 클릭 = 다음 레벨까지 필요한 만큼
func _on_candy_input(event: InputEvent, item_id: StringName) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or _selected_uid == "":
		return
	var b := _candy_s if item_id == ProfessorManager.CANDY_S else _candy_m
	if b.disabled:
		return
	var r: Dictionary
	if mb.button_index == MOUSE_BUTTON_LEFT:
		r = ProfessorManager.use_candy(_selected_uid, item_id, 1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		r = ProfessorManager.use_candies_to_next_level(_selected_uid)
	else:
		return
	b.accept_event()
	_show_message(r.reason if not r.ok else ("레벨 업! (사탕 %d개)" % r.used if r.levels > 0 else "경험치를 얻었다 (사탕 %d개)" % r.used))


func _on_send() -> void:
	var p := PlayerState.find_pokemon(_selected_uid)
	if p.is_empty():
		return
	var s := GameData.get_species(p.dex_id)
	var c := ProfessorManager.preview_rewards([p.uid])
	var uid: String = p.uid
	confirm_requested.emit("박사에게 보내기",
		"%s Lv%d을(를) 박사에게 보낼까요?\n받는 것: %s\n되돌릴 수 없습니다." % [s.name_ko if s else "?", p.level, _candy_text(c)],
		"보내기", func() -> void:
			var r := ProfessorManager.transfer([uid])
			_selected_uid = ""
			refresh()
			_show_message(("보냈다! " + _candy_text(r.rewards)) if r.ok else r.reason))


func _on_bulk_transfer() -> void:
	var uids := ProfessorManager.duplicate_candidates(true)
	if uids.is_empty():
		_show_message("보낼 중복 포켓몬이 없다")
		return
	var c := ProfessorManager.preview_rewards(uids)
	confirm_requested.emit("중복 보내기",
		"같은 종이 여러 마리면 가장 좋은 1마리만 남기고\n%d마리를 박사에게 보냅니다.\n(즐겨찾기·원정 중·특성 있는 포켓몬은 남김)\n받는 것: %s" % [uids.size(), _candy_text(c)],
		"보내기", func() -> void:
			var r := ProfessorManager.transfer(uids)
			if not uids.has(_selected_uid):
				pass
			else:
				_selected_uid = ""
			refresh()
			_show_message(("%d마리를 보냈다! " % r.count + _candy_text(r.rewards)) if r.ok else r.reason))


func _on_favorite() -> void:
	var p := PlayerState.find_pokemon(_selected_uid)
	if not p.is_empty():
		ProfessorManager.set_favorite(p.uid, not p.get("favorite", false))


## 별 버튼 모양: 즐겨찾기면 금색, 아니면 흐린 회색 (마우스를 올리면 조금 밝게)
func _update_favorite(p: Dictionary) -> void:
	var on: bool = p.get("favorite", false)
	var base := FAVORITE_COLOR if on else Color(0.55, 0.57, 0.65, 0.7)
	_fav.add_theme_color_override(&"font_color", base)
	_fav.add_theme_color_override(&"font_hover_color", base.lightened(0.25))
	_fav.add_theme_color_override(&"font_pressed_color", base)
	_fav.tooltip_text = "즐겨찾기 해제" if on else "즐겨찾기 (파티·원정 목록 맨 위, 박사에게 보낼 수 없음)"


func _candy_text(c: Dictionary) -> String:
	var parts: Array[String] = []
	if c.get(ProfessorManager.CANDY_M, 0) > 0:
		parts.append("경험사탕 M %d" % c[ProfessorManager.CANDY_M])
	if c.get(ProfessorManager.CANDY_S, 0) > 0:
		parts.append("경험사탕 S %d" % c[ProfessorManager.CANDY_S])
	return ", ".join(parts) if parts.size() > 0 else "없음"


func _show_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""



# ---------------------------------------------------------------- 진화 (M9)

func _update_evolution_buttons(p: Dictionary) -> void:
	for c in _evo_box.get_children():
		c.queue_free()
	if p.is_empty() or PlayerState.is_busy(p.uid) or EvolutionManager.is_queued(p.uid):
		_evo_box.visible = false
		return
	var count := 0
	var to := EvolutionManager.level_target(p)
	if to > 0:
		var b := _evo_button("진화하기", "%s(으)로 진화한다" % GameData.get_species(to).name_ko)
		var uid: String = p.uid
		b.pressed.connect(func() -> void: _request(EvolutionManager.request_level_evolution(uid)))
		count += 1
	for opt in EvolutionManager.stone_options(p):
		var item := GameData.get_item(opt.item)
		var b2 := _evo_button(item.name_ko if item else String(opt.item),
			"%s을(를) 써서 %s(으)로 진화한다" % [item.name_ko if item else "", GameData.get_species(opt.to).name_ko])
		b2.icon = item.load_icon() if item else null
		var item_id: StringName = opt.item
		var uid2: String = p.uid
		b2.pressed.connect(func() -> void: _request(EvolutionManager.request_item_evolution(uid2, item_id)))
		count += 1
	_evo_box.visible = count > 0


func _evo_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override(&"font_color", Color(1, 0.85, 0.35))
	_evo_box.add_child(b)
	return b


func _request(r: Dictionary) -> void:
	if not r.ok:
		_show_message(r.reason)
