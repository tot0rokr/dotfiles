# shellcheck shell=bash
# Stand-in for nvm.sh in a fabricated ~/.nvm (live-migration test): puts the
# default node on PATH, as nvm does when a shell starts.
NVM_DIR=${NVM_DIR:-$HOME/.nvm}
if read -r __t_nvm_version <"$NVM_DIR/alias/default"; then
    PATH="$NVM_DIR/versions/node/$__t_nvm_version/bin:$PATH"
fi
unset __t_nvm_version
