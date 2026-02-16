#!/usr/bin/bash

declare -A PAGES_CACHE
CURRENT_PAGE=1

fetchPage() {
    local PAGE_NUM="$1"

    [[ -n "${PAGES_CACHE[$PAGE_NUM]}" ]] && return 0

    notify info "Please Wait !!\n$([[ $PAGE_NUM -eq 1 ]] && echo "Scraping versions list for $APP_NAME from apkmirror.com..." || echo "Fetching next page...")"

    local PAGE_CONTENT
    PAGE_CONTENT=$("${CURL[@]}" -A "$USER_AGENT" "https://www.apkmirror.com/uploads/page/$PAGE_NUM/?appcategory=$APKMIRROR_APP_NAME" 2>/dev/null)

    PAGES_CACHE[$PAGE_NUM]=$(
        pup -c 'div.widget_appmanager_recentpostswidget div.listWidget div:not([class]) json{}' <<< "$PAGE_CONTENT" |
            jq -c '[.[].children as $CHILDREN | {
                version: $CHILDREN[1].children[0].children[1].text,
                info: $CHILDREN[0].children[0].children[1].children[0].children[0].children[0]
            } | select(.version != null and .info.text != null and .info.href != null) | {
                version: .version,
                tag: (.info.text | ascii_downcase | if test("beta") then "[BETA]" elif test("alpha") then "[ALPHA]" else "[STABLE]" end),
                url: .info.href
            }]'
    )

    if [[ "${PAGES_CACHE[$PAGE_NUM]}" == "[]" ]]; then
        notify msg "Unable to fetch versions !!\nThere is some problem with your internet connection. Disable VPN or Change your network."
        TASK="CHOOSE_APP"
        return 1
    fi
}

showRecommendedVersions() {
    local SELECTED_VERSION EXIT_CODE STORED_VER=""

    STORED_APK=$(ls "apps/$APP_NAME/"*.apk 2>/dev/null | grep -v -- "-" | head -n 1)
    [[ -n "$STORED_APK" ]] && STORED_VER=$(basename "$STORED_APK" .apk)

    readarray -t RECOMMENDED_LIST < <(
        jq -nrc --arg PKG "$PKG_NAME" --arg INSTALLED "$INSTALLED_VERSION" --arg STORED "$STORED_VER" --argjson PATCHES "$AVAILABLE_PATCHES" '
            ($PATCHES[] | select(.pkgName == $PKG) | .versions // []) as $REC |
            (if $STORED != "" then [{
                ver: $STORED,
                tag: (["[RECENT]"]
                    + (if $REC | index($STORED) then ["[RECOMMENDED]"] else [] end)
                    + (if $STORED == $INSTALLED then ["[INSTALLED]"] else [] end)
                    | join(""))
            }] else [] end) +
            [if ($REC | length) > 0 then
                $REC | reverse | .[] | select(. != $STORED) | {
                    ver: .,
                    tag: (if . == $INSTALLED then "[INSTALLED]" else "[RECOMMENDED]" end)
                }
            else empty end] |
            .[] | {version: .ver, tag: .tag, url: null}, "\(.ver)|\(.tag)"
        '
    )

    if [ "${#RECOMMENDED_LIST[@]}" -eq 0 ]; then
        showMoreVersions
        return $?
    fi

    SELECTED_VERSION=$(
        "${DIALOG[@]}" --title '| Recommended Versions |' --no-tags --column-separator "|" \
            --ok-label 'Select' --cancel-label 'Back' --extra-button --extra-label 'More versions' \
            --menu "$NAVIGATION_HINT" -1 -1 0 "${RECOMMENDED_LIST[@]}" 2>&1 >/dev/tty
    )
    EXIT_CODE=$?

    case "$EXIT_CODE" in
        0)
            APP_VER=$(jq -nrc --argjson V "$SELECTED_VERSION" '$V.version | sub(" "; ""; "g")')
            APP_DL_URL="https://www.apkmirror.com${APKMIRROR_APP_URL}${APKMIRROR_APP_NAME}-$(echo "$APP_VER" | sed 's/\./-/g')-release/"
            ;;
        1) TASK="CHOOSE_APP"; return 1 ;;
        3) showMoreVersions; return $? ;;
    esac
}

showMoreVersions() {
    local SELECTED_VERSION ACTION

    while true; do
        fetchPage "$CURRENT_PAGE" || return 1

        readarray -t PAGE_LIST < <(
            jq -rc --arg INSTALLED_VERSION "$INSTALLED_VERSION" --arg PKG_NAME "$PKG_NAME" --argjson AVAILABLE_PATCHES "$AVAILABLE_PATCHES" '
                (($AVAILABLE_PATCHES[] | select(.pkgName == $PKG_NAME) | .versions) // []) as $SUPPORTED |
                .[] | .version as $V |
                if ($SUPPORTED | index($V)) != null then .tag = "[RECOMMENDED]"
                elif $V == $INSTALLED_VERSION then .tag = "[INSTALLED]"
                else . end |
                ., "\(.version)|\(.tag)"
            ' <<< "${PAGES_CACHE[$CURRENT_PAGE]}"
        )

        local MENU_LIST=()
        [[ $CURRENT_PAGE -gt 1 ]] && MENU_LIST+=('{"action":"prev"}' '<<<<<')
        MENU_LIST+=("${PAGE_LIST[@]}")
        MENU_LIST+=('{"action":"next"}' '>>>>>')

        if ! SELECTED_VERSION=$(
            "${DIALOG[@]}" --title "| Version Selection Menu (Page $CURRENT_PAGE) |" --no-tags --column-separator "|" \
                --ok-label 'Select' --cancel-label 'Back' \
                --menu "$NAVIGATION_HINT" -1 -1 0 "${MENU_LIST[@]}" 2>&1 >/dev/tty
        ); then
            [[ ${#RECOMMENDED_LIST[@]} -gt 0 ]] && showRecommendedVersions && return $?
            TASK="CHOOSE_APP"; return 1
        fi

        ACTION=$(jq -r '.action // empty' <<< "$SELECTED_VERSION" 2>/dev/null)
        case "$ACTION" in
            prev) ((CURRENT_PAGE--)) ;;
            next) ((CURRENT_PAGE++)) ;;
            *)
                APP_VER=$(jq -nrc --argjson V "$SELECTED_VERSION" '$V.version | sub(" "; ""; "g")')
                APP_DL_URL=$(jq -nrc --argjson V "$SELECTED_VERSION" '"https://www.apkmirror.com" + $V.url')
                return 0
                ;;
        esac
    done
}

chooseVersion() {
    unset APP_VER APP_DL_URL
    internet || return 1
    getInstalledVersion
    showRecommendedVersions
}
