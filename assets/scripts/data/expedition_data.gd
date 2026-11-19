class_name ExpeditionData
extends Resource
## 원정지. 원정은 전투가 아니며 시간만 소모한다. (기획서 4.10)
## tools/source/expeditions_gen1.json → tools/json_to_traits_expeditions.gd 로 생성한다.

@export var id: StringName
@export var name_ko: String
@export var order: int = 0
@export var duration_sec: int
@export var required_power: int
## 최소 인원. 최대 인원은 없다 (v0.24)
@export var min_party: int = 5
@export var recommended_types: Array[StringName] = []
@export var weak_types: Array[StringName] = []
## [{item: "great_ball", min: 1, max: 3, weight: 10}]
@export var reward_table: Array[Dictionary] = []
@export var reward_rolls: int = 3
## 최소~최대 (원)
@export var currency_reward: Vector2i
## 참여 포켓몬 1마리당 경험치
@export var exp_reward: int
@export var player_exp_reward: int
@export var unlock_conditions: Array[Dictionary] = []
