class_name FieldMaps
extends RefCounted
## 메인 화면 왼쪽 들판의 지역별 타일 배치 (기획서 6.1, v0.48).
## 한 글자 = 16×16 한 칸. 20칸 × 11줄 = 320×176 (장면 163px 만 보이고 마지막 줄은 조금 잘린다).
## 타일 그림: Assets/Generated/field/<지역>.png (tools/make_field_tiles.py). 칸 번호는 FieldTiles.
##
##  .  땅 (칸마다 땅 3종 중 하나)     *  장식(꽃·자갈·눈·리벳)
##  g  풀숲 (지나갈 수 있음)          p  길
##  w  물·용암 (못 지나감)            T  나무 4×4 (64×64, v0.49. 못 지나감)
##     나무 칸은 4칸씩 짝짓는다. 맵 왼쪽·위 끝에 닿은 나무 줄은 오른쪽·아래 끝에 맞춰 짝지어
##     가장자리 밖으로 잘린 나무처럼 보인다(예: 위 3줄 = 나무의 아래 3/4).
##  h  바위 단 (못 지나감)            o  돌 (못 지나감)
##  b  덤불·수정 (못 지나감)
## 길·물·단·풀숲은 같은 글자 이웃을 보고 가장자리 칸을 고른다(맵 밖은 같은 글자로 본다).
## 왼쪽 위(지역 이름)·오른쪽 위(버프)·왼쪽 아래(엔트리 상자)는 되도록 비워 둔다.

const COLS := 20
const ROWS := 11

const MAPS := {
	&"grassland": [
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		".....*........gggggg",
		".*......*.....gggggg",
		"ppppppppppp...gggggg",
		"ppppppppppp...gggggg",
		".....*......b.......",
		"..*......o......TTTT",
		"..........*.....TTTT",
		"................TTTT",
	],
	&"forest": [
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		"TTTT........gggg....",
		"TTTT...pppppppp.....",
		"TTTT...pppppppp.....",
		"TTTT.b..........gggg",
		".......*....o...gggg",
		"..gggg..........TTTT",
		"..gggg.....*....TTTT",
		"................TTTT",
	],
	&"waterside": [
		"TTTTTTTT.....wwwwwww",
		"TTTTTTTT.....wwwwwww",
		"TTTTTTTT.....wwwwwww",
		"..*..........wwwwwww",
		".......gggg..wwwwwww",
		".......gggg..wwwwwww",
		"pppppppppp...wwwwwww",
		"pppppppppp.o.wwwwwww",
		"..*..........wwwwwww",
		".........*...wwwwwww",
		".............wwwwwww",
	],
	&"cave": [
		"hhhhhhhh....hhhhhhhh",
		"hhhhhhhh....hhhhhhhh",
		"hhhhhhhh..b.hhhhhhhh",
		".....b..........b...",
		".o..........*.......",
		".......hhhhh........",
		"..*....hhhhh...wwwww",
		".......hhhhh...wwwww",
		"...............wwwww",
		"........o......wwwww",
		"...............wwwww",
	],
	&"power_plant": [
		"hhhh..hhhh..hhhh..hh",
		"hhhh..hhhh..hhhh..hh",
		"....................",
		".b........b.........",
		"....pppppppppppp....",
		"....pppppppppppp....",
		".............*......",
		"..*...........hhhh..",
		"........o.....hhhh..",
		"..............hhhh..",
		"....................",
	],
	&"volcano": [
		"hhhhhh........hhhhhh",
		"hhhhhh..b.....hhhhhh",
		"hhhhhh........hhhhhh",
		"..........o.........",
		"..*.wwwwww......b...",
		"....wwwwww..........",
		"....wwwwww....*.....",
		"..........ppppppppp.",
		"..........ppppppppp.",
		"...b......o.........",
		"....................",
	],
	&"ghost_tower": [
		"hhhh............hhhh",
		"hhhh..b......b..hhhh",
		"hhhh............hhhh",
		"........o...........",
		".....pppppppppp.....",
		".....pppppppppp.....",
		"..*...........*.....",
		"...........o....b...",
		"..........hhhh......",
		"..........hhhh......",
		"....................",
	],
	&"snow_mountain": [
		"TTTTTTTTTTTT....TTTT",
		"TTTTTTTTTTTT....TTTT",
		"TTTTTTTTTTTT....TTTT",
		"......*.......gggg..",
		"..............gggg..",
		"..wwwww...o.........",
		"..wwwww.......*.....",
		"..wwwww....pppppppp.",
		"...........pppppppp.",
		"..*...b.............",
		"....................",
	],
	&"deep_cave": [
		"hhhhhhhhhhhhhhhhhhhh",
		"hhhhhhhhhhhhhhhhhhhh",
		"hhhhh..b......hhhhhh",
		"..........o.........",
		"...wwwwwwww.....b...",
		"...wwwwwwww.........",
		"...wwwwwwww....*....",
		"..........hhhhh.....",
		"..b.......hhhhh..o..",
		"..........hhhhh.....",
		"....................",
	],
}


## 지역 배치. 없으면 초원.
static func rows_for(region_id: StringName) -> Array:
	return MAPS.get(region_id, MAPS[&"grassland"])
