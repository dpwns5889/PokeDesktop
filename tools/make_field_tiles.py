"""왼쪽 들판 타일 생성기 (기획서 6.1, 7.4, v0.48).

assets/sprites/reference/ 의 게임 화면(확대·흐림·원근이 있어 그대로 자를 수 없음)에서 뽑은
색 팔레트와 무늬를 참고해, 정면 탑뷰 16×16 타일을 코드로 새로 그린다.
원근 보정: 비스듬히 보이던 절벽·단은 "윗면 + 한 칸 앞면"으로 단순화한다.

실행: python tools/make_field_tiles.py   (프로젝트 루트에서)
결과: assets/generated/field/<region_id>.png  (1600×16, 칸 100개 — 칸 번호는 FieldMap 과 같음)
      tools/previews/preview_field.png      (검토용: 지역별 타일 줄)
      tools/previews/preview_field_maps.png (검토용: 모든 지역 들판, tools/preview_field_maps.py)

칸 번호 (v0.70)
  0 땅  1 땅(풀결)  2 땅(얼룩)  3 장식
  4 풀숲 윗줄  5 풀숲
  6~14  길 9칸   (왼위 위 오위 / 왼 가운데 오 / 왼아래 아래 오아래)
  15~23 물 9칸
  24~32 단(언덕) 9칸
  33 돌  34 덤불
  35~46 나무 3×4  47~50 큰 바위 2×2  51~52 작은 나무 1×2  53~58 기계 3×2  59 상자 (위 줄부터 왼→오)
  60~62 가로 다리  63~65 세로 다리  66~69 꽃밭 4종  70 물 위 회색 돌  71~74 물 위 회색 큰 바위 2×2
  75~90 나무 군락 4×4 (열 0 = 첫 그루 왼쪽, 1 = 오른쪽 + 다음 그루 경계, 2 = 다음 그루 왼쪽, 3 = 마지막 그루 오른쪽 /
         줄 0 = 뒤 나무와 겹친 윗부분, 1 = 꼭대기, 2 = 몸통, 3 = 밑동)
  91~98 군락 옆 칸 (줄 r: 91 + 2r = 군락 왼쪽 옆 땅, 92 + 2r = 오른쪽 옆 땅) — 군락 그림은 양 끝 나무가 칸 경계에서
         잘려 있어, 한 그루 나무 그림에서 삐져나온 잎 가장자리를 옆 땅 칸에 그린다
  99    풀 덤불 (Tileset1 덤불을 작게 다듬음, 지나갈 수 있음 — 34 덤불은 Object 열매 덤불에서 열매를 지운 것, 못 지나감)

v0.69: assets/sprites/tilemap/Tileset1.png 와 Object.png 가 있으면 모든 칸을 그 두 장에서 잘라 쓴다 (아래 TILESETS).
없으면 코드로 그린 그림.
"""
import math
import os
import random
import sys

from PIL import Image

T = 16
TREE_W, TREE_H = 3, 4   # 나무 한 그루 = 3×4칸 (v0.69 Object.png, assets/scenes/main/field_map.gd 와 같게)
ROCK_I, BUSH_I = 33, 34   # 돌·덤불 칸 (ROCK 은 아래 팔레트 이름)
TREE = 35                                   # 35~46 나무 3×4
BOULDER = TREE + TREE_W * TREE_H            # 47~50 큰 바위 2×2
SMALL_TREE = BOULDER + 2 * 2                # 51~52 작은 나무 1×2
MACHINE = SMALL_TREE + 1 * 2                # 53~58 기계 3×2
CRATE = MACHINE + 3 * 2                     # 59 상자
BRIDGE_H = CRATE + 1                        # 60~62 가로 다리, 63~65 세로 다리, 66~69 꽃밭 4종
BRIDGE_V = BRIDGE_H + 3
FLOWERS = BRIDGE_V + 3
FLOWER_KINDS = 4
WATER_ROCK = FLOWERS + FLOWER_KINDS          # 70 물 위 회색 돌, 71~74 물 위 회색 큰 바위 2×2
WATER_BOULDER = WATER_ROCK + 1
CLUSTER = WATER_BOULDER + 2 * 2            # 75~90 나무 군락 4×4 (여러 그루가 붙은 숲, Object.png 12~15줄)
CLUSTER_SIDE = CLUSTER + 4 * 4             # 91~98 군락 양 끝 옆 칸 (줄마다 왼쪽 옆·오른쪽 옆)
LEAF_BUSH = CLUSTER_SIDE + 4 * 2           # 99 풀 덤불 (지나갈 수 있음)
COLS = LEAF_BUSH + 1
OUT_DIR = 'assets/generated/field'
PREVIEW = 'tools/previews/preview_field.png'


def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


CLEAR = (0, 0, 0, 0)

# ---------------------------------------------------------------- 팔레트
# 참고 이미지에서 뽑은 색 (plain2: 풀·풀숲·모래길·나무, Forest1: 숲, cave1~3: 동굴 바닥·단·물, etc1: 강·다리·절벽)
GRASS_TALL = dict(tall_out='#1d5a3a', tall_dk='#216b44', tall_md='#259d44', tall_lt='#32c057', tall_hi='#5ce692')
TREE_GREEN = dict(tree_out='#2e2a1c', tree_dk='#3f4a22', tree_md='#4d661d', tree_lt='#5aa249', tree_hi='#86c860',
                  trunk='#8a5a2b', trunk_dk='#5a3a1c')
SAND_PATH = dict(path='#f7dd8c', path_lt='#fbe9a8', path_dk='#e9c27a', path_edge='#d6a35e')
WATER = dict(water='#3c8cf0', water_dk='#2a6cd0', water_lt='#78b8f8', foam='#e0f4ff')
ROCK = dict(rock_hi='#a89e8a', rock_lt='#8f8879', rock_md='#6d6553', rock_dk='#5d5748', rock_out='#3a3428')

