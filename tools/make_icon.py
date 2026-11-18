"""프로젝트 아이콘: PC 모니터 화면에 몬스터볼이 나타나는 32×32 픽셀 그림.
모니터·화면은 음영 없이 단색, 반짝임 없음 (v0.71 수정).

결과 (프로젝트 루트):
  icon.png  256×256 (32×32 를 8배 nearest 로 키움) — project.godot 의 config/icon
  icon.ico  16·32·48·64·128·256 — 내보낸 exe 아이콘 (export_presets.cfg application/icon)
실행: python tools/make_icon.py
"""
from pathlib import Path
import math
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
N = 32

OUTLINE = (24, 27, 38, 255)
BEZEL = (62, 70, 90, 255)
SCREEN = (34, 58, 102, 255)
RED = (230, 56, 61, 255)
RED_HI = (255, 120, 110, 255)
RED_LO = (170, 30, 42, 255)
WHITE = (244, 244, 248, 255)
WHITE_LO = (190, 196, 210, 255)
LED = (110, 230, 120, 255)

img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = img.load()


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = c


def rounded(x0, y0, x1, y1, c):
    rect(x0, y0, x1, y1, c)
    for x, y in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
        px[x, y] = (0, 0, 0, 0)


# ---- 받침대
rounded(9, 27, 22, 29, OUTLINE)
rect(10, 28, 21, 28, BEZEL)
rect(13, 24, 18, 27, OUTLINE)
rect(14, 24, 17, 27, BEZEL)

# ---- 모니터 테두리
rounded(1, 2, 30, 24, OUTLINE)
rect(2, 3, 29, 23, BEZEL)
px[27, 22] = LED          # 전원 불빛

# ---- 화면: 단색
SX0, SY0, SX1, SY1 = 4, 5, 27, 20
rect(SX0 - 1, SY0 - 1, SX1 + 1, SY1 + 1, OUTLINE)
rect(SX0, SY0, SX1, SY1, SCREEN)

# ---- 몬스터볼 (반지름 6.5, 화면 가운데)
R = 6.5
bx, by = 16.0, 13.0
for y in range(SY0, SY1 + 1):
    for x in range(SX0, SX1 + 1):
        dx, dy = x + 0.5 - bx, y + 0.5 - by
        d = math.hypot(dx, dy)
        if d > R:
            continue
        if d > R - 1.0:
            px[x, y] = OUTLINE
        elif abs(dy) < 1.0:
            px[x, y] = OUTLINE                       # 가운데 띠
        elif dy < 0:
            # 위 = 빨강, 왼쪽 위 밝게, 오른쪽 아래 어둡게
            if dx < -1.5 and dy < -2.5:
                px[x, y] = RED_HI
            elif dx > 2.5 and dy > -2.5:
                px[x, y] = RED_LO
            else:
                px[x, y] = RED
        else:
            px[x, y] = WHITE_LO if (dx > 2.0 or dy > 4.0) else WHITE
# 가운데 버튼
for y in range(int(by) - 2, int(by) + 2):
    for x in range(int(bx) - 2, int(bx) + 2):
        d = math.hypot(x + 0.5 - bx, y + 0.5 - by)
        if d <= 2.1:
            px[x, y] = OUTLINE if d > 1.2 else WHITE
# 위쪽 하이라이트 한 점
px[12, 9] = WHITE

big = img.resize((256, 256), Image.NEAREST)
big.save(ROOT / "icon.png")
sizes = [16, 32, 48, 64, 128, 256]
frames = []
for s in sizes:
    if s % N == 0:
        frames.append(img.resize((s, s), Image.NEAREST))
    else:   # 16·48: 정수배가 아니라 크게 키운 뒤 부드럽게 줄인다
        frames.append(img.resize((N * 6, N * 6), Image.NEAREST).resize((s, s), Image.LANCZOS))
frames[-1].save(ROOT / "icon.ico", sizes=[(s, s) for s in sizes], append_images=frames[:-1])
print("wrote icon.png, icon.ico")
