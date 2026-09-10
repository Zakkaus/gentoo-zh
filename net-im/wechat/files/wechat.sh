#!/bin/bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

declare -a user_wechat_flags
if [[ -f "${XDG_CONFIG_HOME}/wechat-flags.conf" ]]; then
  mapfile -t user_wechat_flags <<<"$(grep -v '^#' "${XDG_CONFIG_HOME}/wechat-flags.conf")"
  echo "User WeChat flags:" "${user_wechat_flags[@]}"
fi

if [[ -z "${QT_QPA_PLATFORM:-}" ]]; then
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    export QT_QPA_PLATFORM="wayland;xcb"
  else
    export QT_QPA_PLATFORM="xcb"
  fi
fi

export QT_AUTO_SCREEN_SCALE_FACTOR=1
export GTK_USE_PORTAL=1

exec /opt/wechat/wechat "${user_wechat_flags[@]}" "$@"
