#!/bin/bash
# install.sh : installs codex-image on a Mac, asking before each change.
# Usage: scripts/install.sh [--yes] [--output DIR]
set -u

SELF="$0"
while [ -L "$SELF" ]; do SELF="$(readlink "$SELF")"; done
REPO="$(cd "$(dirname "$SELF")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$REPO/lib/common.sh"

YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --output) OUTPUT_ROOT="$2"; shift ;;
    -h|--help) echo "Usage: scripts/install.sh [--yes] [--output DIR]"; exit 0 ;;
  esac
  shift
done

say() { printf '\n==> %s\n' "$1"; }
ask() { # ask "question" : true when the user accepts
  [ "$YES" = 1 ] && return 0
  printf '%s [y/N] ' "$1"
  read -r answer </dev/tty || return 1
  case "$answer" in y|Y|o|O|yes|oui) return 0 ;; *) return 1 ;; esac
}
stop() { printf '\nStopped: %s\n' "$1"; exit 1; }

[ "$(uname -s)" = "Darwin" ] || stop "this installer targets macOS."

say "Checking the Mac"
"$REPO/scripts/doctor.sh" || true

# Command line tools
if ! xcode-select -p >/dev/null 2>&1; then
  say "Xcode Command Line Tools are missing"
  ask "Launch their installer now?" && xcode-select --install
  stop "finish the Command Line Tools install, then run this script again."
fi

# Node
CODEX="$(resolve_codex)"
if ! command -v node >/dev/null 2>&1 && { [ -z "$CODEX" ] || [ ! -x "$(dirname "$CODEX")/node" ]; }; then
  say "Node.js is missing"
  if command -v brew >/dev/null 2>&1 && ask "Install Node with Homebrew (brew install node)?"; then
    brew install node || stop "brew install node failed."
  else
    stop "install Node LTS (https://nodejs.org or nvm), then run this script again."
  fi
fi

# Codex CLI
CODEX="$(resolve_codex)"
CODEX_V=""
[ -n "$CODEX" ] && CODEX_V="$(codex_version "$CODEX")"
if [ -z "$CODEX" ] || ! version_ge "$CODEX_V" "$MIN_CODEX_VERSION"; then
  say "Codex CLI missing or too old (${CODEX_V:-none})"
  if ask "Install the latest Codex CLI (npm install -g @openai/codex@latest)?"; then
    NPM="$(command -v npm)"
    [ -n "$CODEX" ] && [ -x "$(dirname "$CODEX")/npm" ] && NPM="$(dirname "$CODEX")/npm"
    "$NPM" install -g @openai/codex@latest || stop "npm install failed."
    CODEX="$(find_best_codex)"
    CODEX_V="$(codex_version "$CODEX")"
  else
    stop "Codex $MIN_CODEX_VERSION+ is required."
  fi
fi
use_codex "$CODEX"
echo "Using Codex $CODEX_V ($CODEX)"

# Codex login
if ! codex login status 2>&1 | grep -q "Logged in"; then
  say "Codex is not logged in"
  echo "A browser window will open: sign in with your ChatGPT account (the entry plan is enough)."
  ask "Run codex login now?" && codex login
  codex login status 2>&1 | grep -q "Logged in" || stop "Codex login is required."
fi

