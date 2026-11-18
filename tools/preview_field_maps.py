"""들판 맵 미리보기 (검토용, v0.48): scripts/data/field_maps.gd 의 배치를 타일 그림으로 조립한다.
가장자리 칸 고르기는 scenes/main/field_map.gd 와 같은 규칙.

실행: python tools/preview_field_maps.py  → Assets/Generated/preview_field_maps.png
"""
import re
import time

from PIL import Image

T = 16
SRC = 'scripts/data/field_maps.gd'
OUT = 'Assets/Generated/preview_field_maps.png'
BASE9 = {'p': 6, 'w': 15, 'h': 24}
ROCK, BUSH = 33, 34
# 여러 칸 오브젝트: 글자 → (첫 칸 번호, 가로, 세로) (v0.64, field_map.gd 와 같게)
TREE = 35
BOULDER = TREE + 3 * 4
SMALL_TREE = BOULDER + 2 * 2
MACHINE = SMALL_TREE + 1 * 2
CRATE = MACHINE + 3 * 2
OBJECTS = {'Y': (TREE, 3, 4), 'O': (BOULDER, 2, 2), 'i': (SMALL_TREE, 1, 2), 'm': (MACHINE, 3, 2)}
BRIDGE_H = CRATE + 1
BRIDGE_V = BRIDGE_H + 3
FLOWERS = BRIDGE_V + 3
FLOWER_KINDS = 4
WATER_ROCK = FLOWERS + FLOWER_KINDS   # 물 위 회색 돌, 다음 4칸 = 물 위 회색 큰 바위 2×2
WATER_BOULDER = WATER_ROCK + 1
OBJECTS['Q'] = (WATER_BOULDER, 2, 2)
CLUSTER = WATER_BOULDER + 2 * 2   # 나무 군락 4×4 (T)
CLUSTER_SIDE = CLUSTER + 4 * 4    # 군락 옆 땅 칸 (줄마다 왼쪽 옆·오른쪽 옆)
LEAF_BUSH = CLUSTER_SIDE + 4 * 2  # 풀 덤불 v
WATERY = ('w', '=', '|', 'q', 'Q')


def load_maps():
    s = open(SRC, encoding='utf-8').read()
    maps = {}
    for m in re.finditer(r'&"(\w+)": \[(.*?)\]', s, re.S):
        maps[m.group(1)] = re.findall(r'"([^"]*)"', m.group(2))
    return maps


def part(rows, x, y, horizontal, ch, size):
    def at(i):
        cx, cy = (i, y) if horizontal else (x, i)
        return 0 <= cy < len(rows) and 0 <= cx < len(rows[cy]) and rows[cy][cx] == ch
    pos = x if horizontal else y
    start = pos
    while at(start - 1):
        start -= 1
    end = pos
    while at(end + 1):
        end += 1
    if start == 0:
        return size - 1 - (end - pos) % size
    return (pos - start) % size


def cluster_index(rows, x, y):
    """나무 군락(T) — field_map.gd _cluster_index 와 같은 규칙"""
    def is_t(xx, yy):
        return 0 <= yy < len(rows) and 0 <= xx < len(rows[yy]) and rows[yy][xx] == 'T'
    s = x
    while is_t(s - 1, y):
        s -= 1
    e = x
    while is_t(e + 1, y):
        e += 1
    i = x - s
    col = 0 if i == 0 else ((3 if x == e else 1) if i % 2 == 1 else 2)
    bottom = y
    while is_t(x, bottom + 1):
        bottom += 1
    d = bottom - y
    row = 3 if d == 0 else [2, 1, 0][(d - 1) % 3]
    return CLUSTER + row * 4 + col


def cluster_side(rows, x, y):
    """땅(.) 칸이 군락 첫 그루 왼쪽 옆 / 마지막 그루 오른쪽 옆이면 옆 칸 번호 — field_map.gd _cluster_side 와 같은 규칙"""
    def is_t(xx, yy):
        return 0 <= yy < len(rows) and 0 <= xx < len(rows[yy]) and rows[yy][xx] == 'T'
    if is_t(x + 1, y):
        i = cluster_index(rows, x + 1, y) - CLUSTER
        if i % 4 == 0:
            return CLUSTER_SIDE + (i // 4) * 2
    if is_t(x - 1, y):
        i = cluster_index(rows, x - 1, y) - CLUSTER
        if i % 4 == 3:
            return CLUSTER_SIDE + (i // 4) * 2 + 1
    return -1


def tile_index(rows, x, y):
    ch = rows[y][x]
    h, w = len(rows), len(rows[0])

    def same(dx, dy):
        nx, ny = x + dx, y + dy
        if not (0 <= nx < w and 0 <= ny < h):
            return True
        return rows[ny][nx] == ch or (ch == 'w' and rows[ny][nx] in WATERY)

    def is_(xx, yy, c):
        return 0 <= yy < h and 0 <= xx < w and rows[yy][xx] == c

    if ch == '.':
        side = cluster_side(rows, x, y)
        if side >= 0:
            return side
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
        return cluster_index(rows, x, y)
    if ch in OBJECTS:
        base, ow, oh = OBJECTS[ch]
        return base + part(rows, x, y, False, ch, oh) * ow + part(rows, x, y, True, ch, ow)
    if ch == 'o':
        return ROCK
    if ch == 'b':
        return BUSH
    if ch == 'v':
        return LEAF_BUSH
    if ch == 'c':
        return CRATE
    if ch == 'q':
        return WATER_ROCK
    if ch == '=':
        return BRIDGE_H + (0 if not is_(x - 1, y, '=') else (2 if not is_(x + 1, y, '=') else 1))
    if ch == '|':
        return BRIDGE_V + (0 if not is_(x, y - 1, '|') else (2 if not is_(x, y + 1, '|') else 1))
    if ch == 'f':
        return FLOWERS + (x * 3 + y * 5) % FLOWER_KINDS
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
    for i in range(20):   # 열려 있는 Godot 편집기가 다시 가져오는 중이면 잠깐 잠긴다
        try:
            out.save(OUT)
            break
        except OSError:
            if i == 19:
                raise
            time.sleep(0.3)
    print('미리보기 →', OUT)


if __name__ == '__main__':
    main()
