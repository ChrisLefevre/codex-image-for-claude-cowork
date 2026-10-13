#!/bin/bash
# doctor.sh : checks that this Mac has everything codex-image needs.
# Usage: doctor.sh [--json]
# Exit code: 0 = ready, 1 = at least one blocking problem.
set -u

SELF="$0"
while [ -L "$SELF" ]; do SELF="$(readlink "$SELF")"; done
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"

JSON=0
[ "${1:-}" = "--json" ] && JSON=1

FAILS=0
WARNS=0
RESULTS=""

report() { # level id message [fix]
  local level="$1" id="$2" msg="$3" fix="${4:-}"
  case "$level" in
    ok) icon="OK  " ;;
    warn) icon="WARN"; WARNS=$((WARNS + 1)) ;;
    fail) icon="FAIL"; FAILS=$((FAILS + 1)) ;;
  esac
  if [ "$JSON" = 1 ]; then
    RESULTS="$RESULTS$(printf '{"check": "%s", "level": "%s", "message": %s, "fix": %s},' \
      "$id" "$level" "$(json_escape "$msg")" "$(json_escape "$fix")")"
  else
    printf '[%s] %s\n' "$icon" "$msg"
    [ -n "$fix" ] && printf '       -> %s\n' "$fix"
  fi
}

[ "$JSON" = 1 ] || printf '\ncodex-image doctor\n==================\n\n'

# 1. macOS
if [ "$(uname -s)" = "Darwin" ]; then
  report ok macos "macOS $(sw_vers -productVersion) ($(uname -m))"
else
  report fail macos "This tool targets macOS (found $(uname -s))." "Linux may work but is not supported here."
fi

# 2. Free disk space in the home folder
FREE_GB="$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -z "$FREE_GB" ]; then
  report warn disk "Could not read free disk space."
elif [ "$FREE_GB" -lt "$MIN_FREE_GB" ]; then
  report fail disk "Only ${FREE_GB} GB free on the disk." "Free at least ${MIN_FREE_GB} GB (Node, Codex and images need room)."
else
  report ok disk "${FREE_GB} GB free on the disk"
fi

# 3. Command line tools (needed by python3, git, patch)
if xcode-select -p >/dev/null 2>&1; then
  report ok clt "Xcode Command Line Tools installed"
else
  report fail clt "Xcode Command Line Tools missing (python3, git and patch depend on them)." "Run: xcode-select --install"
fi

# 4. Python
if PY_V="$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)"; then
  if version_ge "$PY_V" "$MIN_PYTHON_VERSION"; then
    report ok python "Python $PY_V ($(command -v python3))"
  else
    report fail python "Python $PY_V is too old (need $MIN_PYTHON_VERSION+)." "Install a recent Python: brew install python"
  fi
else
  report fail python "python3 not found." "Run: xcode-select --install (or brew install python)"
fi

# 5. Node and npm (Codex is distributed with npm)
CODEX="$(resolve_codex)"
NODE_BIN=""
if [ -n "$CODEX" ] && [ -x "$(dirname "$CODEX")/node" ]; then NODE_BIN="$(dirname "$CODEX")/node"; fi
[ -n "$NODE_BIN" ] || NODE_BIN="$(command -v node 2>/dev/null || true)"
if [ -n "$NODE_BIN" ]; then
  NODE_V="$("$NODE_BIN" --version 2>/dev/null | tr -d v)"
  if version_ge "$NODE_V" "$MIN_NODE_MAJOR"; then
    report ok node "Node $NODE_V ($NODE_BIN)"
  else
    report fail node "Node $NODE_V is too old (need $MIN_NODE_MAJOR+)." "Install Node LTS: brew install node, or nvm install --lts"
  fi
else
  report fail node "Node.js not found." "Install Node LTS: brew install node, or nvm install --lts"
fi

# 6. Codex CLI : best version, and the trap of an older one first in PATH
if [ -z "$CODEX" ]; then
  report fail codex "Codex CLI not found." "Run: npm install -g @openai/codex"
