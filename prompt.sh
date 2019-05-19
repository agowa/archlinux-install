# Configure prompt to show more information

# Git Repository status
function parse_git_dirty {
    status=`git status 2>&1 | tee`
    dirty=`echo -n "${status}" 2> /dev/null | grep "modified:" &> /dev/null; printf "$?"`
    untracked=`echo -n "${status}" 2> /dev/null | grep "Untracked files" &> /dev/null; printf "$?"`
    ahead=`echo -n "${status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; printf "$?"`
    newfile=`echo -n "${status}" 2> /dev/null | grep "new file:" &> /dev/null; printf "$?"`
    renamed=`echo -n "${status}" 2> /dev/null | grep "renamed:" &> /dev/null; printf "$?"`
    deleted=`echo -n "${status}" 2> /dev/null | grep "deleted:" &> /dev/null; printf "$?"`
    bits=''
    if [ "${renamed}" == "0" ]; then
            bits=">${bits}"
    fi
    if [ "${ahead}" == "0" ]; then
            bits="*${bits}"
    fi
    if [ "${newfile}" == "0" ]; then
            bits="+${bits}"
    fi
    if [ "${untracked}" == "0" ]; then
            bits="?${bits}"
    fi
    if [ "${deleted}" == "0" ]; then
            bits="x${bits}"
    fi
    if [ "${dirty}" == "0" ]; then
            bits="!${bits}"
    fi
    if [ ! "${bits}" == "" ]; then
            printf "${bits}"
    else
            printf ""
    fi
}

# Last exit code
function nonzero_return() {
    RETVAL=$?
    [ $RETVAL -ne 0 ] && printf "$RETVAL "
}

export PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'nonzero_return; parse_git_dirty'
