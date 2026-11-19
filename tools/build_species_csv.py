"""PokeAPI CSV → tools/source/pokemon_gen<N>.csv, assets/data/types/types.json 생성기. (기획서 7.3)

준비: PokeAPI 저장소의 data/v2/csv/ 에서 아래 파일을 한 폴더에 받는다.
  pokemon_species, pokemon, pokemon_stats, pokemon_types, types, type_names,
  pokemon_species_names, pokemon_evolution, items, pokemon_types_past
실행: python -I tools/build_species_csv.py <받은 폴더> [--gen 1] [--type-gen 1]

- 타입은 --type-gen 세대 기준(기본 1 = 1세대 타입: 페어리·강철 없음).
  다른 세대를 추가할 때 기준을 바꾸려면 --type-gen 값을 바꿔 모든 세대 CSV를 다시 만든다(0 = 현재 세대 기준).
- 종족값은 현재 세대 기준(1세대의 '특수' 능력치는 특공/특방으로 나뉜 값)을 쓴다.
- 통신교환 진화는 기획서 4.9의 레벨 진화로 대체한다.
- 진화 대상이 이번 세대 범위 밖이면(예: 골뱃→크로뱃) 제외한다.
"""
import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

KO = "3"  # PokeAPI local_language_id: 한국어
GEN_DEX_RANGES = {1: (1, 151), 2: (152, 251)}
STAT_KEYS = {"1": "hp", "2": "atk", "3": "def", "4": "spa", "5": "spd", "6": "spe"}

# 기획서 4.9 — 통신교환 진화 대체 (진화 후 도감번호: 레벨)
TRADE_REPLACEMENT_LEVEL = {65: 36, 68: 40, 76: 40, 94: 38}

# 암수 차이가 HGSS(4세대) 이후에 추가되어 스프라이트 시트에 암컷 블록이 없는 종
GENDER_SPRITES_NOT_IN_HGSS = {133}  # 이브이(8세대에 추가)

ROOT = Path(__file__).resolve().parent.parent


