"""아이템 아이콘 = assets/sprites/items 의 32×32 그림을 그대로 복사 (기획서 7.4, v0.101).

실행: python tools/import_item_sprites.py
결과: assets/generated/icons/<아이템 id>.png (원본 크기 그대로)
시트에서 자르는 coin 은 tools/import_icons.gd 가 만든다.
"""
import shutil
from pathlib import Path

SRC = Path("assets/sprites/items")
OUT = Path("assets/generated/icons")
MAP = {
    "poke_ball": "ball/poke", "great_ball": "ball/great", "ultra_ball": "ball/ultra",
    "fire_stone": "evo-item/fire-stone", "water_stone": "evo-item/water-stone",
    "thunder_stone": "evo-item/thunder-stone", "leaf_stone": "evo-item/leaf-stone",
    "moon_stone": "evo-item/moon-stone",
    "nugget": "valuable-item/nugget", "big_nugget": "valuable-item/big-nugget",
    "pearl": "valuable-item/pearl", "star_piece": "valuable-item/star-piece",
    "stardust": "valuable-item/stardust", "pretty_feather": "valuable-item/pretty-wing",
    "lucky_egg": "hold-item/lucky-egg",
    "exp_candy_s": "exp-candy/xs", "exp_candy_m": "exp-candy/s",
    "trait_capsule": "medicine/ability-capsule", "expand_storage": "storage/pokemon-box",
    "incense": "incense/full", "shiny_incense": "incense/odd",
    "gold_cologne": "other-item/max-lure", "forget_berry": "berry/enigma",
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for item_id, rel in MAP.items():
        shutil.copyfile(SRC / f"{rel}.png", OUT / f"{item_id}.png")
    print(f"아이콘 {len(MAP)}개 복사")
