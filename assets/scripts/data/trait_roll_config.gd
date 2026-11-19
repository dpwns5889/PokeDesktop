class_name TraitRollConfig
extends Resource
## 포획 시 무작위 특성 생성 규칙. (기획서 4.6)

## [0개, 1개, 2개, 3개] 가중치
@export var count_weights: Array[int] = []
## {normal: ?, rare: ?, negative: ?}
@export var tier_weights: Dictionary = {}
