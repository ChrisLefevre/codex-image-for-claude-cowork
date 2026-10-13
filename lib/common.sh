# shellcheck shell=bash
# Shared helpers for codex-image. Compatible with the bash 3.2 shipped with macOS.

CODEX_IMAGE_HOME="${CODEX_IMAGE_HOME:-$HOME/.codex-image}"
CODEX_IMAGE_CONFIG="${CODEX_IMAGE_CONFIG:-$CODEX_IMAGE_HOME/config}"
MIN_CODEX_VERSION="0.153.4"
MIN_PYTHON_VERSION="3.9"
MIN_NODE_MAJOR=18
MIN_FREE_GB=2
UPSTREAM_REPO="https://github.com/JunSeo99/claude-skill-codex-imagegen"

# Load user config if present (CODEX_BIN, IMAGEGEN_DIR, OUTPUT_ROOT).
if [ -f "$CODEX_IMAGE_CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$CODEX_IMAGE_CONFIG"
fi
OUTPUT_ROOT="${OUTPUT_ROOT:-$HOME/Desktop/codex-images}"

# version_ge A B : true when version A >= version B (numeric, dot separated).
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, ".");
    n = (na > nb) ? na : nb;
    for (i = 1; i <= n; i++) {
      xi = (i <= na) ? x[i] + 0 : 0; yi = (i <= nb) ? y[i] + 0 : 0;
      if (xi > yi) exit 0;
      if (xi < yi) exit 1;
    }
    exit 0
  }'
}

# codex_version BIN : prints the version number of a codex binary, or nothing.
# A codex installed with npm is a node script, so its own folder goes first in PATH.
codex_version() {
  local bin="$1" dir
  dir="$(dirname "$bin")"
  PATH="$dir:$PATH" "$bin" --version 2>/dev/null | awk '{print $NF}' | head -1
}

# list_codex_candidates : every codex binary we can find, one per line, no duplicates.
list_codex_candidates() {
  {
    which -a codex 2>/dev/null
    ls -1 "$HOME"/.nvm/versions/node/*/bin/codex 2>/dev/null
    for p in /opt/homebrew/bin/codex /usr/local/bin/codex "$HOME/.npm-global/bin/codex" \
             "$HOME/.volta/bin/codex" "$HOME/.local/bin/codex" "$HOME/.bun/bin/codex"; do
      [ -x "$p" ] && echo "$p"
    done
  } | awk '!seen[$0]++'
}

# find_best_codex : prints the path of the most recent codex binary (empty if none).
find_best_codex() {
  local best="" best_v="0" bin v
  while IFS= read -r bin; do
    [ -x "$bin" ] || continue
    v="$(codex_version "$bin")"
    [ -n "$v" ] || continue
    if version_ge "$v" "$best_v" && [ "$v" != "$best_v" ]; then
      best="$bin"; best_v="$v"
    fi
  done <<EOF
$(list_codex_candidates)
EOF
  echo "$best"
}

# resolve_codex : CODEX_BIN from config when still valid, otherwise the best one found.
resolve_codex() {
  if [ -n "${CODEX_BIN:-}" ] && [ -x "$CODEX_BIN" ]; then
    echo "$CODEX_BIN"
  else
    find_best_codex
  fi
}

# find_imagegen_dir : folder of the upstream codex-imagegen skill.
find_imagegen_dir() {
  local d
  for d in "${IMAGEGEN_DIR:-}" "$HOME/.agents/skills/codex-imagegen" "$HOME/.claude/skills/codex-imagegen"; do
    if [ -n "$d" ] && [ -f "$d/scripts/image_project.py" ]; then
      echo "$d"; return 0
    fi
  done
  return 1
}

# use_codex BIN : put the folder of BIN (and its node) first in PATH.
use_codex() {
  PATH="$(dirname "$1"):/opt/homebrew/bin:/usr/local/bin:$PATH"
  export PATH
}

# json_escape STRING
json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}
