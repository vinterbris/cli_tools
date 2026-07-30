#!/usr/bin/env bash
#
# Bootstrap a modern CLI environment on a Debian-family system.
# Idempotent: safe to re-run. Installs only what is missing.
#
# Targets: Ubuntu 24.04 (WSL), Pop!_OS 22.04, Debian 12.
# See INSTALL.md for the manual equivalent.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES="$REPO_ROOT/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
SKIP_TOOLS=0
SKIP_DOTFILES=0
SKIP_SHELL=0
INSTALL_MANAGERS=0

# ── output ───────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'
  C_DIM=$'\033[2m';  C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_ERR=''; C_DIM=''; C_BOLD=''; C_OFF=''
fi

info() { printf '%s==>%s %s\n' "$C_BOLD" "$C_OFF" "$*"; }
ok()   { printf '  %sok%s   %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '  %swarn%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
err()  { printf '  %serr%s  %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }
dim()  { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  %s[dry-run]%s %s\n' "$C_DIM" "$C_OFF" "$*"
  else
    "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

  --dry-run            Print what would happen, change nothing
  --skip-tools         Only link dotfiles, install no packages
  --skip-dotfiles      Only install tools, touch no config
  --skip-shell         Do not change the login shell
  --install-managers   Install rustup and Homebrew if absent
  -h, --help           This message

Install priority per tool: apt (if new enough) > cargo > brew.
Re-running is safe; anything already present is left alone.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)          DRY_RUN=1 ;;
    --skip-tools)       SKIP_TOOLS=1 ;;
    --skip-dotfiles)    SKIP_DOTFILES=1 ;;
    --skip-shell)       SKIP_SHELL=1 ;;
    --install-managers) INSTALL_MANAGERS=1 ;;
    -h|--help)          usage; exit 0 ;;
    *) err "unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

# ── preflight ────────────────────────────────────────────────────
DISTRO_ID=''; DISTRO_VER=''; DISTRO_NAME=''
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_ID="${ID:-}"; DISTRO_VER="${VERSION_ID:-}"; DISTRO_NAME="${PRETTY_NAME:-}"
fi

info "System"
dim "${DISTRO_NAME:-unknown}"
command -v apt-get >/dev/null || { err "apt-get not found — this script targets Debian-family systems only"; exit 1; }
[ -d "$DOTFILES" ] || { err "dotfiles/ not found next to bootstrap/ (looked in $DOTFILES)"; exit 1; }
ok "repo root: $REPO_ROOT"

APT_UPDATED=0
apt_update_once() {
  [ "$APT_UPDATED" -eq 1 ] && return 0
  info "apt update"
  run sudo apt-get update -qq
  APT_UPDATED=1
}

# ── tool table ───────────────────────────────────────────────────
# name | binary | apt package | min version | cargo crate | brew formula
# min version "-" means any apt version is acceptable.
# "-" in a source column means that source cannot provide the tool.
TOOLS=(
  "git|git|git|-|-|git"
  "zsh|zsh|zsh|-|-|zsh"
  "curl|curl|curl|-|-|curl"
  "jq|jq|jq|-|-|jq"
  "ripgrep|rg|ripgrep|-|ripgrep|ripgrep"
  "fd|fd|fd-find|-|fd-find|fd"
  "bat|bat|bat|-|bat|bat"
  "fzf|fzf|fzf|0.48|-|fzf"
  "eza|eza|eza|-|eza|eza"
  "zoxide|zoxide|zoxide|-|zoxide|zoxide"
  "starship|starship|-|-|starship|starship"
  "atuin|atuin|-|-|atuin|atuin"
  "delta|delta|git-delta|-|git-delta|git-delta"
  "lazygit|lazygit|lazygit|-|-|lazygit"
  "btop|btop|btop|-|-|btop"
  "duf|duf|duf|-|-|duf"
  "gdu|gdu|gdu|-|-|gdu"
  "dust|dust|-|-|du-dust|dust"
  "procs|procs|-|-|procs|procs"
  "tealdeer|tldr|tealdeer|-|tealdeer|tealdeer"
  "micro|micro|micro|-|-|micro"
  "yazi|yazi|-|-|yazi-fm|yazi"
  "xh|xh|-|-|xh|xh"
  "sd|sd|-|-|sd|sd"
  "hyperfine|hyperfine|hyperfine|-|hyperfine|hyperfine"
  "jless|jless|-|-|jless|jless"
  "trash-cli|trash-put|trash-cli|-|-|trash-cli"
)

