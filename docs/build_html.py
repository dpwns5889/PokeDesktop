"""GAME_DESIGN.md -> GAME_DESIGN.html 변환기 (외부 라이브러리 없음).

사용법:  python docs/build_html.py
문서(.md)를 고친 뒤 다시 실행하면 HTML이 갱신된다.
"""
import html
import re
from pathlib import Path

HERE = Path(__file__).parent
SRC = HERE / "GAME_DESIGN.md"
OUT = HERE / "GAME_DESIGN.html"


def slugify(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text).strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def split_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    cells, cur, in_code = [], "", False
    for ch in line:
        if ch == "`":
            in_code = not in_code
        if ch == "|" and not in_code:
            cells.append(cur.strip())
            cur = ""
        else:
            cur += ch
    cells.append(cur.strip())
    return cells


def trait_tier_column(header: list[str]) -> int:
    """특성 표(머리줄에 "등급"과 "특성"이 있는 표)면 등급 칸 번호, 아니면 -1."""
    if "특성" in header and "등급" in header:
        return header.index("등급")
    return -1


def trait_row_class(row: list[str], tier_col: int) -> str:
    """특성 표의 줄 색: 부정 = 빨강, 보류 = 색 없음, 나머지(일반·희귀·고정) = 파랑."""
    if tier_col < 0 or tier_col >= len(row):
        return ""
    tier = row[tier_col]
    if "부정" in tier:
        return ' class="trait-neg"'
    if "보류" in tier:
        return ""
    return ' class="trait-pos"'


BADGE_RE = re.compile(r"(?<![\w/])(P[0-3])(?![\w])")


def inline(text: str) -> str:
    codes: list[str] = []

    def keep(m):
        codes.append(f"<code>{html.escape(m.group(1))}</code>")
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", keep, text)
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"~~(.+?)~~", r"<del>\1</del>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    text = BADGE_RE.sub(lambda m: f'<span class="badge b{m.group(1)[1]}">{m.group(1)}</span>', text)
    text = re.sub(r"\bTBD\b", '<span class="tbd">TBD</span>', text)
    text = re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], text)
    return text


