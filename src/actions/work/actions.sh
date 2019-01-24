requirements-work() {
  sourceCatalystfile
}

work-diff-master() {
  git diff $(git merge-base master HEAD)..HEAD "$@"
}

work-edit() {
  # TODO: make editor configurable
  local EDITOR_CMD='atom'
  local OPEN_PROJ_CMD="${EDITOR_CMD} ."
  cd "${BASE_DIR}" && ${OPEN_PROJ_CMD}
}

work-ignore-rest() {
  pushd "${BASE_DIR}" > /dev/null
  touch .gitignore
  # first ignore whole directories
  for i in `git ls-files . --exclude-standard --others --directory`; do
    echo "${i}" >> .gitignore
  done
  popd > /dev/null
}

work-involve() {
  if [[ ! -L "${CATALYST_WORK_DB}/curr_work" ]]; then
    echoerrandexit "There is no active unit of work to involve. Try:\ncatalyst work resume"
  fi

  local PROJECT_NAME
  if (( $# == 0 )) && [[ -n "$BASE_DIR" ]]; then
    PROJECT_NAME=`basename $BASE_DIR`
  else
    exactUserArgs PROJECT_NAME -- "$@"
    test -d "${CATALYST_PLAYGROUND}/${PROJECT_NAME}" \
      || echoerrandexit "Invalid project name '$PROJECT_NAME'. Perhaps it needs to be imported? Try:\ncatalyst workspace import <git URL>"
  fi

  source "${CATALYST_WORK_DB}/curr_work"
  local BRANCH_NAME=$(basename $(readlink "${CATALYST_WORK_DB}/curr_work"))

  cd "${CATALYST_PLAYGROUND}/${PROJECT_NAME}"
  if git branch | grep -qE "^\*? *${BRANCH_NAME}\$"; then
    echowarn "Found existing work branch '${BRANCH_NAME}' in project ${PROJECT_NAME}. We will use it. Please fix manually if this is unexpected."
    git checkout -q "${BRANCH_NAME}" || echoerrandexit "There was a problem checking out the work branch. ($?)"
  else
    git checkout -qb "${BRANCH_NAME}" || echoerrandexit "There was a problem creating the work branch. ($?)"
    echo "Created work branch '${BRANCH_NAME}' for project '${PROJECT_NAME}'."
  fi

  INVOLVED_PROJECTS="${INVOLVED_PROJECTS} ${PROJECT_NAME}"
  updateWorkDb
}

work-merge() {
  source "${CATALYST_WORK_DB}/curr_work"
  local CURR_WORK=$(basename $(readlink "${CATALYST_WORK_DB}/curr_work" ))

  if [[ -z "$INVOLVED_PROJECTS" ]]; then
    echoerrandexit "No projects involved in the current unit of work '$CURR_WORK'."
  fi

  local IP
  for IP in $INVOLVED_PROJECTS; do
    requireCleanRepo "$IP"

    local WORKBRANCH=`git branch | (grep '*' || true) | awk '{print $2}'`
    if [[ "$WORKBRANCH" != "$CURR_WORK" ]]; then
      echoerrandexit "Project '$IP' is not currently on the expected workbranch '$CURR_WORK'. Please fix and re-run."
    fi
  done

  for IP in $INVOLVED_PROJECTS; do
    cd "${CATALYST_PLAYGROUND}/${IP}"
    local SHORT_STAT=`git diff --shortstat master ${WORKBRANCH}`
    local INS_COUNT=`echo "${SHORT_STAT}" | egrep -Eio -e '\d+ insertion' | awk '{print $1}' || true`
    INS_COUNT=${INS_COUNT:-0}
    local DEL_COUNT=`echo "${SHORT_STAT}" | egrep -Eio -e '\d+ deletion' | awk '{print $1}' || true`
    DEL_COUNT=${DEL_COUNT:-0}
    local DIFF_COUNT=$(( $INS_COUNT - $DEL_COUNT ))

    local PUSH_FAILED=N
    # in case the current working dir does not exist in master
    pushd ${BASE_DIR} > /dev/null \
    && (git checkout -q master \
        || (popd > /dev/null && echoerrandexit "Could not switch to master branch in project '$IP'.")) \
    && (git merge --no-ff -qm "merge branch $WORKBRANCH" "$WORKBRANCH" \
        || (echoerrandexit "Problem merging work branch with master for project '$IP'. ($?)")) \
    && popd > /dev/null \
    && ( (git push -q && echo "Work merged and pushed to origin.") \
        || (PUSH_FAILED=Y && echoerr "Local merge successful, but there was a problem pushing work to master."))
    # if we have not exited, then the merge was made and we'll attempt to clean up
    # local work branch (even if the push fails)
    git branch -qd "$WORKBRANCH" \
      || echoerr "Could not delete '${WORKBRANCH}'. This can happen if the branch was renamed."
    # TODO: provide a reference for checking the merge is present and if safe to delete.
    echo "$IP linecount change: $DIFF_COUNT"

    INVOLVED_PROJECTS=$(echo "$INVOLVED_PROJECTS" | sed -E "s/(^| +)$IP( +|\$)//")
    updateWorkDb
  done

  if [[ -n "$INVOLVED_PROJECTS" ]]; then
    echoerrandexit "Unexpectedly, it may be that not all involved projects were committed. Leaving things as they are. You will need to the current work."
  fi
  rm "${CATALYST_WORK_DB}/curr_work"
  rm "${CATALYST_WORK_DB}/${CURR_WORK}"
}

work-qa() {
  echo "Checking local repo status..."
  work-report
  echo "Checking package dependencies..."
  packages-version-check
  echo "Linting code..."
  packages-lint
  echo "Running tests..."
  packages-test
}

work-report() {
  local BRANCH_NAME
  statusReport() {
    local COUNT="$1"
    local DESC="$2"
    if (( $COUNT > 0 )); then
      echo "$1 files $2."
    fi
  }

  requireCatalystfile
  (cd "${BASE_DIR}"
   echo
   echo "${green}"`basename "$PWD"`; tput sgr0
   BRANCH_NAME=`git rev-parse --abbrev-ref HEAD 2> /dev/null || echo ''`
   if [[ $BRANCH_NAME == "HEAD" ]]; then
     echo "${red}NO WORKING BRANCH"
  else
    echo "On branch: ${green}${BRANCH_NAME}"
  fi
  tput sgr0
  # TODO: once 'git status' once and capture output
  statusReport `git status --porcelain | grep '^ M' | wc -l || true` 'modified'
  statusReport `git status --porcelain | grep '^R ' | wc -l || true` 'renamed'
  statusReport `git status --porcelain | grep '^RM' | wc -l || true` 'renamed and modifed'
  statusReport `git status --porcelain | grep '^D ' | wc -l || true` 'deleted'
  statusReport `git status --porcelain | grep '^ D' | wc -l || true` 'missing'
  statusReport `git status --porcelain | grep '^??' | wc -l || true` 'untracked'
  local TOTAL_COUNT=`git status --porcelain | wc -l | xargs || true`
  if (( $TOTAL_COUNT > 0 )); then
    echo -e "------------\n$TOTAL_COUNT total"
  fi
 )

  tput sgr0 # TODO: put this in the exit trap, too, I think.
}

work-resume() {
  if [[ -L "${CATALYST_WORK_DB}/curr_work" ]]; then
    requireCleanRepos
  fi

  local WORK_NAME
  workUserSelectOne WORK_NAME '' true "$@"

  requireCleanRepos "${WORK_NAME}"

  local CURR_WORK
  if [[ -L "${CATALYST_WORK_DB}/curr_work" ]]; then
    CURR_WORK=$(basename $(readlink "${CATALYST_WORK_DB}/curr_work"))
    if [[ "${CURR_WORK}" == "${WORK_NAME}" ]]; then
      echowarn "'$CURR_WORK' is already the current unit of work."
      exit 0
    fi
    workSwitchBranches master
    rm "${CATALYST_WORK_DB}/curr_work"
  fi
  cd "${CATALYST_WORK_DB}" && ln -s "${WORK_NAME}" curr_work
  source "${CATALYST_WORK_DB}"/curr_work
  workSwitchBranches "$WORK_NAME"

  if [[ -n "$CURR_WORK" ]]; then
    echo "Switched from '$CURR_WORK' to '$WORK_NAME'."
  else
    echo "Resumed '$WORK_NAME'."
  fi
}

work-show() {
  local WORK_NAME
  workUserSelectOne WORK_NAME true '' "$@"

  echo "Branch name: $WORK_NAME"
  echo
  source "${CATALYST_WORK_DB}/${WORK_NAME}"
  if [[ -z "$INVOLVED_PROJECTS" ]]; then
    "Involved projects: <none>"
  else
    echo "Involved projects:"
    local IP
    for IP in $INVOLVED_PROJECTS; do
      echo "  $IP"
    done
  fi
}

work-start() {
  local WORK_DESC
  exactUserArgs WORK_DESC -- "$@"
  local WORK_DESC_SPEC='^[a-z0-9][a-z0-9-]+$'
  # TODO: require a minimum length of 5 non-dash characters.
  echo "$WORK_DESC" | grep -qE $WORK_DESC_SPEC \
    || echoerrandexit "Work description must begin with a lowercase letter or number and contain only lowercase letters and numbers separated by a single dash (/$WORK_DESC_SPEC/)."
  local BRANCH_NAME=`branchName "${WORK_DESC}"`

  if [[ -f "${CATALYST_WORK_DB}/${BRANCH_NAME}" ]]; then
    echoerrandexit "Unit of work '${BRANCH_NAME}' aready exists. Bailing out."
  fi

  # TODO: check that current work branch is clean before switching away from it
  # https://github.com/Liquid-Labs/catalyst-cli/issues/14

  if [[ -L "${CATALYST_WORK_DB}/curr_work" ]]; then
    rm "${CATALYST_WORK_DB}/curr_work"
  fi
  touch "${CATALYST_WORK_DB}/${BRANCH_NAME}"
  cd ${CATALYST_WORK_DB} && ln -s "${BRANCH_NAME}" curr_work
  updateWorkDb

  if [[ -n "$BASE_DIR" ]]; then
    local CURR_PROJECT=`basename $BASE_DIR`
    echo "Adding current project '$CURR_PROJECT' to unit of work..."
    work-involve "$CURR_PROJECT"
  fi
}

work-stop() {
  if [[ -L "${CATALYST_WORK_DB}/curr_work" ]]; then
    local CURR_WORK=$(basename $(readlink "${CATALYST_WORK_DB}/curr_work"))
    requireCleanRepos
    workSwitchBranches master
    rm "${CATALYST_WORK_DB}/curr_work"
    echo "Paused work on '$CURR_WORK'. No current unit of work."
  else
    echoerrandexit "No current unit of work to stop."
  fi
}
