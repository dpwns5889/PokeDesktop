class_name PokemonSpecies
extends Resource
## 포켓몬 종 데이터. 전국도감 번호가 키. (기획서 7.2)
## 스프라이트는 리소스에 직접 연결하지 않고 경로 규칙으로 필요할 때 불러온다(PokemonSprites).
## 희귀도 필드는 두지 않는다.

@export var dex_id: int
@export var generation: int
@export var name_ko: String
## UI에 표시하지 않음. 스프라이트 시트·PokeAPI 데이터와 맞추는 용도.
@export var name_en: String
@export var types: Array[StringName] = []
## {hp, atk, def, spa, spd, spe}
@export var base_stats: Dictionary = {}
## 0–255. 인카운터 전투 난이도에 쓰인다.
@export var catch_rate: int
@export var base_exp: int
## 수컷 비율 0.0~1.0, 무성 = -1
@export var gender_ratio: float
## 암수 스프라이트가 다른 종 (스프라이트 시트 2행)
@export var has_gender_sprites: bool
## 0 = 기본, 1, 2
@export var evo_stage: int
@export var is_legendary: bool
@export var is_mythical: bool
## 항상 붙는 특성. 전설: [&"legend"]. 무작위 특성은 개체에 저장한다.
@export var fixed_trait_ids: Array[StringName] = []
## [{to: 2, method: &"level", value: 16}, {to: 136, method: &"item", item: &"fire_stone"}]
@export var evolutions: Array[Dictionary] = []


func is_genderless() -> bool:
	return gender_ratio < 0.0


func base_stat_total() -> int:
	var total := 0
	for v in base_stats.values():
		total += int(v)
	return total
