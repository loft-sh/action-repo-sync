#!/bin/bash
set -e

if [ -z "$INPUT_GITHUB_TOKEN" ]; then
    echo "Var INPUT_GITHUB_TOKEN required"
    return -1
fi

if [ -z "$INPUT_TARGET_REPO" ]; then
    echo "Var INPUT_TARGET_REPO required"
    return -1
fi

if [ -z "$INPUT_PATH_MAPPING" ]; then
    echo "Var INPUT_PATH_MAPPING required"
    return -1
fi

git config --global user.email "${INPUT_GIT_EMAIL:-bot@loft.sh}" "noreply@loft.sh"
git config --global user.name "${INPUT_GIT_USERNAME:-Loft Bot}" "Repo Sync Bot"

SOURCE_REPO_DIR=$PWD
TARGET_REPO_DIR=$(mktemp -d)

gh auth login --with-token <<< "${INPUT_GITHUB_TOKEN}"

git clone "https://${INPUT_GITHUB_TOKEN}@github.com/${INPUT_TARGET_REPO}.git" "$TARGET_REPO_DIR"
git remote set-url origin "https://${INPUT_GITHUB_TOKEN}@github.com/${REPO_DIR}.git"

cd $TARGET_REPO_DIR

USE_PR=true
if [ "$INPUT_PR_SOURCE_BRANCH" = "$INPUT_PR_TARGET_BRANCH" ]; then
    USE_PR=false
fi

if [ -z "$INPUT_PR_SOURCE_BRANCH" ]; then
    INPUT_PR_SOURCE_BRANCH=${INPUT_PR_TARGET_BRANCH}
else
    BRANCH_EXISTS=$(git show-ref "$INPUT_PR_SOURCE_BRANCH" | wc -l)

    git fetch -a
    if [ "$BRANCH_EXISTS" = 1 ];
    then
        git checkout "$INPUT_PR_SOURCE_BRANCH"
    else
        git checkout -b "$INPUT_PR_SOURCE_BRANCH"
    fi
fi


HAS_CHANGES=false

export IFS=";"
for PATH_MAPPING in $INPUT_PATH_MAPPING; do

    IFS=":" read -a PATH_MAP <<< "$PATH_MAPPING"

    SOURCE_PATH="${SOURCE_REPO_DIR}/${PATH_MAP[0]}"
    if [ -z "${PATH_MAP[1]}" ]; then
        TARGET_PATH="${TARGET_REPO_DIR}/${PATH_MAP[0]}"
    else
        TARGET_PATH="${TARGET_REPO_DIR}/${PATH_MAP[1]}"
    fi

    rm -rf "$TARGET_PATH"

    if ! [ -f "$SOURCE_PATH" ] || [ "${TARGET_PATH: -1}" == "/" ] ; then
        mkdir -p "$TARGET_PATH"
    fi
    
    shopt -s dotglob nullglob
    cp -rf $SOURCE_PATH "$TARGET_PATH";  # DO NOT ADD QUOTES TO SOURCE_PATH

    if [ -z "$INPUT_COMMIT_MSG" ]; then
        INPUT_COMMIT_MSG=$(cd "$SOURCE_REPO_DIR" && git log -1 --format="%s" "$SOURCE_PATH")
    fi

    if [ -z "$INPUT_COMMIT_MSG" ]; then
        INPUT_COMMIT_MSG="chore: repo-sync"
    fi

    git add -A

    COMMIT_SUCCESSFUL=true
    git commit -m "$INPUT_COMMIT_MSG" || COMMIT_SUCCESSFUL=false

    if [ "$COMMIT_SUCCESSFUL" = true ]; then 
        HAS_CHANGES=true
    fi

done

cd "$REPO_DIR"

if [ "$HAS_CHANGES" = true ]; then
    git push --force -u origin HEAD:$INPUT_PR_SOURCE_BRANCH
fi

if [ "$USE_PR" = true ]; then

    PR_STATE=$(gh pr view "$INPUT_PR_SOURCE_BRANCH" --json state --template "{{.state}}" || echo "UNKNOWN")
    if ! [ "$PR_STATE" = "OPEN" ]; then
        gh pr create --title "${INPUT_PR_TITLE:-chore: repo-sync}" \
                    --body "Repo sync" \
                    --base "$INPUT_PR_TARGET_BRANCH" \
                    --head "$INPUT_PR_SOURCE_BRANCH"
    fi

fi
