extends Node
## 런타임 플레이어 상태: 레벨/경험치, 재화, 보관함, 인벤토리, 도감, 해금 목록. (기획서 4.1, 4.7, 7.5)
## 저장 형식 변환은 to_save_dict() / load_save_dict() 에서만 한다(SaveManager가 호출).

const MAX_PLAYER_LEVEL := Formulas.MAX_PLAYER_LEVEL
const BASE_STORAGE_CAPACITY := 100
const INFINITE_BALL := &"poke_ball"
const DEFAULT_REGION := &"grassland"
## 새 게임 시작 자금 (원). 첫 원정 전에도 상점을 써 볼 수 있게. (기획서 4.12, M10에서 조정)
const STARTING_CURRENCY := 1000
## 엔트리(전투에 함께 나가는 포켓몬) 최대 수 (기획서 4.13, v0.26)
const MAX_ENTRIES := 3

## 저장할 내용이 바뀔 때마다 발생 → SaveManager가 저장을 예약한다.
signal changed

var level: int = 1
var experience: int = 0
var currency: int = STARTING_CURRENCY
var storage_capacity: int = BASE_STORAGE_CAPACITY
var current_region: StringName = DEFAULT_REGION
var unlocked_regions: Array[StringName] = [DEFAULT_REGION]

var selected_ball: StringName = INFINITE_BALL
## item_id -> 개수. 몬스터볼은 무한이라 저장하지 않는다.
var inventory: Dictionary = {}
## 보유 포켓몬 개체 목록 (기획서 7.5 pokemon 항목 형식)
var pokemon: Array[Dictionary] = []
## 도감: dex_id(int) -> {seen: bool, caught: int, first_caught_at: int}
var dex: Dictionary = {}
## 진행 중인 원정 [{id, party: [uid], started_at, end_at, power, ratio, mods, notified}] (기획서 4.10)
var expeditions: Array[Dictionary] = []
## 엔트리 uid 목록 (최대 MAX_ENTRIES). 전투에서 능력치·특성이 쓰인다. (기획서 4.13)
var entries: Array[String] = []
## 쓰고 있는 향로 (v0.41). {"incense": {"type": "fire", "end_at": unix}, "shiny_incense": {"end_at": unix}}
## 끝나는 시각은 실제 시각 기준(앱이 꺼져 있어도 흐른다).
var active_items: Dictionary = {}

## 특성 생성 등에 쓰는 난수 (테스트에서 seed 고정)
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func reset() -> void:
	level = 1
	experience = 0
	currency = STARTING_CURRENCY
	storage_capacity = BASE_STORAGE_CAPACITY
	current_region = DEFAULT_REGION
	unlocked_regions = [DEFAULT_REGION]
	selected_ball = INFINITE_BALL
	inventory = {}
	pokemon = []
	dex = {}
	expeditions = []
	entries = []
	active_items = {}


# ---------------------------------------------------------------- 레벨 / 경험치

func exp_to_next() -> int:
	return Formulas.player_exp_to_next(level)


## 경험치 추가. 레벨업하면 player_leveled_up 발생. 최대 레벨에서는 경험치가 쌓이지 않는다.
## 플레이어 경험치 얻기. 행복의 알(v0.61)을 쓰고 있으면 배율을 곱한다(반올림).
func add_exp(amount: int, now: int = -1) -> void:
	if level >= MAX_PLAYER_LEVEL or amount <= 0:
		return
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	amount = roundi(amount * player_exp_multiplier(now))
	experience += amount
	while level < MAX_PLAYER_LEVEL and experience >= exp_to_next():
		experience -= exp_to_next()
		level += 1
		EventBus.player_leveled_up.emit(level)
	if level >= MAX_PLAYER_LEVEL:
		experience = 0
	changed.emit()


# ---------------------------------------------------------------- 지역 (기획서 4.4)

func unlock_region(id: StringName) -> void:
	if not unlocked_regions.has(id):
		unlocked_regions.append(id)
		changed.emit()


## 현재 지역 변경. 해금되지 않은 지역이면 false.
func set_current_region(id: StringName) -> bool:
	if not unlocked_regions.has(id) or GameData.get_region(id) == null:
		return false
	if current_region != id:
		current_region = id
		EventBus.current_region_changed.emit(id)
		changed.emit()
	return true


# ---------------------------------------------------------------- 도감

func mark_seen(dex_id: int) -> void:
	var e: Dictionary = dex.get(dex_id, {})
	if e.get("seen", false):
		return
	e["seen"] = true
	dex[dex_id] = e
	changed.emit()


