# Setup fzf
# ---------
if [[ ! "$PATH" == */home/tot0ro/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/tot0ro/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/tot0ro/.fzf/shell/completion.bash" 2> /dev/null

# Key bindings
# ------------
source "/home/tot0ro/.fzf/shell/key-bindings.bash"
