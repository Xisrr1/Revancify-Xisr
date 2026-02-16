#!/usr/bin/bash

selectFile() {
    local DIR="/storage/emulated/0/Download"
    
    while :; do
        local MAX_LENGTH=$(( $(tput cols) * 3 / 5 ))
        local ITEMS=() MENU_ITEMS=()
        [[ "$DIR" != "/storage/emulated/0" ]] && ITEMS+=("...")
        
        readarray -t -O ${#ITEMS[@]} ITEMS < <(
            {
                for d in "$DIR"/*/; do
                    [ -d "$d" ] || continue
                    d=${d%/}
                    printf '%s/\n' "${d##*/}"
                done
                for f in "$DIR"/*.apk "$DIR"/*.apkm; do
                    [ -f "$f" ] || continue
                    printf '%s\n' "${f##*/}"
                done
            } | sort -u
        )

        for ITEM in "${ITEMS[@]}"; do
            MENU_ITEMS+=("$ITEM")
            if [[ ${#ITEM} -gt $MAX_LENGTH ]]; then
                MENU_ITEMS+=("${ITEM:0:MAX_LENGTH-11}…${ITEM: -10}")
            else
                MENU_ITEMS+=("$ITEM")
            fi
            MENU_ITEMS+=("$ITEM")
        done
        
        local PICK
        PICK=$(
            "${DIALOG[@]}" \
                --title '| Import App |' \
                --no-tags \
                --item-help \
                --default-item "$([[ "$DIR" != "/storage/emulated/0" ]] && printf '%s' "${ITEMS[1]}" || printf '%s' "${ITEMS[0]}")" \
                --menu "$NAVIGATION_HINT\n\nCurrent Path: $DIR" $(( $(tput lines) - 3 )) -1 15 \
                "${MENU_ITEMS[@]}" \
                2>&1 >/dev/tty
        ) || { TASK="CHOOSE_APP"; return 1; }
        
        [[ "$PICK" == "..." ]] && { DIR=$(dirname "$DIR"); continue; }
        [[ -d "$DIR/${PICK%/}" ]] && { DIR="$DIR/${PICK%/}"; continue; }
        
        SELECTED_FILE="$DIR/$PICK"
        return 0
    done
}

extractMeta() {
    local APP_INFO
    FILE_PATH="$SELECTED_FILE"
    if [ "${SELECTED_FILE##*.}" == "apk" ]; then
        notify info "Please Wait !!\nExtracting data from \"$(basename "$FILE_PATH")\""
        if ! APP_INFO=$(./bin/aapt2 dump badging "$FILE_PATH"); then
            notify msg "The Apk you selected is not valid. Download again and retry."
            return 1
        fi
        APP_EXT="apk"
        PKG_NAME=$(grep -oP "(?<=package: name=')[^']+" <<< "$APP_INFO")
        APP_NAME=$(grep -oP "(?<=application-label:')[^']+" <<< "$APP_INFO" | sed -E 's/[.: ]+/-/g')
        SELECTED_VERSION=$(grep -oP "(?<=versionName=')[^']+" <<< "$APP_INFO")
    else
        if ! APP_INFO=$(unzip -qqp "$FILE_PATH" info.json 2> /dev/null); then
            notify msg "The Bundle you selected is not valid. Download again and retry."
            return 1
        fi
        if jq -e --arg ARCH "$ARCH" '.arches | index($ARCH) == null' <<< "$APP_INFO" &> /dev/null; then
            notify msg "The selected Apk Bundle doesn't contain $ARCH lib.\nChoose another file."
        fi
        APP_EXT="apkm"
        source <(jq -rc '
            "APP_NAME=\(.app_name)
            PKG_NAME=\(.pname)
            SELECTED_VERSION=\(.release_version)"
        ' <<< "$APP_INFO")
    fi
}

importApp() {
    unset PKG_NAME APP_NAME APP_VER
    local SELECTED_FILE FILE_PATH APP_EXT SELECTED_VERSION
    selectFile || return 1
    extractMeta || return 1
    APP_VER="${SELECTED_VERSION// /-}"
    getInstalledVersion
    if [ "$ALLOW_APP_VERSION_DOWNGRADE" == "off" ] &&
        jq -e '.[0] > .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$SELECTED_VERSION\"]" \
            &> /dev/null; then
        notify msg "The selected version $SELECTED_VERSION is lower then version $INSTALLED_VERSION installed on your device.\nPlease Select a higher version !!"
        return 1
    fi
    if ! "${DIALOG[@]}" \
        --title '| Proceed |' \
        --yes-label 'Import' \
        --no-label 'Back' \
        --yesno "The following data is extracted from the apk file you provided.\nApp Name    : $APP_NAME\nPackage Name: $PKG_NAME\nVersion     : $SELECTED_VERSION\nDo you want to proceed with this app?" -1 -1; then
        return 1
    fi
    mkdir -p "apps/$APP_NAME" &> /dev/null
    rm -rf apps/"$APP_NAME"/* &> /dev/null
    cp "$FILE_PATH" "apps/$APP_NAME/$APP_VER.$APP_EXT"
    if [ "$APP_EXT" == "apkm" ]; then
        antisplitApp || return 1
    fi
    findPatchedApp || return 1
}