def read(folder: Path, name: str) -> list[dict]:
    with open(folder / f"{name}.csv", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("--gen", type=int, default=1)
    ap.add_argument("--type-gen", type=int, default=1, help="타입 기준 세대 (0 = 현재)")
    args = ap.parse_args()
    src: Path = args.src
    lo, hi = GEN_DEX_RANGES[args.gen]

    species = {int(r["id"]): r for r in read(src, "pokemon_species") if lo <= int(r["id"]) <= hi}
    names_ko = {int(r["pokemon_species_id"]): r["name"] for r in read(src, "pokemon_species_names")
                if r["local_language_id"] == KO}
    default_pokemon = {int(r["species_id"]): r for r in read(src, "pokemon")
                       if r["is_default"] == "1" and int(r["species_id"]) in species}
    pid_to_dex = {int(p["id"]): dex for dex, p in default_pokemon.items()}

    stats: dict[int, dict] = defaultdict(dict)
    for r in read(src, "pokemon_stats"):
        dex = pid_to_dex.get(int(r["pokemon_id"]))
        if dex and r["stat_id"] in STAT_KEYS:
            stats[dex][STAT_KEYS[r["stat_id"]]] = int(r["base_stat"])

    type_ident = {r["id"]: r["identifier"] for r in read(src, "types")}
    types: dict[int, list] = defaultdict(list)
    for r in sorted(read(src, "pokemon_types"), key=lambda r: int(r["slot"])):
        dex = pid_to_dex.get(int(r["pokemon_id"]))
        if dex:
            types[dex].append(type_ident[r["type_id"]])

    # 과거 타입: (pokemon, generation_id=G) 행 = G세대까지 쓰인 타입. 기준 세대 이상인 가장 이른 기록을 쓴다.
    if args.type_gen > 0:
        past: dict[int, dict[int, list]] = defaultdict(lambda: defaultdict(list))
        for r in sorted(read(src, "pokemon_types_past"), key=lambda r: int(r["slot"])):
            dex = pid_to_dex.get(int(r["pokemon_id"]))
            if dex:
                past[dex][int(r["generation_id"])].append(type_ident[r["type_id"]])
        for dex, by_gen in past.items():
            gens = sorted(g for g in by_gen if g >= args.type_gen)
            if gens:
                types[dex] = list(dict.fromkeys(by_gen[gens[0]]))

    item_ident = {r["id"]: r["identifier"].replace("-", "_") for r in read(src, "items")}

    # 진화: 진화 전 종 → [(진화 후, 방식, 값)]
    evolutions: dict[int, list] = defaultdict(list)
    seen_targets = set()
    for r in read(src, "pokemon_evolution"):
        to = int(r["evolved_species_id"])
        if not (lo <= to <= hi) or to in seen_targets:
            continue
        frm = int(species[to]["evolves_from_species_id"])
        trig = r["evolution_trigger_id"]
        if to in TRADE_REPLACEMENT_LEVEL:
            evo = (to, "level", str(TRADE_REPLACEMENT_LEVEL[to]))
        elif trig == "1" and r["minimum_level"]:
            evo = (to, "level", r["minimum_level"])
        elif trig == "3" and r["trigger_item_id"]:
            evo = (to, "item", item_ident[r["trigger_item_id"]])
        else:
            continue  # 다른 세대 방식의 중복 행 등은 건너뛴다
        seen_targets.add(to)
        evolutions[frm].append(evo)

    # 진화 단계
    def stage(dex: int) -> int:
        n, cur = 0, species[dex]
        while cur["evolves_from_species_id"] and int(cur["evolves_from_species_id"]) in species:
            n += 1
            cur = species[int(cur["evolves_from_species_id"])]
        return n

    missing_evo = [dex for dex, sp in species.items()
                   if sp["evolves_from_species_id"] and int(sp["evolves_from_species_id"]) in species
                   and dex not in seen_targets]
    if missing_evo:
        raise SystemExit(f"진화 방법을 찾지 못한 종: {missing_evo}")

    out = ROOT / "tools" / "source" / f"pokemon_gen{args.gen}.csv"
    cols = ["dex_id", "generation", "name_ko", "name_en", "type1", "type2",
            "hp", "atk", "def", "spa", "spd", "spe", "catch_rate", "base_exp",
            "gender_ratio", "has_gender_sprites", "evo_stage", "is_legendary", "is_mythical", "evolutions"]
    with open(out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(cols)
        for dex in sorted(species):
            sp, st, ty = species[dex], stats[dex], types[dex]
            gr = int(sp["gender_rate"])  # 암컷 비율(1/8 단위), -1 = 무성
            male_ratio = -1 if gr < 0 else round(1 - gr / 8, 3)
            evo_str = ";".join(f"{t}:{m}:{v}" for t, m, v in evolutions.get(dex, []))
            w.writerow([dex, args.gen, names_ko[dex], sp["identifier"], ty[0], ty[1] if len(ty) > 1 else "",
                        st["hp"], st["atk"], st["def"], st["spa"], st["spd"], st["spe"],
                        sp["capture_rate"], default_pokemon[dex]["base_experience"],
                        male_ratio, 0 if dex in GENDER_SPRITES_NOT_IN_HGSS else int(sp["has_gender_differences"]), stage(dex),
                        sp["is_legendary"], sp["is_mythical"], evo_str])
    print(f"wrote {out} ({len(species)} species)")

    type_names = {type_ident[r["type_id"]]: r["name"] for r in read(src, "type_names")
                  if r["local_language_id"] == KO and r["type_id"] in type_ident}
    # types.json = 생성된 모든 세대 CSV에 쓰인 타입만
    used = set()
    for csv_path in (ROOT / "tools" / "source").glob("pokemon_gen*.csv"):
        with open(csv_path, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                used.update(t for t in (r["type1"], r["type2"]) if t)
    tj = ROOT / "assets" / "data" / "types" / "types.json"
    tj.write_text(json.dumps({t: type_names[t] for t in sorted(used)}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {tj} ({len(used)} types)")


if __name__ == "__main__":
    main()
