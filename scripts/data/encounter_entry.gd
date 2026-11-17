class_name EncounterEntry
extends Resource
## 지역 출현 테이블의 한 줄. (기획서 4.2, 7.2)

@export var dex_id: int
@export var weight: int = 10
@export var min_level: int = 1
@export var max_level: int = 1
@export var min_player_level: int = 1
## 예약: 이후 시간대/날씨 조건 {type: "time", value: "night"}
@export var conditions: Array[Dictionary] = []
