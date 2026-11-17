"""들판 맵 미리보기 (검토용, v0.48): scripts/data/field_maps.gd 의 배치를 타일 그림으로 조립한다.
가장자리 칸 고르기는 scenes/main/field_map.gd 와 같은 규칙.

실행: python tools/preview_field_maps.py  → Assets/Generated/preview_field_maps.png
"""
import re

from PIL import Image

T = 16
SRC = 'scripts/data/field_maps.gd'
OUT = 'Assets/Generated/preview_field_maps.png'
BASE9 = {'p': 6, 'w': 15, 'h': 24}
TREE = 4


def load_maps():
    s = open(SRC, encoding='utf-8').read()
    maps = {}
    for m in re.finditer(r'&"(\w+)": \[(.*?)\]', s, re.S):
        maps[m.group(1)] = re.findall(r'"([^"]*)"', m.group(2))
    return maps


def tree_part(rows, x, y, horizontal):
    def at(i):
        cx, cy = (i, y) if horizontal else (x, i)
        return 0 <= cy < len(rows) and 0 <= cx < len(rows[cy]) and rows[cy][cx] == 'T'
    pos = x if horizontal else y
    start = pos
    while at(start - 1):
        start -= 1
    end = pos
    while at(end + 1):
        end += 1
    if start == 0:
        return TREE - 1 - (end - pos) % TREE
    return (pos - start) % TREE


def tile_index(rows, x, y):
    ch = rows[y][x]
    h, w = len(rows), len(rows[0])

    def same(dx, dy):
        nx, ny = x + dx, y + dy
        if not (0 <= nx < w and 0 <= ny < h):
            return True
        return rows[ny][nx] == ch

    if ch == '.':
        k = (x * 7 + y * 13 + x * y) % 20
        return 0 if k < 12 else (1 if k < 17 else 2)
    if ch == '*':
        return 3
    if ch == 'g':
        return 4 if not same(0, -1) else 5
    if ch in BASE9:
        col = 0 if not same(-1, 0) else (2 if not same(1, 0) else 1)
        row = 0 if not same(0, -1) else (2 if not same(0, 1) else 1)
        return BASE9[ch] + row * 3 + col
    if ch == 'T':
        return 35 + tree_part(rows, x, y, False) * TREE + tree_part(rows, x, y, True)
    if ch == 'o':
        return 33
    if ch == 'b':
        return 34
    return 0


def main():
    maps = load_maps()
    shots = []
    for region, rows in maps.items():
        sheet = Image.open('Assets/Generated/field/%s.png' % region)
        im = Image.new('RGBA', (len(rows[0]) * T, len(rows) * T))
        for y in range(len(rows)):
            for x in range(len(rows[0])):
                i = tile_index(rows, x, y)
                im.paste(sheet.crop((i * T, 0, i * T + T, T)), (x * T, y * T))
        shots.append(im.crop((0, 0, 320, 163)))
    out = Image.new('RGBA', (320 * 3 + 8, 163 * 3 + 8), (30, 30, 36, 255))
    for i, im in enumerate(shots):
        out.paste(im, ((i % 3) * 324, (i // 3) * 167))
    out.save(OUT)
    print('미리보기 →', OUT)


if __name__ == '__main__':
    main()
