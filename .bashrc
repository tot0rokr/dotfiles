# ~/.bashrc - shell entry point
# Portable, shared config lives in ~/.bashrc.common (tracked in dotfiles).
# Add this machine's own settings and secrets directly below.

# If not running interactively, do not do anything.
case $- in
    *i*) ;;
      *) return ;;
esac

# Shared, dotfiles-tracked configuration.
if [ -f "$HOME/.bashrc.common" ]; then
    . "$HOME/.bashrc.common"
fi

# ============================================================
# Machine-specific settings below (edit per host)
# ============================================================
