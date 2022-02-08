#!/bin/bash
set -e
set -x

INPUT_GITHUB_TOKEN=${1:-$INPUT_GITHUB_TOKEN}
INPUT_PATH_MAPPING=${2:-$INPUT_PATH_MAPPING}
INPUT_TARGET_REPO=${3:-$INPUT_TARGET_REPO}
INPUT_TARGET_REPO_DIR=${4:-$INPUT_TARGET_REPO_DIR}
INPUT_PR_SOURCE_BRANCH=${5:-$INPUT_PR_SOURCE_BRANCH}
INPUT_PR_SOURCE_BRANCH=${INPUT_PR_SOURCE_BRANCH#refs/heads/}
INPUT_PR_TARGET_BRANCH=${6:-$INPUT_PR_TARGET_BRANCH}
INPUT_PR_TARGET_BRANCH=${INPUT_PR_TARGET_BRANCH#refs/heads/}
INPUT_PR_TITLE=${7:-$INPUT_PR_TITLE}
INPUT_COMMIT_MSG=${8:-$INPUT_COMMIT_MSG}
INPUT_GIT_EMAIL=${9:-$INPUT_GIT_EMAIL}
INPUT_GIT_USERNAME=${10:-$INPUT_GIT_USERNAME}

if [ -z "$INPUT_GITHUB_TOKEN" ]; then
    echo "Var INPUT_GITHUB_TOKEN required"
    exit 1
fi

if [ -z "$INPUT_TARGET_REPO" ]; then
    echo "Var INPUT_TARGET_REPO required"
    exit 1
fi

if [ -z "$INPUT_PATH_MAPPING" ]; then
    echo "Var INPUT_PATH_MAPPING required"
    exit 1
fi

gh auth login --with-token <<< "${INPUT_GITHUB_TOKEN}"

git config --global user.email "${INPUT_GIT_EMAIL:-73976634+loft-bot@users.noreply.github.com}" "noreply@loft.sh"
git config --global user.name "${INPUT_GIT_USERNAME:-Loft Bot}" "Repo Sync Bot"

SOURCE_REPO_DIR=$PWD
TARGET_REPO_DIR=$(mktemp -d)
GIT_FOLDER_BACKUP_DIR=$(mktemp -d)

if [ -z "$INPUT_TARGET_REPO_DIR" ]; then
    # Clone target repo
    git clone "https://${INPUT_GITHUB_TOKEN}@github.com/${INPUT_TARGET_REPO}.git" "$TARGET_REPO_DIR"
else
    # Use already cloned repo
    TARGET_REPO_DIR = $INPUT_TARGET_REPO_DIR
fi

cd $TARGET_REPO_DIR
git remote set-url origin "https://${INPUT_GITHUB_TOKEN}@github.com/${INPUT_TARGET_REPO}.git"

git fetch -a

if [ "$INPUT_PR_TARGET_BRANCH" = "main" ]; then
    MAIN_BRANCH_EXISTS=$(git show-ref "$INPUT_PR_TARGET_BRANCH" || echo "")

    if [ -z "$MAIN_BRANCH_EXISTS" ]; then
        INPUT_PR_TARGET_BRANCH="master"
    fi
fi

if [ -z "$INPUT_PR_SOURCE_BRANCH" ]; then
    INPUT_PR_SOURCE_BRANCH=${INPUT_PR_TARGET_BRANCH}
else
    BRANCH_EXISTS=$(git show-ref "$INPUT_PR_SOURCE_BRANCH" || echo "")
    if [ -z "$BRANCH_EXISTS" ]; then
        git checkout -b "$INPUT_PR_SOURCE_BRANCH"
    else
        git checkout "$INPUT_PR_SOURCE_BRANCH"
    fi
fi

USE_PR=true
if [ "$INPUT_PR_SOURCE_BRANCH" = "$INPUT_PR_TARGET_BRANCH" ]; then
    USE_PR=false
fi


export IFS=";"
for PATH_MAPPING in $INPUT_PATH_MAPPING; do

    IFS=":" read -a PATH_MAP <<< "$PATH_MAPPING"

    SOURCE_PATH="${SOURCE_REPO_DIR}/${PATH_MAP[0]}"
    if [ -z "${PATH_MAP[1]}" ]; then
        TARGET_PATH="${TARGET_REPO_DIR}/${PATH_MAP[0]}"
    else
        TARGET_PATH="${TARGET_REPO_DIR}/${PATH_MAP[1]}"
    fi

    if [ -d "$TARGET_REPO_DIR/.git" ]; then
        mv "$TARGET_REPO_DIR/.git" "$GIT_FOLDER_BACKUP_DIR/"
    fi

    if ! [ -f "$SOURCE_PATH" ] && [ -d "$TARGET_PATH" ]; then
        rm -rf $TARGET_PATH/*
    else
        rm -rf "$TARGET_PATH"
    fi

    if [ -d "$GIT_FOLDER_BACKUP_DIR/.git" ]; then
        mv "$GIT_FOLDER_BACKUP_DIR/.git" "$TARGET_REPO_DIR/"
    fi
    
    if [ -d "$SOURCE_PATH" ]; then
        TARGET_PATH="${TARGET_PATH%/*}"
    fi

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

    cd $TARGET_REPO_DIR     # DO NOT REMOVE / Must ensure workdir if it was recreated

    git add -A

    git commit -m "$INPUT_COMMIT_MSG" || echo "Skipped commit"

done

cd "$REPO_DIR"

git push -u origin HEAD:$INPUT_PR_SOURCE_BRANCH || git push --force -u origin HEAD:$INPUT_PR_SOURCE_BRANCH || echo "Skipped push"

if [ "$USE_PR" = true ]; then

    PR_STATE=$(gh pr view "$INPUT_PR_SOURCE_BRANCH" --json state --template "{{.state}}" || echo "UNKNOWN")
    if ! [ "$PR_STATE" = "OPEN" ]; then
        gh pr create --title "${INPUT_PR_TITLE:-chore: repo-sync}" \
                    --body "Repo sync" \
                    --base "$INPUT_PR_TARGET_BRANCH" \
                    --head "$INPUT_PR_SOURCE_BRANCH"
    fi

fi