THEMES = {
    'grassland': dict(style='grass', ground='#6be7ad', ground_lt='#86efbe', ground_dk='#43cb8e', shade='#3fb985',
                      deco='flowers', bush=True, **GRASS_TALL, **TREE_GREEN, **SAND_PATH, **WATER, **ROCK),
    'forest': dict(style='grass', ground='#4fb87a', ground_lt='#62c88a', ground_dk='#3a9a62', shade='#2f8656',
                   deco='flowers', bush=True,
                   tall_out='#163f2a', tall_dk='#1b5236', tall_md='#1f7a3a', tall_lt='#2a9a48', tall_hi='#48c070',
                   tree_out='#1c2416', tree_dk='#2a3d1e', tree_md='#36592a', tree_lt='#467a34', tree_hi='#62a04a',
                   trunk='#7a4e26', trunk_dk='#4a3018',
                   path='#cfa874', path_lt='#ddb98a', path_dk='#b8905e', path_edge='#987048', **WATER, **ROCK),
    'waterside': dict(style='grass', ground='#6be7ad', ground_lt='#86efbe', ground_dk='#43cb8e', shade='#3fb985',
                      deco='flowers', bush=True, **GRASS_TALL, **TREE_GREEN, **SAND_PATH,
                      water='#2f6fe0', water_dk='#1f4fc8', water_lt='#6aa4f4', foam='#e8f6ff',
                      rock_hi='#9a8890', rock_lt='#7a6670', rock_md='#6b5663', rock_dk='#4b3644', rock_out='#2e2028'),
    'cave': dict(style='rock', ground='#58625f', ground_lt='#6a7470', ground_dk='#455050', shade='#3c4645',
                 deco='pebbles', bush=False, crystal=('#1e3a30', '#2f6b55', '#3f8a6a', '#6fbf98'),
                 **GRASS_TALL, **TREE_GREEN, **SAND_PATH,
                 water='#1c6d91', water_dk='#145a7c', water_lt='#3a8fb0', foam='#8ac4d6', **ROCK),
    'power_plant': dict(style='plate', ground='#8a92a2', ground_lt='#a4acba', ground_dk='#6c7484', shade='#5c6474',
                        deco='rivets', bush=False, crystal=('#3a3020', '#c8a020', '#f0d040', '#fff0a0'),
                        **GRASS_TALL, **TREE_GREEN,
                        path='#c8b060', path_lt='#e0c870', path_dk='#a89040', path_edge='#706028',
                        water='#3a4a6a', water_dk='#2a3850', water_lt='#5a6e94', foam='#a8b8d8',
                        rock_hi='#c0c8d4', rock_lt='#9aa2b0', rock_md='#767e8e', rock_dk='#5c6474', rock_out='#323844'),
    'volcano': dict(style='rock', ground='#7a5a4a', ground_lt='#8e6c58', ground_dk='#5e4438', shade='#4e382e',
                    deco='pebbles', bush=False, crystal=('#3a1408', '#b03818', '#e86030', '#ffb070'),
                    **GRASS_TALL, **TREE_GREEN,
                    path='#a87858', path_lt='#bc8c68', path_dk='#8c6046', path_edge='#6a4632',
                    water='#e04818', water_dk='#b83010', water_lt='#f89038', foam='#ffe070',
                    rock_hi='#a07868', rock_lt='#86604e', rock_md='#6a4a3c', rock_dk='#523a30', rock_out='#2a1c16'),
    'ghost_tower': dict(style='plate', ground='#5e5272', ground_lt='#72668a', ground_dk='#4a4060', shade='#3c3450',
                        deco='pebbles', bush=False, crystal=('#1c1428', '#5a3c8a', '#8a5ac8', '#d0a8ff'),
                        **GRASS_TALL, **TREE_GREEN,
                        path='#8a7aa0', path_lt='#9c8cb2', path_dk='#76688c', path_edge='#5a4e70',
                        water='#2a2440', water_dk='#1c1830', water_lt='#463c66', foam='#7a6aa0',
                        rock_hi='#9a90a8', rock_lt='#7c7290', rock_md='#625a76', rock_dk='#4c4560', rock_out='#241f30'),
    'snow_mountain': dict(style='snow', ground='#e6eef8', ground_lt='#ffffff', ground_dk='#c4d4ea', shade='#a8bcd8',
                          deco='snow', bush=True,
                          tall_out='#5a7890', tall_dk='#7896b0', tall_md='#a0bcd4', tall_lt='#c8dcec', tall_hi='#f0f8ff',
                          tree_out='#1c2c2c', tree_dk='#2a4a44', tree_md='#3a6458', tree_lt='#c8dcec', tree_hi='#ffffff',
                          trunk='#6a4a30', trunk_dk='#40301c',
                          path='#c8d6e6', path_lt='#d8e4f0', path_dk='#b0c2d8', path_edge='#90a6c4',
                          water='#9ccce8', water_dk='#7ab0d4', water_lt='#c4e4f6', foam='#ffffff',
                          rock_hi='#d0d8e4', rock_lt='#a8b2c0', rock_md='#8894a4', rock_dk='#6c7888', rock_out='#3a4250'),
    'deep_cave': dict(style='rock', ground='#3c4448', ground_lt='#4a5458', ground_dk='#2e3438', shade='#262c30',
                      deco='pebbles', bush=False, crystal=('#101c2c', '#2a5a8a', '#4a8ac8', '#a8d8ff'),
                      **GRASS_TALL, **TREE_GREEN, **SAND_PATH,
                      water='#123c58', water_dk='#0c2c44', water_lt='#245a7c', foam='#5a8aa8',
                      rock_hi='#7a7468', rock_lt='#625c52', rock_md='#4c4840', rock_dk='#3c3832', rock_out='#1c1a16'),
}


class Pal:
    def __init__(self, d):
        self.d = d

    def __getattr__(self, k):
        v = self.d[k]
        return hx(v) if isinstance(v, str) else v


# ---------------------------------------------------------------- 그리기 도구

class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y % self.h][x % self.w]

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y][x]
                if c[3]:
                    self.set(ox + x, oy + y, c)

    def to_image(self):
        im = Image.new('RGBA', (self.w, self.h))
        im.putdata([c for row in self.px for c in row])
        return im


def wob(n, seed):
    """길이 16 주기로 반복되는 0/1 흔들림 (타일 경계가 이어지도록)"""
    r = random.Random(seed)
    pattern = [r.choice([0, 0, 1]) for _ in range(T)]
    return pattern[n % T]


# ---------------------------------------------------------------- 땅

def ground(p, variant, seed=0):
    c = Canvas(T, T, p.ground)
    r = random.Random(1000 + seed + variant * 17)
    style = p.d['style']
    if style == 'grass':
        # HGSS 풀밭: 거의 평평한 색 + 드문드문 밝은 점(디더)
        for _ in range(5 if variant == 2 else 3):
            c.set(r.randrange(T), r.randrange(T), p.ground_lt)
        if variant == 1:   # 풀결: 작은 "ᴧᴧ" 두 개
            for (bx, by) in [(3, 5), (10, 11)]:
                for dx, dy in [(0, 1), (1, 0), (2, 1), (3, 0), (4, 1)]:
                    c.set(bx + dx, by + dy, p.ground_dk)
        if variant == 2:
            for _ in range(4):
                c.set(r.randrange(T), r.randrange(T), p.ground_dk)
    elif style == 'snow':
        for _ in range(6 if variant == 2 else 3):
            c.set(r.randrange(T), r.randrange(T), p.ground_dk)
        if variant == 1:
            for (bx, by) in [(4, 6), (11, 12)]:
                for dx in range(3):
                    c.set(bx + dx, by, p.ground_lt)
                    c.set(bx + dx, by + 1, p.ground_dk)
    elif style == 'rock':
        # 동굴 바닥: 납작한 자갈 무늬 (밝은 덩어리 + 아래·오른쪽 어두운 테)
        stones = {0: [(4, 4, 3), (12, 11, 3)], 1: [(3, 11, 2), (11, 4, 3), (8, 13, 2)], 2: [(6, 7, 4), (14, 2, 2)]}[variant]
        for (cx, cy, rr) in stones:
            for y in range(-rr - 1, rr + 2):
                for x in range(-rr - 1, rr + 2):
                    d = (x * x) / (rr * rr * 1.4) + (y * y) / (rr * rr * 0.8)
                    if d <= 1.0:
                        c.set((cx + x) % T, (cy + y) % T, p.ground_lt)
            for y in range(-rr - 1, rr + 2):
                for x in range(-rr - 1, rr + 2):
                    d = (x * x) / (rr * rr * 1.4) + (y * y) / (rr * rr * 0.8)
                    if 1.0 < d <= 1.6 and (y > 0 or x > 0):
                        c.set((cx + x) % T, (cy + y) % T, p.ground_dk)
    elif style == 'plate':
        # 바닥판: 16px 판, 위·왼쪽 밝은 테, 아래·오른쪽 이음매
        for i in range(T):
            c.set(i, 0, p.ground_lt)
            c.set(0, i, p.ground_lt)
            c.set(i, T - 1, p.ground_dk)
            c.set(T - 1, i, p.ground_dk)
        if variant == 1:
            for i in range(3, 13, 3):
                c.set(i, 8, p.ground_dk)
        if variant == 2:
            for _ in range(4):
                c.set(r.randrange(2, 14), r.randrange(2, 14), p.ground_dk)
    return c


