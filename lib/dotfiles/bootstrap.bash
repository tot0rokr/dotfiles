# Installers behind `dotfiles bootstrap system|user|agents`. Sourced by
# bin/dotfiles after core.bash; migrate.bash calls __bs_init and
# install_fnm_user directly.
#
# Nothing here edits rc files: rustup runs with --no-modify-path, fnm and fzf
# are installed without their shell-setup steps, and bell-bash/noti-bash are
# only cloned (env.bash, common.bash and common.conf wire them up, so neither
# writes ~/.claude). The exceptions under ~/.claude are third-party: the
# claude-account-switcher installer routes its statusLine in
# ~/.claude/settings.json, the Claude CLI installer downloads into
# ~/.claude/downloads (its `claude install` adds backups/ and sessions/), and
# the agents harness installer that `bootstrap agents` runs replaces ~/.claude
# with a link into ~/agents.

# Installs even when a system tmux exists: distro builds lag (Ubuntu 24.04's
# 3.4 misparses nvim's DECRQSS query as sixel). The binary lives alone in
# $LOCAL_OPT_PATH/tmux/bin, which env.bash puts ahead of the system dirs on
# PATH for every bash, including the non-interactive one `ssh host tmux
# attach` starts; $LOCAL_BIN_PATH gets a link too. Pinned to a known-good
# release; bumping the tag upgrades on the next run, and --force reinstalls
# even when the pinned version is present. v3.7b ships no arm64 build, so
# arm64 pins the newest release that has one. Both tags are read from the
# environment, e.g.
# `TMUX_STATIC_TAG=v3.2 dotfiles bootstrap user --only tmux --force`.
TMUX_STATIC_TAG="${TMUX_STATIC_TAG:-v3.7b}"
TMUX_STATIC_TAG_ARM64="${TMUX_STATIC_TAG_ARM64:-v3.6b}"

# Run order of `dotfiles bootstrap user`; --only keeps this order. fnm comes
# before vim-plug because markdown-preview's plugin build runs npx. claude
# comes before switcher: the switcher's installer writes
# ~/.claude/settings.json without creating ~/.claude, which the Claude CLI
# installer creates.
__bs_user_steps=(
    neovim fnm vim-plug rustup cargo-tools tldr starship jq lazygit gh gh-dash
    lazydocker delta gdu up fzf fzf-tab-completion pynvim clangd btop nnn tmux
    bell noti claude switcher
)

__bs_usage() {
    echo "usage: dotfiles bootstrap system|agents"
    echo "       dotfiles bootstrap user [--only NAME[,NAME...]] [--force]"
}

# Set-up shared by every bootstrap kind and by migrate.bash. The CLI never
# reads ~/.bashrc, so env.bash supplies the tool homes (CARGO_HOME,
# RUSTUP_HOME, FNM_DIR, npm_config_cache), LOCAL_BIN_PATH, LOCAL_OPT_PATH and
# PATH.
__bs_init() {
    # shellcheck source=/dev/null
    . "$REPO/.config/bash/env.bash" || return 1
    mkdir -p "$LOCAL_BIN_PATH" "$LOCAL_OPT_PATH" "$DATA" "$CACHE" || return 1
    # Kept unexported and removed from the environment, so third-party
    # installers (starship, the switcher, the claude CLI, agents) never see it.
    __bs_token=${GH_TOKEN:-${GITHUB_TOKEN:-${__bs_token:-}}}
    unset GH_TOKEN GITHUB_TOKEN
}

# hash -r: a cargo or node looked up before the install would otherwise stay
# cached at its old location.
__bs_refresh_path() {
    # shellcheck source=/dev/null
    . "$REPO/.config/bash/env.bash" || return 1
    hash -r
}

__bs_fnm_default_exists() {
    [ -e "$FNM_DIR/aliases/default" ] || [ -L "$FNM_DIR/aliases/default" ]
}

# Prints the old tool locations `dotfiles migrate tools` has not moved yet;
# true when there is any. Installing before that would leave second copies.
# The node move stays pending until migrate removes its pending file: the
# fnm default check alone passes once migrate has set the LTS default.
__bs_relocation_pending() {
    local d pending=1 mark=$STATE_DIR/migrate/node.pending
    for d in .cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash; do
        if [ -d "$HOME/$d" ] && [ ! -L "$HOME/$d" ]; then
            echo "$HOME/$d"
            pending=0
        fi
    done
    if [ -e "$HOME/.nvm" ] && ! __bs_fnm_default_exists; then
        echo "$HOME/.nvm (no fnm default yet)"
        pending=0
    fi
    if [ -s "$mark" ]; then
        echo "$mark (node $(head -n 1 "$mark") not moved to fnm yet; re-run 'dotfiles migrate tools')"
        pending=0
    fi
    return "$pending"
}

__require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1"
        return 1
    fi
}

__host_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "Unsupported CPU architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

__github_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "Unsupported CPU architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

__deb_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "Unsupported CPU architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

