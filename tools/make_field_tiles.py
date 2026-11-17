"""왼쪽 들판 타일 생성기 (기획서 6.1, 7.4, v0.48).

Assets/Sprites/reference/ 의 게임 화면(확대·흐림·원근이 있어 그대로 자를 수 없음)에서 뽑은
색 팔레트와 무늬를 참고해, 정면 탑뷰 16×16 타일을 코드로 새로 그린다.
원근 보정: 비스듬히 보이던 절벽·단은 "윗면 + 한 칸 앞면"으로 단순화한다.

실행: python tools/make_field_tiles.py   (프로젝트 루트에서)
결과: Assets/Generated/field/<region_id>.png  (816×16, 칸 51개 — 칸 번호는 FieldTiles 와 같음)
      Assets/Generated/preview_field.png      (검토용: 지역별 타일 줄)

칸 번호 (v0.49)
  0 땅  1 땅(풀결)  2 땅(얼룩)  3 장식(꽃·자갈·눈)
  4 풀숲 윗줄  5 풀숲
  6~14  길 9칸   (왼위 위 오위 / 왼 가운데 오 / 왼아래 아래 오아래)
  15~23 물 9칸
  24~32 단(바위 단) 9칸 — 아래 줄은 앞면(세로 줄무늬)
  33 돌  34 덤불(풀 지역) / 수정(동굴 지역)
  35~50 나무 64×64 = 4×4칸 (위 줄부터 왼→오)
"""
import math
import os
import random
import sys

from PIL import Image

T = 16
COLS = 51
OUT_DIR = 'Assets/Generated/field'
PREVIEW = 'Assets/Generated/preview_field.png'


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

def build(region):
    p = Pal(THEMES[region])
    tiles = [ground(p, 0), ground(p, 1), ground(p, 2), deco(p), tall_grass(p, True), tall_grass(p, False)]
    tiles += patch9(p, 'path')
    tiles += patch9(p, 'water')
    tiles += patch9(p, 'ledge')
    tiles += [rock(p), bush_or_crystal(p)]
    tiles += tree(p)
    assert len(tiles) == COLS, len(tiles)
    sheet = Canvas(T * COLS, T)
    for i, t in enumerate(tiles):
        sheet.paste(t, i * T, 0)
    return sheet.to_image()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheets = {}
    for region in THEMES:
        im = build(region)
        im.save(os.path.join(OUT_DIR, region + '.png'))
        sheets[region] = im
    prev = Image.new('RGBA', (T * COLS * 2, T * 2 * len(sheets) + 4 * len(sheets)), (40, 40, 48, 255))
    for i, (region, im) in enumerate(sheets.items()):
        prev.paste(im.resize((im.width * 2, im.height * 2), Image.NEAREST), (0, i * (T * 2 + 4)))
    prev.save(PREVIEW)
    print('들판 타일 %d지역 → %s' % (len(sheets), OUT_DIR))


if __name__ == '__main__':
    sys.exit(main())
