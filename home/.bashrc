#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# /usr/local/bin/vi -> /usr/bin/nvim
export VISUAL=vi
export EDITOR=vi

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

alias ls='ls --color=auto'
alias grep='grep --color=auto'

PMT_USER_HOST='\[\033[1;32m\]\u@\h'
PMT_PWD='\[\033[1;36m\]\w'
PMT_GIT_BRANCH='\[\033[1;33m\]$(__git_ps1 "[%s]")'
PMT_PROMPT='\[\033[1;37m\]\$'
PMT_CLEAR='\[\033[00m\]'
PS1="${PMT_USER_HOST} ${PMT_PWD} ${PMT_GIT_BRANCH}\n${PMT_PROMPT}${PMT_CLEAR} "

# Created by `pipx` on 2025-06-24 15:05:34
export PATH="$PATH:/home/bob/.local/bin"

eval "$(fzf --bash)"
. /usr/share/git/git-prompt.sh

