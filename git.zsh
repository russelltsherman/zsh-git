export PATH=${0:A:h}/bin:$PATH

__git_log() {
  echo "-----> $*"
}

__git_merge_locally() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  __git_log "Merging $remote/$branch locally..."
  git fetch "$remote" | __git_prefixed
  git merge --no-edit "$remote/$branch" | __git_prefixed
}

__git_prefixed() {
  sed -e "s/^/       /"
}

__git_prune() {
  # shellcheck disable=SC2039
  local remote
  remote="$1"
  __git_log "Pruning $remote..."
  git remote prune "$remote" | __git_prefixed
}

__git_push_to_fork() {
  # shellcheck disable=SC2039
  local branch remote
  remote="$1"
  branch="$2"
  if ! [ "$remote" = "origin" ]; then
    __git_log "Pushing it to origin/$branch..."
    git push origin "$branch" | __git_prefixed
  fi
}

__git_remote_url() {
  # shellcheck disable=SC2039
  local fork remote current
  fork="$1"
  if ! git config --get remote.origin.url > /dev/null 2>&1; then
    echo "A remote called 'origin' doesn't exist. Aborting." >&2
    return 1
  fi
  remote="$(git config --get remote.origin.url)"
  current="$(echo "$remote" | sed -e 's/.*github.com\://' -e 's/\/.*//')"
  echo "$remote" | sed -e "s/$current/$fork/"
}

#
# Functions
#

# The name of the current branch
# Back-compatibility wrapper for when this was defined here in
# the plugin, before being pulled in to core lib/git.zsh as git_current_branch()
# to fix the core -> git plugin dependency.
current_branch() {
  git_current_branch
}

# Pretty log messages
_git_log_prettily(){
    if ! [ -z $1 ]; then
        git log --pretty=$1
    fi
}
compdef _git _git_log_prettily=git-log

# Warn if the current branch is a WIP
work_in_progress() {
    if $(git log -n 1 2>/dev/null | grep -q -c "\-\-wip\-\-"); then
        echo "WIP!!"
    fi
}

# Check if main exists and use instead of master
git_main_branch() {
    local branch
    for branch in main trunk; do
    if command git show-ref -q --verify refs/heads/$branch; then
        echo $branch
        return
    fi
    done
    echo master
}

gdnolock() {
    git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
}
compdef _git gdnolock=git-diff

gdv() { 
    git diff -w "$@" | view - 
}
compdef _git gdv=git-diff

ggf() {
    [[ "$#" != 1 ]] && local b="$(git_current_branch)"
    git push --force origin "${b:=$1}"
}
compdef _git ggf=git-checkout
ggfl() {
    [[ "$#" != 1 ]] && local b="$(git_current_branch)"
    git push --force-with-lease origin "${b:=$1}"
}
compdef _git ggfl=git-checkout

ggl() {
    if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
    then
        git pull origin "${*}"
    else
    [[ "$#" == 0 ]] && local b="$(git_current_branch)"
    git pull origin "${b:=$1}"
    fi
}
compdef _git ggl=git-checkout

ggp() {
    if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
    then
        git push origin "${*}"
    else
    [[ "$#" == 0 ]] && local b="$(git_current_branch)"
    git push origin "${b:=$1}"
  fi
}
compdef _git ggp=git-checkout

ggpnp() {
    if [[ "$#" == 0 ]]
    then
        ggl && ggp
    else
        ggl "${*}" && ggp "${*}"
    fi
}
compdef _git ggpnp=git-checkout

ggu() {
    [[ "$#" != 1 ]] && local b="$(git_current_branch)"
    git pull --rebase origin "${b:=$1}"
}
compdef _git ggu=git-checkout

grename() {
    if [[ -z "$1" || -z "$2" ]]
    then
        echo "Usage: $0 old_branch new_branch"
        return 1
    fi

    # Rename branch locally
    git branch -m "$1" "$2"
    # Rename branch in origin remote
    if git push origin :"$1"
    then
        git push --set-upstream origin "$2"
    fi
}

