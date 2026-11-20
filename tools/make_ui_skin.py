"""HGSS 가방 메뉴 느낌의 UI 스킨 그림을 만든다 (테스트, 기획서 6장).

시트를 잘라 쓰지 않고 색과 모양만 참고해 새로 그린다(저작권 시트가 없어도 실행되게).
- 진회색 외곽선, 위쪽 흰색 + 아래쪽 회색 두 단, 모서리 2px 둥글게
- 마우스를 올리면 빨간 테두리(가방 선택 칸)
결과: assets/ui/skin/*.png  →  assets/ui/main_theme.tres 의 StyleBoxTexture 가 9-slice 로 늘려 쓴다.
실행: python tools/make_ui_skin.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "skin"

OUTLINE = (74, 74, 74)
WHITE = (248, 248, 248)
LINE = (222, 222, 222)
GRAY = (189, 189, 189)
SHADE = (140, 140, 140)
RED = (231, 0, 0)
PINK = (255, 148, 148)

W, H = 12, 20
GRAY_FROM = 11   # 이 줄부터 회색 (아래 9줄, 9-slice 아래 여백 안이라 늘어나지 않음)


def inside(x: int, y: int, w: int, h: int) -> bool:
    """모서리 2px 를 깎은 둥근 사각형."""
    inset = [2, 1]
    for i, d in enumerate(inset):
        if (y == i or y == h - 1 - i) and (x < d or x > w - 1 - d):
            return False
    return 0 <= x < w and 0 <= y < h


def edge(x: int, y: int, w: int, h: int) -> bool:
    return inside(x, y, w, h) and not all(inside(x + dx, y + dy, w, h) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def button(fill, outline, ring=None, w: int = W, h: int = H) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if not inside(x, y, w, h):
                continue
            if edge(x, y, w, h):
                c = outline
            elif ring and edge(x - 1, y - 1, w - 2, h - 2):
                c = ring
            else:
                c = fill(y)
            im.putpixel((x, y), c + (255,))
    return im


def two_tone(y: int) -> tuple:
    return WHITE if y < GRAY_FROM - 1 else LINE if y == GRAY_FROM - 1 else GRAY


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    button(two_tone, OUTLINE).save(OUT / "button_normal.png")
    button(two_tone, RED, PINK).save(OUT / "button_hover.png")
    button(lambda y: SHADE if y == 1 else GRAY, OUTLINE).save(OUT / "button_pressed.png")
    button(lambda y: LINE, SHADE).save(OUT / "button_disabled.png")
    # 슬라이더 손잡이: 같은 흰 버튼을 작게
    button(lambda y: WHITE if y < 7 else GRAY, OUTLINE, w=8, h=12).save(OUT / "grabber.png")
    button(lambda y: WHITE if y < 7 else GRAY, RED, w=8, h=12).save(OUT / "grabber_hover.png")
    print("저장:", OUT)


if __name__ == "__main__":
    main()
