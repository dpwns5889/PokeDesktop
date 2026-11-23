# PokeCompanion

작업하는 동안 화면 구석에 떠 있는 **방치형 포켓몬 데스크탑 컴패니언**입니다.
일정 시간마다 야생 포켓몬이 나타나면 **과녁을 클릭하는 짧은 전투**로 잡고, 잡은 포켓몬을 **원정**에 보내 아이템과 돈을 벌어 옵니다.
앱을 꺼 둔 동안에도 원정은 흘러가고, 평소에는 작고 조용하게 작업을 방해하지 않는 것이 목표입니다.

- 엔진: **Godot 4.7.2 (GDScript)** · 대상: Windows 10/11 (macOS 빌드도 제공, Mac에서 직접 확인하지는 못함)
- 규모: 게임 코드 약 1만 줄 · 테스트 약 4,300줄(**323개**) · 도구 약 3,100줄
- 비상업 개인 프로젝트 (포트폴리오·지인 공개)
- 상태: **프로젝트 종료 (2026-11-23, 마지막 버전 v0.106).** 더 개발하지 않는다.

> 포켓몬 이름·이미지는 Nintendo / Game Freak / Creatures / The Pokémon Company의 저작물입니다.
> 이 저장소에는 스프라이트 원본과 가공 결과(`assets/sprites/`, `assets/generated/`)를 넣지 않았고, 그림이 없으면 플레이스홀더로 실행됩니다.

---

## 게임 기능

| 기능 | 내용 |
|---|---|
| 인카운터 전투 | 지역별 간격으로 포켓몬 등장 → 클릭하면 10초 동안 나타나는 과녁을 맞혀 게이지를 채움 → 볼 던지기·흔들림·포획 연출 |
| 수집 | 1세대 151종, 성별·색이 다른 개체(1/512), 개체치, 전설 출현 조건, 도감·도감 완성 보상 |
| 지역 | 9개 지역, 레벨·도감 조건으로 해금, 지역마다 출현 표·난이도·타일맵 들판 |
| 특성 | 개체마다 무작위 패시브 52종(원정용·전투용), 특성 캡슐로 붙이고 깜빡열매로 지우기 |
| 원정 | 파티 자동 편성 → 요구 전투력 → 실제 시간 경과(앱이 꺼져 있어도) → 보상 |
| 성장 | 박사에게 보내기 → 경험사탕 → 레벨업, 레벨·진화의 돌 진화(연출·취소·넘기기) |
| 경제 | 상점(레벨별 해금), 아이템 인카운터로 귀중품 수집, 보관함 확장 |
| 엔트리 | 함께하는 포켓몬 3마리가 창 안을 4방향으로 걸어다니고, 인카운터 때 발판을 바라봄 |
| 창 | 테두리 없는 448×200 창, 항상 위, 1~4배 정수 배율, 전체화면 앱이 앞에 오면 자동 숨김 |
| 소리 | 효과음 17종, BGM 플레이리스트(무작위·교차 페이드), 효과음 중 BGM 일시정지 |

---

## 개발 특징

### 1. 기획서가 먼저, 코드는 그다음
- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)가 **기준 문서**입니다. 결정이 바뀌면 코드보다 문서를 먼저 고칩니다.
- 기획서 버전(현재 **v0.106**)과 게임 안 버전 표시·exe 버전 정보가 항상 같습니다. 변경 이력 표에 버전마다 무엇을 왜 바꿨는지 남깁니다.
- 마일스톤 M0~M13(세팅 → 창 → 데이터 → 전투 → 저장 → … → 도감 완성)으로 진행했고, 단계마다 완료 기준이 있습니다.
- 미결정 사항은 13장 표로 관리하고, 정해지면 해당 장을 고친 뒤 표에서 지웁니다.

