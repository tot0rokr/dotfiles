# Clean Ubuntu sandbox for testing the dotfiles bootstrap end to end.
# amd64 is pinned because bootstrap_user_tools installs a couple of x86_64-only
# tools (clangd, static nnn); the rest also work on arm64.
FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# A pristine ubuntu image has no sudo/git/curl/ca-certificates, but the bootstrap
# functions require them (bootstrap_system_tools needs sudo; bootstrap_user_tools
# needs curl; cloning needs git). Everything else the bootstrap installs itself.
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates git curl \
 && rm -rf /var/lib/apt/lists/*

# Run the bootstrap as a non-root user with passwordless sudo — the realistic
# "regular user on a fresh host" scenario the dotfiles target.
RUN useradd --create-home --shell /bin/bash tester \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 0440 /etc/sudoers.d/tester

COPY container/ /opt/dotfiles-test/
RUN chmod +x /opt/dotfiles-test/*.sh

USER tester
WORKDIR /home/tester
ENTRYPOINT ["/opt/dotfiles-test/entrypoint.sh"]
