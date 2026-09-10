#!/bin/bash

set -euo pipefail

USER_RUN_DIR="/run/user/$(id -u)"
XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

declare -a user_bwrap_flags
if [[ -f "${XDG_CONFIG_HOME}/wechat-bwrap-flags.conf" ]]; then
  mapfile -t user_bwrap_flags <<<"$(grep -v '^#' "${XDG_CONFIG_HOME}/wechat-bwrap-flags.conf")"
  echo "User bubblewrap flags:" "${user_bwrap_flags[@]}"
fi

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

if [[ -e "${XDG_DATA_HOME}/wechat/home/.xwechat" && -e "${XDG_DATA_HOME}/wechat/home/xwechat_files" && ! -e "${HOME}/.xwechat" && ! -e "${HOME}/xwechat_files" ]]; then
  echo Mergeing data dirs...
  mv -v "${XDG_DATA_HOME}/wechat/home/.xwechat" "${HOME}/.xwechat"
  mv -v "${XDG_DATA_HOME}/wechat/home/xwechat_files" "${HOME}/xwechat_files"
  rm -r "${XDG_DATA_HOME}/wechat"
fi

mkdir -p "${HOME}"/{.xwechat,xwechat_files}

exec bwrap \
  --new-session \
  --cap-drop ALL \
  --unshare-user-try \
  --unshare-ipc \
  --unshare-pid \
  --unshare-cgroup-try \
  --dev-bind /dev /dev \
  --dev-bind /run/dbus /run/dbus \
  --ro-bind /usr /usr \
  --ro-bind /bin /bin \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /sys /sys \
  --ro-bind /etc/ld.so.cache /etc/ld.so.cache \
  --ro-bind /etc/localtime /etc/localtime \
  --ro-bind /etc/passwd /etc/passwd \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind /etc/machine-id /etc/machine-id \
  --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
  --ro-bind-try /etc/fonts /etc/fonts \
  --ro-bind-try /run/systemd/userdb /run/systemd/userdb \
  --proc /proc \
  --tmpfs /tmp \
  --tmpfs /sys/devices/virtual \
  --ro-bind /opt/wechat /opt/wechat \
  --bind "${HOME}/.xwechat" "${HOME}/.xwechat" \
  --bind "${HOME}/xwechat_files" "${HOME}/xwechat_files" \
  --bind "${USER_RUN_DIR}" "${USER_RUN_DIR}" \
  --bind-try "${HOME}/.pki" "${HOME}/.pki" \
  --ro-bind-try "${XAUTHORITY}" "${XAUTHORITY}" \
  --ro-bind-try "${HOME}/.fonts" "${HOME}/.fonts" \
  --ro-bind-try "${HOME}/.icons" "${HOME}/.icons" \
  --ro-bind-try "${XDG_DATA_HOME}/icons" "${XDG_DATA_HOME}/icons" \
  --ro-bind-try "${XDG_DATA_HOME}/fonts" "${XDG_DATA_HOME}/fonts" \
  --ro-bind-try "${XDG_CONFIG_HOME}/dconf" "${XDG_CONFIG_HOME}/dconf" \
  --ro-bind-try "${XDG_CONFIG_HOME}/fontconfig" "${XDG_CONFIG_HOME}/fontconfig" \
  --ro-bind-try "${XDG_CONFIG_HOME}/gtk-3.0" "${XDG_CONFIG_HOME}/gtk-3.0" \
  --ro-bind-try "${XDG_CONFIG_HOME}/pulse" "${XDG_CONFIG_HOME}/pulse" \
  --setenv QT_AUTO_SCREEN_SCALE_FACTOR 1 \
  --setenv GTK_USE_PORTAL 1 \
  "${user_bwrap_flags[@]}" \
  /opt/wechat/wechat "${user_wechat_flags[@]}" "$@"
