class_name EncounterEntry
extends Resource
## 지역 출현 테이블의 한 줄. (기획서 4.2, 7.2)

@export var dex_id: int
@export var weight: int = 10
@export var min_level: int = 1
@export var max_level: int = 1
@export var min_player_level: int = 1
## 이 줄로 나온 야생의 추가 포획 난이도 (0~1, Formulas.capture_difficulty 에 더함, v0.76). 예: 동굴 라프라스 0.2
@export var difficulty_bonus: float = 0.0
## 예약: 이후 시간대/날씨 조건 {type: "time", value: "night"}
@export var conditions: Array[Dictionary] = []
