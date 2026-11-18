class_name ItemData
extends Resource
## 아이템. (기획서 4.11)
## data/source/items.json → tools/json_to_items.gd 로 생성한다.
## 아이콘은 tools/import_icons.gd 가 만든 Assets/Generated/icons/<id>.png 를 경로 규칙으로 불러온다.

@export var id: StringName
@export var name_ko: String
@export var description: String
## ball / exp_candy / evolution / valuable(판매 전용, 금구슬 v0.28) (지닌 물건은 폐기, v0.24)
@export var category: StringName
## 목록 정렬 순서
@export var order: int = 0
## {catch_modifier: 1.5} / {exp: 100}
@export var params: Dictionary = {}
## [&"shop", &"expedition", &"professor"]
@export var sources: Array[StringName] = []
## 0 = 상점에서 팔지 않음
@export var buy_price: int = 0
## 0 = 팔 수 없음
@export var sell_price: int = 0
## 몬스터볼만 true
@export var infinite: bool = false
## 플레이어 레벨이 이 값 이상이어야 상점에서 살 수 있다 (0 = 처음부터, v0.79)
@export var unlock_level: int = 0
## 아이콘을 다른 아이템과 같이 쓸 때 그 id (특성 캡슐은 특성마다 아이템이 따로지만 그림은 하나, v0.79)
@export var icon_id: StringName = &""


func icon_path() -> String:
	return "res://Assets/Generated/icons/%s.png" % (icon_id if icon_id != &"" else id)


func load_icon() -> Texture2D:
	return load(icon_path()) if ResourceLoader.exists(icon_path()) else null


func is_ball() -> bool:
	return category == &"ball"


func catch_modifier() -> float:
	return float(params.get(&"catch_modifier", 1.0))


func can_buy() -> bool:
	return buy_price > 0 and sources.has(&"shop")


## 지금 상점에 보이는가 (해금 레벨, v0.79)
func is_on_sale(player_level: int) -> bool:
	return can_buy() and player_level >= unlock_level


func can_sell() -> bool:
	return sell_price > 0 and not infinite
