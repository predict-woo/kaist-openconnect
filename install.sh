#!/bin/bash
# install.sh — one-shot installer for kvpn (kaist-openconnect).
#
# Installs everything a fresh machine needs: Homebrew (macOS, if missing),
# OpenConnect, Python 3, and the kvpn script itself, linked onto your PATH.
#
# Run it from a clone:
#     ./install.sh
# or without cloning anything first:
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/predict-woo/kaist-openconnect/main/install.sh)"
#
# Safe to re-run: it skips whatever is already installed and updates kvpn.
#
# Overrides (mostly for testing):
#   KVPN_INSTALL_DIR  where to clone the repo when not run from a checkout
#                     (default: ~/.local/share/kaist-openconnect)
#   KVPN_BIN_DIR      where to put the `kvpn` symlink (default: first writable
#                     of /opt/homebrew/bin, /usr/local/bin, ~/.local/bin)

set -eu

REPO_URL="https://github.com/predict-woo/kaist-openconnect.git"
DEFAULT_INSTALL_DIR="$HOME/.local/share/kaist-openconnect"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"

# When invoked as `curl ... | bash`, stdin is the pipe, so interactive
# installers (Homebrew, sudo) would misread it. Reattach stdin to the
# terminal if we can.
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then
    exec </dev/tty
fi

# --- Homebrew (macOS only) --------------------------------------------------

ensure_homebrew() {
    # brew may be installed but not on PATH in this shell (fresh installs).
    for brew_prefix in /opt/homebrew /usr/local; do
        if [ -x "$brew_prefix/bin/brew" ]; then
            eval "$("$brew_prefix/bin/brew" shellenv)"
            break
        fi
    done
    if have brew; then
        info "Homebrew already installed."
        return
    fi
    info "Installing Homebrew (this also installs Apple's Command Line Tools)..."
    info "You may be asked for your macOS password."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for brew_prefix in /opt/homebrew /usr/local; do
        if [ -x "$brew_prefix/bin/brew" ]; then
            eval "$("$brew_prefix/bin/brew" shellenv)"
            break
        fi
    done
    have brew || die "Homebrew installation did not complete. Re-run this script after fixing the issue above."
    # Make brew available in future shells too.
    shell_rc="$HOME/.zprofile"
    case "${SHELL:-}" in
        */bash) shell_rc="$HOME/.bash_profile" ;;
    esac
    if ! grep -qs 'brew shellenv' "$shell_rc" 2>/dev/null; then
        printf '\neval "$(%s/bin/brew shellenv)"\n' "$(brew --prefix)" >> "$shell_rc"
        info "Added Homebrew to $shell_rc."
    fi
}

# --- Dependencies -----------------------------------------------------------

install_deps_macos() {
    ensure_homebrew
    if have openconnect; then
        info "OpenConnect already installed."
    else
        info "Installing OpenConnect..."
        brew install openconnect
    fi
    # macOS ships a /usr/bin/python3 stub; the Command Line Tools that Homebrew
    # installs provide the real one, so this is normally already satisfied.
    if ! have python3; then
        info "Installing Python 3..."
        brew install python3
    fi
}

install_deps_linux() {
    linux_install() {
        if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
    }
    pkgs=""
    have openconnect || pkgs="openconnect"
    have python3 || pkgs="$pkgs python3"
    have git || pkgs="$pkgs git"
    if [ -z "$pkgs" ]; then
        info "OpenConnect, Python 3, and git already installed."
        return
    fi
    info "Installing:$( printf ' %s' $pkgs )..."
    if have apt-get; then
        linux_install apt-get update
        linux_install apt-get install -y $pkgs
    elif have dnf; then
        linux_install dnf install -y $pkgs
    elif have pacman; then
        linux_install pacman -S --noconfirm --needed $pkgs
    elif have zypper; then
        linux_install zypper install -y $pkgs
    else
        die "No supported package manager found (apt/dnf/pacman/zypper). Please install manually: $pkgs"
    fi
}

# --- kvpn itself ------------------------------------------------------------

get_kvpn_source() {
    # If this script sits next to kvpn (run from a checkout), use that copy.
    script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
    if [ -n "$script_dir" ] && [ -f "$script_dir/kvpn" ]; then
        KVPN_SRC="$script_dir/kvpn"
        info "Using kvpn from this checkout ($script_dir)."
        return
    fi
    install_dir="${KVPN_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    if [ -d "$install_dir/.git" ]; then
        info "Updating existing copy in $install_dir..."
        git -C "$install_dir" pull --ff-only || warn "Could not update $install_dir; using the existing copy."
    else
        info "Downloading kvpn to $install_dir..."
        mkdir -p "$(dirname "$install_dir")"
        git clone --depth 1 "$REPO_URL" "$install_dir"
    fi
    KVPN_SRC="$install_dir/kvpn"
    [ -f "$KVPN_SRC" ] || die "kvpn not found in $install_dir."
}

link_kvpn() {
    [ -f "$(dirname "$KVPN_SRC")/kvpn_macos.py" ] || die "kvpn_macos.py must be kept next to kvpn. Download the complete repository and try again."
    chmod +x "$KVPN_SRC"
    bin_dir="${KVPN_BIN_DIR:-}"
    if [ -z "$bin_dir" ]; then
        for candidate in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
            if [ -d "$candidate" ] && [ -w "$candidate" ]; then
                bin_dir="$candidate"
                break
            fi
        done
    fi
    if [ -z "$bin_dir" ]; then
        bin_dir="$HOME/.local/bin"
        mkdir -p "$bin_dir"
    fi
    ln -sf "$KVPN_SRC" "$bin_dir/kvpn"
    info "Linked kvpn -> $bin_dir/kvpn"
    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *) warn "$bin_dir is not on your PATH. Add this to your ~/.zshrc or ~/.bashrc:
    export PATH=\"$bin_dir:\$PATH\"" ;;
    esac
}

# --- main -------------------------------------------------------------------

case "$OS" in
    Darwin) install_deps_macos ;;
    Linux)  install_deps_linux ;;
    *)      die "Unsupported OS: $OS (kvpn supports macOS and Linux)." ;;
esac

get_kvpn_source
link_kvpn

info "Done! Connect with:"
printf '\n    kvpn\n\n'
printf 'To disconnect, press Ctrl-C. To remove stored credentials: kvpn --forget\n'
