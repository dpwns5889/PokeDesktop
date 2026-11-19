"""도감 "색다름" 화면 확인용 테스트 세이브 (개발용, 기획서 6.2).

사용:
  python tools/dex_test_save.py make      # 지금 세이브를 백업하고, 도감 151종 완성 상태로 바꾼다
  python tools/dex_test_save.py restore   # 백업한 세이브로 되돌린다
그다음 게임을 `-- --open=dex` 로 띄운다 (도감 완성 팝업 -> 확인 -> 제목 줄 "색다름").
1, 4, 7, ... 번은 색이 다른 모습으로 잡은 것(shiny 1), 나머지는 일반.
게임을 끈 상태에서 실행한다 (켜져 있으면 종료할 때 세이브를 덮어쓴다).
"""
import json
import os
import shutil
import sys

SAVE_DIR = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "PokeCompanion")
BACKUP_DIR = os.path.join(SAVE_DIR, "backup_before_dex_test")
FILES = ["save.json", "save.json.bak"]


def make() -> None:
    if os.path.isdir(BACKUP_DIR):
        sys.exit("이미 백업이 있습니다. 먼저 `restore` 로 되돌리세요: " + BACKUP_DIR)
    os.makedirs(BACKUP_DIR)
    for f in FILES:
        src = os.path.join(SAVE_DIR, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(BACKUP_DIR, f))
    path = os.path.join(SAVE_DIR, "save.json")
    with open(path, encoding="utf-8") as fp:
        data = json.load(fp)
    data["dex"] = {str(i): {"seen": True, "caught": 1, "shiny": 1 if i % 3 == 1 else 0} for i in range(1, 152)}
    data["dex_completed_at"] = 0
    data["dex_complete_noticed"] = False
    with open(path, "w", encoding="utf-8", newline="\n") as fp:
        json.dump(data, fp, ensure_ascii=False)
    print("테스트 세이브를 만들었습니다. 백업: " + BACKUP_DIR)


def restore() -> None:
    if not os.path.isdir(BACKUP_DIR):
        sys.exit("백업이 없습니다: " + BACKUP_DIR)
    for f in FILES:
        src = os.path.join(BACKUP_DIR, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(SAVE_DIR, f))
    shutil.rmtree(BACKUP_DIR)
    print("원래 세이브로 되돌렸습니다.")


if __name__ == "__main__":
    {"make": make, "restore": restore}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit(__doc__))()