have() { command -v "$1" >/dev/null 2>&1; }

# A real executable, not an alias — this script runs non-interactively
# so aliases are absent, but be explicit anyway.
have_bin() {
  local p
  p="$(command -v "$1" 2>/dev/null)" || return 1
  case "$p" in /*) [ -x "$p" ] ;; *) return 1 ;; esac
}

apt_candidate() {
  apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2; exit}'
}

# apt can provide $pkg at >= $min ?  min "-" means any version.
apt_can_provide() {
  local pkg="$1" min="$2" cand
  cand="$(apt_candidate "$pkg")"
  # Written as an explicit if — the `[ a ] || [ b ] && return 1` form parses
  # as `([ a ] || [ b ]) && return 1`, which happens to be right here but
  # reads as a precedence bug to anyone maintaining it.
  if [ -z "$cand" ] || [ "$cand" = "(none)" ]; then return 1; fi
  [ "$min" = "-" ] && return 0
  # dpkg is guaranteed present on apt systems and handles Debian version syntax
  dpkg --compare-versions "$cand" ge "$min"
}

install_via_apt()   { apt_update_once; run sudo apt-get install -y -qq "$1"; }
install_via_cargo() { run cargo install --locked "$1"; }
install_via_brew()  { run brew install "$1"; }

INSTALLED=(); SKIPPED=(); FAILED=()

install_tool() {
  local name bin apt_pkg min crate formula
  IFS='|' read -r name bin apt_pkg min crate formula <<<"$1"

  if have_bin "$bin"; then
    ok "$name — already present"
    SKIPPED+=("$name"); return 0
  fi

  # 1. apt, if it can supply a new enough version
  if [ "$apt_pkg" != "-" ] && apt_can_provide "$apt_pkg" "$min"; then
    info "$name — apt ($apt_pkg)"
    if install_via_apt "$apt_pkg"; then INSTALLED+=("$name:apt"); return 0; fi
    warn "$name — apt install failed, falling through"
  elif [ "$apt_pkg" != "-" ] && [ "$min" != "-" ]; then
    dim "$name — apt has $(apt_candidate "$apt_pkg"), need >= $min"
  fi

  # 2. cargo
  if [ "$crate" != "-" ] && have cargo; then
    info "$name — cargo ($crate)"
    if install_via_cargo "$crate"; then INSTALLED+=("$name:cargo"); return 0; fi
    warn "$name — cargo install failed, falling through"
  fi

  # 3. brew
  if [ "$formula" != "-" ] && have brew; then
    info "$name — brew ($formula)"
    if install_via_brew "$formula"; then INSTALLED+=("$name:brew"); return 0; fi
    warn "$name — brew install failed"
  fi

  err "$name — no usable source (apt too old/absent, cargo and brew unavailable)"
  FAILED+=("$name")
  return 0   # never abort the whole run for one tool
}

# ── package managers ─────────────────────────────────────────────
ensure_managers() {
  if ! have cargo && [ "$INSTALL_MANAGERS" -eq 1 ]; then
    info "Installing rustup"
    run bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  fi
  if ! have brew && [ "$INSTALL_MANAGERS" -eq 1 ]; then
    info "Installing Homebrew"
    run bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    for b in /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
      [ -d "$b/bin" ] && export PATH="$b/bin:$b/sbin:$PATH" && break
    done
  fi
  have cargo || warn "cargo absent — Rust-only tools will fall back to brew (--install-managers adds it)"
  have brew  || warn "brew absent — Go-only tools may be unavailable (--install-managers adds it)"
}

# ── dotfiles ─────────────────────────────────────────────────────
link_dotfiles() {
  info "Linking dotfiles"

  local pairs=(
    "shell_common|$HOME/.shell_common"
    "zshrc|$HOME/.zshrc"
    "bashrc|$HOME/.bashrc"
    "starship.toml|$HOME/.config/starship.toml"
  )

  run mkdir -p "$HOME/.config"

  local entry src dst
  for entry in "${pairs[@]}"; do
    src="$DOTFILES/${entry%%|*}"
    dst="${entry##*|}"

    if [ ! -f "$src" ]; then
      err "missing source: $src"; continue
    fi

    # Already pointing at the right place — nothing to do.
    if [ -L "$dst" ] && [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
      ok "${dst/#$HOME/\~} — already linked"; continue
    fi

    # Real file in the way: back it up before replacing.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      run mkdir -p "$BACKUP_DIR"
      run cp -a "$dst" "$BACKUP_DIR/"
      warn "${dst/#$HOME/\~} — backed up to ${BACKUP_DIR/#$HOME/\~}"
    fi

    run ln -sfn "$src" "$dst"
    ok "${dst/#$HOME/\~} -> ${src/#$HOME/\~}"
  done
}

install_zsh_plugins() {
  info "zsh plugins"
  run mkdir -p "$HOME/.zsh"
  local repo dir
  for repo in zsh-autosuggestions zsh-syntax-highlighting; do
    dir="$HOME/.zsh/$repo"
    if [ -d "$dir/.git" ]; then
      ok "$repo — present"
    elif [ -e "$dir" ]; then
      warn "$repo — $dir exists but is not a git checkout, leaving alone"
    else
      run git clone --depth=1 "https://github.com/zsh-users/$repo" "$dir"
      ok "$repo — cloned"
    fi
  done
}

configure_git() {
  info "git config"
  if ! have_bin delta; then
    warn "delta absent — skipping pager config"
    return 0
  fi
  run git config --global core.pager delta
  run git config --global interactive.diffFilter 'delta --color-only'
  run git config --global delta.navigate true
  run git config --global delta.line-numbers true
  run git config --global delta.side-by-side true
  run git config --global merge.conflictStyle zdiff3
  ok "delta wired into git"
}

set_login_shell() {
  [ "$SKIP_SHELL" -eq 1 ] && { dim "login shell — skipped"; return 0; }
  info "Login shell"
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null)" || { warn "zsh not installed"; return 0; }
  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "already zsh"; return 0
  fi
  if run chsh -s "$zsh_path" "$USER"; then
    ok "set to $zsh_path (takes effect on next login)"
  else
    warn "chsh failed — under WSL, set the Windows Terminal profile to: wsl.exe ~ -e zsh"
  fi
}

post_checks() {
  info "Verification"
  local entry name bin missing=0
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name bin _ _ _ _ <<<"$entry"
    if have_bin "$bin"; then :; else warn "$name ($bin) still missing"; missing=$((missing+1)); fi
  done
  [ "$missing" -eq 0 ] && ok "all tools present"

  local f
  for f in "$HOME/.shell_common" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.config/starship.toml"; do
    [ -f "$f" ] || warn "${f/#$HOME/\~} does not resolve"
  done

  if have_bin zsh; then
    if zsh -n "$DOTFILES/zshrc" 2>/dev/null; then ok "zshrc parses"; else err "zshrc has a syntax error"; fi
  fi
  if bash -n "$DOTFILES/bashrc" 2>/dev/null; then ok "bashrc parses"; else err "bashrc has a syntax error"; fi
}

# ── main ─────────────────────────────────────────────────────────
[ "$DRY_RUN" -eq 1 ] && warn "dry run — nothing will be changed"

if [ "$SKIP_TOOLS" -eq 0 ]; then
  ensure_managers
  info "Tools"
  for entry in "${TOOLS[@]}"; do install_tool "$entry"; done
else
  dim "tools — skipped"
fi

if [ "$SKIP_DOTFILES" -eq 0 ]; then
  link_dotfiles
  install_zsh_plugins
  configure_git
  set_login_shell
else
  dim "dotfiles — skipped"
fi

post_checks

# ── summary ──────────────────────────────────────────────────────
info "Summary"
_verb="installed"; [ "$DRY_RUN" -eq 1 ] && _verb="would install"
[ ${#INSTALLED[@]} -gt 0 ] && printf '  %s: %s\n' "$_verb" "${INSTALLED[*]}"
[ ${#SKIPPED[@]}   -gt 0 ] && printf '  already there: %d tools\n' "${#SKIPPED[@]}"
if [ ${#FAILED[@]} -gt 0 ]; then
  printf '  %sfailed:%s %s\n' "$C_ERR" "$C_OFF" "${FAILED[*]}"
  printf '  retry with --install-managers, or install those by hand\n'
fi

cat <<EOF

Next:
  exec zsh                 start the configured shell
  atuin import auto        pull existing history into atuin (once)
  ./install.sh --dry-run   see what a re-run would change

Docs: docs/cheatsheet.md · docs/usecases.md · docs/learning-plan.md
EOF
