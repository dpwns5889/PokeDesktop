class_name Formulas
extends RefCounted
## 게임 계산식 모음. 모두 순수 함수(static)로 두어 테스트·밸런싱을 쉽게 한다. (기획서 8.1)
## 수치를 바꿀 때는 기획서의 해당 절도 함께 고친다.

const MAX_POKEMON_LEVEL := 100

# 박사에게 보내기 (기획서 4.8.2)
const TRANSFER_BASE_VALUE := 100
const TRANSFER_EXP_RATIO := 0.18   # M10 밸런스 (초안 0.25)
const EXP_CANDY_S := 100
const EXP_CANDY_M := 800


## 포켓몬 레벨 L → L+1 에 필요한 경험치. (기획서 4.8.1)
static func exp_to_next(level: int) -> int:
	return 50 + 10 * level + (level * level) / 2


## Lv1 에서 Lv `level` 까지 필요한 누적 경험치.
static func total_exp(level: int) -> int:
	var total := 0
	for l in range(1, level):
		total += exp_to_next(l)
	return total


## 박사에게 보냈을 때 받는 경험사탕. 반환: {"exp_candy_m": n, "exp_candy_s": n}
static func transfer_candies(level: int) -> Dictionary:
	var value := TRANSFER_BASE_VALUE + int(total_exp(level) * TRANSFER_EXP_RATIO)
	var m := value / EXP_CANDY_M
	var s := roundi(float(value - m * EXP_CANDY_M) / EXP_CANDY_S)
	if m == 0 and s == 0:
		s = 1
	return {&"exp_candy_m": m, &"exp_candy_s": s}


## 능력치 계산 (기획서 4.7.1). v0.55: 개체치(IV, 0~31) 추가 — 원작과 같은 꼴 ((2×종족값 + 개체치) × 레벨 / 100). 노력치 없음.
static func calc_stat(base: int, level: int, is_hp: bool, iv: int = 0) -> int:
	var v := ((2 * base + iv) * level) / 100
	return v + level + 10 if is_hp else v + 5


# ---------------------------------------------------------------- 개체치 (기획서 4.7.1, v0.55)

const IV_MAX := 31
## 보관함 표시: 31 = ★★, IV_HIGH 이상 = ★, IV_LOW 이하 = 하늘색 값
const IV_HIGH := 25
const IV_LOW := 9


