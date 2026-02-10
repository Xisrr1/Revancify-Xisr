#!/usr/bin/bash

SRC="$HOME/Revancify-Xisr"
source "$SRC/.info"

STORAGE="$HOME/storage/shared/Revancify-Xisr"

ARCH=$(getprop ro.product.cpu.abi)
DPI=$(getprop ro.sf.lcd_density)

USER_AGENT="APKUpdater"

DIALOG=(dialog --backtitle "Revancify Xisr ${VERSION}" --no-shadow --begin 2 0)

CURL=(curl -sL --fail-early --connect-timeout 2 --max-time 5 -H 'Cache-Control: no-cache')

WGET=(wget -qc --show-progress --user-agent="$USER_AGENT")

NAVIGATION_HINT="Navigate with [↑] [↓] [←] [→]"
SELECTION_HINT="Select with [SPACE]"