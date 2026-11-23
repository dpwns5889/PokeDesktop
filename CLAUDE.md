# PokeCompanion

Godot 4.7.2(GDScript) 데스크탑 컴패니언. 기준 문서는 `docs/GAME_DESIGN.md`(기획서)다.

## 작업 순서
1. 세션을 시작하면 기획서 11.1 "다음 작업" 표부터 읽는다.
2. 결정이나 동작이 바뀌는 작업은 **기획서를 먼저 고치고** 코드를 고친다. 기획서를 고친 뒤에는 `python docs/build_html.py`로 `GAME_DESIGN.html`을 다시 만든다.
3. 끝난 항목은 해당 장에 반영하고 11.1 표에서 지운다.
4. 테스트를 모두 통과시킨다(명령은 아래).
5. 작업이 끝나면 커밋하지 않은 상태로 둔다. 끝에 "커밋할까요?"라고 묻지 않는다(아래 Git).

## 변경 이력과 버전
- 게임 동작·데이터·화면이 바뀐 작업만 변경 이력 표에 행을 추가하고 버전을 올린다. 버전은 기획서, `project.godot`, `export_presets.cfg`, README 네 곳에 함께 적는다.
- 비슷한 작업(같은 화면·같은 시스템·같은 목적)은 **같은 버전으로 묶고**, 묶음 하나마다 버전을 0.01씩 올린다. 아직 커밋하지 않은 버전은 비슷한 작업이 이어지면 그 버전에 합친다.
- **0.99 다음은 0.100, 0.101, … 로 이어 간다**(소수점 아래를 정수로 읽는다. 1.00으로 올리지 않는다). 1.0은 정식 배포를 결정할 때 따로 정한다.
- 문서만 바뀐 작업(README, 11.1 정리, 폴더 정리 등)은 본문만 고치고 이력과 버전은 그대로 둔다.

## Git
- 브랜치는 `master` 하나다. 혼자 개발하므로 `master`에 바로 커밋하고 기능 브랜치는 만들지 않는다.
- 커밋은 사용자가 "커밋해줘"라고 할 때만 한다. 그때 마지막 커밋 이후의 변경을 커밋 하나로 묶는다. 게임 변경과 상관없는 구조·문서 작업이 섞여 있으면 커밋을 나눈다. `git add -A`를 써도 된다(빌드·리포트·저작권 리소스·`CLAUDE.local.md`는 gitignore에 있다).
- push는 사용자가 따로 요청할 때만 한다. 커밋 요청에 push는 포함되지 않는다.
- 커밋 메시지 형식:
  ```
  <한국어 요약: 바뀐 기능을 쉼표로 나열> (기획서 v0.xx[~0.yy])

  - 파일 또는 기능: 무엇을 왜 바꿨는지
  ```
  게임 내용이 바뀌지 않은 커밋은 `(기획서 v…)` 표기를 빼고 요약만 쓴다.
- 배포할 exe를 내보낼 때만 그 커밋에 `v0.xx` 태그를 달고, exe를 그 태그의 GitHub Release에 올린다(2026-11-22 사용자 결정). exe 안에 저작권 스프라이트·사운드가 들어 있으니 README 라이선스 항목을 유지한다.

## 폴더 규칙 (기획서 8.2)
- 게임 실행에 쓰이는 것은 `assets/` 아래에 둔다(scenes, scripts, data, audio, fonts, ui, sprites, generated).
- 개발용은 `tools/`에 둔다. 변환 입력 원본은 `tools/source/`, 검토용 미리보기는 `tools/previews/`다. 테스트는 `tests/`에 둔다.
- 폴더와 새 파일 이름은 소문자 snake_case로 짓는다. 이미 받은 원본 시트·음원 파일 이름은 그대로 둔다.
- `assets/sprites/`, `assets/generated/`, `tools/previews/*.png`는 저작권 리소스라 git에 올리지 않는다.
- 파일을 옮기면 `res://` 경로를 모두 치환한다. 끝에 `/`가 없는 `"res://assets/scenes"` 같은 형태도 빠뜨리지 않는다. 그다음 `--headless --import`와 테스트로 확인한다. Windows git은 대소문자만 다른 이름 변경을 놓치므로 `git rm --cached` 후 `git add`로 바로잡는다.

