extends Node
## 전역 시그널 모음. 매니저와 UI는 서로를 직접 참조하지 않고 이 시그널로 통신한다.
## (기획서 8.1)

# 인카운터 / 전투 (기획서 4.2, 4.3)
## 풀숲 흔들림 예고 시작. encounter = {dex_id, level, gender, shiny, region}
signal encounter_started(encounter: Dictionary)
## 예고가 끝나고 포켓몬이 모습을 드러냄 (클릭하면 전투)
signal encounter_appeared(encounter: Dictionary)
## 아이템 인카운터에서 아이템을 얻었다 (v0.84)
signal item_found(item_id: StringName, count: int)
## 전투 시작. ball = 사용한 볼 ID
signal battle_started(encounter: Dictionary, ball: StringName)
signal battle_finished(success: bool)
## 반응이 없거나 전투에 실패해 도망
signal encounter_fled(encounter: Dictionary)
## 결과 표시가 끝나고 대기 상태로 돌아감
signal encounter_ended
signal ball_shortage_changed(is_short: bool)

# 포켓몬
signal pokemon_caught(instance: Dictionary)
signal pokemon_transferred(uids: PackedStringArray, rewards: Dictionary)
signal pokemon_leveled_up(uid: String, new_level: int)
signal evolution_requested(uid: String, to_species_id: int)
signal evolution_cancelled(uid: String)
signal pokemon_evolved(uid: String, from_species_id: int, to_species_id: int)

# 플레이어 / 진행
signal player_leveled_up(new_level: int)
signal region_unlocked(region_id: StringName)
## 엔트리(파티)가 바뀜 (기획서 4.13)
signal entries_changed
## 전투 후 엔트리 특성이 발동함 (픽업·꿀모으기·볼줍기). lines = 화면에 보여 줄 문구 (기획서 4.6)
signal battle_traits_triggered(lines: PackedStringArray)
signal current_region_changed(region_id: StringName)
signal currency_changed(new_amount: int)
## 아이템을 받음. items = {item_id: 개수}, source = &"shop" / &"expedition" / &"professor" — 효과음 등
signal items_received(items: Dictionary, source: StringName)
## 아이템을 씀 (향로·특이한 향로·행복의 알·경험사탕, v0.62) — 효과음
signal item_used(item_id: StringName)
## 저장된 진행을 초기화함 (개발용) → 화면들은 전체를 다시 그린다
signal game_reset

# 원정
signal expedition_finished(expedition_id: StringName)

# 설정
signal setting_changed(key: StringName, value: Variant)
