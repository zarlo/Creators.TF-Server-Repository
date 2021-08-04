#!/bin/bash

shopt -s globstar

SPCOMP_PATH=$(realpath "tf/addons/sourcemod/scripting/spcomp64")
COMPILED_DIR=$(realpath 'tf/addons/sourcemod/plugins/')
SCRIPTS_DIR=$(realpath 'tf/addons/sourcemod/scripting/')

chmod 744 "$SPCOMP_PATH"

git diff --name-only HEAD "$1" | grep "\.sp$" > ./00

# ==========================
# Compile all scripts that don't have any smxes
# ==========================

echo "Seeking for .sp in $SCRIPTS_DIR/**/*"

for p in "$SCRIPTS_DIR"/**/*
do
    if [ "${p##*.}" == 'sp' ]; then
        if [[ $p =~ "stac/" ]] || [[ $p =~ "include/" ]] || [[ $p =~ "disabled/" ]] || [[ $p =~ "external/" ]] || [[ $p =~ "economy/" ]]; then
            continue
        fi
        PLUGIN_NAME=$(realpath --relative-to "$SCRIPTS_DIR" "$p")
        PLUGIN_NAME=${PLUGIN_NAME%.*}
        PLUGIN_SCRIPT_PATH="$SCRIPTS_DIR/$PLUGIN_NAME.sp"
        PLUGIN_COMPILED_PATH="$COMPILED_DIR/$(basename "$PLUGIN_NAME").smx"

        if [[ ! -f "$PLUGIN_COMPILED_PATH" ]]; then
            echo "$PLUGIN_SCRIPT_PATH" >> ./00
        fi
    fi
done

echo "[INFO] Full compile list:"
echo "========================="
cat ./00
echo "========================="


echo "[INFO] Starting processing of plugin files."
while read -r p; do
    PLUGIN_NAME=$(realpath --relative-to "$SCRIPTS_DIR" "$p")
    PLUGIN_NAME=${PLUGIN_NAME%.*}
    PLUGIN_SCRIPT_PATH="$SCRIPTS_DIR/$PLUGIN_NAME.sp"
    PLUGIN_COMPILED_PATH="$COMPILED_DIR/$(basename "$PLUGIN_NAME").smx"


    if [[ ! -f "$PLUGIN_SCRIPT_PATH" ]]; then
        if [[ -f "$PLUGIN_COMPILED_PATH" ]]; then
            rm "$PLUGIN_COMPILED_PATH";
        fi
    fi

    if [[ $p =~ "stac/" ]] || [[ $p =~ "include/" ]] || [[ $p =~ "disabled/" ]] || [[ $p =~ "external/" ]] || [[ $p =~ "economy/" ]] || [[ ! -f "$PLUGIN_SCRIPT_PATH" ]]; then
        continue
    fi

    echo "$PLUGIN_SCRIPT_PATH";
    if [[ -f "$PLUGIN_SCRIPT_PATH" ]]; then
        $SPCOMP_PATH -D"$SCRIPTS_DIR" "$(realpath --relative-to "$SCRIPTS_DIR" "$PLUGIN_SCRIPT_PATH")" -o"$PLUGIN_COMPILED_PATH" -v0
    fi
done < ./00
rm ./00

echo "[INFO] All plugin files are recompiled."

exit;