def convert(md: str):
    lines = md.splitlines()
    out: list[str] = []
    toc: list[tuple[int, str, str]] = []
    title = ""
    i = 0
    para: list[str] = []

    def flush_para():
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>")
            para.clear()

    while i < len(lines):
        raw = lines[i]
        line = raw.strip()

        # 코드 블록 (들여쓰기 포함)
        if line.startswith("```"):
            flush_para()
            indent = len(raw) - len(raw.lstrip())
            lang = line[3:].strip()
            i += 1
            buf = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i][indent:] if lines[i][:indent].strip() == "" else lines[i])
                i += 1
            i += 1
            cls = f' class="lang-{lang}"' if lang else ""
            out.append(f"<pre><code{cls}>{html.escape(chr(10).join(buf))}</code></pre>")
            continue

        # 제목
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m and not raw.startswith(" "):
            flush_para()
            level, text = len(m.group(1)), m.group(2)
            rendered = inline(text)
            sid = slugify(text.replace("`", ""))
            if level == 1:
                title = text
                out.append(f'<h1 id="{sid}">{rendered}</h1>')
            else:
                if level in (2, 3):
                    toc.append((level, sid, re.sub(r"<[^>]+>", "", rendered)))
                if level == 2:
                    out.append("</section>" if any(o.startswith("<section") for o in out) else "")
                    out.append(f'<section class="chapter" id="sec-{sid}">')
                out.append(f'<h{level} id="{sid}">{rendered}<a class="anchor" href="#{sid}">#</a></h{level}>')
            i += 1
            continue

        # 구분선
        if line == "---":
            flush_para()
            i += 1
            continue

        # 표
        if line.startswith("|"):
            flush_para()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            header, body = rows[0], [r for r in rows[1:] if not all(re.fullmatch(r":?-+:?", c) for c in r)]
            t = ['<div class="table-wrap"><table><thead><tr>']
            t += [f"<th>{inline(c)}</th>" for c in header]
            t.append("</tr></thead><tbody>")
            tier_col = trait_tier_column(header)
            for r in body:
                cls = trait_row_class(r, tier_col)
                t.append(f"<tr{cls}>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
            t.append("</tbody></table></div>")
            out.append("".join(t))
            continue

        # 인용
        if line.startswith(">"):
            flush_para()
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(lines[i].strip()[1:].strip())
                i += 1
            out.append(f'<div class="callout">{"<br>".join(inline(b) for b in buf)}</div>')
            continue

        # 목록
        lm = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", raw)
        if lm:
            flush_para()
            stack: list[tuple[int, str]] = []
            html_list: list[str] = []
            while i < len(lines):
                lm = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if not lm:
                    # 목록 안의 들여쓴 코드/표는 목록을 끝내고 일반 블록으로 처리
                    break
                ind = len(lm.group(1))
                kind = "ol" if lm.group(2)[0].isdigit() else "ul"
                while stack and ind < stack[-1][0]:
                    html_list.append(f"</li></{stack.pop()[1]}>")
                if not stack or ind > stack[-1][0]:
                    html_list.append(f"<{kind}>")
                    stack.append((ind, kind))
                else:
                    html_list.append("</li>")
                html_list.append(f"<li>{inline(lm.group(3))}")
                i += 1
            while stack:
                html_list.append(f"</li></{stack.pop()[1]}>")
            out.append("".join(html_list))
            continue

        if not line:
            flush_para()
            i += 1
            continue

        para.append(line)
        i += 1

    flush_para()
    out.append("</section>")
    return title, toc, "\n".join(o for o in out if o)


def meta_block(md: str) -> list[tuple[str, str]]:
    items = []
    for line in md.splitlines()[1:12]:
        m = re.match(r"^- (.+?):\s*(.+)$", line)
        if m:
            items.append((m.group(1), m.group(2)))
    return items


CSS = """
:root{--bg:#f7f6f3;--panel:#fff;--ink:#1f2328;--muted:#5f6670;--line:#e3e1dc;--accent:#d6452f;--accent-soft:#fbe9e5;
--code-bg:#f1efea;--th:#f3f1ec;--b0:#d6452f;--b1:#c77d0a;--b2:#2f6fd6;--b3:#7a7f87;--side:280px;--pos:#1f5fd1;--neg:#c8322a}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#15171a;--panel:#1c1f23;--ink:#e6e6e3;--muted:#9aa0a8;
--line:#2c3036;--accent:#ff7a5c;--accent-soft:#3a2420;--code-bg:#24282e;--th:#22262b;--b0:#ff7a5c;--b1:#f0b040;--b2:#6fa3ff;--b3:#9aa0a8;--pos:#7fb0ff;--neg:#ff7d72}}
:root[data-theme="dark"]{--bg:#15171a;--panel:#1c1f23;--ink:#e6e6e3;--muted:#9aa0a8;--line:#2c3036;--accent:#ff7a5c;--accent-soft:#3a2420;
--code-bg:#24282e;--th:#22262b;--b0:#ff7a5c;--b1:#f0b040;--b2:#6fa3ff;--b3:#9aa0a8;--pos:#7fb0ff;--neg:#ff7d72}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:16px}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.7 "Pretendard","Apple SD Gothic Neo","Malgun Gothic",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.layout{display:grid;grid-template-columns:var(--side) minmax(0,1fr);min-height:100vh}
aside{position:sticky;top:0;height:100vh;overflow-y:auto;border-right:1px solid var(--line);padding:24px 16px 40px;background:var(--panel)}
.brand{font-weight:800;font-size:14px;letter-spacing:.02em;margin:0 8px 4px}
.brand-sub{color:var(--muted);font-size:12px;margin:0 8px 16px}
#search{width:100%;padding:8px 10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--ink);font:inherit;font-size:13px;margin-bottom:12px}
nav a{display:block;color:var(--muted);text-decoration:none;font-size:13px;line-height:1.4;padding:5px 8px;border-radius:6px}
nav a.l3{padding-left:22px;font-size:12.5px}
nav a:hover{background:var(--bg);color:var(--ink)}
nav a.active{background:var(--accent-soft);color:var(--accent);font-weight:600}
nav a.hidden{display:none}
main{padding:40px 48px 120px;max-width:1080px}
.hero{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:28px 32px;margin-bottom:32px}
.hero h1{margin:0 0 16px;font-size:28px;line-height:1.3;letter-spacing:-.01em}
.meta{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px}
.meta div{background:var(--bg);border-radius:10px;padding:10px 14px}
.meta dt{font-size:12px;color:var(--muted)}
.meta dd{margin:0;font-weight:600;font-size:14px}
.legend{display:flex;flex-wrap:wrap;gap:12px;margin-top:16px;font-size:13px;color:var(--muted)}
section.chapter{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:8px 32px 24px;margin-bottom:24px}
h2{font-size:22px;margin:24px 0 12px;padding-bottom:10px;border-bottom:2px solid var(--accent);letter-spacing:-.01em}
h3{font-size:17px;margin:32px 0 10px}
h4{font-size:15px;margin:24px 0 8px;color:var(--muted)}
h1 .anchor,h2 .anchor,h3 .anchor,h4 .anchor{margin-left:8px;color:var(--line);text-decoration:none;font-weight:400;opacity:0}
h2:hover .anchor,h3:hover .anchor,h4:hover .anchor{opacity:1}
p{margin:10px 0}
ul,ol{padding-left:22px;margin:8px 0}
li{margin:3px 0}
a{color:var(--accent)}
code{font-family:"JetBrains Mono","D2Coding",Consolas,monospace;font-size:.88em;background:var(--code-bg);padding:1px 6px;border-radius:5px}
pre{background:var(--code-bg);border-radius:10px;padding:14px 16px;overflow-x:auto;font-size:13px;line-height:1.55;margin:12px 0}
pre code{background:none;padding:0;font-size:inherit}
.table-wrap{overflow-x:auto;margin:12px 0;border:1px solid var(--line);border-radius:10px}
table{border-collapse:collapse;width:100%;font-size:13.5px}
th{background:var(--th);text-align:left;font-weight:700;white-space:nowrap}
th,td{padding:8px 12px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
tbody tr:hover{background:var(--bg)}
.callout{border-left:4px solid var(--accent);background:var(--accent-soft);padding:12px 16px;border-radius:0 10px 10px 0;margin:12px 0;font-size:14px}
.badge{display:inline-block;font-size:11px;font-weight:800;padding:1px 7px;border-radius:999px;color:#fff;vertical-align:1px;letter-spacing:.03em}
.b0{background:var(--b0)}.b1{background:var(--b1)}.b2{background:var(--b2)}.b3{background:var(--b3)}
tr.trait-pos td{color:var(--pos)}
tr.trait-neg td{color:var(--neg)}
tr.trait-pos td code,tr.trait-neg td code{color:inherit}
.tbd{font-size:11px;font-weight:700;padding:0 6px;border-radius:4px;border:1px dashed var(--muted);color:var(--muted)}
.theme-btn{position:fixed;right:16px;top:16px;border:1px solid var(--line);background:var(--panel);color:var(--ink);border-radius:999px;padding:6px 12px;font:inherit;font-size:12px;cursor:pointer;z-index:10}
.menu-btn{display:none}
@media (max-width:900px){
 .layout{grid-template-columns:1fr}
 aside{position:fixed;inset:0 auto 0 0;width:min(86vw,320px);transform:translateX(-100%);transition:transform .2s;z-index:20;box-shadow:0 0 40px rgba(0,0,0,.2)}
 aside.open{transform:none}
 .menu-btn{display:block;position:fixed;left:16px;top:16px;z-index:30;border:1px solid var(--line);background:var(--panel);color:var(--ink);border-radius:999px;padding:6px 12px;font:inherit;font-size:12px}
 main{padding:64px 16px 80px}
 .hero,section.chapter{padding:16px}
 .hero h1{font-size:22px}
}
@media print{aside,.theme-btn,.menu-btn{display:none}.layout{display:block}section.chapter,.hero{border:0;padding:0}}
"""

JS = """
const links=[...document.querySelectorAll('nav a')];
const byId=Object.fromEntries(links.map(a=>[a.getAttribute('href').slice(1),a]));
const obs=new IntersectionObserver(es=>{es.forEach(e=>{if(e.isIntersecting){links.forEach(l=>l.classList.remove('active'));
const a=byId[e.target.id];if(a){a.classList.add('active');a.scrollIntoView({block:'nearest'});}}})},{rootMargin:'0px 0px -75% 0px'});
document.querySelectorAll('main h2[id],main h3[id]').forEach(h=>obs.observe(h));
document.getElementById('search').addEventListener('input',e=>{const q=e.target.value.trim().toLowerCase();
links.forEach(a=>a.classList.toggle('hidden',q&&!a.textContent.toLowerCase().includes(q)));});
const root=document.documentElement;
try{const t=localStorage.getItem('gd-theme');if(t)root.dataset.theme=t;}catch(e){}
document.querySelector('.theme-btn').addEventListener('click',()=>{const dark=root.dataset.theme?root.dataset.theme==='dark':matchMedia('(prefers-color-scheme: dark)').matches;
root.dataset.theme=dark?'light':'dark';try{localStorage.setItem('gd-theme',root.dataset.theme);}catch(e){}});
const aside=document.querySelector('aside');
document.querySelector('.menu-btn').addEventListener('click',()=>aside.classList.toggle('open'));
links.forEach(a=>a.addEventListener('click',()=>aside.classList.remove('open')));
"""


def main():
    md = SRC.read_text(encoding="utf-8")
    title, toc, body = convert(md)
    meta = meta_block(md)
    # 본문에서 제목(h1)과 상단 메타 목록은 hero로 옮긴다
    body = re.sub(r'^<h1 id="[^"]*">.*?</h1>\s*<ul>.*?</ul>', "", body, count=1, flags=re.S)
    nav = "\n".join(f'<a class="l{lvl}" href="#{sid}">{text}</a>' for lvl, sid, text in toc)
    meta_html = "".join(f"<div><dt>{html.escape(k)}</dt><dd>{inline(v)}</dd></div>" for k, v in meta)
    legend = (
        '<div class="legend"><span><span class="badge b0">P0</span> v0.1 필수</span>'
        '<span><span class="badge b1">P1</span> 기초 시스템 이후</span>'
        '<span><span class="badge b2">P2</span> v0.2 이후</span>'
        '<span><span class="badge b3">P3</span> 선택</span>'
        '<span><span class="tbd">TBD</span> 초안 값</span></div>'
    )
    page = f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>포켓몬 컴패니언 기획서</title>
<style>{CSS}</style>
</head>
<body>
<button class="menu-btn" type="button">목차</button>
<button class="theme-btn" type="button">테마 전환</button>
<div class="layout">
<aside>
<div class="brand">포켓몬 컴패니언</div>
<div class="brand-sub">개발 기획서</div>
<input id="search" type="search" placeholder="목차 검색">
<nav>
{nav}
</nav>
</aside>
<main>
<header class="hero">
<h1>{inline(title)}</h1>
<dl class="meta">{meta_html}</dl>
{legend}
</header>
{body}
</main>
</div>
<script>{JS}</script>
</body>
</html>
"""
    OUT.write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(page):,} bytes, {len(toc)} toc entries)")


if __name__ == "__main__":
    main()