# Upstream skill
IMG_DIR="$(find_imagegen_dir || true)"
if [ -z "$IMG_DIR" ]; then
  say "Installing the codex-imagegen skill (JunSeo99, MIT license)"
  ask "Download it from $UPSTREAM_REPO into ~/.agents/skills/codex-imagegen?" || stop "the codex-imagegen skill is required."
  TMP="$(mktemp -d)"
  git clone --depth 1 "$UPSTREAM_REPO.git" "$TMP/upstream" || stop "git clone failed."
  mkdir -p "$HOME/.agents/skills"
  cp -RL "$TMP/upstream/skill" "$HOME/.agents/skills/codex-imagegen"
  # The launcher scripts may live next to the skill or at the repository root.
  if [ ! -f "$HOME/.agents/skills/codex-imagegen/scripts/image_project.py" ]; then
    mkdir -p "$HOME/.agents/skills/codex-imagegen/scripts"
    cp "$TMP/upstream/scripts/"*.py "$HOME/.agents/skills/codex-imagegen/scripts/"
  fi
  (cd "$TMP/upstream" && git rev-parse HEAD) > "$HOME/.agents/skills/codex-imagegen/.upstream-commit"
  rm -rf "$TMP"
  IMG_DIR="$HOME/.agents/skills/codex-imagegen"
  # Claude Code reads ~/.claude/skills: link it there too.
  if [ ! -e "$HOME/.claude/skills/codex-imagegen" ]; then
    mkdir -p "$HOME/.claude/skills"
    ln -s "$IMG_DIR" "$HOME/.claude/skills/codex-imagegen"
  fi
fi
echo "codex-imagegen: $IMG_DIR"

# Patch for Codex 0.162+
TARGET="$IMG_DIR/scripts/run_codex_imagegen.py"
if version_ge "$CODEX_V" "0.162.0" && ! grep -q "recover_generated_paths" "$TARGET"; then
  say "Applying the Codex 0.162 compatibility patch"
  if patch --dry-run -s "$TARGET" < "$REPO/patches/codex-cli-0.162.patch" >/dev/null 2>&1; then
    cp "$TARGET" "$TARGET.before-0162"
    patch -s "$TARGET" < "$REPO/patches/codex-cli-0.162.patch" || stop "patch failed (backup: $TARGET.before-0162)."
    echo "Patched (backup kept: $TARGET.before-0162)."
  else
    echo "WARNING: the patch does not apply to this upstream version."
    echo "Upstream may have fixed it already. Test with: codex-image doctor, then one image."
  fi
fi

# codex-image itself
say "Installing codex-image into $CODEX_IMAGE_HOME"
mkdir -p "$CODEX_IMAGE_HOME"
for d in bin lib scripts patches; do
  rm -rf "${CODEX_IMAGE_HOME:?}/$d"
  cp -R "$REPO/$d" "$CODEX_IMAGE_HOME/$d"
done
chmod +x "$CODEX_IMAGE_HOME/bin/codex-image" "$CODEX_IMAGE_HOME/scripts/"*.sh
cat > "$CODEX_IMAGE_CONFIG" <<EOF
# codex-image configuration (written by install.sh, edit freely)
CODEX_BIN="$CODEX"
IMAGEGEN_DIR="$IMG_DIR"
OUTPUT_ROOT="$OUTPUT_ROOT"
EOF
mkdir -p "$OUTPUT_ROOT"

# Optional shortcut in the PATH
if [ -d /usr/local/bin ] && [ -w /usr/local/bin ] && [ ! -e /usr/local/bin/codex-image ]; then
  ln -s "$CODEX_IMAGE_HOME/bin/codex-image" /usr/local/bin/codex-image && echo "Shortcut: /usr/local/bin/codex-image"
fi

# Skill for Claude Code (the Claude app needs a manual upload, see README)
mkdir -p "$HOME/.claude/skills"
rm -rf "$HOME/.claude/skills/codex-image"
cp -R "$REPO/skill/codex-image" "$HOME/.claude/skills/codex-image"
echo "Skill copied for Claude Code: ~/.claude/skills/codex-image"

say "Final check"
"$CODEX_IMAGE_HOME/scripts/doctor.sh" || stop "some checks still fail, see above."

cat <<EOF

All set.
  Command : $CODEX_IMAGE_HOME/bin/codex-image
  Images  : $OUTPUT_ROOT
  Next    : add the skill to the Claude app (README, step 3) and connect the folder
            $OUTPUT_ROOT to Claude so it can read the images back.
  Test    : echo "A red apple on a white table, square 1:1. No text." | $CODEX_IMAGE_HOME/bin/codex-image generate - --name test

EOF
