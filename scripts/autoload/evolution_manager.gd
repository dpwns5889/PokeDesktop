extends Node
## 진화: 조건 확인, 진화 대기열, 확인/취소. (기획서 4.9)
##
## - 레벨 진화: 진화 레벨에 도달하는 순간 대기열에 들어가 연출이 시작된다(비용 없음).
##   취소하면 evolution_cancelled = true, 다음 레벨업 때 다시 시도한다.
##   레벨업 없이도 보관함의 "진화하기"로 다시 요청할 수 있다(Lv100이거나 앱을 껐다 켠 경우 대비).
## - 진화의 돌: 보관함에서 요청 → 연출 → 확인하는 순간 돌 1개 소모 (취소하면 돌은 그대로).
## - 원정 중인 개체는 진화하지 않는다. 원정 보상으로 레벨이 오르면 귀환 처리 뒤라 바로 진화한다.
## - 진화하면 종이 바뀌고 도감에 포획으로 등록, 플레이어 경험치. 특성·성별·레벨은 유지.
## 화면(EvolutionOverlay)은 evolution_requested 를 받아 대기열 맨 앞을 보여주고 confirm_current / cancel_current 를 부른다.

## 대기열: [{uid, from, to, method: &"level"/&"item", item}]
var queue: Array[Dictionary] = []


func _ready() -> void:
	EventBus.pokemon_leveled_up.connect(_on_leveled_up)
	EventBus.game_reset.connect(func() -> void: queue.clear())


# ---------------------------------------------------------------- 조건

## 지금 레벨로 진화할 수 있는 종 (없으면 -1). 활성 세대 밖의 종은 제외.
func level_target(inst: Dictionary) -> int:
	var s := GameData.get_species(inst.get("dex_id", 0))
	if s == null:
		return -1
	for e in s.evolutions:
		if e.method == &"level" and inst.level >= int(e.value) and GameData.has_species(e.to):
			return e.to
	return -1


## 그 아이템으로 진화하는 종 (없으면 -1)
func item_target(inst: Dictionary, item_id: StringName) -> int:
	var s := GameData.get_species(inst.get("dex_id", 0))
	if s == null:
		return -1
	for e in s.evolutions:
		if e.method == &"item" and StringName(e.item) == item_id and GameData.has_species(e.to):
			return e.to
	return -1


## 이 개체에 쓸 수 있는 진화의 돌 (가진 것만): [{item, to}]
func stone_options(inst: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := GameData.get_species(inst.get("dex_id", 0))
	if s == null:
		return out
	for e in s.evolutions:
		if e.method == &"item" and PlayerState.item_count(StringName(e.item)) > 0 and GameData.has_species(e.to):
			out.append({"item": StringName(e.item), "to": int(e.to)})
	return out


func is_queued(uid: String) -> bool:
	for q in queue:
		if q.uid == uid:
			return true
	return false


func current() -> Dictionary:
	return queue[0] if not queue.is_empty() else {}


# ---------------------------------------------------------------- 요청

## 레벨 진화 다시 요청 (취소했던 개체의 "진화하기")
func request_level_evolution(uid: String) -> Dictionary:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return _fail("없는 포켓몬입니다.")
	if PlayerState.is_busy(uid):
		return _fail("원정 중인 포켓몬은 진화할 수 없습니다.")
	var to := level_target(p)
	if to < 0:
		return _fail("아직 진화할 수 없습니다.")
	_enqueue({"uid": uid, "from": int(p.dex_id), "to": to, "method": &"level", "item": &""})
	return {"ok": true, "reason": ""}


## 진화의 돌 사용 요청 (돌은 확인하는 순간 소모)
func request_item_evolution(uid: String, item_id: StringName) -> Dictionary:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return _fail("없는 포켓몬입니다.")
	if PlayerState.is_busy(uid):
		return _fail("원정 중인 포켓몬은 진화할 수 없습니다.")
	if PlayerState.item_count(item_id) <= 0:
		return _fail("진화의 돌이 없습니다.")
	var to := item_target(p, item_id)
	if to < 0:
		return _fail("이 돌로는 진화하지 않습니다.")
	_enqueue({"uid": uid, "from": int(p.dex_id), "to": to, "method": &"item", "item": item_id})
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- 확인 / 취소

## 대기열 맨 앞을 진화시킨다. 반환: {ok, reason, uid, from, to}
func confirm_current() -> Dictionary:
	if queue.is_empty():
		return _fail("진화할 포켓몬이 없습니다.")
	var e: Dictionary = queue.pop_front()
	var p := PlayerState.find_pokemon(e.uid)
	var result: Dictionary
	if p.is_empty() or PlayerState.is_busy(e.uid) or int(p.dex_id) != int(e.from):
		result = _fail("진화할 수 없는 상태가 되었습니다.")
	elif e.method == &"item" and not PlayerState.remove_item(e.item, 1):
		result = _fail("진화의 돌이 없습니다.")
	else:
		_evolve(p, int(e.to))
		result = {"ok": true, "reason": "", "uid": e.uid, "from": e.from, "to": e.to}
		# 이미 다음 단계 레벨도 넘었으면 이어서 진화 (예: 경험사탕으로 한 번에 많이 오른 경우)
		_check_level(p)
	_emit_next()
	return result


func cancel_current() -> void:
	if queue.is_empty():
		return
	var e: Dictionary = queue.pop_front()
	var p := PlayerState.find_pokemon(e.uid)
	if not p.is_empty() and e.method == &"level":
		p.evolution_cancelled = true
		PlayerState.changed.emit()
	EventBus.evolution_cancelled.emit(e.uid)
	_emit_next()


# ---------------------------------------------------------------- 내부

func _on_leveled_up(uid: String, _new_level: int) -> void:
	var p := PlayerState.find_pokemon(uid)
	if p.is_empty():
		return
	p.evolution_cancelled = false   # 취소했어도 다음 레벨업 때 다시 시도
	_check_level(p)


func _check_level(p: Dictionary) -> void:
	if PlayerState.is_busy(p.uid) or is_queued(p.uid) or p.get("evolution_cancelled", false):
		return
	var to := level_target(p)
	if to > 0:
		_enqueue({"uid": p.uid, "from": int(p.dex_id), "to": to, "method": &"level", "item": &""})


func _enqueue(e: Dictionary) -> void:
	if is_queued(e.uid):
		return
	queue.append(e)
	if queue.size() == 1:
		EventBus.evolution_requested.emit(e.uid, e.to)


func _emit_next() -> void:
	if not queue.is_empty():
		EventBus.evolution_requested.emit(queue[0].uid, queue[0].to)


func _evolve(p: Dictionary, to: int) -> void:
	var from := int(p.dex_id)
	p.dex_id = to
	p.evolution_cancelled = false
	var new_dex := PlayerState.register_caught_species(to, bool(p.get("shiny", false)))
	PlayerState.add_exp(Formulas.evolution_player_exp(new_dex))
	PlayerState.changed.emit()
	EventBus.pokemon_evolved.emit(p.uid, from, to)


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
