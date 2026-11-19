"""포획 연출용 볼 프레임 (기획서 4.3, v0.50).

원본: assets/sprites/DS _ DSi - Pokemon HeartGold _ SoulSilver - Miscellaneous - Poke Balls.png (432×200)
- 볼 종류마다 16px 폭 세로 줄 하나(배경색이 줄마다 다름). 왼쪽부터 마스터볼·하이퍼볼·슈퍼볼·몬스터볼 …
- 줄 안: y 0~127 = 16×16 프레임 8장(0 = 똑바로 선 모습, 0~7 = 굴러가며 도는 모습),
         y 128~143 = 납작해진 모습, y 144~167 = 뚜껑이 열린 모습(16×24)

실행: python tools/make_ball_frames.py   (프로젝트 루트에서)
결과: assets/generated/ui/balls/<볼 id>.png  160×24 = 16×24 칸 10개
      칸 0~7 회전(볼은 칸 아래쪽 16px), 칸 8 납작, 칸 9 열림 — 배경 투명
"""
import os

from PIL import Image

SRC = 'assets/sprites/DS _ DSi - Pokemon HeartGold _ SoulSilver - Miscellaneous - Poke Balls.png'
OUT = 'assets/generated/ui/balls'
COLUMN = {'master_ball': 0, 'ultra_ball': 1, 'great_ball': 2, 'poke_ball': 3}
W, H = 16, 24


def clear_bg(img, bg):
    """가장자리에서 이어진 배경색만 투명으로"""
    px = img.load()
    w, h = img.size
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][:3] != bg:
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]


def main():
    sheet = Image.open(SRC).convert('RGBA')
    os.makedirs(OUT, exist_ok=True)
    for ball, col in COLUMN.items():
        x0 = col * 16
        bg = sheet.getpixel((x0, 0))[:3]
        out = Image.new('RGBA', (W * 10, H), (0, 0, 0, 0))
        cells = [(0, i * 16, 16) for i in range(9)] + [(0, 144, 24)]
        for k, (_, y, h) in enumerate(cells):
            cut = sheet.crop((x0, y, x0 + 16, y + h)).copy()
            clear_bg(cut, bg)
            out.paste(cut, (k * W, H - h), cut)
        out.save(os.path.join(OUT, ball + '.png'))
    print('볼 프레임 %d종 → %s' % (len(COLUMN), OUT))


if __name__ == '__main__':
    main()
