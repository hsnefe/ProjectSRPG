"""Assemble the Python source bundle that serious_python embeds in the iOS app.

    python tools/phone/assemble_bundle.py --out build/phone_app [--match ../match_engine]

Output (``--out``)::

    main.py  phone_main.py
    career/   career_engine sources (+ db/migrations/*.sql, read from disk at runtime)
    match/    match_engine sources, its ``api`` package renamed ``match_api``

Why the rename: both back-ends have a top-level package called ``api`` and they must
share one interpreter. Only the match_engine side is renamed, in the *copy*; the
repositories are untouched. The rewrite is verified (no ``api`` import may survive and
every renamed module must still compile) and fails loudly otherwise.

Tests, caches, virtualenvs, databases, docs and the dev/demo scripts are left out.
Third-party wheels are NOT handled here - that is serious_python's ``-r`` step.
"""
import argparse
import ast
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent

OLD_PKG, NEW_PKG = "api", "match_api"

COMMON_IGNORE = shutil.ignore_patterns(
    "__pycache__", "*.pyc", "tests", ".venv", "venv", ".pytest_cache",
    "*.db", "*.db-journal", "*.db-wal", "*.db-shm", "*.md", "run_server.py",
)
# Standalone scripts at match_engine's root; nothing in the API imports them
# (verified by the import check in --verify).
MATCH_ONLY_IGNORE = {"demo_match.py", "play_interactive.py", "validate_realism.py"}

MAIN_SHIM = '''"""serious_python entry point: hand over to phone_main."""
import os
import sys

# serious_python may run this file without defining __file__, so the bundle root is
# found by looking for phone_main on sys.path when it is missing.
try:
    _root = os.path.dirname(os.path.abspath(__file__))
except NameError:
    _root = next((p for p in sys.path if p and os.path.isfile(os.path.join(p, "phone_main.py"))), os.getcwd())
sys.path.insert(0, _root)
os.environ.setdefault("PHONE_ROOT", _root)

import phone_main  # noqa: E402

phone_main.run()
'''

# `from api import x` / `from api.sub import y` / `import api.sub [as z]` / `import api`
_IMPORT_RE = re.compile(r"^(?P<ind>\s*)(?P<kw>from|import)\s+api(?=[\s.]|$)", re.MULTILINE)
_LEFTOVER_RE = re.compile(r"^\s*(from|import)\s+api(?=[\s.,]|$)", re.MULTILINE)


def rewrite_source(text: str) -> str:
    return _IMPORT_RE.sub(lambda m: f"{m['ind']}{m['kw']} {NEW_PKG}", text)


def _copy_tree(src: Path, dst: Path, extra_skip=()) -> None:
    def ignore(directory, names):
        skipped = set(COMMON_IGNORE(directory, names))
        if Path(directory) == src:
            skipped |= {n for n in names if n in extra_skip}
        return skipped

    shutil.copytree(src, dst, ignore=ignore)


def _rename_match_api(match_dst: Path) -> int:
    api_dir = match_dst / OLD_PKG
    if not api_dir.is_dir():
        sys.exit(f"match_engine has no {OLD_PKG}/ package at {api_dir}")
    api_dir.rename(match_dst / NEW_PKG)
    rewritten = 0
    for path in match_dst.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        new = rewrite_source(text)
        if new != text:
            path.write_text(new, encoding="utf-8")
            rewritten += 1
    return rewritten


def _verify(match_dst: Path) -> None:
    problems = []
    for path in match_dst.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        if _LEFTOVER_RE.search(text):
            problems.append(f"{path.relative_to(match_dst)}: still imports `api`")
        for quote in ('"', "'"):  # dotted-path strings like "api.app:app"
            if f"{quote}{OLD_PKG}." in text:
                problems.append(f"{path.relative_to(match_dst)}: string reference to `{OLD_PKG}.`")
        try:
            ast.parse(text, filename=str(path))
        except SyntaxError as exc:
            problems.append(f"{path.relative_to(match_dst)}: {exc}")
    if problems:
        sys.exit("match_engine rename failed verification:\n  " + "\n  ".join(problems))


def assemble(out: Path, match_src: Path, career_src: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    _copy_tree(career_src, out / "career")
    _copy_tree(match_src, out / "match", extra_skip=MATCH_ONLY_IGNORE)
    rewritten = _rename_match_api(out / "match")
    _verify(out / "match")
    shutil.copy2(HERE / "phone_main.py", out / "phone_main.py")
    (out / "main.py").write_text(MAIN_SHIM, encoding="utf-8")
    migrations = list((out / "career" / "db" / "migrations").glob("*.sql"))
    if not migrations:
        sys.exit("no migrations copied - career_engine would start with an empty schema")
    print(f"bundle: {out}  (match files rewritten: {rewritten}, migrations: {len(migrations)})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--match", type=Path, default=REPO.parent / "match_engine")
    parser.add_argument("--career", type=Path, default=REPO / "career_engine")
    args = parser.parse_args()
    for label, path in (("match_engine", args.match), ("career_engine", args.career)):
        if not path.is_dir():
            sys.exit(f"{label} not found at {path}")
    assemble(args.out.resolve(), args.match.resolve(), args.career.resolve())


if __name__ == "__main__":
    main()