### 2. 로직과 화면의 분리
- **오토로드 매니저**(`EncounterManager`, `PlayerState`, `ExpeditionManager`, `ProfessorManager` …)가 상태를 갖고, UI는 매니저를 호출하고 `EventBus` 시그널을 받아 **표시만** 바꿉니다.
- 계산식은 `assets/scripts/logic/`의 **순수 static 함수**(`Formulas`, `EncounterLogic`, `ExpeditionLogic`, `BattleTraits`, `CaptureGame`, `WindowLayout`)에 모아 화면 없이 테스트합니다.
- 난수는 `RandomNumberGenerator`를 주입해 테스트에서 시드를 고정합니다.

### 3. 시간은 프레임이 아니라 시각으로
- 인카운터 상태 머신(`WAITING → PREVIEW → APPEARED → BATTLE → RESULT`)은 시스템 시각을 비교하는 `tick(now)`로 움직입니다. 테스트는 가짜 시각을 넣어 몇 시간짜리 흐름을 즉시 확인합니다.
- 원정·향로·행복의 알은 **실제 시각** 기준이라 절전·종료 후에도 정확합니다.

### 4. 데이터 주도 + 생성 파이프라인
- 종·지역·아이템·특성·원정은 사람이 고치는 원본(`tools/source/*.json`, CSV)에서 도구로 `.tres` 리소스를 만듭니다.
- 스프라이트도 도구로 가공합니다(`tools/`).
  - HGSS 전투 시트 → 종별 시트(영역 자동 검출, 배경 제거, 암수·색다름 칸 정리)
  - 오버월드 시트 → 4방향 걷기 시트, 아이템 시트 → 24px 아이콘(가장자리 배경만 제거, 색상 바꾸기 옵션)
  - 지역 타일맵·볼 회전 프레임·앱 아이콘 생성(Python)
- 결과는 미리보기 이미지로 눈 검토 + 데이터 검증 테스트(151종 시트 크기, 폰트에 없는 글자, 진화 아이템 존재 등)로 확인합니다.

### 5. 테스트와 밸런스 시뮬레이터
- **gdUnit4 테스트 323개**를 헤드리스로 돌립니다. 로직뿐 아니라 UI 배치(팝업 가운데 정렬, 긴 문구 줄바꿈, 버튼 위치), 스크립트 컴파일, 세이브 손상 복구까지 검사합니다.
- **밸런스 시뮬레이터**(`tools/balance_sim.tscn`)가 실제 게임 로직으로 가상 플레이어의 14일(하루 5시간)을 돌려 일차별 목표(플레이어 레벨·도감 수, 허용 ±15%)와 비교합니다. 수치를 바꿀 때마다 돌려 결과를 기획서 9장에 남깁니다.

### 6. 안전한 세이브
- `save.json.tmp`에 쓰고 성공하면 교체, 직전 파일은 `.bak`. 둘 다 손상되면 새 게임 + 손상 파일 보관.
- `save_version` 별 마이그레이션(`SaveManager.migrate`)으로 예전 세이브를 계속 읽습니다. 형식이 바뀌면 버전을 올리고 기획서 7.5 표에 한 줄 기록합니다.
- 테스트(헤드리스)에서는 실제 세이브를 읽거나 쓰지 않습니다.

### 7. 데스크탑 컴패니언다운 동작
- 평상시 `low_processor_mode` + 30fps. 릴리스 exe 측정: 대기 중 **CPU 평균 0.29%**(12코어 기준).
- Godot가 다른 앱 창을 볼 수 없어서, **전체화면 감지**는 작은 PowerShell 감시 스크립트(Win32 `GetForegroundWindow`·`ShowWindow`)가 1초마다 판정해 창을 숨기고, 다시 보일 때 포커스를 빼앗지 않습니다. 게임이 끝나면 스스로 종료합니다.
- 창은 주 모니터 우하단에 붙고, 해상도·작업표시줄이 바뀌면 따라가며, 화면 밖으로 나가지 않습니다.