def deco(p):
    c = ground(p, 0, 3)
    kind = p.d['deco']
    if kind == 'flowers':
        # 4장 꽃잎 꽃 두 송이 (주황·흰색, 노란 가운데) — plain2 의 꽃밭
        for (fx, fy, col, dk) in [(4, 4, (244, 140, 60, 255), (208, 96, 40, 255)), (11, 10, (250, 250, 244, 255), (200, 206, 214, 255))]:
            for dx, dy in [(-1, 2), (1, 2), (0, 3)]:
                c.set(fx + dx, fy + dy, p.shade)
            for dx, dy in [(0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)]:
                c.set(fx + dx, fy + dy, col)
            for dx, dy in [(1, 1), (0, 2), (2, 0)]:
                c.set(fx + dx, fy + dy, dk)
            c.set(fx, fy, (248, 208, 48, 255))
    elif kind == 'pebbles':
        for (x, y) in [(4, 5), (10, 3), (8, 11), (13, 12)]:
            c.set(x, y, p.rock_lt)
            c.set(x + 1, y, p.rock_lt)
            c.set(x, y + 1, p.rock_dk)
            c.set(x + 1, y + 1, p.rock_dk)
    elif kind == 'rivets':
        for (x, y) in [(3, 3), (12, 3), (3, 12), (12, 12)]:
            c.set(x, y, p.rock_hi)
            c.set(x + 1, y + 1, p.rock_dk)
    elif kind == 'snow':
        for (x, y) in [(4, 4), (11, 9)]:
            for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]:
                c.set(x + dx, y + dy, p.ground_lt)
            c.set(x + 1, y + 2, p.shade)
    return c


# ---------------------------------------------------------------- 풀숲 (plain2 오른쪽의 짙은 풀숲)

def tall_grass(p, top):
    base = ground(p, 0, 9)
    c = Canvas(T, T, p.tall_md)
    # 잎 덩어리 4개 (2×2, 엇갈림) — 타일이 이어지도록 좌표를 16 으로 감는다
    clumps = [(4, 4), (12, 4), (0, 12), (8, 12), (16, 12)]
    for (cx, cy) in clumps:
        for y in range(-4, 4):
            for x in range(-4, 5):
                if abs(x) + max(0, y) * 0.6 > 4.5:
                    continue
                if y <= -3:
                    col = p.tall_hi if x < 0 else p.tall_lt
                elif y <= -1:
                    col = p.tall_lt if x < 1 else p.tall_md
                elif y <= 1:
                    col = p.tall_md
                else:
                    col = p.tall_dk
                c.set((cx + x) % T, (cy + y) % T, col)
        c.set(cx % T, (cy + 3) % T, p.tall_out)
        c.set((cx - 1) % T, (cy + 3) % T, p.tall_out)
        c.set((cx + 1) % T, (cy + 3) % T, p.tall_out)
    if not top:
        return c
    # 윗줄: 위 4px 는 땅이 보이고 잎 끝이 삐죽 올라온다
    out = Canvas(T, T)
    out.paste(base, 0, 0)
    for x in range(T):
        tip = 4 - (2 if x % 4 == 1 else (1 if x % 4 in (0, 2) else 0))
        for y in range(tip, T):
            out.set(x, y, c.get(x, y))
        out.set(x, tip, p.tall_out if x % 4 == 3 else p.tall_hi)
    return out


# ---------------------------------------------------------------- 9칸 덩어리 (길·물·단)

INSET = 3   # 덩어리 바깥 가장자리 칸에서 경계까지 거리


def patch9(p, kind):
    """kind: path / water / ledge → 9칸 (왼위, 위, 오위, 왼, 가운데, 오, 왼아래, 아래, 오아래)"""
    tiles = []
    for row in range(3):
        for col in range(3):
            c = ground(p, 0, 5 + row * 3 + col)
            inside = lambda x, y, row=row, col=col: _inside9(x, y, row, col, kind)
            body = Canvas(T, T)
            r = random.Random(77 + row * 3 + col)
            for y in range(T):
                for x in range(T):
                    if not inside(x, y):
                        continue
                    edge = any(not inside(x + dx, y + dy) for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
                    body.set(x, y, _fill9(p, kind, x, y, row, col, edge, r, inside))
            # 바깥 테두리(덩어리 밖 1px): 길은 땅 그림자, 물은 물가 그림자, 단은 그림자
            for y in range(T):
                for x in range(T):
                    if inside(x, y):
                        continue
                    if any(inside(x + dx, y + dy) for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]):
                        c.set(x, y, p.shade)
            c.paste(body, 0, 0)
            # 단 아래 그림자 한 줄 더
            if kind == 'ledge' and row == 2:
                for x in range(T):
                    for y in range(T - 1, -1, -1):
                        if inside(x, y):
                            if y + 2 < T:
                                c.set(x, y + 2, p.shade)
                            break
            tiles.append(c)
    return tiles


def _inside9(x, y, row, col, kind):
    if not (0 <= x < T and 0 <= y < T):
        # 이웃 칸으로 넘어가면: 가운데 쪽이면 안, 바깥쪽이면 밖
        if x < 0 and col == 0 or x >= T and col == 2 or y < 0 and row == 0 or y >= T and row == 2:
            return False
        return _inside9(min(max(x, 0), T - 1), min(max(y, 0), T - 1), row, col, kind)
    seed = {'path': 11, 'water': 23, 'ledge': 37}[kind]
    left = INSET + wob(y, seed) if col == 0 else -99
    right = T - 1 - INSET - wob(y, seed + 1) if col == 2 else 99
    top = INSET + wob(x, seed + 2) if row == 0 else -99
    bottom = T - 1 - INSET - wob(x, seed + 3) if row == 2 else 99
    if kind == 'ledge':   # 단은 반듯하게
        left = INSET if col == 0 else -99
        right = T - 1 - INSET if col == 2 else 99
        top = INSET if row == 0 else -99
        bottom = T - 1 - 1 if row == 2 else 99
    if not (left <= x <= right and top <= y <= bottom):
        return False
    rad = 4 if kind != 'ledge' else 2
    for (is_c, cx, cy) in [(row == 0 and col == 0, left + rad, top + rad), (row == 0 and col == 2, right - rad, top + rad),
                           (row == 2 and col == 0, left + rad, bottom - rad), (row == 2 and col == 2, right - rad, bottom - rad)]:
        if is_c:
            inx = (x < cx) if cx == left + rad else (x > cx)
            iny = (y < cy) if cy == top + rad else (y > cy)
            if inx and iny and (x - cx) ** 2 + (y - cy) ** 2 > rad * rad + 1:
                return False
    return True


