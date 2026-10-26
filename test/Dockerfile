# Test images for the dotfiles, all tagged dotfiles-xdg-test:*. test/run.sh
# builds them from a clean context made of `git ls-files` plus .git, so
# ignored local files never reach the daemon. Stages:
#   base        ubuntu 24.04, test packages, user tester (1001), XDG-capable vim
#   tools-lite  `dotfiles bootstrap system` and part of `bootstrap user`
#   tools-full  the full `bootstrap user` and `bootstrap agents`
#   editor      nvim and vim plugins, treesitter parsers, coc extensions (TIER
#               picks the tools)
#   repo        the checkout at ~/.dotfiles, the test tree, a git baseline
#   repo-ro     the same checkout owned by root and read-only
#   tmux32      repo with the static tmux 3.2 build
# The tool stages copy only the four files the bootstrap needs, so editing
# the rest of the repo reuses them. The GitHub token reaches them only as the
# BuildKit secret gh_token.
# amd64 is pinned: some bootstrap tools ship x86_64 builds only.
ARG TIER=lite

FROM --platform=linux/amd64 ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        sudo ca-certificates git curl unzip xz-utils build-essential libncurses-dev \
        locales bsdutils fontconfig bash-completion expect lua5.4 strace procps \
 && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04's vim (9.1.0016) predates XDG support (9.1.0327).
ARG VIM_TAG=v9.1.1230
RUN curl -fsSL "https://github.com/vim/vim/archive/refs/tags/${VIM_TAG}.tar.gz" | tar -xz -C /tmp \
 && cd "/tmp/vim-${VIM_TAG#v}" \
 && ./configure --with-features=huge --prefix=/usr/local \
 && make -j"$(nproc)" \
 && make install \
 && cd / && rm -rf "/tmp/vim-${VIM_TAG#v}" \
 && /usr/local/bin/vim -es -i NONE -u NONE +'exe has("patch-9.1.0327") ? "qa!" : "cq"'

RUN useradd --create-home --uid 1001 --shell /bin/bash tester \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester \
 && chmod 0440 /etc/sudoers.d/tester \
 && install -d -o tester -g tester /opt/dotfiles-test /opt/dotfiles-test/build-checks \
        /opt/dotfiles-test/baseline
ENV USER=tester LESSHISTFILE=- GIT_PAGER=cat
USER tester
WORKDIR /home/tester
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

FROM base AS tools-lite
COPY bin/dotfiles /opt/dotfiles-bootstrap/bin/dotfiles
COPY lib/dotfiles/core.bash lib/dotfiles/bootstrap.bash /opt/dotfiles-bootstrap/lib/dotfiles/
COPY .config/bash/env.bash /opt/dotfiles-bootstrap/.config/bash/env.bash
COPY test/container/build/tools.sh /opt/dotfiles-test/build/tools.sh
RUN --mount=type=secret,id=gh_token,env=GH_TOKEN \
    bash /opt/dotfiles-test/build/tools.sh lite
RUN bash /opt/dotfiles-test/build/tools.sh extras

FROM tools-lite AS tools-full
# BuildKit would create the parents of the cache mounts as root.
RUN mkdir -p /home/tester/.local/share/cargo/registry /home/tester/.local/share/cargo/git
RUN --mount=type=secret,id=gh_token,env=GH_TOKEN \
    --mount=type=cache,id=dotfiles-xdg-cargo-registry,target=/home/tester/.local/share/cargo/registry,uid=1001,gid=1001 \
    --mount=type=cache,id=dotfiles-xdg-cargo-git,target=/home/tester/.local/share/cargo/git,uid=1001,gid=1001 \
    --mount=type=cache,id=dotfiles-xdg-cargo-target,target=/tmp/cargo-target,uid=1001,gid=1001 \
    CARGO_TARGET_DIR=/tmp/cargo-target bash /opt/dotfiles-test/build/tools.sh full

FROM tools-${TIER} AS editor
COPY --chown=tester:tester .config/nvim/ /opt/editor-cfg/nvim/
COPY --chown=tester:tester .config/vim/ /opt/editor-cfg/vim/
COPY test/container/build/editor.sh test/container/build/nvim-plugins.lua /opt/dotfiles-test/build/
RUN XDG_CONFIG_HOME=/opt/editor-cfg bash /opt/dotfiles-test/build/editor.sh

FROM editor AS repo
COPY --chown=tester:tester . /home/tester/.dotfiles
COPY test/container/ /opt/dotfiles-test/
# Stage the new files (this also proves .gitignore whitelists them), then
# record the state every scenario compares the checkout with (A09).
RUN cd /home/tester/.dotfiles \
 && git add -A \
 && git status --porcelain >/opt/dotfiles-test/baseline/status.txt \
 && git diff --cached | sha256sum >/opt/dotfiles-test/baseline/diff-cached.sha256 \
 && git ls-files -o -i --exclude-standard >/opt/dotfiles-test/baseline/ignored.txt
ENTRYPOINT ["bash", "/opt/dotfiles-test/entrypoint.sh"]

FROM repo AS repo-ro
USER root
RUN chown -R root:root /home/tester/.dotfiles && chmod -R a-w /home/tester/.dotfiles
USER tester

FROM repo AS tmux32
# 3.2 has no 3.2a static build; 3.2 already has source-file -F and #{d:...}.
RUN TMUX_STATIC_TAG=v3.2 /home/tester/.dotfiles/bin/dotfiles bootstrap user --only tmux --force \
 && test "$(/home/tester/.local/opt/tmux/bin/tmux -V)" = "tmux 3.2"