func is_caught(dex_id: int) -> bool:
	return dex.get(dex_id, {}).get("caught", 0) > 0


func dex_caught_count() -> int:
	var n := 0
	for id in dex:
		if dex[id].get("caught", 0) > 0:
			n += 1
	return n


func dex_seen_count() -> int:
	var n := 0
	for id in dex:
		if dex[id].get("seen", false):
			n += 1
	return n


# ---------------------------------------------------------------- 보관함

func storage_count() -> int:
	return pokemon.size()


func is_storage_full() -> bool:
	return pokemon.size() >= storage_capacity


## 보관함에서 개체를 뺀다 (박사에게 보내기). 원정 중이면 빼지 않는다.
func remove_pokemon(uid: String) -> bool:
	if is_busy(uid):
		return false
	for i in pokemon.size():
		if pokemon[i].uid == uid:
			pokemon.remove_at(i)
			entries.erase(uid)
			changed.emit()
			return true
	return false


func find_pokemon(uid: String) -> Dictionary:
	for p in pokemon:
		if p.uid == uid:
			return p
	return {}


## 포획한 개체를 보관함에 추가하고 도감·경험치를 갱신한다. 반환: 개체 Dictionary
func add_caught(encounter: Dictionary) -> Dictionary:
	var dex_id := int(encounter[&"dex_id"])
	var now := int(Time.get_unix_time_from_system())
	var inst := {
		"uid": _new_uid(),
		"dex_id": dex_id,
		"level": int(encounter[&"level"]),
		"exp": 0,
		"gender": String(encounter[&"gender"]),
		"shiny": bool(encounter.get(&"shiny", false)),
		"traits": _roll_traits(dex_id, bool(encounter.get(&"shiny", false))),   # 고정 특성(전설·색이다른) + 무작위 특성 (기획서 4.6)
		"ivs": Formulas.roll_ivs(rng),   # 개체치 (v0.55)
		"evolution_cancelled": false,
		"locked": false,
		"caught_at": now,
		"region": String(encounter.get(&"region", "")),
		"nickname": "",
	}
	pokemon.append(inst)
	var new_dex := register_caught_species(dex_id)

	EventBus.pokemon_caught.emit(inst)
	add_exp(Formulas.capture_player_exp(inst.level, new_dex))
	changed.emit()
	return inst


## 도감에 포획으로 등록 (포획·진화). 반환: 처음 포획한 종인가
func register_caught_species(dex_id: int) -> bool:
	var new_dex := not is_caught(dex_id)
	var e: Dictionary = dex.get(dex_id, {})
	e["seen"] = true
	e["caught"] = int(e.get("caught", 0)) + 1
	if new_dex:
		e["first_caught_at"] = int(Time.get_unix_time_from_system())
	dex[dex_id] = e
	return new_dex


## 개체 능력치 (기획서 4.7.1). 특성은 능력치를 바꾸지 않는다 (v0.28 개편).
func stats_of(inst: Dictionary) -> Dictionary:
	var species := GameData.get_species(inst.dex_id)
	if species == null:
		return {}
	return Formulas.calc_stats(species.base_stats, inst.level, {}, inst.get("ivs", {}))


## 원정 중인 개체인가 (원정 중에는 다른 원정·박사 보내기·진화·레벨업 불가)
func is_busy(uid: String) -> bool:
	for x in expeditions:
		if x.party.has(uid):
			return true
	return false


# ---------------------------------------------------------------- 향로 (기획서 4.11, v0.41)

## 향로 사용: type 의 포켓몬이 30분 동안 잘 나온다. 같은 타입을 쓰면 30분 연장, 다른 타입이면 그 타입으로 새로 30분.
## 반환: "" = 성공, 아니면 이유
func use_incense(type_id: StringName, now: int) -> String:
	var item := GameData.get_item(&"incense")
	if item == null or item_count(&"incense") <= 0:
		return "향로가 없습니다."
	if type_id == &"":
		return "타입을 고르세요."
	var dur := int(item.params.get("duration_min", 30)) * 60
	var cur: Dictionary = active_items.get("incense", {})
	var start := now
	if String(cur.get("type", "")) == String(type_id) and int(cur.get("end_at", 0)) > now:
		start = int(cur.end_at)   # 같은 타입이면 이어서
	remove_item(&"incense", 1)
	active_items["incense"] = {"type": String(type_id), "end_at": start + dur}
	changed.emit()
	return ""


