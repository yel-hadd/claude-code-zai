#!/usr/bin/env python3
"""Keep README.md, docs/index.html and docs/llms-full.txt in sync with scripts/ and config/.

- Code between <!-- BEGIN:path --> and <!-- END:path --> markers is replaced with the file at path.
- The FAQ in docs/index.html (HTML and FAQPage JSON-LD) is generated from README.md's "## FAQ" section.
- docs/llms-full.txt is the README plus every script, for LLMs.

Usage: python3 tools/sync.py          # rewrite files
       python3 tools/sync.py --check  # exit 1 if anything is out of date (used by CI)
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANG = {".sh": "bash", ".ps1": "powershell", ".json": "json", ".md": "markdown"}
MARKER = re.compile(r"(<!-- BEGIN:([^ ]+) -->\n)(.*?)(<!-- END:\2 -->)", re.S)
SCRIPTS = [
    "scripts/claude-z.sh", "scripts/zai-quota.sh", "scripts/statusline.sh", "scripts/zai-usage-hook.sh",
    "scripts/claude-z.ps1", "scripts/zai-quota.ps1", "scripts/statusline.ps1", "scripts/zai-usage-hook.ps1",
    "scripts/zai-usage.md", "config/settings.json", "install.sh", "install.ps1",
]
SITE = "https://yel-hadd.github.io/claude-code-zai/"


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def code_md(rel):
    return f"```{LANG.get(Path(rel).suffix, '')}\n{read(rel).rstrip()}\n```\n"


def code_html(rel):
    lang = LANG.get(Path(rel).suffix, "")
    return f'<pre><code class="language-{lang}">{html.escape(read(rel).rstrip(), quote=False)}</code></pre>\n'


def link_html(m):
    text, url = m.group(1), m.group(2)
    rel = ' rel="sponsored noopener"' if "z.ai/subscribe?ic=" in url else ""  # referral links
    return f'<a href="{url}"{rel}>{text}</a>'


def inline_html(text):
    """Markdown inline (code spans, links) to HTML."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for p in parts:
        if p.startswith("`") and p.endswith("`"):
            out.append(f"<code>{html.escape(p[1:-1], quote=False)}</code>")
        else:
            p = html.escape(p, quote=False)
            p = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link_html, p)
            out.append(p)
    return "".join(out)


def plain(text):
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1", text)
    return text.replace("`", "")


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", plain(text).lower()).strip("-")[:80]


def faq_items(readme):
    m = re.search(r"^## FAQ\n(.*?)(?=^## )", readme, re.S | re.M)
    if not m:
        sys.exit("README.md has no '## FAQ' section")
    items = []
    for block in re.split(r"^### ", m.group(1), flags=re.M)[1:]:
        q, _, body = block.partition("\n")
        paras = [" ".join(p.split()) for p in body.strip().split("\n\n") if p.strip()]
        items.append((q.strip(), paras))
    return items


def fill(text, render):
    return MARKER.sub(lambda m: m.group(1) + render(m.group(2)) + m.group(4), text)


def build():
    out = {}
    readme = fill(read("README.md"), code_md)
    out["README.md"] = readme

    faq = faq_items(readme)

    def site_render(key):
        if key == "faq":
            return "".join(
                f'<h3 id="{slug(q)}">{inline_html(q)}</h3>\n' + "".join(f"<p>{inline_html(p)}</p>\n" for p in paras)
                for q, paras in faq
            )
        if key == "faq-jsonld":
            obj = {
                "@context": "https://schema.org",
                "@type": "FAQPage",
                "@id": SITE + "#faq",
                "mainEntity": [
                    {"@type": "Question", "name": plain(q),
                     "acceptedAnswer": {"@type": "Answer", "text": " ".join(plain(p) for p in paras)}}
                    for q, paras in faq
                ],
            }
            body = json.dumps(obj, ensure_ascii=False, indent=2).replace("</", "<\\/")
            return f'<script type="application/ld+json">\n{body}\n</script>\n'
        return code_html(key)

    out["docs/index.html"] = fill(read("docs/index.html"), site_render)

    body = MARKER.sub(lambda m: m.group(3), readme)  # drop the marker comments, keep the code
    appendix = "\n".join(f"### {rel}\n\n{code_md(rel)}" for rel in SCRIPTS)
    out["docs/llms-full.txt"] = (
        f"# claude-code-zai: full guide for LLMs\n\n> Source: https://github.com/yel-hadd/claude-code-zai"
        f" · Web: {SITE}\n\n{body.rstrip()}\n\n## Appendix: every script\n\n{appendix}"
    )
    return out


def main():
    check = "--check" in sys.argv
    stale = []
    for rel, new in build().items():
        path = ROOT / rel
        old = path.read_text(encoding="utf-8") if path.exists() else None
        if old != new:
            stale.append(rel)
            if not check:
                path.write_text(new, encoding="utf-8")
    if check and stale:
        print("Out of date (run python3 tools/sync.py):", ", ".join(stale))
        sys.exit(1)
    print("updated: " + ", ".join(stale) if stale and not check else "in sync")


if __name__ == "__main__":
    main()
