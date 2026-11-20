"""도감 아틀라스(assets/sprites/atlas) → UI 포켓몬 아이콘 PNG. (기획서 7.4)

실행: python tools/import_atlas_icons.py   이후: <godot> --headless --path . --import
원본: regular-gen1.png / shiny-gen1.png (68x56 칸 16열, 도감 번호 순서, 25번 피카츄 뒤에 피카츄 암컷 칸 하나).
결과: assets/generated/icons/pokemon/<이름>.png, <이름>_shiny.png, pikachu-female(_shiny).png
      (24x24 캔버스 가운데에 그림 부분만, 모든 종 같은 배율 0.75 = 크기 차이 유지. UiUtil.ICON_SIZE 그대로)
누락 검사: 1~151번 중 칸이 비었거나 칸 수가 151+1 이 아니면 오류로 멈춘다.
"""
import glob
import os
import re
import sys
from PIL import Image

SRC = "assets/sprites/atlas"
OUT = "assets/generated/icons/pokemon"
SIZE = 24  # UiUtil.ICON_SIZE
CW, CH, COLS = 68, 56, 16
PIKACHU = 25
SCALE = SIZE / 32  # 원본 그림 중 가장 큰 것(32px)이 24px 에 들어가는 공통 배율 → 작은 그림은 작게, 큰 그림은 크게

names = {}  # 도감 번호 → name_en
for f in glob.glob("assets/data/pokemon/gen1/*.tres"):
    m = re.search(r'name_en = "([^"]+)"', open(f, encoding="utf-8").read())
    names[int(os.path.basename(f).split("_")[0])] = m.group(1)
if sorted(names) != list(range(1, 152)):
    sys.exit("종 데이터가 1~151 이 아님")

os.makedirs(OUT, exist_ok=True)
for kind, suffix in (("regular", ""), ("shiny", "_shiny")):
    sheet = Image.open(f"{SRC}/{kind}-gen1.png").convert("RGBA")
    cells = []
    for i in range((sheet.height // CH) * COLS):
        x, y = (i % COLS) * CW, (i // COLS) * CH
        cell = sheet.crop((x, y, x + CW, y + CH))
        if cell.getbbox():
            cells.append(cell)
    if len(cells) != 152:
        sys.exit(f"{kind}: 칸 {len(cells)}개 (152개여야 함: 151종 + 피카츄 암컷)")
    out = {}
    for dex in range(1, 152):
        out[names[dex]] = cells[dex - 1 if dex <= PIKACHU else dex]
    out["pikachu-female"] = cells[PIKACHU]
    for name, cell in out.items():
        art = cell.crop(cell.getbbox())
        w, h = max(1, round(art.width * SCALE)), max(1, round(art.height * SCALE))
        icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        icon.paste(art.resize((w, h), Image.LANCZOS), ((SIZE - w) // 2, (SIZE - h) // 2))
        icon.save(f"{OUT}/{name}{suffix}.png")
    print(kind, "icons:", len(out))