## 특이한 향로 사용: 30분 동안 색이 다른 포켓몬 확률 ×4. 쓰고 있는 중이면 30분 연장.
func use_shiny_incense(now: int) -> String:
	var item := GameData.get_item(&"shiny_incense")
	if item == null or item_count(&"shiny_incense") <= 0:
		return "특이한 향로가 없습니다."
	var dur := int(item.params.get("duration_min", 30)) * 60
	var start := maxi(now, int(active_items.get("shiny_incense", {}).get("end_at", 0)))
	remove_item(&"shiny_incense", 1)
	active_items["shiny_incense"] = {"end_at": start + dur}
	changed.emit()
	return ""


## 지금 효과가 있는 향로의 타입 (없으면 &"")
func incense_type(now: int) -> StringName:
	var cur: Dictionary = active_items.get("incense", {})
	return StringName(cur.get("type", "")) if int(cur.get("end_at", 0)) > now else &""


## 남은 초 (끝났으면 0). key = "incense" / "shiny_incense"
func item_seconds_left(key: String, now: int) -> int:
	return maxi(0, int(active_items.get(key, {}).get("end_at", 0)) - now)


## 출현 타입 배율 (향로) {type: 배율}
func incense_type_weights(now: int) -> Dictionary:
	var t := incense_type(now)
	if t == &"":
		return {}
	var item := GameData.get_item(&"incense")
	return {t: float(item.params.get("type_weight", 2.0)) if item else 2.0}


## 색이 다른 확률 배율 (특이한 향로)
func shiny_multiplier(now: int) -> float:
	if item_seconds_left("shiny_incense", now) <= 0:
		return 1.0
	var item := GameData.get_item(&"shiny_incense")
	return float(item.params.get("shiny_mult", 4.0)) if item else 4.0


# ---------------------------------------------------------------- 행복의 알 (기획서 4.11, v0.61)

## 행복의 알 사용: 15분 동안 플레이어 경험치 ×1.5. 쓰고 있는 중이면 15분 연장(특이한 향로와 같은 방식).
## 반환: "" = 성공, 아니면 이유
func use_lucky_egg(now: int) -> String:
	var item := GameData.get_item(&"lucky_egg")
	if item == null or item_count(&"lucky_egg") <= 0:
		return "행복의 알이 없습니다."
	var dur := int(item.params.get("duration_min", 15)) * 60
	var start := maxi(now, int(active_items.get("lucky_egg", {}).get("end_at", 0)))
	remove_item(&"lucky_egg", 1)
	active_items["lucky_egg"] = {"end_at": start + dur}
	changed.emit()
	return ""


## 플레이어 경험치 배율 (행복의 알)
func player_exp_multiplier(now: int) -> float:
	if item_seconds_left("lucky_egg", now) <= 0:
		return 1.0
	var item := GameData.get_item(&"lucky_egg")
	return float(item.params.get("player_exp_mult", 1.5)) if item else 1.5


# ---------------------------------------------------------------- 엔트리 (기획서 4.13)

func is_entry(uid: String) -> bool:
	return entries.has(uid)


## 엔트리 개체 목록 (엔트리 순서)
func entry_pokemon() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in entries:
		var p := find_pokemon(u)
		if not p.is_empty():
			out.append(p)
	return out


## 엔트리에 넣을 수 없는 이유. "" = 가능
func entry_block_reason(uid: String) -> String:
	if find_pokemon(uid).is_empty():
		return "없는 포켓몬입니다."
	if is_entry(uid):
		return "이미 엔트리에 있습니다."
	if entries.size() >= MAX_ENTRIES:
		return "엔트리는 %d마리까지입니다." % MAX_ENTRIES
	if is_busy(uid):
		return "원정 중인 포켓몬은 엔트리에 넣을 수 없습니다."
	return ""


## 반환: "" = 성공, 아니면 이유
func add_entry(uid: String) -> String:
	var reason := entry_block_reason(uid)
	if reason == "":
		entries.append(uid)
		EventBus.entries_changed.emit()
		changed.emit()
	return reason


func remove_entry(uid: String) -> void:
	if entries.has(uid):
		entries.erase(uid)
		EventBus.entries_changed.emit()
		changed.emit()


## 포켓몬 경험치 추가 → 레벨업 (최대 100, 플레이어 레벨과 무관). 반환: 오른 레벨 수 (기획서 4.8)
func add_pokemon_exp(inst: Dictionary, amount: int) -> int:
	if amount <= 0 or inst.level >= Formulas.MAX_POKEMON_LEVEL:
		return 0
	var gained := 0
	inst.exp = int(inst.get("exp", 0)) + amount
	while inst.level < Formulas.MAX_POKEMON_LEVEL and inst.exp >= Formulas.exp_to_next(inst.level):
		inst.exp -= Formulas.exp_to_next(inst.level)
		inst.level += 1
		gained += 1
		EventBus.pokemon_leveled_up.emit(inst.uid, inst.level)
	if inst.level >= Formulas.MAX_POKEMON_LEVEL:
		inst.exp = 0
	changed.emit()
	return gained


