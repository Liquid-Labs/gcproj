#!/usr/bin/env bash

# http://linuxcommand.org/lc3_adv_tput.php
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
purple=`tput setaf 5`
cyan=`tput setaf 6`
white=`tput setaf 7`

bold=`tput bold`
red_b="${red}${bold}"
green_b="${green}${bold}"
yellow_b="${yellow}${bold}"
blue_b="${blue}${bold}"
purple_b="${purple}${bold}"
cyan_b="${cyan}${bold}"
white_b="${white}${bold}"

underline=`tput smul`
red_u="${red}${underline}"
green_u="${green}${underline}"
yellow_u="${yellow}${underline}"
blue_u="${blue}${underline}"
purple_u="${purple}${underline}"
cyan_u="${cyan}${underline}"
white_u="${white}${underline}"

red_bu="${red}${bold}${underline}"
green_bu="${green}${bold}${underline}"
yellow_bu="${yellow}${bold}${underline}"
blue_bu="${blue}${bold}${underline}"
purple_bu="${purple}${bold}${underline}"
cyan_bu="${cyan}${bold}${underline}"
white_bu="${white}${bold}${underline}"

reset=`tput sgr0`
list-add-item() {
  local LIST_VAR="${1}"; shift
  while (( $# > 0 )); do
    local ITEM
    ITEM="${1}"; shift
    # TODO: enforce no newlines in item

    if [[ -n "$ITEM" ]]; then
      if [[ -z "${!LIST_VAR:-}" ]]; then
        eval $LIST_VAR='"$ITEM"'
      else
        # echo $LIST_VAR='"${!LIST_VAR}"$'"'"'\n'"'"'"${ITEM}"'
        eval $LIST_VAR='"${!LIST_VAR:-}"$'"'"'\n'"'"'"${ITEM}"'
      fi
    fi
  done
}

list-add-uniq() {
  local LIST_VAR="${1}"; shift
  while (( $# > 0 )); do
    local ITEM
    ITEM="${1}"; shift
    # TODO: enforce no newlines in item
    if [[ -z $(list-get-index $LIST_VAR "$ITEM") ]]; then
      list-add-item $LIST_VAR "$ITEM"
    fi
  done
}

# Echos the number of items in the list.
#
# Takes single argument, the list var name.
#
# Example:
# list-add-item A B C
# list-count MY_LIST # echos '3'
list-count() {
  if [[ -z "${!1:-}" ]]; then
    echo -n "0"
  else
    echo -e "${!1}" | wc -l | tr -d '[:space:]'
  fi
}

list-from-csv() {
  local LIST_VAR="${1}"
  local CSV="${2:-}"

  if [[ -z "$CSV" ]]; then
    CSV="${!LIST_VAR:-}"
    unset ${LIST_VAR}
  fi

  if [[ -n "$CSV" ]]; then
    local ADDR
    while IFS=',' read -ra ADDR; do
      for i in "${ADDR[@]}"; do
        i="$(echo "$i" | awk '{$1=$1};1')"
        list-add-item "$LIST_VAR" "$i"
      done
    done <<< "$CSV"
  fi
}

list-get-index() {
  local LIST_VAR="${1}"
  local TEST="${2}"

  local ITEM
  local INDEX=0
  while read -r ITEM; do
    if [[ "${ITEM}" == "${TEST}" ]]; then
      echo $INDEX
      return
    fi
    INDEX=$(($INDEX + 1))
  done <<< "${!LIST_VAR:-}"
}

list-get-item() {
  local LIST_VAR="${1}"
  local INDEX="${2}"

  local CURR_INDEX=0
  local ITEM
  while read -r ITEM; do
    if (( $CURR_INDEX == $INDEX )) ; then
      echo -n "${ITEM%\\n}"
      return
    fi
    CURR_INDEX=$(($CURR_INDEX + 1))
  done <<< "${!LIST_VAR:-}"
}

# Echoes the frist item in the named list matching the given prefix.
#
# Example:
# LIST="foo bar"$'\n'"foo baz"
# list-get-item-by-prefix LIST "foo " # echoes 'foo bar'
list-get-item-by-prefix() {
  local LIST_VAR="${1}"
  local PREFIX="${2}"

  local ITEM
  while read -r ITEM; do
    if [[ "${ITEM}" == "${PREFIX}"* ]] ; then
      echo -n "${ITEM%\\n}"
      return
    fi
  done <<< "${!LIST_VAR:-}"
}

# Joins a list with a given string and echos the result. We use 'echo -e' for the join string, so '\n', '\t', etc. will
# work.
#
# Takes (1) the list variable name, (2) the join string
#
# Example:
# list-add-item MY_LIST A B C
# list-join MY_LIST '||' # echos 'A||B||C'
list-join() {
  local LIST_VAR="${1}"
  local JOIN_STRING="${2}"

  local CURR_INDEX=0
  local COUNT
  COUNT="$(list-count $LIST_VAR)"
  while read -r ITEM; do
    echo -n "$ITEM"
    CURR_INDEX=$(($CURR_INDEX + 1))
    if (( $CURR_INDEX < $COUNT )) ; then
      echo -ne "$JOIN_STRING"
    fi
  done <<< "${!LIST_VAR:-}"
}

list-replace-by-string() {
  local LIST_VAR="${1}"
  local TEST_ITEM="${2}"
  local NEW_ITEM="${3}"

  local ITEM INDEX NEW_LIST
  INDEX=0
  for ITEM in ${!LIST_VAR:-}; do
    if [[ "$(list-get-item $LIST_VAR $INDEX)" == "$TEST_ITEM" ]]; then
      list-add-item NEW_LIST "$NEW_ITEM"
    else
      list-add-item NEW_LIST "$ITEM"
    fi
    INDEX=$(($INDEX + 1))
  done
  eval $LIST_VAR='"'"$NEW_LIST"'"'
}

list-quote() {
  local LIST_VAR="${1}"

  while read -r ITEM; do
    echo -n "'$(echo "$ITEM" | sed -e "s/'/'\"'\"'/")' "
  done <<< "${!LIST_VAR:-}"
}

list-rm-item() {
  local LIST_VAR="${1}"; shift
  while (( $# > 0 )); do
    local ITEM NEW_ITEMS
    ITEM="${1}"; shift
    ITEM=${ITEM//\/\\/}
    ITEM=${ITEM//#/\\#}
    ITEM=${ITEM//./\\.}
    ITEM=${ITEM//[/\\[}
    # echo "ITEM: $ITEM" >&2
    NEW_ITEMS="$(echo "${!LIST_VAR:-}" | sed -e '\#^'"${ITEM}"'$#d')"
    eval $LIST_VAR='"'"$NEW_ITEMS"'"'
  done
}

if [[ $(uname) == 'Darwin' ]]; then
  GNU_GETOPT="$(brew --prefix gnu-getopt)/bin/getopt"
else
  GNU_GETOPT="$(which getopt)"
fi

# Usage:
#   eval "$(setSimpleOptions DEFAULT VALUE= SPECIFY_SHORT:X NO_SHORT: LONG_ONLY:= COMBINED:C= -- "$@")" \
#     || ( contextHelp; echoerrandexit "Bad options."; )
setSimpleOptions() {
  local SCRIPT SET_COUNT VAR_SPEC LOCAL_DECLS
  local LONG_OPTS=""
  local SHORT_OPTS=""

  # our own, bootstrap option processing
  while [[ "${1:-}" == '-'* ]]; do
    local OPT="${1}"; shift
    case "${OPT}" in
      --set-count)
        SET_COUNT="${1}"
        shift;;
      --script)
        SCRIPT=true;;
      --) # usually we'd find a non-option first, but this is valid; we were called with no options specs to process.
        break;;
      *)
        echoerrandexit "Unknown option: $1";;
    esac
  done

  # Bash Bug? This looks like a straight up bug in bash, but the left-paren in
  # '--)' was matching the '$(' and causing a syntax error. So we use ']' and
  # replace it later.
  local CASE_HANDLER=$(cat <<EOF
    --]
      break;;
EOF
)
  while true; do
    if (( $# == 0 )); then
      echoerrandexit "setSimpleOptions: No argument to process; did you forget to include the '--' marker?"
    fi
    VAR_SPEC="$1"; shift
    local VAR_NAME LOWER_NAME SHORT_OPT LONG_OPT IS_PASSTHRU
    IS_PASSTHRU=''
    if [[ "$VAR_SPEC" == *'^' ]]; then
      IS_PASSTHRU=true
      VAR_SPEC=${VAR_SPEC/%^/}
    fi
    local OPT_ARG=''
    if [[ "$VAR_SPEC" == *'=' ]]; then
      OPT_ARG=':'
      VAR_SPEC=${VAR_SPEC/%=/}
    fi

    if [[ "$VAR_SPEC" == '--' ]]; then
      break
    elif [[ "$VAR_SPEC" == *':'* ]]; then
      VAR_NAME=$(echo "$VAR_SPEC" | cut -d: -f1)
      SHORT_OPT=$(echo "$VAR_SPEC" | cut -d: -f2)
    else # each input is a variable name
      VAR_NAME="$VAR_SPEC"
      SHORT_OPT=$(echo "${VAR_NAME::1}" | tr '[:upper:]' '[:lower:]')
    fi

    VAR_NAME=$(echo "$VAR_NAME" | tr -d "=")
    LOWER_NAME=$(echo "$VAR_NAME" | tr '[:upper:]' '[:lower:]')
    LONG_OPT="$(echo "${LOWER_NAME}" | tr '_' '-')"

    if [[ -n "${SHORT_OPT}" ]]; then
      SHORT_OPTS="${SHORT_OPTS:-}${SHORT_OPT}${OPT_ARG}"
    fi

    LONG_OPTS=$( ( test ${#LONG_OPTS} -gt 0 && echo -n "${LONG_OPTS},") || true && echo -n "${LONG_OPT}${OPT_ARG}")

    # Note, we usually want locals, so we actually just blindling build it up and then decide wether to include it at
    # the last minute.
    LOCAL_DECLS="${LOCAL_DECLS:-}local ${VAR_NAME}='';"
    local CASE_SELECT="-${SHORT_OPT}|--${LONG_OPT}]"
    if [[ "$IS_PASSTHRU" == true ]]; then # handle passthru
      CASE_HANDLER=$(cat <<EOF
        ${CASE_HANDLER}
          ${CASE_SELECT}
          list-add-item _PASSTHRU "\$1"
EOF
      )
      if [[ -n "$OPT_ARG" ]]; then
        CASE_HANDLER=$(cat <<EOF
          ${CASE_HANDLER}
            list-add-item _PASSTHRU "\$2"
            shift
EOF
        )
      fi
      CASE_HANDLER=$(cat <<EOF
        ${CASE_HANDLER}
          shift;;
EOF
      )
    else # non-passthru vars
      local VAR_SETTER="${VAR_NAME}=true;"
      if [[ -n "$OPT_ARG" ]]; then
        LOCAL_DECLS="${LOCAL_DECLS}local ${VAR_NAME}_SET='';"
        VAR_SETTER=${VAR_NAME}'="${2}"; '${VAR_NAME}'_SET=true; shift;'
      fi
      if [[ -z "$SHORT_OPT" ]]; then
        CASE_SELECT="--${LONG_OPT}]"
      fi
      CASE_HANDLER=$(cat <<EOF
      ${CASE_HANDLER}
        ${CASE_SELECT}
          $VAR_SETTER
          _OPTS_COUNT=\$(( \$_OPTS_COUNT + 1))
          shift;;
EOF
      )
    fi
  done # main while loop
  CASE_HANDLER=$(cat <<EOF
    case "\${1}" in
      $CASE_HANDLER
    esac
EOF
)
  # replace the ']'; see 'Bash Bug?' above
  CASE_HANDLER=$(echo "$CASE_HANDLER" | perl -pe 's/\]$/)/')

  # now we actually start the output to be evaled by the caller.

  # In script mode, we skip the local declarations. When used in a function
  # (i.e., not in scirpt mode), we declare everything local.
  if [[ -z "${SCRIPT:-}" ]]; then
    echo "${LOCAL_DECLS}"
    cat <<'EOF'
local _OPTS_COUNT=0
local _PASSTHRU=""
local TMP # see https://unix.stackexchange.com/a/88338/84520
EOF
  else # even though we don't declare local, we still want to support 'strict'
    # mode, so we do have to declare, just not local
    echo "${LOCAL_DECLS}" | sed -E 's/(^|;)[[:space:]]*local /\1/g'
    cat <<'EOF'
_OPTS_COUNT=0
_PASSTHRU=""
EOF
  fi

  cat <<EOF
TMP=\$(${GNU_GETOPT} -o "${SHORT_OPTS}" -l "${LONG_OPTS}" -- "\$@") \
  || exit \$?
eval set -- "\$TMP"
while true; do
  $CASE_HANDLER
done
shift
if [[ -n "\$_PASSTHRU" ]]; then
  eval set -- \$(list-quote _PASSTHRU) "\$@"
fi
EOF
  [[ -z "${SET_COUNT:-}" ]] || echo "${SET_COUNT}=\${_OPTS_COUNT}"
}

# Formats and echoes the the message.
#
# * Will process special chars the same as 'echo -e' (so \t, \n, etc. can be used in the message).
# * Treats all arguments as the message. 'echofmt "foo bar"' and 'echofmt foo bar' are equivalent.
# * Error and warning messages are directed towards stderr (unless modified by options).
# * Default message width is the lesser of 82 columns or the terminal column width.
# * Environment variable 'ECHO_WIDTH' will set the width. The '--width' option will override the environment variable.
# * Environment variable 'ECHO_QUIET' will suppress all non-error, non-warning messages if set to any non-empty value.
# * Environment variable 'ECHO_SILENT' will suppress all non-error messages if set to any non-empty value.
# * Environment variable 'ECHO_STDERR' will cause all output to be directed to stderr unless '--stderr' or '--stdout'
#   is specified.
# * Environment variable 'ECHO_STDOUT' will cause all output to be directed to stdout unless '--stderr' or '--stdout'
#   is specified.
echofmt() {
  local OPTIONS='INFO WARN ERROR WIDTH NO_FOLD:F STDERR STDOUT'
  eval "$(setSimpleOptions ${OPTIONS} -- "$@")"

  # First, let's check to see of the message is suppressed. The 'return 0' is explicitly necessary. 'return' sends
  # along $?, which, if it gets there, is 1 due to the failed previous test.
  ! { [[ -n "${ECHO_SILENT:-}" ]] && [[ -z "${ERROR:-}" ]]; } || return 0
  ! { [[ -n "${ECHO_QUIET:-}" ]] && [[ -z "${ERROR:-}" ]] && [[ -z "${WARN}" ]]; } || return 0

  # Examine environment to see if the redirect controls are set.
  if [[ -z "${STDERR:-}" ]] && [[ -z "${STDOUT:-}" ]]; then
    [[ -z "${ECHO_STDERR:-}" ]] || STDERR=true
    [[ -z "${ECHO_STDOUT:-}" ]] || STDOUT=true
  fi

  # Determine width... if folding
  [[ -z "${NO_FOLD:-}" ]] && [[ -n "${WIDTH:-}" ]] || { # If width is set as an option, then that's the end of story.
    local DEFAULT_WIDTH=82
    local WIDTH="${ECHO_WIDTH:-}"
    [[ -n "${WIDTH:-}" ]] || WIDTH=$DEFAULT_WIDTH
    # ECHO_WIDTH and DEFAULT_WIDTH are both subject to actual terminal width limitations.
    local TERM_WIDITH
    TERM_WIDTH=$(tput cols)
    (( ${TERM_WIDTH} >= ${WIDTH} )) || WIDTH=${TERM_WIDTH}
  }

  # Determine output color, if any.
  # internal helper function; set's 'STDERR' true unless target has already been set with '--stderr' or '--stdout'
  default-stderr() {
    [[ -n "${STDERR:-}" ]] || [[ -n "${STDOUT:-}" ]] || STDERR=true
  }
  local COLOR=''
  if [[ -n "${ERROR:-}" ]]; then
    COLOR="${red}"
    default-stderr
  elif [[ -n "${WARN:-}" ]]; then
    COLOR="${yellow}"
    default-stderr
  elif [[ -n "${INFO:-}" ]]; then
    COLOR="${green}"
  fi

  # we don't want to use an eval, and the way bash is evaluated means we can't do 'echo ... ${REDIRECT}' or something.
  if [[ -n "${STDERR:-}" ]]; then
    if [[ -z "$NO_FOLD" ]]; then
      echo -e "${COLOR:-}$*${reset}" | fold -sw "${WIDTH}" >&2
    else
      echo -e "${COLOR:-}$*${reset}" >&2
    fi
  else
    if [[ -z "${NO_FOLD:-}" ]]; then
      echo -e "${COLOR:-}$*${reset}" | fold -sw "${WIDTH}"
    else
      echo -e "${COLOR:-}$*${reset}"
    fi
  fi
}

echoerr() {
  echofmt --error "$@"
}

echowarn() {
  echofmt --warn "$@"
}

# Echoes a formatted message to STDERR. The default exit code is '1', but if 'EXIT_CODE', then that will be used. E.g.:
#
#    EXIT_CODE=5
#    echoerrandexit "Fatal code 5
#
# 'ECHO_NEVER_EXIT' can be set to any non-falsy value to supress the exit. This is intended primarily for use when liq
# functions are sourced and called directly from within the main shell, in which case exiting would kill the entire
# terminal session.
#
# See echofmt for further options and details.
echoerrandexit() {
  echofmt --error "$@"

  if [[ -z "${ECHO_NEVER_EXIT:-}" ]]; then
    [[ -z "${EXIT_CODE:-}" ]] || exit ${EXIT_CODE}
    exit 1
  fi
}

echo "Starting liq install..."

# Basic indent of a line.
indent() {
  cat | sed -e 's/^/  /'
}

# Folds the summary with a hanging indent.
_help-func-summary() {
  local FUNC_NAME="${1}"
  local OPTIONS="${2:-}"

  local STD_FOLD=82
  local WIDTH
  WIDTH=$(( $STD_FOLD - 2 ))

  (
    # echo -n "${underline}${yellow}${FUNC_NAME}${reset} "
    echo -n "${FUNC_NAME} "
    [[ -z "$OPTIONS" ]] || echo -n "${OPTIONS}"
    echo -n ": "
    cat
  ) | fold -sw $WIDTH | sed -E \
    -e "1 s/^([[:alpha:]-]+) /\\1 ${green}/" \
    -e "1,/:/ s/:/${reset}:/" \
    -e "1 s/^([[:alpha:]-]+)/${yellow}${underline}\\1${reset}/" \
    -e '2,$s/^/  /'
    # We fold, then color because fold sees the control characters as just plain characters, so it throws the fold off.
    # The non-printing characters are only really understood as such by the terminal and individual programs that
    # support it (which fold should, but, as this is written, doesn't).
    # 1 & 2) make options green
    # 3) yellow underline function name
    # 4) add hanging indent
}

# Prints and indents the help for each action
_help-actions-list() {
  local GROUP="${1}"; shift
  local ACTION
  for ACTION in "$@"; do
    echo
    help-$GROUP-$ACTION -i
  done
}

_help-sub-group-list() {
  local PREFIX="${1}"
  local GROUPS_VAR="${2}"

  if [[ -n "${!GROUPS_VAR}" ]]; then
    local SG
    echo "$( {  echo -e "\n${bold}Sub-groups${reset}:";
                for SG in ${!GROUPS_VAR}; do
                  echo "* $( SUMMARY_ONLY=true; help-${PREFIX}-${SG} )";
                done; } | indent)"
  fi
}

helpActionPrefix() {
  if [[ -z "${INDENT:-}" ]]; then
    echo -n "liq $1 "
  fi
}

colorerr() {
  # TODO: in the case of long output, it would be nice to notice whether we saw
  # error or not and tell the user to scroll back and check the logs. e.g., if
  # we see an error and then 20+ lines of stuff, then emit advice.
  (eval "$@ 2> >(echo -n \"${red}\"; cat -; tput sgr0)")
}

# TODO: is this better? We switched to it for awhile, but there were problems.
# The reasons for both the initial switch and the switchback are now obscured
# but may have been due to failure of the original code to exit with the
# underling error status from the eval, which has since been fixed. The
# switchback was, in part, because of problems with syncronous calls. Of course,
# it didn't wait as we would like, but it was also causing functional problems
# with... somethnig.
# TODO: We are currently not using colorerrbg anywhere.
colorerrbg() {
  (eval "$@" 2>&1>&3|sed 's/^\(.*\)$/'$'\e''[31m\1'$'\e''[m/'>&2)3>&1 &
}

# Verifies access to github.
check-git-access() {
  eval "$(setSimpleOptions NO_EXIT -- "$@")"
  # if we don't supress the output, then we get noise even when successful
  ssh -qT git@github.com 2> /dev/null || if [ $? -ne 1 ]; then
    [[ -z "${NO_EXIT}" ]] || return 1
    echoerrandexit "Could not connect to github; try to add add your GitHub key like:\nssh-add /example/path/to/key"
  fi
}

change-working-project() {
  if [[ -n "$PROJECT" ]]; then
    if ! [[ -d "${LIQ_PLAYGROUND}/${PROJECT}" ]]; then
      echoerrandexit "No such project '${PROJECT}' found locally."
    fi
    cd "${LIQ_PLAYGROUND}/${PROJECT}"
  fi
}

findFile() {
  local SEARCH_DIR="${1}"
  local FILE_NAME="${2}"
  local RES_VAR="${3}"
  local FOUND_FILE
  local START_DIR="$SEARCH_DIR"

  while SEARCH_DIR="$(cd "$SEARCH_DIR"; echo $PWD)" && [[ "${SEARCH_DIR}" != "/" ]]; do
    FOUND_FILE=`find -L "$SEARCH_DIR" -maxdepth 1 -mindepth 1 -name "${FILE_NAME}" -type f | grep "${FILE_NAME}" || true`
    if [ -z "$FOUND_FILE" ]; then
      SEARCH_DIR="$SEARCH_DIR/.."
    else
      break
    fi
  done

  if [ -z "$FOUND_FILE" ]; then
    echoerr "Could not find '${FILE_NAME}' in '$START_DIR' or any parent directory."
    return 1
  else
    eval $RES_VAR="$FOUND_FILE"
  fi
}

findBase() {
  findFile "${PWD}" package.json PACKAGE_FILE
  BASE_DIR="$( cd "$( dirname "${PACKAGE_FILE}" )" && pwd )"
}

sourceFile() {
  local SEARCH_DIR="${1}"
  local FILE_NAME="${2}"
  local PROJFILE
  findFile "$SEARCH_DIR" "$FILE_NAME" PROJFILE && {
    source "$PROJFILE"
    # TODO: this works (at time of note) because all the files we currently source are in the root, but it's a bit odd and should be reworked.
    BASE_DIR="$( cd "$( dirname "${PROJFILE}" )" && pwd )"
    return 0
  }
}

sourceCatalystfile() {
  sourceFile "${PWD}" '.catalyst'
  return $? # TODO: is this how this works in bash?
}

requireCatalystfile() {
  sourceCatalystfile \
    || echoerrandexit "Run 'liq projects init' from project root." 1
}

requireNpmPackage() {
  findFile "${BASE_DIR}" 'package.json' PACKAGE_FILE
}

sourceWorkspaceConfig() {
  sourceFile "${PWD}" "${_WORKSPACE_CONFIG}"
  return $? # TODO: is this how this works in bash?
}

requirePackage() {
  requireNpmPackage
  PACKAGE="$(cat $PACKAGE_FILE)"
  PACKAGE_NAME="$(echo "$PACKAGE" | jq --raw-output ".name")"
}

requireEnvironment() {
  requireCatalystfile
  requirePackage
  CURR_ENV_FILE="${LIQ_ENV_DB}/${PACKAGE_NAME}/curr_env"
  if [[ ! -L "$CURR_ENV_FILE" ]]; then
    contextHelp
    echoerrandexit "No environment currently selected."
  fi
  CURR_ENV=`readlink "${CURR_ENV_FILE}" | xargs basename`
}

addLineIfNotPresentInFile() {
  local FILE="${1:-}"
  local LINE="${2:-}"
  touch "$FILE"
  grep "$LINE" "$FILE" > /dev/null || echo "$LINE" >> "$FILE"
}

requireArgs() {
  local COUNT=$#
  local I=1
  while (( $I <= $COUNT )); do
    if [[ -z ${!I:-} ]]; then
      if [[ -z $ACTION ]]; then
        echoerr "Global action '$COMPONENT' requires $COUNT additional arguments."
      else
        echoerr "'$COMPONENT $ACTION' requires $COUNT additional arguments."
      fi
      # TODO: as 'requireArgs' this should straight up exit.
      return 1
    fi
    I=$(( I + 1 ))
  done

  return 0
}

contextHelp() {
  # TODO: this is a bit of a workaround until all the ACTION helps are broken
  # out into ther own function.
  if type -t help-${GROUP}-${ACTION} | grep -q 'function'; then
    help-${GROUP}-${ACTION}
  else
    help-${GROUP}
  fi
}

exactUserArgs() {
  local REQUIRED_ARGS=()
  while true; do
    case "$1" in
      --)
        break;;
      *)
        REQUIRED_ARGS+=("$1");;
    esac
    shift
  done
  shift

  if (( $# < ${#REQUIRED_ARGS[@]} )); then
    contextHelp
    echoerrandexit "Insufficient number of arguments."
  elif (( $# > ${#REQUIRED_ARGS[@]} )); then
    contextHelp
    echoerrandexit "Found extra arguments."
  else
    local I=0
    while (( $# > 0 )); do
      eval "${REQUIRED_ARGS[$I]}='$1'"
      shift
      I=$(( $I + 1 ))
    done
  fi
}

requireGlobals() {
  local COUNT=$#
  local I=1
  while (( $I <= $COUNT )); do
    local GLOBAL_NAME=${!I}
    if [[ -z ${!GLOBAL_NAME:-} ]]; then
      echoerr "'${GLOBAL_NAME}' not set. Try:\nliq ${COMPONENT} configure"
      exit 1
    fi
    I=$(( I + 1 ))
  done

  return 0
}

loadCurrEnv() {
  resetEnv() {
    CURR_ENV=''
    CURR_ENV_TYPE=''
    CURR_ENV_PURPOSE=''
  }

  local PACKAGE_NAME=`cat $BASE_DIR/package.json | jq --raw-output ".name"`
  local CURR_ENV_FILE="${LIQ_ENV_DB}/${PACKAGE_NAME}/curr_env"

  if [[ -f "${CURR_ENV_FILE}" ]]; then
    source "$CURR_ENV_FILE"
  else
    resetEnv
  fi
}

getPackageDef() {
  local VAR_NAME="$1"
  local FQN_PACKAGE_NAME="${2:-}"

  # The project we're looking at might be our own or might be a dependency.
  if [[ -z "$FQN_PACKAGE_NAME" ]] || [[ "$FQN_PACKAGE_NAME" == "$PACKAGE_NAME" ]]; then
    eval "$VAR_NAME=\"\$PACKAGE\""
  else
    eval "$VAR_NAME=\$(npm explore \"$FQN_PACKAGE_NAME\" -- cat package.json)"
  fi
}

getProvidedServiceValues() {
  local SERV_KEY="${1:-}"
  local FIELD_LABEL="$2"

  local SERV_PACKAGE SERV_NAME SERV
  if [[ -n "$SERV_KEY" ]];then
    # local SERV_IFACE=`echo "$SERV_KEY" | cut -d: -f1`
    local SERV_PACKAGE_NAME=`echo "$SERV_KEY" | cut -d: -f2`
    SERV_NAME=`echo "$SERV_KEY" | cut -d: -f3`
    getPackageDef SERV_PACKAGE "$SERV_PACKAGE_NAME"
  else
    SERV_PACKAGE="$PACKAGE"
  fi

  echo "$SERV_PACKAGE" | jq --raw-output ".catalyst.provides | .[] | select(.name == \"$SERV_NAME\") | .\"${FIELD_LABEL}\" | @sh" | tr -d "'" \
    || ( ( [[ -n $SERV_PACKAGE_NAME ]] && echoerrandexit "$SERV_PACKAGE_NAME package.json does not define .catalyst.provides[${SERV_NAME}]." ) || \
         echoerrandexit "Local package.json does not define .catalyst.provides[${SERV_NAME}]." )
}

getRequiredParameters() {
  getProvidedServiceValues "${1:-}" "params-req"
}

# TODO: this is not like the others; it should take an optional package name, and the others should work with package names, not service specs. I.e., decompose externally.
# TODO: Or maybe not. Have a set of "objective" service key manipulators to build from and extract parts?
getConfigConstants() {
  local SERV_IFACE="${1}"
  echo "$PACKAGE" | jq --raw-output ".catalyst.requires | .[] | select(.iface==\"$SERV_IFACE\") | .\"config-const\" | keys | @sh" | tr -d "'"
}

getCtrlScripts() {
  getProvidedServiceValues "${1:-}" "ctrl-scripts"
}

pressAnyKeyToContinue() {
  read -n 1 -s -r -p "Press any key to continue..."
  echo
}

getCatPackagePaths() {
  local NPM_ROOT=`npm root`
  local CAT_PACKAGE_PATHS=`find -L "$NPM_ROOT"/\@* -maxdepth 2 -name ".catalyst" -not -path "*.prelink/*" -exec dirname {} \;`
  CAT_PACKAGE_PATHS="${CAT_PACKAGE_PATHS} "`find -L "$NPM_ROOT" -maxdepth 2 -name ".catalyst" -not -path "*.prelink/*" -exec dirname {} \;`

  echo "$CAT_PACKAGE_PATHS"
}

# Takes a project name and checks that the local repo is clean. By specifyng '--check-branch' (which will take a comma
# separated list of branch names) or '--check-all-branches', the function will also check that the current head of each
# branch is present in the remote repo. The branch checks do not include a 'fetch', so local information may be out of
# date.
requireCleanRepo() {
  eval "$(setSimpleOptions CHECK_BRANCH= CHECK_ALL_BRANCHES -- "$@")"

  local _IP="$1"
  _IP="${_IP/@/}"
  # TODO: the '_WORK_BRANCH' here seem to be more of a check than a command to check that branch.
  _IP=${_IP/@/}

  local BRANCHES_TO_CHECK
  if [[ -n "$CHECK_ALL_BRANCHES" ]]; then
    BRANCHES_TO_CHECK="$(git branch --list --format='%(refname:lstrip=-1)')"
  elif [[ -n "$CHECK_BRANCH" ]]; then
    list-from-csv BRANCHES_TO_CHECK "$CHECK_BRANCH"
  fi

  cd "${LIQ_PLAYGROUND}/${_IP}"

  echo "Checking ${_IP}..."
  # credit: https://stackoverflow.com/a/8830922/929494
  # look for uncommitted changes
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echoerrandexit "Found uncommitted changes.\n$(git status --porcelain)"
  fi
  # check for untracked files
  if (( $({ git status --porcelain 2>/dev/null| grep '^??' || true; } | wc -l) != 0 )); then
    echoerrandexit "Found untracked files."
  fi
  # At this point, the local repo is clean. Now we look at any branches of interest to make sure they've been pushed.
  if [[ -n "$BRANCHES_TO_CHECK" ]]; then
    local BRANCH_TO_CHECK
    for BRANCH_TO_CHECK in $BRANCHES_TO_CHECK; do
      if [[ "$BRANCH_TO_CHECK" == master ]] \
         && ! git merge-base --is-ancestor master upstream/master; then
        echoerrandexit "Local master has not been pushed to upstream master."
      fi
      # if the repo was created without forking, then there's no separate workspace
      if git remote | grep -e '^workspace$' \
          && ! git merge-base --is-ancestor "$BRANCH_TO_CHECK" "workspace/${BRANCH_TO_CHECK}"; then
        echoerrandexit "Local branch '$BRANCH_TO_CHECK' has not been pushed to workspace."
      fi
    done
  fi
}

# For each 'involved project' in the indicated unit of work (default to current unit of work), checks that the repo is
# clean.
requireCleanRepos() {
  local _WORK_NAME="${1:-curr_work}"

  ( # isolate the source
    source "${LIQ_WORK_DB}/${_WORK_NAME}"

    local IP
    for IP in $INVOLVED_PROJECTS; do
      requireCleanRepo "$IP"
    done
  )
}

defineParameters() {
  local SERVICE_DEF_VAR="$1"

  echo "Enter required parameters. Enter blank line when done."
  local PARAM_NAME
  while [[ $PARAM_NAME != '...quit...' ]]; do
    read -p "Required parameter: " PARAM_NAME
    if [[ -z "$PARAM_NAME" ]]; then
      PARAM_NAME='...quit...'
    else
      eval $SERVICE_DEF_VAR'=$(echo "$'$SERVICE_DEF_VAR'" | jq ". + { \"params-req\": (.\"params-req\" + [\"'$PARAM_NAME'\"]) }")'
    fi
  done

  PARAM_NAME=''
  echo "Enter optional parameters. Enter blank line when done."
  while [[ $PARAM_NAME != '...quit...' ]]; do
    read -p "Optional parameter: " PARAM_NAME
    if [[ -z "$PARAM_NAME" ]]; then
      PARAM_NAME='...quit...'
    else
      eval $SERVICE_DEF_VAR='$(echo "$'$SERVICE_DEF_VAR'" | jq ". + { \"params-opt\": (.\"params-opt\" + [\"'$PARAM_NAME'\"]) }")'
    fi
  done

  PARAM_NAME=''
  echo "Enter configuration constants. Enter blank line when done."
  while [[ $PARAM_NAME != '...quit...' ]]; do
    read -p "Configuration constant: " PARAM_NAME
    if [[ -z "$PARAM_NAME" ]]; then
      PARAM_NAME='...quit...'
    else
      local PARAM_VAL=''
      require-answer "Value: " PARAM_VAL
      eval $SERVICE_DEF_VAR='$(echo "$'$SERVICE_DEF_VAR'" | jq ". + { \"config-const\": (.\"config-const\" + { \"'$PARAM_NAME'\" : \"'$PARAM_VAL'\" }) }")'
    fi
  done
}

BREW_UPDATED=''
brewInstall() {
  local EXEC="$1"
  local INSTALL_TEST="$2"
  local POST_INSTALL="${3:-}"
  if ! $INSTALL_TEST; then
    if ! which -s brew; then
      echoerr "Required executable '${EXEC}' not found."
      echoerr "Install Homebrew and re-run installation, or install '${EXEC}' manually."
      echoerrandexit https://brew.sh/
    fi
    # else
    doInstall() {
      test -n "${BREW_UPDATED}" \
        || brew update \
        || echoerrandexit "'brew update' exited with errors. Please update Homebrew and re-run Catalyst CLI installation."
      BREW_UPDATED=true
      brew install $EXEC \
        || (echo "First install attempt failed. Re-running often fixes brew install issue; trying again..."; brew install $EXEC) \
        || echoerrandexit "'brew install ${EXEC}' exited with errors. Otherwise, please install '${EXEC}' and re-run Catalyst CLI installation."
      if test -n "$POST_INSTALL"; then eval "$POST_INSTALL"; fi
    }
    giveFeedback() {
      echo "Catalyst CLI requires '${EXEC}'. Please install with Homebrew (recommended) or manually."
      exit
    }
    yes-no \
      "Catalyst CLI requires command '${EXEC}'. OK to attempt install via Homebrew? (Y/n) " \
      Y \
      doInstall \
      giveFeedback
  fi
}

APT_UPDATED=false
function apt-install() {
  local EXEC="$1"
  local INSTALL_TEST="$2"

  if ! ${INSTALL_TEST}; then
    echo "Installing '${EXEC}'..."
    if [[ "${APT_UPDATED}"  == 'false' ]]; then
      sudo apt-get -q update || echoerrandexit "Could not install '${EXEC}' while performing 'apt-get update'."
      APT_UPDATED=false
    fi
    sudo apt-get -qqy "${EXEC}" || echoerrandexit "Could not install  '${EXEC}' while performing 'apt-get install'."
  else
    echo "Found '${EXEC}'..."
  fi
}

function npm-install() {
  local PKG="${1}"
  local INSTALL_TEST="${2}"

  if ! ${INSTALL_TEST}; then
    npm install -g ${PKG}
  fi
}

if [[ $(uname) == 'Darwin' ]]; then
  brewInstall jq 'which -s jq'
  # Without the 'eval', the tick quotes are treated as part of the filename.
  # Without the tickquotes we're vulnerable to spaces in the path.
  brewInstall gnu-getopt \
    "eval test -f '$(brew --prefix gnu-getopt)/bin/getopt'" \
    "addLineIfNotPresentInFile ~/.bash_profile 'alias gnu-getopt=\"\$(brew --prefix gnu-getopt)/bin/getopt\"'"
else
  apt-install jq 'which jq' # '-s' is not supported on linux and a /dev/null redirect doesn't interpret correctly (?)
  apt-install node 'which node'
fi

npm-install yalc 'which yalc'

declare COMPLETION_SEUTP
for i in /etc/bash_completion.d /usr/local/etc/bash_completion.d; do
  if [[ -e "${i}" ]]; then
    COMPLETION_PATH="${i}"
    COMPLETION_SETUP=true
    break
  fi
done
[[ -n "${COMPLETION_SETUP}" ]] || echowarn "Could not setup completion; did not find expected completion paths."
cp ./dist/completion.sh "${COMPLETION_PATH}/liq"

COMPLETION_SETUP=false
for i in /etc/bash.bashrc "${HOME}/.bash_profile" "${HOME}/.profile"; do
  if [[ -e "${i}" ]]; then
    addLineIfNotPresentInFile "${i}" "[ -d '$COMPLETION_PATH' ] && . '${COMPLETION_PATH}/liq'"
    COMPLETION_SETUP=true
    break
  fi
done

if [[ "${COMPLETION_SETUP}" == 'false' ]]; then
  echoerr "Completion support not set up; could not find likely bash profile/rc."
fi
# TODO: accept '-e' option which exchos the source command so user can do 'eval ./install.sh -e'
# TODO: only echo if lines added (here or in POST_INSTALL)
[[ -z "${PS1}" ]] || echo "You must open a new shell or 'source ~/.bash_profile' to enable completion updates."
