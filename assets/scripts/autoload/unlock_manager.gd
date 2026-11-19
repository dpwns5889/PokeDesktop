extends Node
## 해금 조건 평가와 지역 해금. (기획서 4.4)
## 조건은 Dictionary 배열(AND). 지역·전설·원정지(M7)가 같은 형식을 쓴다.
##
## 조건 타입
##   {type: "player_level",      value: N}
##   {type: "dex_caught_count",  value: N}                 도감에 포획으로 등록된 종 수
##   {type: "species_caught",    value: dex_id}
##   {type: "type_caught_count", type_id: "water", value: N}   그 타입을 가진 포획 종 수
##   {type: "region_unlocked",   value: "forest"}


func _ready() -> void:
	EventBus.pokemon_caught.connect(func(_i: Dictionary) -> void: check_regions())
	EventBus.player_leveled_up.connect(func(_l: int) -> void: check_regions())
	EventBus.pokemon_evolved.connect(func(_u: String, _f: int, _t: int) -> void: check_regions())
	EventBus.game_reset.connect(check_regions)
	# 세이브를 불러온 뒤(SaveManager가 먼저 준비됨) 한 번 확인. 조건이 바뀐 경우 대비.
	check_regions.call_deferred()


## 모든 조건을 만족하는가
func evaluate(conditions: Array) -> bool:
	for c in conditions:
		var p := progress(c)
		if p.current < p.target:
			return false
	return true


## 조건 하나의 진행도 {current, target, label}
func progress(c: Dictionary) -> Dictionary:
	var target := int(c.get("value", 0)) if c.get("type") != "region_unlocked" and c.get("type") != "species_caught" else 1
	var current := 0
	var label := ""
	match c.get("type", ""):
		"player_level":
			current = PlayerState.level
			label = "플레이어 Lv%d" % target
		"dex_caught_count":
			current = PlayerState.dex_caught_count()
			label = "도감 %d종 포획" % target
		"species_caught":
			var s := GameData.get_species(int(c.value))
			current = 1 if PlayerState.is_caught(int(c.value)) else 0
			label = "%s 포획" % (s.name_ko if s else str(c.value))
		"type_caught_count":
			var t := StringName(c.get("type_id", ""))
			current = type_caught_count(t)
			label = "%s 타입 %d종 포획" % [GameData.type_name(t), target]
		"region_unlocked":
			var r := GameData.get_region(StringName(c.value))
			current = 1 if PlayerState.unlocked_regions.has(StringName(c.value)) else 0
			label = "%s 해금" % (r.name_ko if r else str(c.value))
		_:
			push_warning("알 수 없는 조건: %s" % c)
			label = "?"
			target = 1
	return {"current": mini(current, target), "target": target, "label": label}


## 그 타입을 가진(어느 슬롯이든) 포획 종 수
func type_caught_count(type_id: StringName) -> int:
	var n := 0
	for id in PlayerState.dex:
		if PlayerState.dex[id].get("caught", 0) > 0:
			var s := GameData.get_species(id)
			if s and s.types.has(type_id):
				n += 1
	return n


## 조건을 새로 만족한 지역을 해금한다. 반환: 새로 해금한 지역 ID
func check_regions() -> Array[StringName]:
	var newly: Array[StringName] = []
	for r in GameData.all_regions():
		if PlayerState.unlocked_regions.has(r.id):
			continue
		if evaluate(r.unlock_conditions):
			PlayerState.unlock_region(r.id)
			newly.append(r.id)
			EventBus.region_unlocked.emit(r.id)
	return newly