## 능력치 6종의 개체치 (0~31 고르게). 키는 세이브와 같은 문자열 ("hp", "atk", ...)
static func roll_ivs(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for k in STAT_KEYS:
		out[String(k)] = rng.randi_range(0, IV_MAX)
	return out


static func max_ivs() -> Dictionary:
	var out := {}
	for k in STAT_KEYS:
		out[String(k)] = IV_MAX
	return out


## 개체치 등급: 2 = 최대(★★), 1 = 높음(★), 0 = 보통, -1 = 낮음(하늘색)
static func iv_grade(iv: int) -> int:
	if iv >= IV_MAX:
		return 2
	if iv >= IV_HIGH:
		return 1
	if iv <= IV_LOW:
		return -1
	return 0


# ---------------------------------------------------------------- 인카운터 (기획서 4.2)

## 지역에 간격이 없을 때 쓰는 기본 간격 (초). 지역별 간격은 RegionData.encounter_interval (v0.24)
const DEFAULT_ENCOUNTER_INTERVAL := Vector2(240.0, 480.0)
## 어떤 지역이든 간격은 이 값을 넘지 않는다 (테스트·검증용 상한)
const MAX_ENCOUNTER_INTERVAL_SEC := 600.0
const ENCOUNTER_PREVIEW_SEC := 2.5        # 풀숲 흔들림 예고
const ENCOUNTER_APPEAR_SEC := 90.0        # 반응하지 않으면 도망
const ENCOUNTER_RESULT_SEC := 2.5         # 결과 표시
## 색이 다른 포켓몬 확률 (기획서 4.2, M11 확정). 전설도 같은 확률.
const SHINY_CHANCE := 1.0 / 512.0

## 아이템 인카운터 (v0.84): 인카운터가 포켓몬 대신 아이템일 확률 (픽업 특성이면 ×2)
const ITEM_ENCOUNTER_CHANCE := 0.10
## 지역 등급(RegionData.item_tier)별 [아이템, 가중치]. 평균 판매가 약 485 / 865 / 1,410원 (v0.84: 큰진주를 진주로 합침)
const ITEM_ENCOUNTER_TABLES := {
	1: [["pretty_feather", 40], ["pearl", 37], ["stardust", 20], ["nugget", 3]],
	2: [["pretty_feather", 20], ["pearl", 40], ["stardust", 25], ["star_piece", 8], ["nugget", 6], ["big_nugget", 1]],
	3: [["pretty_feather", 10], ["pearl", 35], ["stardust", 20], ["star_piece", 15], ["nugget", 15], ["big_nugget", 5]],
}



## 다음 인카운터까지의 시간. 지역의 [최소, 최대] 범위에서 고르게 뽑는다. (기획서 4.2)
static func encounter_interval_range(region: RegionData) -> Vector2:
	if region == null or region.encounter_interval.y <= 0.0:
		return DEFAULT_ENCOUNTER_INTERVAL
	var lo := clampf(region.encounter_interval.x, 1.0, MAX_ENCOUNTER_INTERVAL_SEC)
	return Vector2(lo, clampf(region.encounter_interval.y, lo, MAX_ENCOUNTER_INTERVAL_SEC))


## mult = 특이한 향로 등 배율 (v0.41)
static func roll_shiny(rng: RandomNumberGenerator, mult: float = 1.0) -> bool:
	return rng.randf() < SHINY_CHANCE * mult


static func roll_encounter_interval(rng: RandomNumberGenerator, region: RegionData = null) -> float:
	var r := encounter_interval_range(region)
	return rng.randf_range(r.x, r.y)


## 야생 레벨 (기획서 4.2):
## level = clamp(rand(min, max) + floor(player_level * level_scale), entry.min_level, region.level_cap)
static func roll_wild_level(entry: EncounterEntry, level_scale: float, level_cap: int,
		player_level: int, rng: RandomNumberGenerator) -> int:
	var base := rng.randi_range(entry.min_level, entry.max_level)
	var lv := base + floori(player_level * level_scale)
	return clampi(lv, entry.min_level, maxi(entry.min_level, mini(level_cap, MAX_POKEMON_LEVEL)))


# ---------------------------------------------------------------- 인카운터 전투 (기획서 4.3)

const CAPTURE_TIME_LIMIT_SEC := 10.0      # v0.55: 20초 → 12초, v0.74: 12초 → 10초
const CAPTURE_BASE_FILL := 0.12
const CAPTURE_INNER_RATIO := 0.45        # 과녁 반지름 대비 '중심' 영역
const CAPTURE_INNER_BONUS := 1.5         # 중심 명중 시 게이지 배율
const LEGENDARY_DIFFICULTY_BONUS := 0.15


## bonus = 출현 표 한 줄의 추가 난이도 (EncounterEntry.difficulty_bonus, v0.76)
static func capture_difficulty(catch_rate: int, level: int, legendary: bool, bonus: float = 0.0) -> float:
	var d := (1.0 - catch_rate / 255.0) * 0.8 + (level / 100.0) * 0.2 + bonus
	if legendary:
		d += LEGENDARY_DIFFICULTY_BONUS
	return clampf(d, 0.0, 1.0)


## 전투 파라미터. 거리 단위는 기준 해상도 픽셀.
## entry = entry_battle_bonus() 결과 (엔트리 능력치 보너스, 기획서 4.13). 비우면 보너스 없음.
## difficulty_bonus = 출현 표의 추가 난이도 (v0.76)
static func capture_params(catch_rate: int, level: int, legendary: bool, ball_modifier: float,
		entry: Dictionary = {}, difficulty_bonus: float = 0.0) -> Dictionary:
	var d := capture_difficulty(catch_rate, level, legendary, difficulty_bonus)
	var atk := float(entry.get(&"attack", 0.0))
	var spe := float(entry.get(&"speed", 0.0))
	var dfn := float(entry.get(&"defense", 0.0))
	var hp := float(entry.get(&"hp", 0.0))
	return {
		&"difficulty": d,
		&"time_limit": CAPTURE_TIME_LIMIT_SEC * (1.0 + hp),
		# 어려울수록 과녁이 빨리 사라진다 (곡선: 어려운 쪽에서 더 급격히)
		&"target_life": lerpf(1.6, 0.55, d * d * 0.4 + d * 0.6) * (1.0 + spe),
		&"target_radius": lerpf(17.0, 9.0, d),
		&"fill": CAPTURE_BASE_FILL * ball_modifier * (1.0 + atk),
		&"penalty": lerpf(0.04, 0.10, d) * (1.0 - dfn),
		&"decay_per_sec": lerpf(0.01, 0.04, d) * (1.0 - dfn),
		&"max_targets": 3 if d > 0.5 else 2,
	}


# ---------------------------------------------------------------- 엔트리 (기획서 4.13, v0.26)

## 능력치 묶음별 최대 보너스
const ENTRY_BONUS_MAX := 0.25
## 기준: 종족값이 모두 ENTRY_REF_BASE 인 Lv ENTRY_REF_LEVEL 포켓몬 3마리 = 최대 보너스 (v0.27)
## 1세대 최종 진화의 평균 종족값이 약 80. 종족값이 높은 종은 더 일찍, 낮은 종은 Lv100이어도 못 미친다.
const ENTRY_REF_BASE := 80
const ENTRY_REF_LEVEL := 80
## 기준 대비 비율 r 에 대한 곡선 지수 (1보다 크면 낮은 레벨에서 보너스가 더 작다)
const ENTRY_BONUS_EXP := 1.5
## 묶음: 공격(공격+특공) → 게이지, 스피드 → 과녁 유지 시간, 방어(방어+특방) → 감점·감소, HP → 제한 시간
const ENTRY_GROUPS := {
	&"attack": [&"atk", &"spa"],
	&"speed": [&"spe"],
	&"defense": [&"def", &"spd"],
	&"hp": [&"hp"],
}


## 엔트리 능력치 보너스 (v0.27: 야생과 비교하지 않고 고정 기준과 비교). entry_stats = 엔트리 개체들의 능력치 목록.
## 묶음마다 r = 엔트리 합 / (기준 포켓몬 값 × 엔트리 최대 수) → bonus = 0.25 × clamp(r, 0, 1)^1.5
## 종족값 80 기준으로 3마리 모두 Lv20 ≈ +3.7%, Lv40 ≈ +9%, Lv60 ≈ +16%, Lv80 = +25%(최대).
## 보너스만 있고 손해는 없다(엔트리 0마리 = 보너스 0).
static func entry_battle_bonus(entry_stats: Array, max_entries: int = 3) -> Dictionary:
	var ref := entry_reference_stats()
	var out := {}
	for g in ENTRY_GROUPS:
		var mine := 0.0
		var target := 0.0
		for k in ENTRY_GROUPS[g]:
			target += float(ref[k]) * max_entries
			for st in entry_stats:
				mine += float(st.get(k, 0))
		var r := clampf(mine / maxf(1.0, target), 0.0, 1.0)
		out[g] = ENTRY_BONUS_MAX * pow(r, ENTRY_BONUS_EXP)
	return out


## 최대 보너스 기준 포켓몬 1마리의 능력치 (종족값 모두 ENTRY_REF_BASE, Lv ENTRY_REF_LEVEL)
static func entry_reference_stats() -> Dictionary:
	var base := {}
	for k in STAT_KEYS:
		base[String(k)] = ENTRY_REF_BASE
	return calc_stats(base, ENTRY_REF_LEVEL, {}, max_ivs())   # v0.55: 개체치 최대 기준 → 최대 보너스엔 개체치도 필요


# ---------------------------------------------------------------- 플레이어 레벨 (기획서 4.1) — 수치는 M10에서 조정

const MAX_PLAYER_LEVEL := 40
const PLAYER_EXP_NEW_DEX_BONUS := 40   # M10 밸런스 (초안 30)


## 플레이어 레벨 L → L+1 에 필요한 경험치.
static func player_exp_to_next(level: int) -> int:
	return mini(1250, 20 + 60 * level)


## 진화 시 플레이어 경험치. 새 종이면 도감 보너스. (기획서 4.9, 수치는 M10에서 조정)
static func evolution_player_exp(new_dex: bool) -> int:
	return 20 + (PLAYER_EXP_NEW_DEX_BONUS if new_dex else 0)


## 포획 시 플레이어 경험치. 신규 도감이면 보너스.
static func capture_player_exp(wild_level: int, new_dex: bool) -> int:
	return 5 + wild_level * 2 + (PLAYER_EXP_NEW_DEX_BONUS if new_dex else 0)


# ---------------------------------------------------------------- 능력치 (기획서 4.7.1)

const STAT_KEYS: Array[StringName] = [&"hp", &"atk", &"def", &"spa", &"spd", &"spe"]


## 종족값·레벨·개체치로 계산한 능력치 6종. stat_mults = {atk: 1.2, ...} (특성 등, M7), ivs = {"hp": 0~31, ...} (v0.55)
static func calc_stats(base_stats: Dictionary, level: int, stat_mults: Dictionary = {}, ivs: Dictionary = {}) -> Dictionary:
	var out := {}
	for k in STAT_KEYS:
		var iv := int(ivs.get(String(k), ivs.get(k, 0)))
		var v := calc_stat(int(base_stats.get(String(k), base_stats.get(k, 0))), level, k == &"hp", iv)
		out[k] = int(floor(v * float(stat_mults.get(k, 1.0))))
	return out