# ------------------------------------------------------------------------------
# Impromptu Prompt Segment Function
# ------------------------------------------------------------------------------
impromptu::prompt::git() {
  IMPROMPTU_GIT_COLOR="white"
  IMPROMPTU_GIT_SHOW="true"
  IMPROMPTU_GIT_PREFIX=""
  IMPROMPTU_GIT_SUFFIX=" "
  IMPROMPTU_GIT_SYMBOL=""
  IMPROMPTU_GIT_STATUS_PREFIX=" ["
  IMPROMPTU_GIT_STATUS_SUFFIX="]"
  IMPROMPTU_GIT_STATUS_COLOR="red"
  IMPROMPTU_GIT_STATUS_UNTRACKED="?"
  IMPROMPTU_GIT_STATUS_ADDED="+"
  IMPROMPTU_GIT_STATUS_MODIFIED="!"
  IMPROMPTU_GIT_STATUS_RENAMED="»"
  IMPROMPTU_GIT_STATUS_DELETED="✘"
  IMPROMPTU_GIT_STATUS_STASHED="$"
  IMPROMPTU_GIT_STATUS_UNMERGED="="
  IMPROMPTU_GIT_STATUS_AHEAD="⇡"
  IMPROMPTU_GIT_STATUS_BEHIND="⇣"
  IMPROMPTU_GIT_STATUS_DIVERGED="⇕"

  chk::git || return

  [[ "$IMPROMPTU_GIT_SHOW" == "true" ]] || return
  
  local git_branch="$vcs_info_msg_0_"
  [[ -z "$git_branch" ]] && return

  git_current_branch="${git_current_branch#heads/}"
  git_current_branch="${git_current_branch/.../}"

  local INDEX 
  local git_status

  INDEX=$(command git status --porcelain -b 2> /dev/null)

  # Check for untracked files
  if $(echo "$INDEX" | command grep -E '^\?\? ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_UNTRACKED$git_status"
  fi

  # Check for staged files
  if $(echo "$INDEX" | command grep '^A[ MDAU] ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_ADDED$git_status"
  elif $(echo "$INDEX" | command grep '^M[ MD] ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_ADDED$git_status"
  elif $(echo "$INDEX" | command grep '^UA' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_ADDED$git_status"
  fi

  # Check for modified files
  if $(echo "$INDEX" | command grep '^[ MARC]M ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_MODIFIED$git_status"
  fi

  # Check for renamed files
  if $(echo "$INDEX" | command grep '^R[ MD] ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_RENAMED$git_status"
  fi

  # Check for deleted files
  if $(echo "$INDEX" | command grep '^[MARCDU ]D ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_DELETED$git_status"
  elif $(echo "$INDEX" | command grep '^D[ UM] ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_DELETED$git_status"
  fi

  # Check for stashes
  if $(command git rev-parse --verify refs/stash >/dev/null 2>&1)
  then
    git_status="$IMPROMPTU_GIT_STATUS_STASHED$git_status"
  fi

  # Check for unmerged files
  if $(echo "$INDEX" | command grep '^U[UDA] ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_UNMERGED$git_status"
  elif $(echo "$INDEX" | command grep '^AA ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_UNMERGED$git_status"
  elif $(echo "$INDEX" | command grep '^DD ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_UNMERGED$git_status"
  elif $(echo "$INDEX" | command grep '^[DA]U ' &> /dev/null)
  then
    git_status="$IMPROMPTU_GIT_STATUS_UNMERGED$git_status"
  fi

  # Check whether branch is ahead
  local is_ahead=false
  if $(echo "$INDEX" | command grep '^## [^ ]\+ .*ahead' &> /dev/null)
  then
    is_ahead=true
  fi

  # Check whether branch is behind
  local is_behind=false
  if $(echo "$INDEX" | command grep '^## [^ ]\+ .*behind' &> /dev/null)
  then
    is_behind=true
  fi

  # Check wheather branch has diverged
  if [[ "$is_ahead" == true && "$is_behind" == true ]]
  then
    git_status="$IMPROMPTU_GIT_STATUS_DIVERGED$git_status"
  else
    [[ "$is_ahead" == true ]] && git_status="$IMPROMPTU_GIT_STATUS_AHEAD$git_status"
    [[ "$is_behind" == true ]] && git_status="$IMPROMPTU_GIT_STATUS_BEHIND$git_status"
  fi

  impromptu::segment "$IMPROMPTU_GIT_COLOR" \
    "${IMPROMPTU_GIT_PREFIX} ${IMPROMPTU_GIT_SYMBOL} ${git_branch} ${git_status}${IMPROMPTU_GIT_SUFFIX}"
}
