#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ $DISPLAY ]] && shopt -s checkwinsize

PS1='[\u@\h \W]\$ '

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

# Load bashrc scripts from /etc/bash.bashrc.d
if test -d /etc/bash.bashrc.d/
then
    for profile in /etc/bash.bashrc.d/*.sh; do
        test -r "$profile" && . "$profile"
    done
    unset profile
fi