__gnu_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
        *) echo "Unsupported CPU architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

# Relative link, computed between physical directories so it resolves the way
# the kernel follows it even when $HOME is reached through a symlink.
__ln_rel() {
    local target=$1 link=$2 tdir ldir
    tdir=$(cd -P "${target%/*}" && pwd -P) || return 1
    ldir=$(cd -P "${link%/*}" && pwd -P) || return 1
    ln -sfn "$(realpath -m -s --relative-to="$ldir" "$tdir/${target##*/}")" "$link"
}

# An absolute link that an older bootstrap made to TARGET becomes relative.
__bs_relink() {
    local target=$1 link=$2
    case $(readlink -- "$link" 2>/dev/null) in
        /*)
            if [ "$link" -ef "$target" ]; then
                __ln_rel "$target" "$link" || echo "could not make $link relative" >&2
            fi
            ;;
    esac
    return 0
}

# GitHub API request, authenticated when a token was given. The header goes to
# curl on stdin (--config -), so the token never appears in any argv. A token
# github.com rejects (401: expired, or meant for another host) falls back to an
# unauthenticated request instead of failing every lookup.
__gh_api() {
    local out code
    if [ -n "$__bs_token" ]; then
        out=$(printf 'header = "Authorization: Bearer %s"\n' "$__bs_token" |
            curl -sSL --config - -w '\n%{http_code}' "$1") || return 1
        code=${out##*$'\n'}
        case $code in
            2??)
                printf '%s\n' "${out%$'\n'*}"
                return 0
                ;;
            401) echo "GitHub rejected the token (HTTP 401); retrying $1 without it." >&2 ;;
            *)
                echo "GitHub API request failed (HTTP $code): $1" >&2
                return 1
                ;;
        esac
    fi
    curl -fsSL "$1"
}

# Skips when the user-local nvim exists (re-running `dotfiles bootstrap user`
# must not silently upgrade it); --force upgrades to the latest release. The
# archive is unpacked next to the target first and swapped in only after it
# extracted cleanly, so a failed download/extract never leaves you without nvim.
install_neovim_user() {
    local arch dest tmp archive
    arch="$(__host_arch)" || return 1
    dest="$LOCAL_OPT_PATH/nvim-linux-${arch}"

    if [ "${1:-}" != "--force" ] && [ -x "$dest/bin/nvim" ]; then
        __bs_relink "$dest/bin/nvim" "$LOCAL_BIN_PATH/nvim"
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    mkdir -p "$LOCAL_OPT_PATH" "$LOCAL_BIN_PATH"
    tmp="$(mktemp -d "$LOCAL_OPT_PATH/.nvim-install.XXXXXX")" || return 1
    archive="$tmp/nvim-linux-${arch}.tar.gz"

    echo "Installing Neovim under $LOCAL_OPT_PATH ..."
    if ! curl -fL --retry 3 -o "$archive" \
            "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz" \
        || ! tar -C "$tmp" -xzf "$archive" \
        || [ ! -x "$tmp/nvim-linux-${arch}/bin/nvim" ]; then
        echo "Neovim download/extract failed; existing install left untouched." >&2
        rm -rf "$tmp"
        return 1
    fi

    rm -rf "$dest.old"
    [ -e "$dest" ] && mv "$dest" "$dest.old"
    mv "$tmp/nvim-linux-${arch}" "$dest" || {
        [ -e "$dest.old" ] && mv "$dest.old" "$dest"
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$dest.old" "$tmp"

    __ln_rel "$dest/bin/nvim" "$LOCAL_BIN_PATH/nvim" || return 1
    echo "Installed: $LOCAL_BIN_PATH/nvim ($("$LOCAL_BIN_PATH/nvim" --version | head -1))"
}

# fnm comes from its release binary: the upstream install script edits
# ~/.bashrc. The LTS default is set only when no default exists, so a re-run
# never moves node away from the version global npm packages belong to.
install_fnm_user() {
    local asset tmp dest="$LOCAL_OPT_PATH/fnm"
    case "$(uname -m)" in
        x86_64|amd64) asset="fnm-linux" ;;
        aarch64|arm64) asset="fnm-arm64" ;;
        *) echo "Unsupported CPU architecture for fnm: $(uname -m)" >&2; return 1 ;;
    esac

    if [ ! -x "$dest/fnm" ]; then
        __require_cmd curl || return 1
        __require_cmd unzip || return 1

        tmp="$(mktemp -d)" || return 1
        echo "Installing fnm under $dest ..."
        if ! curl -fL --retry 3 -o "$tmp/fnm.zip" \
                "https://github.com/Schniz/fnm/releases/latest/download/${asset}.zip" \
            || ! unzip -q -o "$tmp/fnm.zip" -d "$tmp" \
            || ! chmod 755 "$tmp/fnm" \
            || ! "$tmp/fnm" --version >/dev/null 2>&1; then
            echo "fnm download/verify failed." >&2
            rm -rf "$tmp"
            return 1
        fi
        if ! mkdir -p "$dest" || ! install -m 755 "$tmp/fnm" "$dest/fnm"; then
            rm -rf "$tmp"
            return 1
        fi
        rm -rf "$tmp"
    fi
    __ln_rel "$dest/fnm" "$LOCAL_BIN_PATH/fnm" || return 1

    if ! __bs_fnm_default_exists; then
        echo "Installing the Node.js LTS release as the fnm default ..."
        "$dest/fnm" install --lts || return 1
        "$dest/fnm" default lts-latest || return 1
    fi
    __bs_refresh_path
}

# Vim uses vim-plug (vimrc); Neovim uses lazy.nvim (lua/plugin_manager.lua),
# which clones itself on first start.
install_vim_plug_user() {
    __require_cmd curl || return 1

    local plug_path
    plug_path="$DATA/vim/autoload/plug.vim"

    if [ ! -f "$plug_path" ]; then
        echo "Installing vim-plug under $DATA/vim ..."
        curl -fLo "$plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || return 1
    fi

    if type -P vim >/dev/null 2>&1; then
        # Only a vim with XDG support reads ~/.config/vim; an older one would
        # run without our vimrc. stdin from /dev/null so a vim that fails the
        # probe cannot sit in Ex mode waiting on the tty.
        if command vim -es -i NONE -u NONE +'exe has("patch-9.1.0327") ? "qa!" : "cq"' </dev/null; then
            # --sync: otherwise +qall races the async install and Vim never exits.
            # -i NONE: before `dotfiles install` no vimrc moves viminfo under
            # $STATE, so vim would write ~/.viminfo; vim-plug needs none.
            command vim -i NONE +'silent! PlugInstall --sync' +qall || true
        else
            echo "vim predates 9.1.0327 (no XDG config support); skipping PlugInstall."
        fi
    fi

    if command -v nvim >/dev/null 2>&1; then
        nvim --headless '+Lazy! sync' +qa || true
    fi
}

# Skips only when our own cargo exists: an apt cargo must not stop rustup.
# --no-modify-path: env.bash already puts $CARGO_HOME/bin on PATH.
install_rustup_user() {
    if [ -x "$CARGO_HOME/bin/cargo" ]; then
        return 0
    fi

    __require_cmd curl || return 1
    echo "Installing rustup under $CARGO_HOME and $RUSTUP_HOME ..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path || return 1
    __bs_refresh_path
}

cargo_install_if_missing() {
    local bin crate
    bin="$1"
    crate="$2"
    shift 2

    if command -v "$bin" >/dev/null 2>&1; then
        return 0
    fi

    install_rustup_user || return 1
    if ! command -v cargo >/dev/null 2>&1; then
        echo "cargo is unavailable. Skipping $crate."
        return 1
    fi

    echo "Installing $crate with cargo ..."
    cargo install "$@" "$crate"
}

__bs_cargo_tools() {
    local rc=0
    cargo_install_if_missing fd fd-find || rc=1
    cargo_install_if_missing bat bat || rc=1
    cargo_install_if_missing rg ripgrep || rc=1
    cargo_install_if_missing dust du-dust || rc=1
    # --locked: without the crate's own Cargo.lock, cargo picks newer deps that
    # break eza's build, and no zip 5.x it can select for tealdeer
    cargo_install_if_missing eza eza --locked || rc=1
    cargo_install_if_missing hyperfine hyperfine || rc=1
    cargo_install_if_missing difft difftastic --locked || rc=1
    cargo_install_if_missing tldr tealdeer --locked || rc=1
    cargo_install_if_missing choose choose || rc=1
    cargo_install_if_missing zoxide zoxide --locked || rc=1
    return "$rc"
}

install_starship_user() {
    if command -v starship >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    echo "Installing starship under $LOCAL_BIN_PATH ..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN_PATH"
}

install_jq_user() {
    if [ -x "$LOCAL_BIN_PATH/jq" ] || command -v jq >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    local arch
    arch="$(__deb_arch)" || return 1

    echo "Installing jq under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$LOCAL_BIN_PATH/jq" \
        "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}" || return 1
    chmod 755 "$LOCAL_BIN_PATH/jq"
}

install_lazygit_user() {
    if [ -x "$LOCAL_BIN_PATH/lazygit" ] || command -v lazygit >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local version arch tmp archive
    version="$(__gh_api https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": *"v\K[^"]+')" || return 1
    arch="$(__github_arch)" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/lazygit.tar.gz"

    echo "Installing lazygit under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_linux_${arch}.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" lazygit || {
        rm -rf "$tmp"
        return 1
    }
    install -m 755 "$tmp/lazygit" "$LOCAL_BIN_PATH/lazygit" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
}

install_gh_user() {
    if [ -x "$LOCAL_BIN_PATH/gh" ] || command -v gh >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local version arch tmp archive dir
    version="$(__gh_api https://api.github.com/repos/cli/cli/releases/latest | grep -Po '"tag_name": *"v\K[^"]+')" || return 1
    arch="$(__deb_arch)" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/gh.tar.gz"
    dir="gh_${version}_linux_${arch}"

    echo "Installing gh under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/cli/cli/releases/download/v${version}/${dir}.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" "$dir/bin/gh" || {
        rm -rf "$tmp"
        return 1
    }
    install -m 755 "$tmp/$dir/bin/gh" "$LOCAL_BIN_PATH/gh" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
}

# gh-dash (`git pr`) is a gh extension, so gh keeps it under its own data dir.
# The full URL pins github.com when gh's default host is an enterprise one, and
# GH_TOKEN is dropped because a token for another host gets 401 on the release
# lookup; the repo is public, so no auth is needed.
install_gh_dash_user() {
    local gh
    gh="$(command -v gh || echo "$LOCAL_BIN_PATH/gh")"
    if [ ! -x "$gh" ]; then
        echo "gh is unavailable. Skipping gh-dash."
        return 0
    fi
    # Here-string, not a pipe: under pipefail an early grep exit could fail it.
    grep -q '^gh dash[[:space:]]' <<<"$("$gh" extension list 2>/dev/null)" && return 0

    echo "Installing gh-dash as a gh extension ..."
    env -u GH_TOKEN "$gh" extension install https://github.com/dlvhdr/gh-dash
}

install_lazydocker_user() {
    if [ -x "$LOCAL_BIN_PATH/lazydocker" ] || command -v lazydocker >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local version arch tmp archive
    version="$(__gh_api https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep -Po '"tag_name": *"v\K[^"]+')" || return 1
    arch="$(__github_arch)" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/lazydocker.tar.gz"

    echo "Installing lazydocker under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${arch}.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" lazydocker || {
        rm -rf "$tmp"
        return 1
    }
    install -m 755 "$tmp/lazydocker" "$LOCAL_BIN_PATH/lazydocker" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
}

install_delta_user() {
    if [ -x "$LOCAL_BIN_PATH/delta" ] || command -v delta >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local version arch tmp archive dir
    version="$(__gh_api https://api.github.com/repos/dandavison/delta/releases/latest | grep -Po '"tag_name": *"\K[^"]+')" || return 1
    arch="$(__gnu_arch)" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/delta.tar.gz"
    dir="delta-${version}-${arch}"

    echo "Installing delta under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/dandavison/delta/releases/download/${version}/${dir}.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" || {
        rm -rf "$tmp"
        return 1
    }
    install -m 755 "$tmp/$dir/delta" "$LOCAL_BIN_PATH/delta" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
}

install_gdu_user() {
    if [ -x "$LOCAL_BIN_PATH/gdu" ] || command -v gdu >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local arch tmp archive bin
    arch="$(__deb_arch)" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/gdu.tgz"
    bin="gdu_linux_${arch}"

    echo "Installing gdu under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/dundee/gdu/releases/latest/download/gdu_linux_${arch}.tgz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" || {
        rm -rf "$tmp"
        return 1
    }
    install -m 755 "$tmp/$bin" "$LOCAL_BIN_PATH/gdu" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
}

install_up_user() {
    if [ -x "$LOCAL_BIN_PATH/up" ] || command -v up >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    echo "Installing up under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$LOCAL_BIN_PATH/up" \
        https://github.com/akavel/up/releases/latest/download/up || return 1
    chmod 755 "$LOCAL_BIN_PATH/up"
}

# Clone fzf even when the host has its own fzf: Vim and Neovim load the fzf
# Vim plugin from this clone (no plugin manager installs it), and env.bash
# puts its binary ahead of the host one.
# --bin only: without it the installer writes its own fzf.bash into $HOME, or
# with --xdg over ~/.config/fzf/fzf.bash, which is this repo's file.
# An existing clone without the binary (its installer failed to download it)
# gets `install --bin` again instead of counting as installed.
install_fzf_user() {
    local dir="$LOCAL_OPT_PATH/fzf"
    [ -x "$dir/bin/fzf" ] && return 0

    if [ ! -e "$dir/.git" ]; then
        if ! command -v git >/dev/null 2>&1; then
            echo "git is unavailable. Skipping fzf."
            return 0
        fi
        echo "Installing fzf under $dir ..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "$dir" || return 1
    fi
    "$dir/install" --bin || return 1
}

# Separate from install_fzf_user: that one returns early once the fzf binary
# exists, which would skip this clone on hosts that already have it.
install_fzf_tab_completion_user() {
    local dir="$LOCAL_OPT_PATH/fzf-tab-completion"
    [ -d "$dir" ] && return 0
    if ! command -v git >/dev/null 2>&1; then
        echo "git is unavailable. Skipping fzf-tab-completion."
        return 0
    fi
    echo "Installing fzf-tab-completion under $dir ..."
    git clone --depth 1 https://github.com/lincheney/fzf-tab-completion "$dir"
}

# pynvim goes into a dedicated venv: `pip install --user` is refused on
# PEP 668 "externally managed" system Pythons (Ubuntu 24.04+). init.vim points
# g:python3_host_prog at this venv's python (stdpath('data') .. '/venv').
install_pynvim_user() {
    local venv="$DATA/nvim/venv"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is unavailable. Skipping pynvim."
        return 0
    fi

    if [ ! -x "$venv/bin/python" ]; then
        echo "Creating nvim python venv at $venv ..."
        python3 -m venv "$venv" || {
            echo "python3 -m venv failed (install python3-venv). Skipping pynvim." >&2
            return 0
        }
    fi
    echo "Installing pynvim into $venv ..."
    "$venv/bin/python" -m pip install --upgrade pynvim
}

install_clangd_user() {
    if [ -x "$LOCAL_BIN_PATH/clangd" ] || command -v clangd >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd unzip || return 1

    case "$(uname -m)" in
        x86_64|amd64) ;;
        *) echo "clangd prebuilt is x86_64-only. Skipping clangd on $(uname -m)."; return 0 ;;
    esac

    local version tmp archive dir
    version="$(__gh_api https://api.github.com/repos/clangd/clangd/releases/latest | grep -Po '"tag_name": *"\K[^"]+')" || return 1
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/clangd.zip"
    dir="clangd_${version}"

    echo "Installing clangd ${version} under $LOCAL_OPT_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/clangd/clangd/releases/download/${version}/clangd-linux-${version}.zip" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "${LOCAL_OPT_PATH:?}/$dir"
    unzip -q "$archive" -d "$LOCAL_OPT_PATH" || {
        rm -rf "$tmp"
        return 1
    }
    __ln_rel "$LOCAL_OPT_PATH/$dir/bin/clangd" "$LOCAL_BIN_PATH/clangd" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
    echo "Installed: $LOCAL_BIN_PATH/clangd"
}

install_btop_user() {
    if [ -x "$LOCAL_BIN_PATH/btop" ] || command -v btop >/dev/null 2>&1; then
        __bs_relink "$LOCAL_OPT_PATH/btop/bin/btop" "$LOCAL_BIN_PATH/btop"
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    local march tmp archive
    case "$(uname -m)" in
        x86_64|amd64) march="x86_64" ;;
        aarch64|arm64) march="aarch64" ;;
        *) echo "Unsupported CPU architecture for btop: $(uname -m)" >&2; return 1 ;;
    esac
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/btop.tar.gz"

    echo "Installing btop under $LOCAL_OPT_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/aristocratos/btop/releases/latest/download/btop-${march}-unknown-linux-musl.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$LOCAL_OPT_PATH/btop"
    tar -C "$LOCAL_OPT_PATH" -xzf "$archive" || {
        rm -rf "$tmp"
        return 1
    }
    __ln_rel "$LOCAL_OPT_PATH/btop/bin/btop" "$LOCAL_BIN_PATH/btop" || {
        rm -rf "$tmp"
        return 1
    }
    if [ -d "$LOCAL_OPT_PATH/btop/themes" ]; then
        mkdir -p "$CFG/btop/themes"
        cp -rf "$LOCAL_OPT_PATH/btop/themes/." "$CFG/btop/themes/" 2>/dev/null || true
    fi
    rm -rf "$tmp"
    echo "Installed: $LOCAL_BIN_PATH/btop"
}

install_nnn_user() {
    if [ -x "$LOCAL_BIN_PATH/nnn" ] || command -v nnn >/dev/null 2>&1; then
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd tar || return 1

    case "$(uname -m)" in
        x86_64|amd64) ;;
        *) echo "nnn static build is x86_64-only. Skipping nnn on $(uname -m)."; return 0 ;;
    esac

    local tag version tmp archive bin f
    tag="$(__gh_api https://api.github.com/repos/jarun/nnn/releases/latest | grep -Po '"tag_name": *"\K[^"]+')" || return 1
    version="${tag#v}"
    tmp="$(mktemp -d)" || return 1
    archive="$tmp/nnn.tar.gz"

    echo "Installing nnn ${version} under $LOCAL_BIN_PATH ..."
    curl -fL --retry 3 -o "$archive" \
        "https://github.com/jarun/nnn/releases/download/${tag}/nnn-static-${version}.x86_64.tar.gz" || {
        rm -rf "$tmp"
        return 1
    }
    tar -C "$tmp" -xzf "$archive" || {
        rm -rf "$tmp"
        return 1
    }
    bin=""
    for f in "$tmp"/nnn*; do
        [ -f "$f" ] && bin="$f" && break
    done
    if [ -z "$bin" ]; then
        echo "Could not find nnn binary in archive." >&2
        rm -rf "$tmp"
        return 1
    fi
    install -m 755 "$bin" "$LOCAL_BIN_PATH/nnn" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
    echo "Installed: $LOCAL_BIN_PATH/nnn"
}

install_tmux_user() {
    # Static, dependency-free tmux from the community build-static-tmux project.
    local march tag tmp gz new dest="$LOCAL_OPT_PATH/tmux/bin"
    case "$(uname -m)" in
        x86_64|amd64) march="amd64"; tag="$TMUX_STATIC_TAG" ;;
        aarch64|arm64) march="arm64"; tag="$TMUX_STATIC_TAG_ARM64" ;;
        *) echo "Unsupported CPU architecture for static tmux: $(uname -m)" >&2; return 1 ;;
    esac

    if [ "${1:-}" != "--force" ] && [ -x "$dest/tmux" ] \
       && [ "$("$dest/tmux" -V 2>/dev/null)" = "tmux ${tag#v}" ]; then
        __bs_relink "$dest/tmux" "$LOCAL_BIN_PATH/tmux"
        return 0
    fi

    __require_cmd curl || return 1
    __require_cmd gzip || return 1

    tmp="$(mktemp -d)" || return 1
    gz="$tmp/tmux.gz"

    echo "Installing static tmux ${tag} (community build) under $dest ..."
    if ! curl -fL --retry 3 -o "$gz" \
            "https://github.com/mjakob-gh/build-static-tmux/releases/download/${tag}/tmux.linux-${march}.stripped.gz" \
        || ! gzip -dc "$gz" > "$tmp/tmux" \
        || ! chmod 755 "$tmp/tmux" \
        || ! "$tmp/tmux" -V >/dev/null 2>&1; then
        echo "tmux download/verify failed; existing install left untouched." >&2
        rm -rf "$tmp"
        return 1
    fi
    # Staged beside the target and renamed over it: install unlinks the old
    # name before copying, so a client started mid-copy, or any client after
    # a failed copy, would find no usable tmux. Running servers keep their
    # inode either way.
    new="$dest/.tmux.new.$$"
    if ! mkdir -p "$dest" "$LOCAL_BIN_PATH" \
        || ! install -m 755 "$tmp/tmux" "$new" \
        || ! "$new" -V >/dev/null 2>&1 \
        || ! mv -f "$new" "$dest/tmux"; then
        echo "tmux install failed; existing install left untouched." >&2
        rm -f "$new"
        rm -rf "$tmp"
        return 1
    fi
    __ln_rel "$dest/tmux" "$LOCAL_BIN_PATH/tmux" || {
        rm -rf "$tmp"
        return 1
    }
    rm -rf "$tmp"
    echo "Installed: $dest/tmux ($("$dest/tmux" -V))"
    echo "New tmux servers use this binary; running servers keep theirs until they exit."
}

# Shared clone-or-update helper: bell-bash and noti-bash into $LOCAL_OPT_PATH,
# the agents harness into ~/agents (see __bs_agents). bell/noti are only cloned
# or updated, never installed with their own installers: env.bash, common.bash
# and common.conf own their PATH, shell, tmux and Claude Code wiring.
__clone_or_pull() {
    local url="$1" dst="$2" clone_flags
    # $3 = extra `git clone` flags. Default to a shallow clone; pass "" for a
    # full clone (repos you commit to, e.g. the agents harness, need history).
    if [ $# -ge 3 ]; then clone_flags="$3"; else clone_flags="--depth 1"; fi
    if [ -d "$dst/.git" ]; then
        git -C "$dst" pull --ff-only || true
    else
        echo "Cloning $(basename "$dst") into $dst ..."
        # Word-split $clone_flags into git args.
        # shellcheck disable=SC2086
        git clone $clone_flags "$url" "$dst" || return 1
    fi
}

install_bell_bash_user() {
    __require_cmd git || return 1
    __clone_or_pull https://github.com/tot0rokr/bell-bash.git "$LOCAL_OPT_PATH/bell-bash"
}

install_noti_bash_user() {
    __require_cmd git || return 1
    __clone_or_pull https://github.com/tot0rokr/noti-bash.git "$LOCAL_OPT_PATH/noti-bash"
}

# claude-account-switcher runs Claude Code across several accounts and rotates
# to the next one when the active account nears its usage limit. Unlike
# bell/noti we DO run its installer: it owns pieces we don't track here (the
# ~/.claude-accounts store and the statusLine sensor that does the switching,
# chained onto whatever statusLine is already configured).
install_claude_switcher_user() {
    __require_cmd git || return 1
    local repo="$LOCAL_OPT_PATH/claude-account-switcher"
    __clone_or_pull https://github.com/tot0rokr/claude-account-switcher.git "$repo" || return 1
    # Adopt the logged-in account as the first slot, but only on a first install:
    # with slots already stored this would duplicate whichever one is active.
    local seed=""
    if [ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" ] \
       && ! grep -qE '^[^[:space:]#]' "${CLAUDE_AUTO_HOME:-$HOME/.claude-accounts}/config/accounts.list" 2>/dev/null; then
        seed="--seed-current"
    fi
    # $seed is either empty or a single flag.
    # shellcheck disable=SC2086
    bash "$repo/install.sh" $seed
}

# Install the Claude Code CLI into the user account -- no root. The official
# installer downloads a native binary to ~/.claude/downloads, verifies its
# checksum, then runs `claude install`, which drops a launcher at
# ~/.local/bin/claude symlinked to ~/.local/share/claude/versions/<v> and wires
# shell integration. Everything lands under $HOME (matches $LOCAL_BIN_PATH), so
# no sudo. Skipped when `claude` is already on PATH so re-running is a no-op.
install_claude_code_user() {
    if command -v claude >/dev/null 2>&1; then
        echo "claude already installed ($(command -v claude)); skipping."
        return 0
    fi
    __require_cmd curl || return 1
    echo "Installing Claude Code CLI (user-local, no root) ..."
    curl -fsSL https://claude.ai/install.sh | bash || {
        echo "Claude Code install failed (see output above)." >&2
        return 1
    }
}

show_user_only_notes() {
    cat <<'NOTES'

User-only notes:
- `dotfiles bootstrap user` never runs sudo/apt/snap/dpkg. Programs go to ~/.local/opt and ~/.local/bin; rustup, cargo and fnm keep their data under ${XDG_DATA_HOME:-~/.local/share}.
- It also installs clangd, btop, nnn, and tmux from prebuilt/static downloads (no root needed; x86_64 mainly, see per-tool guards).
- It clones (or pulls) bell-bash and noti-bash into ~/.local/opt; the `noti` CLI and `bell`/`bell-send` come from these clones. It never runs their installers and never writes ~/.claude: ~/.config/bash/env.bash puts them on PATH, ~/.config/bash/common.bash hands both clones to Claude Code through its claude() wrapper (--plugin-dir, --settings), and ~/.config/tmux/common.conf wires tmux. Update the tools with `git -C ~/.local/opt/<repo> pull`.
- It installs claude-account-switcher into ~/.local/opt and runs its installer (this one owns state we don't track: the ~/.claude-accounts store and the statusLine sensor that switches accounts). The claude() wrapper defined in ~/.config/bash/common.bash already launches `claude-auto` when it is installed, so do not add the `alias claude=claude-auto` its installer may suggest: the alias shadows the wrapper and drops its plugin arguments. Add accounts with `claude-auto login <name>` and check them with `claude-auto status`.
- It installs the Claude Code CLI into ~/.local/bin when `claude` is missing (user-local, no root).
- It installs gh-dash (`git pr`) as a gh extension. Upgrade it with `env -u GH_TOKEN gh extension upgrade dash`; a GH_TOKEN meant for another host makes the upgrade fail.
- Tools that genuinely need root are NOT installed here. Run `dotfiles bootstrap system` (sudo apt) for: git, curl, wget, gcc/make (build-essential), openssh-server, python3-venv, ruby-full, universal-ctags, cscope, unzip, wezterm.
- Some cargo installs may fail if system build tools are missing; run `dotfiles bootstrap system` first if so.
- To keep NOTI_WEBHOOK private, put it in ~/.config/noti/webhook with chmod 600 instead of hard-coding it in ~/.bashrc.
- The agents harness (shared Claude/Codex/OpenCode/Gemini config) is NOT installed here; run `dotfiles bootstrap agents` for it.
NOTES
}

__bs_user_step() {
    local force=$2
    case $1 in
        neovim) install_neovim_user ${force:+--force} ;;
        fnm) install_fnm_user ;;
        vim-plug) install_vim_plug_user ;;
        rustup) install_rustup_user ;;
        cargo-tools) __bs_cargo_tools ;;
        tldr)
            if command -v tldr >/dev/null 2>&1; then
                tldr --seed-config || true
                tldr -u || true
            fi
            ;;
        starship) install_starship_user ;;
        jq) install_jq_user ;;
        lazygit) install_lazygit_user ;;
        gh) install_gh_user ;;
        gh-dash) install_gh_dash_user ;;
        lazydocker) install_lazydocker_user ;;
        delta) install_delta_user ;;
        gdu) install_gdu_user ;;
        up) install_up_user ;;
        fzf) install_fzf_user ;;
        fzf-tab-completion) install_fzf_tab_completion_user ;;
        pynvim) install_pynvim_user ;;
        clangd) install_clangd_user ;;
        btop) install_btop_user ;;
        nnn) install_nnn_user ;;
        tmux) install_tmux_user ${force:+--force} ;;
        bell) install_bell_bash_user ;;
        noti) install_noti_bash_user ;;
        switcher) install_claude_switcher_user ;;
        claude) install_claude_code_user ;;
    esac
}

# --only and --force are an internal and test aid: they replace calling single
# installer functions from an interactive shell.
__bs_user() {
    local only="" force="" name
    local -a names=() failed=()
    while [ $# -gt 0 ]; do
        case $1 in
            --only)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    __bs_usage >&2
                    return 2
                fi
                only=$2
                shift 2
                ;;
            --force) force=1; shift ;;
            -h|--help)
                __bs_usage
                return 0
                ;;
            *) __bs_usage >&2; return 2 ;;
        esac
    done
    if [ -n "$only" ]; then
        IFS=, read -r -a names <<<"$only"
        for name in "${names[@]}"; do
            case " ${__bs_user_steps[*]} " in
                *" $name "*) ;;
                *)
                    echo "dotfiles bootstrap user: unknown name '$name' (known: ${__bs_user_steps[*]})" >&2
                    return 2
                    ;;
            esac
        done
    fi

    __bs_init || return 1

    if __bs_relocation_pending >&2; then
        echo "dotfiles bootstrap user: the tools above are not relocated yet; run \`dotfiles migrate tools\` first." >&2
        return 5
    fi
    if __legacy_signals >&2; then
        echo "dotfiles bootstrap user: a legacy dotfiles layout is installed; run \`dotfiles uninstall-legacy\` first." >&2
        return 4
    fi

    # shellcheck source=/dev/null
    if [ -r /etc/os-release ] && ! (. /etc/os-release && [ "${ID:-}" = ubuntu ]); then
        echo "This bootstrap was tuned for Ubuntu, but it will continue with user-local installs only."
    fi

    __require_cmd curl || {
        echo "Install curl first or download the tools manually. No sudo command was run."
        return 1
    }

    for name in "${__bs_user_steps[@]}"; do
        if [ -n "$only" ]; then
            case ",$only," in
                *",$name,"*) ;;
                *) continue ;;
            esac
        fi
        __bs_user_step "$name" "$force" || failed+=("$name")
    done

    [ -n "$only" ] || show_user_only_notes

    if [ ${#failed[@]} -gt 0 ]; then
        echo "dotfiles bootstrap user: failed: ${failed[*]}" >&2
        return 1
    fi
}

# Install the agents harness (shared config/skills/memory/MCP for Claude Code,
# Codex, OpenCode and Gemini). Its own kind, not folded into `user`, because it
# OWNS the home config dirs (~/.claude, ~/.codex, ~/.config/opencode,
# ~/.gemini, ~/.agents) and should be explicit opt-in. Clones to the canonical
# ~/agents path (install.py, doctor.sh and the home symlinks all hard-code it)
# as a FULL clone -- you commit to it (shared memory pool, config), so history
# must be intact. install.py backs up any pre-existing real config dir to
# <path>.bak.<timestamp> before symlinking it into ~/agents, is idempotent (a
# no-op once linked), and rolls back on error; doctor.sh verifies the result.
__bs_agents() {
    __require_cmd git || return 1
    __require_cmd python3 || return 1
    # Make sure the Claude Code CLI itself exists before wiring its config;
    # no-op if already installed.
    install_claude_code_user || return 1
    __clone_or_pull https://github.com/tot0rokr/agents.git "$HOME/agents" "" || return 1
    echo "Installing agents harness symlinks (python3 scripts/install.py) ..."
    python3 "$HOME/agents/scripts/install.py" || {
        echo "agents install.py failed (see output above); skipping doctor." >&2
        return 1
    }
    bash "$HOME/agents/scripts/doctor.sh" || \
        echo "agents doctor.sh reported issues; review the output above." >&2
}

# The system/root packages that the user-local path cannot provide. The only
# kind that uses sudo/apt; it never runs automatically.
__bs_system() {
    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo is required for \`dotfiles bootstrap system\`. Aborting." >&2
        return 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "\`dotfiles bootstrap system\` currently supports Debian/Ubuntu (apt) only." >&2
        return 1
    fi

    echo "Installing system packages with sudo apt-get ..."
    sudo apt-get update || return 1
    sudo apt-get install -y \
        ca-certificates gnupg \
        git curl wget \
        build-essential gcc make \
        openssh-server \
        python3 python3-venv python3-pip \
        ruby-full \
        universal-ctags cscope \
        unzip || return 1

    # wezterm is not in the default repos; add the official fury repo first.
    if ! command -v wezterm >/dev/null 2>&1; then
        echo "Adding WezTerm apt repository ..."
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg || return 1
        echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
        sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
        sudo apt-get update || return 1
        sudo apt-get install -y wezterm || return 1
    fi

    echo "System packages installed."
}

# Entry point of `dotfiles bootstrap`: bin/dotfiles passes the arguments that
# follow the subcommand name.
__bootstrap_main() {
    local kind=${1:-}
    [ $# -eq 0 ] || shift
    case $kind in
        user) __bs_user "$@" ;;
        system|agents)
            case ${1-} in
                -h|--help)
                    __bs_usage
                    return 0
                    ;;
            esac
            if [ $# -gt 0 ]; then
                __bs_usage >&2
                return 2
            fi
            __bs_init || return 1
            "__bs_$kind"
            ;;
        -h|--help) __bs_usage ;;
        *) __bs_usage >&2; return 2 ;;
    esac
}
