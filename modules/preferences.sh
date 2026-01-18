#!/usr/bin/bash

configure() {
    local CONFIG_OPTS UPDATED_CONFIG THEME
    local PREV_BETA="$REVANCIFY_XISR_BETA"
    CONFIG_OPTS=(
        "LIGHT_THEME" "Light Theme" "$LIGHT_THEME"
        "PREFER_SPLIT_APK" "Prefer Split APK" "$PREFER_SPLIT_APK"
        "USE_PRE_RELEASE" "Use Pre-release" "$USE_PRE_RELEASE"
        "LAUNCH_APP_AFTER_MOUNT" "Launch App After Mount" "$LAUNCH_APP_AFTER_MOUNT"
        "ALLOW_APP_VERSION_DOWNGRADE" "Allow App Version Downgrade" "$ALLOW_APP_VERSION_DOWNGRADE"
        "REVANCIFY_XISR_BETA" "Revancify Xisr Beta Updates" "$REVANCIFY_XISR_BETA"
    )

    readarray -t UPDATED_CONFIG < <(
        "${DIALOG[@]}" \
            --title '| Settings |' \
            --no-tags \
            --separate-output \
            --no-cancel \
            --ok-label 'Save' \
            --checklist "$NAVIGATION_HINT\n$SELECTION_HINT" -1 -1 -1 \
            "${CONFIG_OPTS[@]}" \
            2>&1 > /dev/tty
    )

    sed -i "s|='on'|='off'|" .config

    for CONFIG_OPT in "${UPDATED_CONFIG[@]}"; do
        setEnv "$CONFIG_OPT" on update .config
    done

    source .config

    if [ "$PREV_BETA" = "off" ] && [ "$REVANCIFY_XISR_BETA" = "on" ]; then
        if ! "${DIALOG[@]}" --title "Enable Beta Updates?" --yes-label "Confirm" --no-label "Cancel" --yesno "Are you sure you want to enable Revancify Xisr beta updates?\n\nThis option enables beta/pre-release updates for Revancify Xisr itself.\nIt does NOT affect the stability or update channel of patches or the apps you install.\n\nBeta versions may include new features and bug fixes, but could also be less stable than regular releases.\n\nIf Revancify Xisr fails to launch after enabling beta, you can recover by running 'xisr -f'.\n\nYou can always turn this option off in the Settings menu.\n\nProceeding will restart Revancify Xisr." -1 -1; then
            sed -i "s|^REVANCIFY_XISR_BETA=.*|REVANCIFY_XISR_BETA='off'|" .config
            source .config
            configure
            return
        fi
        exec xisr
    elif [ "$PREV_BETA" = "on" ] && [ "$REVANCIFY_XISR_BETA" = "off" ]; then
        exec xisr
    fi

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="config/.DIALOGRC_$THEME"
}
