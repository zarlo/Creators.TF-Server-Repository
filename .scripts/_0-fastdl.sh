#!/bin/bash
# Helper functions
source .scripts/helpers.sh
# obvious
whoami
# ?
shopt -s globstar

SHA_BEFORE="$CI_COMMIT_BEFORE_SHA"
SHA_AFTER="$CI_COMMIT_SHA"

info "Comparing $SHA_BEFORE // $SHA_AFTER"
GIT_DIFF=$(git diff --name-only "$SHA_AFTER" "$SHA_BEFORE")

cd "$CI_PROJECT_DIR" || exit
#git checkout "$CI_COMMIT_REF_NAME"
#git reset --hard origin/"$CI_COMMIT_REF_NAME"

info "Repository path = $CI_PROJECT_DIR"

FASTDL_PATH="/var/www/fastdl/content/branches/$CI_COMMIT_REF_NAME";
cd tf || exit 1
while read -r pattern; do
    important "Pattern: ${pattern}"

    # We go through all the files of this pattern and see if bz2 version is valid.
    for i in ./${pattern}; do

        # Skip missing files.
        [[ ! -f $i ]] && continue;

        ASSET_SRC_PATH=$(realpath "$i");
        ASSET_FASTDL_PATH=$FASTDL_PATH/$i;
        ASSET_BZ2_PATH=$ASSET_FASTDL_PATH.bz2;

        RECOMPRESS=0;

        # Recompress if bz2 file does not exist.
        [[ ! -f $ASSET_BZ2_PATH ]] && RECOMPRESS=1;

        # Recomress if checksums do not match.
        if [[ $RECOMPRESS = 0 ]]; then

            GIT_DIFF_ELEMENT=$(realpath --relative-to ./ "$i");

            # If it exist, let's first check if it changed.
            if [[ $(echo "$GIT_DIFF" | grep "$GIT_DIFF_ELEMENT") ]]; then
                RECOMPRESS=1;
            fi
        fi

        if [[ $RECOMPRESS = 1 ]]; then

            # Remove old bz2 if exists.
            [[ -f $ASSET_BZ2_PATH ]] && rm "$ASSET_BZ2_PATH";

            # Validate directories
            mkdir -p "${ASSET_FASTDL_PATH%/*}"

            # Copying the src file.
            cp "$ASSET_SRC_PATH" "$ASSET_FASTDL_PATH";

            info "Archiving $ASSET_FASTDL_PATH";
            bzip2 "$ASSET_FASTDL_PATH";
        fi
    done
done < ../.scripts/fastdl-patterns.txt
exit