def _fill9(p, kind, x, y, row, col, edge, r, inside):
    if kind == 'path':
        if edge:
            return p.path_edge
        if not inside(x, y - 1) or not inside(x - 1, y):
            return p.path_dk
        return p.path_lt if r.random() < 0.06 else p.path
    if kind == 'water':
        if edge:
            return p.foam
        if any(not inside(x + dx, y + dy) for dx, dy in [(2, 0), (-2, 0), (0, 2), (0, -2)]):
            return p.water_lt
        # 물결: 짧은 밝은 가로줄 (엇갈림, 16 주기)
        if (y % 6 == 2 and (x + (y // 6) * 5) % 8 in (0, 1, 2)):
            return p.water_lt
        if (y % 6 == 3 and (x + (y // 6) * 5) % 8 in (1, 2)):
            return p.water_dk
        return p.water
    # ledge: 윗면(얼룩 무늬) + 아래 줄은 앞면(세로 줄무늬)
    if edge:
        return p.rock_out
    if row == 2 and y >= 7:
        if y == 7:
            return p.rock_lt
        return p.rock_dk if x % 3 == 0 else p.rock_md
    if not inside(x, y - 1) or not inside(x - 1, y):
        return p.rock_hi
    return p.rock_lt if (x * 7 + y * 3) % 11 < 2 else (p.rock_hi if (x * 5 + y * 9) % 17 == 0 else mix(p.rock_lt, p.rock_hi, 0.5))


# ---------------------------------------------------------------- 입체 덩어리 칠하기 (v0.49)
# 둥근 덩어리(lobe) 여러 개를 하나의 울퉁불퉁한 입체로 보고, 왼쪽 위에서 오는 빛으로 한 번에 명암을 준다.
# (v0.48 은 원마다 따로 밝은 쪽을 칠해 겹친 곳의 명암이 어긋났다)

LIGHT = (-0.55, -0.75, 0.62)


def _norm(v):
    l = math.sqrt(sum(c * c for c in v))
    return tuple(c / l for c in v)


def blob(c, lobes, cols, bump=0.0, bump_n=7, outline=True, dither=True):
    """lobes: [(cx, cy, r)], cols: (out, dk, md, lt, hi). bump: 가장자리 잎 톱니 크기"""
    out_c, dk, md, lt, hi = cols
    L = _norm(LIGHT)
    inside = {}
    for y in range(c.h):
        for x in range(c.w):
            best = None
            for (cx, cy, r) in lobes:
                dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                ang = math.atan2(dy, dx)
                rr = 1.0 + bump * math.sin(ang * bump_n + cx * 0.7)
                d2 = dx * dx + dy * dy
                if d2 > rr * rr:
                    continue
                z = math.sqrt(max(0.0, rr * rr - d2)) * r
                if best is None or z + cy * 0.02 > best[0]:
                    best = (z + cy * 0.02, dx, dy, math.sqrt(max(0.0, rr * rr - d2)))
            if best:
                inside[(x, y)] = best
    for (x, y), (_, dx, dy, nz) in inside.items():
        n = _norm((dx, dy, nz + 0.15))
        k = n[0] * L[0] + n[1] * L[1] + n[2] * L[2]
        if dither and (x + y) % 2 == 0:
            k += 0.06
        col = hi if k > 0.86 else lt if k > 0.62 else md if k > 0.30 else dk
        c.set(x, y, col)
    if outline:
        for (x, y) in inside:
            if any((x + ox, y + oy) not in inside for ox, oy in [(1, 0), (-1, 0), (0, 1), (0, -1)]):
                c.set(x, y, out_c)
    return inside


def _ellipse_shadow(c, cx, cy, rx, ry, col):
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                c.set(x, y, col)


# ---------------------------------------------------------------- 나무 (plain2·Forest1 의 소나무, 64×64 = 4×4칸, v0.49)

def tree(p):
    S = 64
    c = Canvas(S, S)
    g = ground(p, 0, 21)
    for y in range(S):
        for x in range(S):
            c.set(x, y, g.get(x, y))
    _ellipse_shadow(c, 32, 57, 25, 6.5, p.shade)
    # 줄기 (아래 가운데)
    for y in range(47, 60):
        for x in range(27, 38):
            col = p.trunk
            if x in (27, 37) or y == 59:
                col = p.tree_out
            elif x <= 29:
                col = mix(p.trunk, (255, 255, 255, 255), 0.15)
            elif x >= 35:
                col = p.trunk_dk
            c.set(x, y, col)
    cols = (p.tree_out, p.tree_dk, p.tree_md, p.tree_lt, p.tree_hi)
    # 아래 층부터 위 층 순서로 겹쳐 칠한다 (위 층이 앞)
    tiers = [
        [(10, 41, 9), (20, 43, 10), (32, 44, 11), (44, 43, 10), (54, 41, 9)],
        [(14, 31, 9), (25, 33, 10), (39, 33, 10), (50, 31, 9)],
        [(19, 21, 8.5), (32, 22, 10), (45, 21, 8.5)],
        [(26, 12, 7.5), (38, 12, 7.5)],
        [(32, 6, 6)],
    ]
    for tier in tiers:
        blob(c, tier, cols, bump=0.09, bump_n=9)
    tiles = []
    for ty in range(4):
        for tx in range(4):
            t = Canvas(T, T)
            for y in range(T):
                for x in range(T):
                    t.set(x, y, c.get(tx * T + x, ty * T + y))
            tiles.append(t)
    return tiles


# ---------------------------------------------------------------- 돌·덤불·수정

def rock(p):
    c = ground(p, 0, 31)
    _ellipse_shadow(c, 8.5, 12.5, 7.0, 3.0, p.shade)
    blob(c, [(8, 9, 6.5), (6, 8, 4.5)], (p.rock_out, p.rock_dk, p.rock_md, p.rock_lt, p.rock_hi), dither=False)
    return c


def bush_or_crystal(p):
    c = ground(p, 0, 41)
    if p.d.get('bush'):
        # 덤불: 잎 덩어리 4개를 하나의 입체로 (v0.49 다시 그림)
        _ellipse_shadow(c, 8, 13, 7.5, 2.8, p.shade)
        blob(c, [(4.5, 10, 4.2), (11.5, 10, 4.2), (8, 9.5, 4.6), (8, 5.5, 4.3)],
             (p.tall_out, p.tall_dk, p.tall_md, p.tall_lt, p.tall_hi), bump=0.12, bump_n=7)
        return c
    out_c, dk, md, hi = [hx(v) for v in p.d['crystal']]
    # 원뿔 수정 (cave1 의 초록 뾰족 바위)
    for x in range(1, 15):
        c.set(x, 15, p.shade)
    for (cx, top, bot, slope) in [(11.0, 6, 14, 0.42), (6.0, 1, 14, 0.42)]:
        for y in range(top, bot + 1):
            half = (y - top) * slope + 0.6
            for x in range(T):
                dx = x - cx
                if abs(dx) <= half:
                    col = hi if dx < -half * 0.25 and y < bot - 3 else (md if dx < half * 0.35 else dk)
                    if abs(dx) > half - 1 or y == bot:
                        col = out_c
                    c.set(x, y, col)
    return c


# ---------------------------------------------------------------- 묶기

def tree_small(p):
    """타일 세트가 없을 때의 나무: 코드로 그린 64×64 나무를 TREE_W×TREE_H 칸으로 줄인다."""
    big = Image.new('RGBA', (64, 64))
    for i, t in enumerate(tree(p)):
        big.paste(t.to_image(), ((i % 4) * T, (i // 4) * T))
    small = big.resize((TREE_W * T, TREE_H * T), Image.NEAREST)
    return [img_canvas(small.crop((x * T, y * T, x * T + T, y * T + T))) for y in range(TREE_H) for x in range(TREE_W)]


# ---------------------------------------------------------------- 타일 세트에서 자르기 (v0.68)
# assets/sprites/tilemap/Tileset1.png (땅·풀숲·꽃밭·길·물·용암·단·다리, 16×16 칸)와
# assets/sprites/tilemap/Object.png (나무·바위·덤불·기계·상자, 16×16 칸) 두 장에서 잘라 쓴다.
# 칸 좌표 = (세트, 열, 줄). 비어 있는(투명) 곳은 그 지역 땅 칸(0번) 위에 겹친다.
# 세트 파일이 없으면(공개 저장소 등) 그 칸은 위의 코드로 그린 그림을 그대로 쓴다.

SETS_DIR = 'assets/sprites/tilemap'
S, O = 'Tileset1', 'Object'
_sets = {}


def tileset(name):
    if name not in _sets:
        path = os.path.join(SETS_DIR, name + '.png')
        _sets[name] = Image.open(path).convert('RGBA') if os.path.exists(path) else None
    return _sets[name]


def img_canvas(im):
    c = Canvas(im.width, im.height)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c.px[y][x] = tuple(px[x, y])
    return c


def cut(name, col, row, w=1, h=1):
    """세트의 (col, row) 칸부터 w×h 칸을 잘라 Image 로. 세트가 없으면 None."""
    s = tileset(name)
    if s is None:
        return None
    return s.crop((col * T, row * T, (col + w) * T, (row + h) * T))


def split(im, w, h):
    return [im.crop((x * T, y * T, x * T + T, y * T + T)) for y in range(h) for x in range(w)]


def over(base, im):
    """base(Canvas, 땅) 위에 im(Image) 을 겹친 새 Canvas"""
    out = base.to_image()
    out.alpha_composite(im)
    return img_canvas(out)


def recolor(im, fn):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c[3]:
                px[x, y] = fn(c)
    return out


def darken(k, tint=(0, 0, 0)):
    return lambda c: tuple(max(0, min(255, int(c[i] * k + tint[i]))) for i in range(3)) + (c[3],)


def frost(c):
    """눈 덮인 색: 초록 잎은 하얗게(밝을수록 더), 줄기는 그대로"""
    r, g, b, a = c
    if g > r and g >= b:
        light = (r + g + b) / 765.0
        t = 0.45 + 0.45 * light
        return (int(r + (236 - r) * t), int(g + (244 - g) * t), int(b + (252 - b) * t), a)
    return c


def gray(k=1.0, tint=(0, 0, 0)):
    """밝기만 남긴 회색 (k 배, tint 더하기) — 흙 언덕을 바위 단으로"""
    def f(c):
        lum = (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) * k
        return tuple(max(0, min(255, int(lum + tint[i]))) for i in range(3)) + (c[3],)
    return f


def purple(c):
    """유령탑: 밝기만 남겨 보랏빛으로"""
    lum = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    return (min(255, int(lum * 0.78 + 18)), min(255, int(lum * 0.62 + 8)), min(255, int(lum * 0.95 + 34)), c[3])


def icy(c):
    """동굴 물을 옅은 얼음물로"""
    return (min(255, int(c[0] * 0.6 + 90)), min(255, int(c[1] * 0.6 + 110)), min(255, int(c[2] * 0.5 + 130)), c[3])


def no_grass(im):
    """흙 언덕(Tileset1 24~26열)의 모서리 풀 바탕을 지운다 → 어느 지역 땅 위에나 얹을 수 있게"""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and g > r + 12 and g > b:
                px[x, y] = (0, 0, 0, 0)
    return out


def pond9():
    """풀밭 연못 9칸: Tileset1 10~12열 0~2줄 (오른쪽 위 모서리가 비어 있어 왼쪽 위를 좌우로 뒤집어 쓴다)"""
    if tileset(S) is None:
        return None
    tl = cut(S, 10, 0)
    parts = [tl, cut(S, 11, 0), tl.transpose(Image.FLIP_LEFT_RIGHT),
             cut(S, 10, 1), cut(S, 11, 1), cut(S, 12, 1),
             cut(S, 10, 2), cut(S, 11, 2), cut(S, 12, 2)]
    out = Image.new('RGBA', (3 * T, 3 * T))
    for k, im in enumerate(parts):
        out.paste(im, ((k % 3) * T, (k // 3) * T))
    return out


def nine(name, col, row):
    return cut(name, col, row, 3, 3)


def no_bg(im):
    """풀 바탕이 깔린 칸(새 덤불 (2,2))에서 가장자리와 이어진 풀밭 색(0~2,0 칸의 색)을 지운다"""
    pal = set()
    for c in range(3):
        g = cut(S, c, 0)
        pal |= {g.getpixel((x, y)) for x in range(T) for y in range(T)}
    out = im.copy()
    px = out.load()
    w, h = out.size
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y] in pal:
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return out


def cluster_block(kind):
    """나무 군락 4×4칸. dark = Object (0~3, 12~15) 짙은 숲 그대로,
    light = Object (5~8, 13~15) 둥근 나무 줄 3줄 — 맨 윗줄(뒤 나무와 겹친 부분)이 없어 꼭대기 줄을 한 번 더."""
    if kind == 'dark':
        return cut(O, 0, 12, 4, 4)
    out = Image.new('RGBA', (4 * T, 4 * T))
    out.paste(cut(O, 5, 13, 4, 1), (0, 0))
    out.paste(cut(O, 5, 13, 4, 3), (0, T))
    return out


# 군락 한 그루(2칸 = 32px)와 같은 그림인 한 그루 나무(3×4칸 = 48px): 나무 그림 (8, y0) 부터가 군락 2칸과 겹친다.
# 그 왼쪽 8px·오른쪽 8px 이 군락 끝에서 잘린 잎 가장자리.
CLUSTER_TREE = {'light': ((O, 1, 0), 9), 'dark': ((O, 4, 0), 10)}


def cluster_sides(kind):
    """군락 옆 칸 8장 (줄 0~3 × 왼쪽 옆·오른쪽 옆). 왼쪽 옆 칸은 칸 오른쪽 끝에, 오른쪽 옆 칸은 왼쪽 끝에 잎 가장자리."""
    spec, y0 = CLUSTER_TREE[kind]
    tree = _one(spec, 3, 4)
    if tree is None:
        return None
    # 위아래로 여유를 둔 나무 그림 (y = 16 + 나무 y)
    tall = Image.new('RGBA', (3 * T, 6 * T))
    tall.paste(tree, (0, T))

    def band(ty):   # 나무 y = ty 부터 16줄
        return tall.crop((0, T + ty, 3 * T, 2 * T + ty))
    rows = [None, band(y0), band(y0 + T), band(y0 + 2 * T)]
    if kind == 'light':
        rows[0] = rows[1]   # 군락 그림도 맨 윗줄 = 꼭대기 줄
    else:
        # 겹친 줄 = 위 나무 몸통 아래쪽 위에 앞(아래) 나무 꼭대기
        r0 = band(y0 + T).copy()
        r0.alpha_composite(band(y0 - T))
        rows[0] = r0
    out = []
    for im in rows:
        left = Image.new('RGBA', (T, T))
        left.paste(im.crop((0, 0, 8, T)), (8, 0))
        right = Image.new('RGBA', (T, T))
        right.paste(im.crop((5 * 8, 0, 6 * 8, T)), (0, 0))
        out += [left, right]
    return out


def no_berry(im):
    """Object 열매 덤불: 노란 열매 픽셀을 둘레 잎 색(가장 흔한 이웃 색)으로 채운다"""
    out = im.copy()
    px = out.load()
    w, h = out.size

    def berry(c):
        return c[3] and c[0] > 120 and c[2] < 60

    todo = [(x, y) for y in range(h) for x in range(w) if berry(px[x, y])]
    while todo:
        rest = []
        fills = {}
        for (x, y) in todo:
            near = [px[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                    if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h]
            near = [c for c in near if c[3] and not berry(c)]
            if near:
                fills[(x, y)] = max(set(near), key=near.count)
            else:
                rest.append((x, y))
        for k, c in fills.items():
            px[k] = c
        if len(rest) == len(todo):
            break
        todo = rest
    return out


def trim_bush(im):
    """Tileset1 덤불(칸을 거의 채움)의 바깥 잎을 지워 작고 둥글게: 타원 밖을 지우고 새 가장자리에 가장 어두운 색 테"""
    out = im.copy()
    px = out.load()
    cols = [px[x, y] for y in range(T) for x in range(T) if px[x, y][3]]
    dark = min(cols, key=lambda c: c[0] + c[1] + c[2]) if cols else (0, 0, 0, 255)
    for y in range(T):
        for x in range(T):
            if ((x + 0.5 - 8) / 7.2) ** 2 + ((y + 0.5 - 8.8) / 6.9) ** 2 > 1.0:
                px[x, y] = (0, 0, 0, 0)
    keep = {(x, y) for y in range(T) for x in range(T) if px[x, y][3]}
    for (x, y) in keep:
        if any((x + dx, y + dy) not in keep for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            px[x, y] = dark
    return out


# ---- 설산: 풀밭 타일을 눈 색으로 옮겨 같은 무늬·같은 느낌으로 (v0.70)
def _lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255.0


def _shift(base, d, k=300, cool=(0.85, 0.92, 1.0)):
    return tuple(max(0, min(255, int(base[i] + d * k * cool[i]))) for i in range(3))


_ref = {}


def _ref_lum(key):
    """기준 밝기: 풀밭 바탕 / 모래길 가운데 / 연못 물 가운데"""
    if key not in _ref:
        spot = {'grass': (S, 0, 0), 'sand': (S, 4, 1), 'water': (S, 11, 1)}[key]
        _ref[key] = _lum(cut(*spot).getpixel((8, 8)))
    return _ref[key]


SNOW = (236, 242, 250)
TRODDEN = (204, 214, 230)
ICE = (176, 216, 238)
BANK = (214, 224, 238)


def snowify(c):
    """땅 무늬: 풀색 → 눈, 모래·흙 → 다져진 눈길(옅은 잿빛 파랑), 물 → 얼음물. 밝기 차이(풀결·얼룩)는 그대로 살린다"""
    r, g, b, a = c
    L = _lum(c)
    if g > r + 8 and g >= b:
        return _shift(SNOW, L - _ref_lum('grass')) + (a,)
    if b > r + 20 and b >= g:
        return _shift(ICE, L - _ref_lum('water'), 220) + (a,)
    return _shift(TRODDEN, L - _ref_lum('sand'), 260) + (a,)


def snow_bank(c):
    """연못 흙 둑 → 눈 둑, 물 → 얼음물"""
    r, g, b, a = c
    if b > r + 20 and b >= g:
        return _shift(ICE, _lum(c) - _ref_lum('water'), 220) + (a,)
    return _shift(BANK, _lum(c) - 0.5, 180) + (a,)


def snowcap(thr, greens_only=False):
    """물체에 눈 덮기: 밝은(빛 받는 윗면) 픽셀은 눈, 어두운 픽셀은 차가운 색. greens_only 면 잎만(줄기 그대로)"""
    def f(c):
        r, g, b, a = c
        green = g > r + 4 and g >= b
        if greens_only and not green:
            return c
        L = _lum(c)
        if L >= thr:
            return _shift(SNOW, (L - thr) * 0.5 - 0.02, 300) + (a,)
        if green:
            return (int(r * 0.55 + 18), int(g * 0.62 + 30), int(b * 0.7 + 44), a)
        return (int(L * 150 + 24), int(L * 165 + 34), int(L * 190 + 52), a)
    return f


# ---- 실험실 바닥 (발전소, v0.70): Object.png 기계와 어울리는 밝은 회색 패널·금속 벽을 코드로 그린다
LAB_HI, LAB_SEAM, LAB_RIVET = (226, 230, 238), (146, 154, 170), (168, 176, 190)
LAB_BASE = [(202, 208, 218), (198, 204, 214), (206, 212, 222)]


def lab_floor(v):
    im = Image.new('RGBA', (T, T), LAB_BASE[v] + (255,))
    px = im.load()
    for i in range(T):
        px[i, 0] = px[0, i] = LAB_HI + (255,)
        px[i, T - 1] = px[T - 1, i] = LAB_SEAM + (255,)
    for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
        px[x, y] = LAB_RIVET + (255,)
    if v == 2:   # 옅은 긁힘
        for x, y in ((6, 9), (7, 9), (8, 10), (9, 10)):
            px[x, y] = (188, 194, 206, 255)
    return im


def lab_vent():
    im = lab_floor(0)
    px = im.load()
    for y in range(5, 11):
        for x in range(4, 12):
            px[x, y] = (92, 100, 116, 255) if y in (5, 10) or x in (4, 11) else ((120, 128, 144, 255) if y % 2 == 0 else (74, 80, 96, 255))
    return im


def _round_inside(x, y, x0, y0, x1, y1, r=2):
    """(x, y)가 모서리를 r 만큼 깎은 사각형 안인가"""
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    dx = max(x0 + r - x, x - (x1 - r), 0)
    dy = max(y0 + r - y, y - (y1 - r), 0)
    return dx + dy <= r


def lab_floor9():
    """발전소 길(p) 자리: 물처럼 보이던 청록 통로를 없애고 바닥 패널 그대로 (v0.70)"""
    out = Image.new('RGBA', (3 * T, 3 * T))
    for k in range(9):
        out.paste(lab_floor(0), ((k % 3) * T, (k // 3) * T))
    return out


def lab_platform9():
    """금속 벽(단 h): 회청색 철판(16px 이음매·리벳) + 짙은 테. 음영 없음 — 앞면 띠·윗줄 밝은 테를 그리지 않는다"""
    W = 3 * T
    im = Image.new('RGBA', (W, W))
    px = im.load()
    for y in range(W):
        for x in range(W):
            if not _round_inside(x, y, 1, 1, W - 2, W - 2, 1):
                continue
            if not _round_inside(x, y, 2, 2, W - 3, W - 3, 1):
                px[x, y] = (58, 64, 78, 255)
            else:
                lx, ly = x % T, y % T
                c = (150, 158, 174)
                if lx in (0, T - 1) or ly in (0, T - 1):
                    c = (138, 146, 162)
                if (lx, ly) in ((3, 3), (12, 3), (3, 12), (12, 12)):
                    c = (116, 124, 140)
                px[x, y] = c + (255,)
    return im


# 지역별 칸 (v0.69). 키 = 칸 번호 묶음, 값 = 자를 위치
#   'ground': [(세트, 열, 줄[, 'flip'|'flipv']) × 3]   'deco': (세트, 열, 줄)   'tall': (세트, 열, 줄) — 풀숲 두 칸 모두
#   'path' / 'water' / 'ledge': 3×3칸 그림을 돌려주는 함수
#   'fx': 땅·장식·길·물·단에 적용할 색 바꾸기,  'obj_fx': 오브젝트·꽃밭·다리에 적용할 색 바꾸기
#   오브젝트(Object.png, 모두 못 지나감): 'tree' 3×4, 'boulder' 2×2, 'small_tree' 1×2, 'rock' 1칸, 'bush' 1칸
#   'stone_fx': 땅 위 돌(갈색 작은 돌·큰 바위, 돌인 덤불)의 색 바꾸기 — 회색 돌은 물 위(water_rock·water_boulder)에만
COMMON = {
    'tall': (S, 1, 2),
    'path': lambda: nine(S, 3, 0),                          # 모래길 (풀 테두리)
    'water': pond9,                                         # 흙 둑 연못
    'ledge': lambda: no_grass(nine(S, 24, 0)),              # 흙 언덕
    'flowers': [(S, 0, 3), (S, 1, 3), (S, 0, 4), (S, 1, 4)],
    'bridge_h': (S, 28, 0),
    'bridge_v': (S, 31, 0),
    'tree': (O, 1, 0),                                      # 한 그루 나무 Y (밝은 활엽수)
    'cluster': 'light',                                     # 여러 그루 나무 T (둥근 나무 줄)
    'boulder': (O, 7, 0),                                   # 갈색 큰 바위 (땅 위 돌은 모두 갈색 돌 — 지역마다 stone_fx 로 색만 바꿈)
    'small_tree': (O, 0, 0),
    'rock': (O, 9, 0),                                      # 갈색 작은 돌
    'bush': (O, 0, 2, 'noberry'),                           # 덤불 b = Object 열매 덤불에서 열매를 지운 것 (못 지나감)
    'leaf_bush': (S, 2, 1, 'nobg', 'trim'),                 # 풀 덤불 v = Tileset1 덤불의 바깥 잎을 지워 작게 (지나갈 수 있음)
    'machine': (O, 0, 5),                                   # 발전소 기계 3대
    'crate': (O, 3, 6),
    'water_rock': (O, 9, 2),                                # 회색 돌·큰 바위 = 물결 테두리 → 물 위에만
    'water_boulder': (O, 7, 2),
}
GRASS_SET = {
    'ground': [(S, 0, 0), (S, 1, 0), (S, 2, 0)],
    'deco': (S, 1, 1),                                      # 흰 꽃
}
CAVE_SET = {
    'ground': [(S, 0, 5), (S, 1, 5), (S, 0, 6)],
    'deco': (S, 1, 6),
    'path': lambda: nine(S, 3, 5),                          # 짙은 돌바닥
    'water': lambda: nine(S, 7, 5),                         # 동굴 물웅덩이
    'ledge': lambda: recolor(no_grass(nine(S, 24, 0)), gray(0.78)),   # 흙 언덕을 잿빛 바위 언덕으로
    'tree': (O, 4, 0),
    'bush': (O, 9, 0),                                      # 작은 돌 (동굴엔 덤불이 없다)
    'stone_fx': gray(0.9, (0, 6, 12)),                      # 갈색 돌을 푸른 잿빛으로
}

TILESETS = {
    'grassland': GRASS_SET,
    'forest': dict(GRASS_SET, deco=(S, 0, 1), tree=(O, 4, 0), cluster='dark'),   # 클로버, 짙은 나무·짙은 숲
    'waterside': GRASS_SET,
    'cave': CAVE_SET,
    'deep_cave': dict(CAVE_SET, fx=darken(0.62, (0, 2, 10)), obj_fx=darken(0.75, (0, 2, 10))),   # 어둡게
    'volcano': {
        'ground': [(S, 10, 10), (S, 10, 10, 'flip'), (S, 10, 10, 'flipv')],   # 붉은 흙바닥
        'deco': (S, 10, 10, 'flip', 'flipv'),
        'path': lambda: nine(S, 6, 9),                      # 잿빛 돌바닥
        'water': lambda: nine(S, 10, 5),                    # 용암
        'ledge': lambda: recolor(no_grass(nine(S, 24, 0)), darken(0.72, (10, 0, 0))),
        'bush': (O, 9, 0),                                  # 작은 돌 (화산엔 덤불이 없다)
        'stone_fx': darken(0.8, (22, 0, 0)),                # 붉게 그을린 돌
    },
    # 설산 (v0.70): 풀밭·모래길·연못·언덕·나무를 눈 색으로 옮겨 다른 지역과 같은 무늬로
    'snow_mountain': {
        'ground': [lambda c=c: recolor(cut(S, c, 0), snowify) for c in range(3)],
        'deco': lambda: recolor(cut(S, 0, 1), snowify),
        'tall_fx': snowify,
        'path': lambda: recolor(nine(S, 3, 0), snowify),     # 다져진 눈길
        'water': lambda: recolor(pond9(), snow_bank),       # 눈 둑 얼음 연못
        'ledge': lambda: recolor(no_grass(nine(S, 24, 0)), snowcap(0.5)),   # 눈 덮인 바위 언덕
        'tree': (O, 4, 0),
        'tree_fx': snowcap(0.36, True),
        'cluster': 'dark',
        'cluster_fx': snowcap(0.36, True),
        'small_tree': (O, 9, 4),                            # 침엽수
        'small_tree_fx': snowcap(0.3, True),
        'stone_fx': snowcap(0.5),                           # 눈 덮인 돌
        'bush_fx': snowcap(0.42, True),
        'water_rock_fx': None,
    },
    # 발전소 = 실험실 (v0.70): 밝은 회색 패널 바닥 + 음영 없는 금속 벽, 기계·상자
    'power_plant': {
        'ground': [lambda v=v: lab_floor(v) for v in range(3)],
        'deco': lab_vent,
        'path': lab_floor9,                                 # 청록 통로 없음 (물처럼 보였다)
        'ledge': lab_platform9,
        'stone_fx': gray(0.95, (6, 8, 14)),                 # 쇳빛 돌
        'bush': (O, 3, 6),                                  # 상자
    },
    # 유령탑: 짙은 돌바닥·잿빛 길·바위 언덕을 보랏빛으로
    'ghost_tower': {
        'ground': [(S, 4, 6), (S, 4, 6, 'flip'), (S, 4, 6, 'flipv')],
        'deco': (S, 1, 6),
        'path': lambda: nine(S, 6, 9),
        'ledge': lambda: no_grass(nine(S, 24, 0)),
        'fx': purple,
        'bush': (O, 9, 0),                                  # 작은 돌 (보랏빛은 obj_fx)
        'obj_fx': purple,
    },
}


def _one(spec, w=1, h=1):
    """(세트, 열, 줄[, 'flip'|'flipv'|'nobg'|'noberry'|'trim' …]) 또는 그림을 돌려주는 함수"""
    if callable(spec):
        return spec()
    im = cut(spec[0], spec[1], spec[2], w, h)
    if im is not None:
        for f in spec[3:]:
            if f == 'nobg':
                im = no_bg(im)
            elif f == 'noberry':
                im = no_berry(im)
            elif f == 'trim':
                im = trim_bush(im)
            else:
                im = im.transpose(Image.FLIP_LEFT_RIGHT if f == 'flip' else Image.FLIP_TOP_BOTTOM)
    return im


def apply_tileset(region, tiles):
    """코드로 그린 tiles(COLS개) 중 세트로 바꿀 수 있는 칸을 바꾼다"""
    if tileset(S) is None or tileset(O) is None:
        return tiles
    spec = dict(COMMON, **TILESETS.get(region, {}))
    fx = spec.get('fx')
    obj_fx = spec.get('obj_fx')

    def fix(im, extra=None, f=fx):
        if im is None:
            return None
        if extra:
            im = recolor(im, extra)
        return recolor(im, f) if f else im

    def obj(im, extra=None):
        return fix(im, extra, obj_fx)

    tiles = list(tiles)
    for i, g in enumerate(spec['ground']):
        tiles[i] = img_canvas(fix(_one(g)))
    base = tiles[0]

    def put(i, im, under=None):
        if im is not None:
            tiles[i] = over(under or base, im)
    put(3, fix(_one(spec['deco'])))
    put(4, fix(_one(spec['tall']), spec.get('tall_fx')))
    put(5, fix(_one(spec['tall']), spec.get('tall_fx')))
    for key, first in (('path', 6), ('water', 15), ('ledge', 24)):
        im = spec[key]()
        if im is not None:
            for k, part in enumerate(split(fix(im), 3, 3)):
                put(first + k, part)
    stone_fx = spec.get('stone_fx')
    put(ROCK_I, obj(_one(spec['rock']), stone_fx))
    bush_is_stone = spec['bush'][0] == O and spec['bush'][1:3] == spec['rock'][1:3]
    put(BUSH_I, obj(_one(spec['bush']), stone_fx if bush_is_stone else spec.get('bush_fx')))
    put(LEAF_BUSH, obj(_one(spec['leaf_bush']), spec.get('bush_fx')))
    put(CRATE, obj(_one(spec['crate'])))
    spec['boulder_fx'] = stone_fx
    for key, first, w, h in (('tree', TREE, 3, 4), ('boulder', BOULDER, 2, 2), ('small_tree', SMALL_TREE, 1, 2),
                             ('machine', MACHINE, 3, 2)):
        im = _one(spec[key], w, h)
        if im is not None:
            for k, part in enumerate(split(obj(im, spec.get(key + '_fx')), w, h)):
                put(first + k, part)
    # 다리는 물 가운데 칸 위에
    water_mid = tiles[19]
    for key, first, w, h in (('bridge_h', BRIDGE_H, 3, 1), ('bridge_v', BRIDGE_V, 1, 3)):
        im = _one(spec[key], w, h)
        for k, part in enumerate(split(obj(im), w, h)):
            put(first + k, part, water_mid)
    for k, f in enumerate(spec['flowers']):
        put(FLOWERS + k, obj(_one(f)))
    # 나무 군락 (여러 그루가 붙은 숲)
    for k, part in enumerate(split(obj(cluster_block(spec['cluster']), spec.get('cluster_fx')), 4, 4)):
        put(CLUSTER + k, part)
    # 군락 양 끝 옆 칸: 잘린 잎 가장자리 (군락과 같은 색 바꾸기)
    for k, part in enumerate(cluster_sides(spec['cluster']) or []):
        put(CLUSTER_SIDE + k, obj(part, spec.get('cluster_fx')))
    # 회색 돌·큰 바위는 물 가운데 칸 위에 (물결 테두리가 물에 잠긴 돌처럼 보이게)
    put(WATER_ROCK, obj(_one(spec['water_rock'])), water_mid)
    for k, part in enumerate(split(obj(_one(spec['water_boulder'], 2, 2)), 2, 2)):
        put(WATER_BOULDER + k, part, water_mid)
    return tiles


def build(region):
    p = Pal(THEMES[region])
    tiles = [ground(p, 0), ground(p, 1), ground(p, 2), deco(p), tall_grass(p, True), tall_grass(p, False)]
    tiles += patch9(p, 'path')
    tiles += patch9(p, 'water')
    tiles += patch9(p, 'ledge')
    tiles += [rock(p), bush_or_crystal(p)]
    # 세트가 없을 때: 나무 = 코드로 그린 나무를 3×4칸으로, 나머지 오브젝트는 돌·덤불, 다리(길 가운데)·꽃밭(장식)
    tiles += tree_small(p)
    tiles += [tiles[ROCK_I]] * 4 + [tiles[BUSH_I]] * 2 + [tiles[ROCK_I]] * 6 + [tiles[ROCK_I]]
    tiles += [tiles[10]] * 6 + [tiles[3]] * FLOWER_KINDS
    tiles += [tiles[ROCK_I]] * 5
    tiles += [tiles[TREE + 4]] * 16
    tiles += [tiles[0]] * 8 + [tiles[BUSH_I]]
    tiles = apply_tileset(region, tiles)
    assert len(tiles) == COLS, len(tiles)
    sheet = Canvas(T * COLS, T)
    for i, t in enumerate(tiles):
        sheet.paste(t, i * T, 0)
    return sheet.to_image()


def save_retry(im, path, tries=20):
    """열려 있는 Godot 편집기가 다시 가져오는 중이면 파일이 잠깐 잠긴다 → 조금 기다렸다 다시"""
    import time
    for i in range(tries):
        try:
            im.save(path)
            return
        except OSError:
            if i == tries - 1:
                raise
            time.sleep(0.3)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheets = {}
    for region in THEMES:
        im = build(region)
        save_retry(im, os.path.join(OUT_DIR, region + '.png'))
        sheets[region] = im
    prev = Image.new('RGBA', (T * COLS * 2, T * 2 * len(sheets) + 4 * len(sheets)), (40, 40, 48, 255))
    for i, (region, im) in enumerate(sheets.items()):
        prev.paste(im.resize((im.width * 2, im.height * 2), Image.NEAREST), (0, i * (T * 2 + 4)))
    save_retry(prev, PREVIEW)
    print('들판 타일 %d지역 → %s' % (len(sheets), OUT_DIR))
    # 모든 지역 지형을 한 장에 (v0.68: 지형을 바꾸면 늘 함께 만든다)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.dont_write_bytecode = True   # tools/__pycache__ 를 만들지 않게
    import preview_field_maps
    preview_field_maps.main()


if __name__ == '__main__':
    sys.exit(main())
