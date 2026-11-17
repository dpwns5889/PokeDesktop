class_name ShinySparkle
extends Node2D
## 색이 다른 포켓몬 등장 연출 (기획서 4.2, M11).
## 포켓몬 주변에서 별 모양 반짝임 몇 개가 바깥으로 퍼지며 커졌다 작아지고, 끝나면 스스로 지워진다.
## 위치 = 포켓몬 중심(기준 해상도). 그림 파일 없이 코드로 그린다.

const DURATION := 1.3
const COUNT := 7
const RADIUS_FROM := 14.0
const RADIUS_TO := 40.0
const COLORS := [Color(1.0, 0.95, 0.55), Color(1.0, 1.0, 1.0), Color(0.75, 0.9, 1.0)]

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in COUNT:
		# 별마다 출발 시각을 조금씩 늦춘다
		var start := i * 0.08
		var k := clampf((_t - start) / (DURATION - start), 0.0, 1.0)
		if k <= 0.0:
			continue
		var ang := TAU * i / COUNT + 0.4
		var r := lerpf(RADIUS_FROM, RADIUS_TO, k)
		var pos := Vector2(cos(ang), sin(ang)) * r
		var size := sin(k * PI) * 5.0 + 1.0     # 커졌다 작아짐
		_draw_star(pos.round(), size, COLORS[i % COLORS.size()])


## 네 갈래 별 (픽셀 느낌이 나도록 직사각형 두 개 + 가운데 점)
func _draw_star(c: Vector2, s: float, color: Color) -> void:
	var len := roundf(s)
	draw_rect(Rect2(c.x - len, c.y, len * 2.0 + 1.0, 1.0), color)
	draw_rect(Rect2(c.x, c.y - len, 1.0, len * 2.0 + 1.0), color)
	if len >= 3.0:
		draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), color)