else
  CODEX_V="$(codex_version "$CODEX")"
  if version_ge "$CODEX_V" "$MIN_CODEX_VERSION"; then
    report ok codex "Codex $CODEX_V ($CODEX)"
  else
    report fail codex "Codex $CODEX_V is too old (need $MIN_CODEX_VERSION+): $CODEX" "Run: npm install -g @openai/codex@latest"
  fi
  FIRST="$(command -v codex 2>/dev/null || true)"
  if [ -n "$FIRST" ] && [ "$FIRST" != "$CODEX" ]; then
    FIRST_V="$(codex_version "$FIRST")"
    report warn codex_path "An older Codex ($FIRST_V, $FIRST) comes first in your PATH." \
      "codex-image always uses $CODEX. To clean up: brew uninstall codex, or remove $FIRST."
  fi

  # 7. Codex login (subscription, not API key)
  LOGIN="$(PATH="$(dirname "$CODEX"):$PATH" "$CODEX" login status 2>&1 | head -3)"
  case "$LOGIN" in
    *"Logged in using ChatGPT"*) report ok login "Codex logged in with a ChatGPT subscription" ;;
    *"API key"*) report warn login "Codex is logged in with an API key: images will be billed on the API." "Prefer: codex logout && codex login (ChatGPT account)" ;;
    *) report fail login "Codex is not logged in." "Run: codex login" ;;
  esac

  # 8. Patch needed for Codex 0.162+
  IMG_DIR="$(find_imagegen_dir || true)"
  if [ -n "$IMG_DIR" ] && version_ge "$CODEX_V" "0.162.0"; then
    if grep -q "recover_generated_paths" "$IMG_DIR/scripts/run_codex_imagegen.py" 2>/dev/null; then
      report ok patch "Codex 0.162 compatibility patch present"
    else
      report fail patch "Codex $CODEX_V needs the compatibility patch (otherwise finished images are lost)." "Run: scripts/install.sh (it applies patches/codex-cli-0.162.patch)"
    fi
  fi
fi

# 9. Upstream skill codex-imagegen
IMG_DIR="$(find_imagegen_dir || true)"
if [ -n "$IMG_DIR" ]; then
  report ok imagegen "codex-imagegen skill found ($IMG_DIR)"
else
  report fail imagegen "codex-imagegen skill not found." "Run: scripts/install.sh"
fi

# 10. codex-image installed and reachable
if [ -x "$CODEX_IMAGE_HOME/bin/codex-image" ]; then
  report ok wrapper "codex-image command installed ($CODEX_IMAGE_HOME/bin/codex-image)"
else
  report warn wrapper "codex-image command not installed in $CODEX_IMAGE_HOME." "Run: scripts/install.sh"
fi

# 11. Output folder
if mkdir -p "$OUTPUT_ROOT" 2>/dev/null && [ -w "$OUTPUT_ROOT" ]; then
  report ok output "Output folder writable ($OUTPUT_ROOT)"
else
  report fail output "Cannot write to $OUTPUT_ROOT." "Set OUTPUT_ROOT in $CODEX_IMAGE_CONFIG"
fi

# 12. sips (JPEG conversion, built into macOS)
if command -v sips >/dev/null 2>&1; then
  report ok sips "sips available for JPEG conversion"
else
  report warn sips "sips not found: JPEG copies will not be created."
fi

if [ "$JSON" = 1 ]; then
  READY=true; [ "$FAILS" -gt 0 ] && READY=false
  printf '{"ready": %s, "fails": %d, "warnings": %d, "checks": [%s]}\n' "$READY" "$FAILS" "$WARNS" "${RESULTS%,}"
else
  echo
  if [ "$FAILS" -eq 0 ]; then
    printf 'Ready. %d warning(s).\n\n' "$WARNS"
  else
    printf 'Not ready: %d problem(s) to fix, %d warning(s).\n\n' "$FAILS" "$WARNS"
  fi
fi
[ "$FAILS" -eq 0 ]
