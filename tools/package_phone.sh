#!/usr/bin/env bash
# Package both Python back-ends for the iPhone build (serious_python, CPython 3.12).
#
#   tools/package_phone.sh [--match DIR] [--project DIR] [--bundle-id ID] [--no-smoke]
#   source build/phone/env.sh && flutter build ios --release   # or flutter run --release
#
# What it does (macOS):
#   1. assembles career_engine + match_engine into one source bundle
#      (tools/phone/assemble_bundle.py - renames match_engine's `api` package);
#   2. runs the desktop smoke test on that bundle with the pinned wheels, so a broken
#      rename or import fails here in seconds instead of on the phone;
#   3. has serious_python install the iOS wheels (requirements-phone.txt) and stage
#      the bundle where the plugin's build picks it up;
#   4. verifies what was staged and writes build/phone/env.sh.
#
# The env.sh step matters: serious_python reads the same variables again during
# `flutter build`, so they must be exported for that command too.
#
# Needs: a Flutter project that depends on `serious_python` (default: this repo; add
# it first - `flutter pub add serious_python`), Python 3.12 on PATH, dart on PATH.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MATCH=""
BUNDLE_ID=""
RUN_SMOKE=1
PY_VERSION="3.12"   # must match the host venv used by the smoke test and the wheels pinned below

while [ $# -gt 0 ]; do
  case "$1" in
    --match)     MATCH="$2"; shift 2 ;;
    --project)   PROJECT="$(cd "$2" && pwd)"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --no-smoke)  RUN_SMOKE=0; shift ;;
    -h|--help)   sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

die() { echo "package_phone: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "iOS packaging needs macOS."
[ -f "$PROJECT/pubspec.yaml" ] || die "no pubspec.yaml in $PROJECT"
grep -Eq '^[[:space:]]+serious_python:' "$PROJECT/pubspec.yaml" \
  || die "serious_python is not a dependency of $PROJECT/pubspec.yaml (run: flutter pub add serious_python)."
command -v dart >/dev/null || die "dart is not on PATH."

PY="${PYTHON:-python3.12}"
command -v "$PY" >/dev/null || die "$PY not found; set PYTHON=/path/to/python3.12."
"$PY" -c "import sys; assert sys.version_info[:2] == (3, 12), sys.version" \
  || die "$PY is not Python 3.12 (the iOS runtime and pinned wheels are 3.12)."

# match_engine is a sibling repo of this one unless told otherwise.
[ -n "$MATCH" ] || MATCH="$(cd "$HERE/../.." && pwd)/match_engine"
[ -d "$MATCH/api" ] || die "match_engine not found at $MATCH (use --match DIR)."

if [ -z "$BUNDLE_ID" ]; then
  BUNDLE_ID="$(grep -h 'PRODUCT_BUNDLE_IDENTIFIER' "$PROJECT/ios/Runner.xcodeproj/project.pbxproj" \
    | grep -v 'Tests' | head -1 | sed -E 's/.*= *([^;]+);.*/\1/')"
fi
[ -n "$BUNDLE_ID" ] || die "could not read the iOS bundle id; pass --bundle-id."

BUILD="$PROJECT/build/phone"
BUNDLE="$BUILD/bundle"
SITE="$BUILD/site-packages"
APP="$BUILD/app"
REQS="$HERE/phone/requirements-phone.txt"

echo "== project   $PROJECT"
echo "== match     $MATCH"
echo "== bundle id $BUNDLE_ID"
mkdir -p "$BUILD"

echo "== 1/4 assemble source bundle"
"$PY" "$HERE/phone/assemble_bundle.py" --out "$BUNDLE" --match "$MATCH"

if [ "$RUN_SMOKE" = 1 ]; then
  echo "== 2/4 desktop smoke test (pinned wheels, host venv)"
  VENV="$BUILD/host-venv"
  if [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -m pip freeze 2>/dev/null | cmp -s - "$BUILD/host-venv.freeze.expected" 2>/dev/null; then
    rm -rf "$VENV"
    "$PY" -m venv "$VENV"
    "$VENV/bin/python" -m pip install -q --disable-pip-version-check -r "$REQS"
    "$VENV/bin/python" -m pip freeze > "$BUILD/host-venv.freeze.expected"
  fi
  "$VENV/bin/python" "$HERE/phone/smoke_test.py" "$BUNDLE" 2>&1 | grep -v 'httpx INFO' \
    || die "desktop smoke test failed - not packaging."
else
  echo "== 2/4 desktop smoke test skipped (--no-smoke)"
fi

echo "== 3/4 install iOS wheels and stage with serious_python"
rm -rf "$SITE" "$APP"
export SERIOUS_PYTHON_VERSION="$PY_VERSION"
export SERIOUS_PYTHON_BUNDLE_ID="$BUNDLE_ID"
export SERIOUS_PYTHON_SITE_PACKAGES="$SITE"
export SERIOUS_PYTHON_APP="$APP"
# `-r -r -r FILE` hands pip the literal `-r FILE` (serious_python's documented form).
# --cleanup-packages strips C sources, stubs and __pycache__ from the wheels.
(cd "$PROJECT" && dart run serious_python:main package "$BUNDLE" -p iOS \
  --cleanup-packages -r -r -r "$REQS")

echo "== 4/4 verify staged output"
for f in main.py phone_main.py career/api/app.py match/match_api/app.py; do
  [ -f "$APP/$f" ] || die "staged app is missing $f"
done
n_sql="$(find "$APP/career/db/migrations" -name '*.sql' | wc -l | tr -d ' ')"
[ "$n_sql" -gt 0 ] || die "no migrations staged under $APP/career/db/migrations"
for arch in iphoneos.arm64 iphonesimulator.arm64; do
  [ -d "$SITE/$arch/pydantic_core" ] || die "no pydantic_core iOS wheel staged for $arch"
  for banned in uvloop httptools watchfiles websockets; do
    [ ! -e "$SITE/$arch/$banned" ] || die "$banned (native/reload-only) was staged for $arch"
  done
done
[ -z "$(find "$APP" -name 'test_*.py' -o -name 'career.db' | head -1)" ] || die "tests or a database leaked into the app bundle"

cat > "$BUILD/env.sh" <<EOF
# generated by tools/package_phone.sh - source before 'flutter build ios' / 'flutter run'
export SERIOUS_PYTHON_VERSION="$PY_VERSION"
export SERIOUS_PYTHON_BUNDLE_ID="$BUNDLE_ID"
export SERIOUS_PYTHON_SITE_PACKAGES="$SITE"
export SERIOUS_PYTHON_APP="$APP"
EOF

echo
echo "app bundle:   $(du -sh "$APP" | cut -f1)  ($n_sql migrations)"
echo "site-packages (iphoneos): $(du -sh "$SITE/iphoneos.arm64" | cut -f1)"
echo "done. Next:   source \"$BUILD/env.sh\" && (cd \"$PROJECT\" && flutter build ios --release)"