### 8. AI 에이전트와 함께 개발 ([`CLAUDE.md`](CLAUDE.md))
- Claude Code가 지킬 규칙을 `CLAUDE.md`에 모았습니다. 원본은 기획서이고, `CLAUDE.md`는 요약과 작업 절차만 담습니다.
- **작업 순서**: 기획서 11.1 "종료 시점에 남은 일" 표 확인 → 기획서 먼저 수정·HTML 재생성 → 코드 → 테스트 전부 통과 → 커밋하지 않은 상태로 넘김.
- **버전 규칙**: 비슷한 작업은 같은 버전으로 묶어 0.01씩 올리고(0.99 다음은 0.100, 0.101 … 로 이어 감) 기획서·`project.godot`·`export_presets.cfg`·README 네 곳을 함께 맞춥니다. 문서만 바뀌면 버전은 그대로입니다.
- **Git**: `master` 하나, 사용자가 요청할 때만 커밋·push, 커밋 메시지에 기획서 버전 표기. exe는 태그를 단 버전만 GitHub Release에 올립니다.
- **코드 규칙**: 데이터·로직·매니저·화면 계층 분리, 모든 변수에 정적 타입, 한국어 `##` 주석과 `(기획서 x.y)` 표기. 기획서에 없는 수치는 추천안과 함께 묻습니다.
- **검증**: 로직을 바꾸면 테스트, 화면을 바꾸면 실제 창 캡처(사용자 세이브 백업·복원), 지형을 바꾸면 미리보기 이미지로 확인합니다.
- **모델 선택**: 기획·설계·원인 모를 버그는 Opus, 확정된 구현·문서·반복 작업은 Sonnet. Sonnet이 같은 문제에서 2번 실패하면 Opus로 바꿉니다.

---

## 구조

```
CLAUDE.md                AI 에이전트 작업 규칙 (원본은 기획서)
docs/GAME_DESIGN.md      기획서 (기준 문서) / build_html.py 로 HTML 생성
assets/                  게임 실행에 쓰이는 것 전부
  scripts/
    autoload/            상태를 가진 매니저 (EventBus, PlayerState, EncounterManager, SaveManager …)
    logic/               순수 계산 (Formulas, EncounterLogic, ExpeditionLogic, BattleTraits, CaptureGame …)
    data/                Resource 정의 (PokemonSpecies, RegionData, ItemData, TraitData …)
  scenes/
    main/                메인 창 (companion), 걸어다니는 엔트리, 포획 연출, 들판 타일맵
    battle/              과녁 전투
    ui/                  패널 (도감·파티·보관함·지역·원정·가방·상점·설정), 확인 창, 진화 연출
  data/                  *.tres 리소스 (도구가 생성)
  audio/ fonts/ ui/      소리·폰트·UI 그림
  sprites/ generated/    스프라이트 원본·가공 결과 (저작권, git 제외)
tools/                   데이터 변환·스프라이트 가공·밸런스 시뮬레이터
  source/                사람이 고치는 원본 JSON·CSV
  previews/              검토용 미리보기 이미지
tests/                   gdUnit4 테스트 (logic / data / ui)
```

---

## 실행

Godot **4.7.2**로 프로젝트를 엽니다. 스프라이트가 없으면 플레이스홀더로 실행됩니다.

```bash
# 테스트 (헤드리스)
godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:1 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode

# 밸런스 시뮬레이션 (5회 평균, 14일)
godot --headless --path . res://tools/balance_sim.tscn -- --seeds 5 --days 14

# Windows exe 내보내기 (내보내기 템플릿 4.7.2 필요)
godot --headless --path . --export-release "Windows Desktop" build/PokeCompanion.exe

# macOS 앱 내보내기 (zip 안에 .app, 공증 없음 → 처음엔 우클릭 → 열기)
godot --headless --path . --export-release "macOS" build/PokeCompanion_mac.zip
```

개발용 실행 인자(디버그 빌드만): `-- --fast-encounter`(약 12초 간격) · `--autoplay`(자동 전투) · `--shiny` · `--item-encounter` · `--open=storage` 등.
메인 창 우클릭 = 개발 메뉴(지금 인카운터, 돈 추가, 레벨 +1, 저장 초기화).

---

## 라이선스

포켓몬 스프라이트와 사운드(BGM·효과음)는 © Nintendo / Creatures Inc. / GAME FREAK Inc.의 저작물입니다.
이 프로젝트는 비상업 팬 프로젝트이며 위 회사들과 관계가 없습니다.