# ---------------------------------------------------------------- 볼 / 아이템

func item_count(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


## 선택한 볼을 쓸 수 있는가. 몬스터볼은 항상 가능. (기획서 4.2 볼 부족 처리)
func can_use_selected_ball() -> bool:
	return selected_ball == INFINITE_BALL or item_count(selected_ball) > 0


func select_ball(item_id: StringName) -> void:
	selected_ball = item_id
	EventBus.ball_shortage_changed.emit(not can_use_selected_ball())
	changed.emit()


## 전투 시작 시 선택한 볼 1개 소모. 반환: 사용한 볼 ID (쓸 수 없으면 &"")
func consume_selected_ball() -> StringName:
	if not can_use_selected_ball():
		return &""
	if selected_ball != INFINITE_BALL:
		inventory[selected_ball] = item_count(selected_ball) - 1
		changed.emit()
		if not can_use_selected_ball():
			EventBus.ball_shortage_changed.emit(true)
	return selected_ball


## 다음 볼로 바꾼다 (몬스터볼 → 슈퍼볼 → 하이퍼볼 → …). 개수가 0인 볼도 고를 수 있다
## (그 경우 인카운터 타이머가 멈춘다, 기획서 4.2).
func cycle_ball() -> StringName:
	var balls := GameData.all_items(&"ball")
	if balls.is_empty():
		return selected_ball
	var idx := 0
	for i in balls.size():
		if balls[i].id == selected_ball:
			idx = i
	select_ball(balls[(idx + 1) % balls.size()].id)
	return selected_ball


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if item_id == INFINITE_BALL or item_count(item_id) < amount:
		return false
	inventory[item_id] = item_count(item_id) - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	changed.emit()
	if item_id == selected_ball and not can_use_selected_ball():
		EventBus.ball_shortage_changed.emit(true)
	return true


func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	EventBus.currency_changed.emit(currency)
	changed.emit()


func add_item(item_id: StringName, amount: int = 1) -> void:
	if item_id == INFINITE_BALL:
		return
	var was_short := not can_use_selected_ball()
	inventory[item_id] = item_count(item_id) + amount
	changed.emit()
	if was_short and can_use_selected_ball():
		EventBus.ball_shortage_changed.emit(false)


# ---------------------------------------------------------------- 저장 형식 (기획서 7.5)

func to_save_dict() -> Dictionary:
	var dex_out := {}
	for id in dex:
		dex_out[str(id)] = dex[id]
	var inv := {}
	for k in inventory:
		if inventory[k] > 0:
			inv[String(k)] = inventory[k]
	return {
		"player": {
			"level": level,
			"exp": experience,
			"current_region": String(current_region),
			"selected_ball": String(selected_ball),
		},
		"currency": currency,
		"storage_capacity": storage_capacity,
		"unlocked_regions": unlocked_regions.map(func(r: StringName) -> String: return String(r)),
		"dex": dex_out,
		"pokemon": pokemon.duplicate(true),
		"inventory": inv,
		"expeditions": expeditions.duplicate(true),
		"entries": entries.duplicate(),
		"active_items": active_items.duplicate(true),
	}


## 저장 데이터를 읽어 상태를 바꾼다. 형식이 이상한 값은 기본값으로 둔다(손상 대비).
func load_save_dict(d: Dictionary) -> void:
	reset()
	var p: Dictionary = d.get("player", {})
	level = clampi(int(p.get("level", 1)), 1, MAX_PLAYER_LEVEL)
	experience = maxi(0, int(p.get("exp", 0)))
	current_region = StringName(p.get("current_region", DEFAULT_REGION))
	selected_ball = StringName(p.get("selected_ball", INFINITE_BALL))
	currency = maxi(0, int(d.get("currency", 0)))
	storage_capacity = maxi(BASE_STORAGE_CAPACITY, int(d.get("storage_capacity", BASE_STORAGE_CAPACITY)))

	unlocked_regions = []
	for r in d.get("unlocked_regions", [DEFAULT_REGION]):
		unlocked_regions.append(StringName(r))
	if not unlocked_regions.has(DEFAULT_REGION):
		unlocked_regions.append(DEFAULT_REGION)
	if not unlocked_regions.has(current_region):
		current_region = DEFAULT_REGION

	for k in d.get("dex", {}):
		var e: Dictionary = d.dex[k]
		dex[int(k)] = {
			"seen": bool(e.get("seen", false)),
			"caught": int(e.get("caught", 0)),
			"first_caught_at": int(e.get("first_caught_at", 0)),
		}

	for raw in d.get("pokemon", []):
		if not raw is Dictionary or not raw.has("uid") or not raw.has("dex_id"):
			continue
		var inst: Dictionary = raw.duplicate(true)
		inst["dex_id"] = int(inst.dex_id)
		inst["level"] = clampi(int(inst.get("level", 1)), 1, Formulas.MAX_POKEMON_LEVEL)
		inst["exp"] = int(inst.get("exp", 0))
		inst["caught_at"] = int(inst.get("caught_at", 0))
		if not GameData.has_species(inst.dex_id):
			push_warning("세이브: 알 수 없는 종 %d (활성 세대 밖?) — 보관은 유지" % inst.dex_id)
		inst["traits"] = _known_traits(inst.get("traits", []))
		inst["ivs"] = _valid_ivs(inst.get("ivs"))
		pokemon.append(inst)

	for k in d.get("inventory", {}):
		var n := int(d.inventory[k])
		if n > 0:
			inventory[StringName(k)] = n

	# 원정: 보관함에 없는 개체는 빼고, 파티가 비면 원정 자체를 버린다
	var uids := {}
	for mon in pokemon:
		uids[mon.uid] = true
	for raw in d.get("expeditions", []):
		if not raw is Dictionary or not raw.has("id"):
			continue
		var x: Dictionary = raw.duplicate(true)
		var party: Array = []
		for u in x.get("party", []):
			if uids.has(u):
				party.append(u)
		if party.is_empty():
			continue
		x["party"] = party
		x["started_at"] = int(x.get("started_at", 0))
		x["end_at"] = int(x.get("end_at", 0))
		x["power"] = int(x.get("power", 0))
		x["ratio"] = float(x.get("ratio", 1.0))
		x["notified"] = bool(x.get("notified", false))
		if not x.get("mods") is Dictionary:
			x["mods"] = {}
		expeditions.append(x)

	# 향로·행복의 알: 형식이 맞는 것만 (끝난 것은 그대로 두어도 효과가 없다)
	var raw_active = d.get("active_items", {})
	if raw_active is Dictionary:
		for k in ["incense", "shiny_incense", "lucky_egg"]:
			var v = raw_active.get(k)
			if v is Dictionary and v.has("end_at"):
				active_items[k] = {"end_at": int(v.end_at), "type": String(v.get("type", ""))}

	# 엔트리: 보관함에 있고 원정 중이 아닌 개체만, 중복 없이 최대 MAX_ENTRIES
	var raw_entries = d.get("entries", [])
	if raw_entries is Array:
		for u in raw_entries:
			var uid := str(u)
			if uids.has(uid) and not entries.has(uid) and not is_busy(uid) and entries.size() < MAX_ENTRIES:
				entries.append(uid)


## 지금 데이터에 있는 특성만 남긴다. v0.28 특성 개편 전 세이브의 옛 특성(튼튼함·길잡이 등)은 사라진다.
## 고정 특성(전설)은 id 가 같아서 그대로 남는다.
## 세이브의 개체치. 없으면(v0.55 이전 세이브) 새로 뽑는다. 값은 0~31 로 자른다.
func _valid_ivs(raw) -> Dictionary:
	if not raw is Dictionary:
		return Formulas.roll_ivs(rng)
	var out := {}
	for k in Formulas.STAT_KEYS:
		out[String(k)] = clampi(int(raw.get(String(k), rng.randi_range(0, Formulas.IV_MAX))), 0, Formulas.IV_MAX)
	return out


func _known_traits(raw) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for t in raw:
		var id := String(t)
		if GameData.get_trait(StringName(id)) != null and not out.has(id):
			out.append(id)
	return out


func _roll_traits(dex_id: int, shiny: bool = false) -> Array:
	var s := GameData.get_species(dex_id)
	var out: Array = [] if s == null else s.fixed_trait_ids.map(func(t: StringName) -> String: return String(t))
	if shiny:
		out.append("shiny")   # 색이 다른 개체의 고정 특성 (M11)
	for t in ExpeditionLogic.roll_traits(rng, GameData.trait_roll_config(), GameData.random_trait_pool()):
		if not out.has(t):
			out.append(t)
	return out


func _new_uid() -> String:
	var bytes := Crypto.new().generate_random_bytes(6)
	return bytes.hex_encode()
