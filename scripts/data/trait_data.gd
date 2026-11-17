class_name TraitData
extends Resource
## 특성(패시브). (기획서 4.6, v0.28 개편)
## data/source/traits.json → tools/json_to_traits_expeditions.gd 로 생성한다.

@export var id: StringName
@export var name_ko: String
@export var description: String
## normal / rare / legend(고정: 전설·색이다른) / negative
@export var tier: StringName = &"normal"
## 무작위 생성 가중치. legend 등급은 0 (무작위로 나오지 않음)
@export var weight: int = 10
## 발동하는 곳: expedition = 원정 파티에 있을 때 / battle = 엔트리일 때 (기획서 4.13)
@export var trigger: StringName = &"expedition"
## [{kind, value, scope, when}] — kind 목록은 기획서 4.6 "효과 종류"
@export var effects: Array[Dictionary] = []
## 같이 붙을 수 없는 특성
@export var exclusive_with: Array[StringName] = []


func is_battle() -> bool:
	return trigger == &"battle"


func is_negative() -> bool:
	return tier == &"negative"
