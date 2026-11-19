class_name LegendaryRule
extends Resource
## 전설 출현 규칙. tools/generate_legendary_conditions.gd 가 자동 생성한다. (기획서 4.5)

@export var dex_id: int
## 등장 레벨
@export var level: int = 50
@export var chance: float = 0.01
## 빈 배열 = 모든 지역
@export var region_ids: Array[StringName] = []
@export var conditions: Array[Dictionary] = []
