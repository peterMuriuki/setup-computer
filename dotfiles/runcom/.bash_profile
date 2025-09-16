# If not running interactively, don't do anything

[ -z "$PS1" ] && return

# Resolve DOTFILES_DIR (assuming ~/.dotfiles on distros without readlink and/or $BASH_SOURCE/$0)
CURRENT_SCRIPT=$BASH_SOURCE
SCRIPT_PATH=$(readlink -f $CURRENT_SCRIPT)
DOTFILES_DIR="$(dirname $(dirname $SCRIPT_PATH))"
# echo $SCRIPT_PATH
# echo $DOTFILES_DIR

# if [[ -n $CURRENT_SCRIPT && -x readlink ]]; then
#   SCRIPT_PATH=$(readlink -n $CURRENT_SCRIPT)
#   DOTFILES_DIR="${PWD}/$(dirname $(dirname $SCRIPT_PATH))"
#   echo $SCRIPT_PATH
#   echo $DOTFILES_DIR
# elif [ -d "$HOME/.dotfiles" ]; then
#   DOTFILES_DIR="$HOME/.dotfiles"
# else
#   echo "Unable to find dotfiles, exiting."
#   return
# fi

# Make utilities available

PATH="$DOTFILES_DIR/bin:$PATH"

# Source the dotfiles (order matters)

for DOTFILE in "$DOTFILES_DIR"/system/.{env,alias,prompt}; do
  . "$DOTFILE"
done

# Set LSCOLORS

# eval "$(dircolors -b "$DOTFILES_DIR"/system/.dir_colors)"

# Wrap up

unset CURRENT_SCRIPT SCRIPT_PATH DOTFILE
export DOTFILES_DIR
. "$HOME/.local/share/../bin/env"
