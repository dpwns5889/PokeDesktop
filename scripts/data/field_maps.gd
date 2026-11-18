class_name FieldMaps
extends RefCounted
## 메인 화면 왼쪽 들판의 지역별 타일 배치 (기획서 6.1, v0.48).
## 한 글자 = 16×16 한 칸. 20칸 × 11줄 = 320×176 (장면 163px 만 보이고 마지막 줄은 조금 잘린다).
## 타일 그림: Assets/Generated/field/<지역>.png (tools/make_field_tiles.py). 칸 번호는 FieldTiles.
##
##  .  땅 (칸마다 땅 3종 중 하나)     *  장식(꽃·자갈·눈)
##  g  풀숲 (지나갈 수 있음)          p  길
##  w  물·용암 (못 지나감)            h  언덕·바위 단 (못 지나감)
##  f  꽃밭 (지나갈 수 있음)          =  가로 나무다리 / |  세로 나무다리 (물 위, 지나갈 수 있음)
##  v  풀 덤불 (Tileset1 덤불을 작게 다듬음, 지나갈 수 있음)
##     다리 아래·옆의 물은 이어진 물로 보아 물가 테두리를 그리지 않는다.
## Object.png 의 물체 — 모두 못 지나감 (v0.64):
##  T  나무 군락 — 여러 그루가 붙은 숲(Object.png 12~15줄). 두 칸 = 한 그루, 아래 끝이 밑동. 짝수 폭이 깔끔하다
##  Y  한 그루 나무 3×4칸     O  큰 바위 2×2칸     i  작은 나무 1×2칸     m  기계 3×2칸 (발전소)
##  o  작은 돌        b  덤불(Object 열매 덤불에서 열매를 지움. 동굴·화산·유령탑: 작은 돌, 발전소: 상자)          c  상자
##     땅 위 돌(o·O)은 갈색 돌을 지역 색으로 바꾼 것.
##  q  물 위 회색 돌   Q  물 위 회색 큰 바위 2×2 — 회색 돌은 물결 테두리가 있어 물(w) 안에만 둔다
##     여러 칸 물체는 같은 글자를 그 크기씩 짝짓는다. 맵 왼쪽·위 끝에 닿은 줄은 오른쪽·아래 끝에 맞춰 짝지어
##     가장자리 밖으로 잘린 물체처럼 보인다(예: 위 3줄 "T" = 나무의 아래 3/4).
##     나무 군락(T) 양 끝 바로 옆의 땅(.) 칸에는 끝 나무의 잎 가장자리가 그려진다(그러니 옆 칸은 . 로 둔다).
## 길·물·단·풀숲은 같은 글자 이웃을 보고 가장자리 칸을 고른다(맵 밖은 같은 글자로 본다).
## 왼쪽 위(지역 이름)·오른쪽 위(버프)·왼쪽 아래(엔트리 상자)는 되도록 비워 둔다.

const COLS := 20
const ROWS := 11

const MAPS := {
	&"grassland": [
		"TTTTTT......TTTTTTTT",
		"TTTTTT......TTTTTTTT",
		"TTTTTT......TTTTTTTT",
		".i...*..ff....gggggg",
		".i......ff....gggggg",
		"ppppppppppp...gggggg",
		"ppppppppppp...gggggg",
		"...v.*......b.......",
		"..ff.....OO.....YYY.",
		"..ff.....OO.*v..YYY.",
		".o.......v......YYY.",
	],
	&"forest": [
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		"TTTTTTTT....TTTTTTTT",
		"YYY.........gggg..i.",
		"YYY....pppppppp...i.",
		"YYY....pppppppp.....",
		"YYY..b.....ff...gggg",
		"....v..*...ffo..gggg",
		"..gggg..v..i....YYY.",
		"..gggg.....i....YYY.",
		"................YYY.",
	],
	&"waterside": [
		"TTTTTTTT.....wwww|ww",
		"TTTTTTTT.....wwww|ww",
		"TTTTTTTT.....===w|qw",
		"..*..ff..v...wwww|ww",
		".i.....gggg..wwwwwww",
		".i.....gggg..=====ww",
		"pppppppppp...wwwwwww",
		"pppppppppp.o.wwwwQQw",
		"..*..ff.v....wqwwQQw",
		"....OO...*...====www",
		"....OO.......wwwwwww",
	],
	&"cave": [
		"hhhhhhhh....hhhhhhhh",
		"hhhhhhhh....hhhhhhhh",
		"hhhhhhhh..b.hhhhhhhh",
		".....b..........b...",
		".o..........*...OO..",
		".......hhhhh....OO..",
		"..*....hhhhh...wwwww",
		".......hhhhh...wwwqw",
		"...............wwwww",
		"..OO....o......wQQww",
		"..OO...........wQQww",
	],
	&"power_plant": [
		"hhhh..hhhh..hhhh..hh",
		"hhhh..hhhh..hhhh..hh",
		"......mmm.....c.....",
		".c....mmm.....cc..o.",
		"....................",
		"........*...........",
		".............*......",
		"..*.mmm.......hhhh..",
		"....mmm.o.....hhhh..",
		"..cc..........hhhh..",
		"....................",
	],
	&"volcano": [
		"hhhhhh........hhhhhh",
		"hhhhhh..b.....hhhhhh",
		"hhhhhh........hhhhhh",
		"..........o.....OO..",
		"..*.wwwwww......OO..",
		"....wwwwww..........",
		"....wwwwww....*.....",
		"..........ppppppppp.",
		"..OO......ppppppppp.",
		"..OO......o.........",
		"...b................",
	],
	&"ghost_tower": [
		"hhhh............hhhh",
		"hhhh..b......b..hhhh",
		"hhhh............hhhh",
		"........o.......OO..",
		".....pppppppppp.OO..",
		".....pppppppppp.....",
		"..*...........*.....",
		"...........o....b...",
		"..OO......hhhh......",
		"..OO......hhhh......",
		"....................",
	],
	&"snow_mountain": [
		"TTTTTTTTTTTT....TTTT",
		"TTTTTTTTTTTT....TTTT",
		"TTTTTTTTTTTT....TTTT",
		"..i...*.......gggg..",
		"..i...........gggg..",
		"..wwwww...o.........",
		"..wwwqw.......*.....",
		"..wwwww....pppppppp.",
		".OO........pppppppp.",
		".OOi..b.......v.....",
		"...i.....v..........",
	],
	&"deep_cave": [
		"hhhhhhhhhhhhhhhhhhhh",
		"hhhhhhhhhhhhhhhhhhhh",
		"hhhhh..b......hhhhhh",
		"..........o.........",
		"...wwwwwwww.....b...",
		"...wwqwwqww.........",
		"...wwwwwwww....*....",
		"..........hhhhh.....",
		"..b.......hhhhh..o..",
		"..OO......hhhhh.....",
		"..OO................",
	],
}


## 지역 배치. 없으면 초원.
static func rows_for(region_id: StringName) -> Array:
	return MAPS.get(region_id, MAPS[&"grassland"])
