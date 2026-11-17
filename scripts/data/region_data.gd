class_name RegionData
extends Resource
## 지역. (기획서 4.4, 7.2)
## data/source/regions_gen1.json → tools/json_to_regions.gd 로 생성한다.

@export var id: StringName
@export var name_ko: String
## 목록 정렬 순서 (해금 순서와 같게)
@export var order: int = 0
@export var main_types: Array[StringName] = []
@export var background: PackedScene
## 배경 아트가 생기기 전까지 쓰는 임시 색
@export var sky_color: Color = Color(0.576, 0.733, 0.925)
@export var ground_color: Color = Color(0.53, 0.75, 0.42)
@export var battle_base: Texture2D
@export var encounters: Array[EncounterEntry] = []
@export var level_scale: float = 0.2
@export var level_cap: int = 100
## 다음 인카운터까지 [최소, 최대] 초. (0, 0)이면 기본값 (기획서 4.2, v0.24)
@export var encounter_interval: Vector2 = Vector2.ZERO
## 전투 바닥 번호 (Assets/Generated/ui/ground.png 의 칸, tools/import_battle_ground.gd 참고) (v0.35)
## 0 풀밭 1 물 2 모래 3 흙길 4 얼음 5 진흙 6 바위 7 눈 8 어두운 바위
@export var battle_ground: int = 0
## [{type: "player_level", value: 10}, ...] (기획서 4.4 조건 타입)
@export var unlock_conditions: Array[Dictionary] = []