## 아키텍처와 코드 (원본: 기획서 8.4~8.6, 코드를 쓰기 전에 읽는다)
- 계층은 데이터(`scripts/data`), 로직(`scripts/logic`: static 순수 함수, RNG는 인자로 받음), 매니저(`scripts/autoload`: 상태·`EventBus` 보내기·세이브), 화면(`scenes`)이다.
- 화면은 매니저 메서드를 부르고 시그널로 갱신만 한다. 상태 값을 직접 대입하지 않는다.
- 새 오토로드는 맡을 매니저가 없을 때만 만들고, 기획서 8.1 표에 먼저 적는다.
- 모든 변수·인자·반환값에 정적 타입을 붙인다(정해지지 않은 값은 `: Variant`). 주석은 한국어 `##`로 쓰고 `(기획서 x.y)`를 표기한다.
- 기획서에 없는 수치·동작은 추천안과 함께 묻고, 정해지면 기획서에 먼저 적는다.
- 로직·매니저를 바꾸면 테스트를 추가하거나 고친다. 화면을 바꾸면 화면 캡처로 확인한다.

## UI 규칙
- 팝업(확인·알림·포획 정보·원정 보상, 새 팝업 포함)은 문구·그림·버튼 줄을 모두 창 가운데에 모은다. `ConfirmPanel`을 쓰거나 같은 정렬로 만든다(기획서 6.2).
- 지형(`field_maps.gd`, `tools/make_field_tiles.py`, tilemap 세트)을 바꾸면 `python tools/preview_field_maps.py`로 `tools/previews/preview_field_maps.png`를 만든다. 직접 확인한 뒤 전체 절대 경로를 알려 준다.

## 실행과 테스트
- `<godot>`은 Godot 4.7.2 실행 파일이다(4.3 실행 파일은 쓰지 않는다). 이 PC의 경로는 `CLAUDE.local.md`에 있다.
- 테스트: `<godot> --headless --path . -s -d --remote-debug tcp://127.0.0.1:1 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode`. `--remote-debug`가 없으면 스크립트 오류가 났을 때 `debug>`에서 멈춘다.
- 실제 창으로 확인할 때는 `-- --fast-encounter --autoplay`로 띄우고 PowerShell CopyFromScreen으로 창 영역을 캡처한다. 창 제목은 "PokeCompanion (DEBUG)"이다. 실행 전후로 사용자 세이브(`%APPDATA%/Godot/app_userdata/PokeCompanion/save.json*`)를 백업하고 복원한다.
- 사용자가 Godot 에디터를 켜 둔 경우가 많다. 열린 씬을 고치거나 파일을 옮기기 전에 알린다.

## Windows 편집 주의
- 저장소는 LF를 쓴다. Python으로 파일을 쓸 때는 `open(p, 'w', encoding='utf-8', newline='\n')`을 쓴다.
- 백슬래시 이스케이프가 들어간 코드는 Edit 도구로 고친다. 긴 Python 헬퍼는 Write로 scratchpad에 파일을 만들고 `python -I <파일>`로 실행한다. Bash heredoc을 거치면 `\n`이 실제 줄바꿈으로 바뀌어 GDScript 문자열이 깨진다.
- 공백이 든 파일 이름(음원, 원본 시트)을 일괄 처리할 때는 `grep -lZ | xargs -0`을 쓴다.

## 모델 사용 규칙
- 작업을 시작할 때 현재 모델이 작업에 맞지 않으면, 시작하기 전에 한 줄로 알린다. (예: "이 작업은 Sonnet으로 충분해요. /model sonnet")
- Opus: 기획, 설계, /grill-me, 원인을 모르는 버그, 여러 파일에 걸친 구조 변경
- Sonnet: 계획이 확정된 구현, 원인이 분명한 버그, 문서 작성, 반복 작업
- 같은 문제를 Sonnet으로 2번 실패하면 Opus로 바꾸자고 제안한다.