# The bump workers' environment, built once instead of ~9.5 min per worker. The tree goes
# out in the layer that fetched it: the workers webrsync their own.
FROM gentoo/stage3:amd64-desktop-openrc

RUN emerge-webrsync --no-pgp-verify \
 && { \
      # MAKEOPTS and CPU_FLAGS_X86 describe the runner, so the worker sets those itself
      echo 'FEATURES="${FEATURES} getbinpkg buildpkg"'; \
      echo 'PORTAGE_ELOG_CLASSES="qa warn error"'; \
      echo 'PORTAGE_ELOG_SYSTEM="save"'; \
      # several opted-in packages are non-free; masked ones defer as a "build failure"
      echo 'ACCEPT_LICENSE="*"'; \
    } >> /etc/portage/make.conf \
 && mkdir -p /etc/portage/package.use \
 # match the binhost's USE or getbinpkg rejects its binpkgs and builds from source; keep
 # in sync with emerge-on-pr's list
 && printf '%s\n' 'dev-qt/qtwebengine bindist' 'net-libs/webkit-gtk keyring' \
      > /etc/portage/package.use/ci-binhost \
 # Xvfb runs the GUI launch probe; dropping it only skips the probe
 && echo 'x11-base/xorg-server xvfb minimal -xorg' > /etc/portage/package.use/autobump-xvfb \
 && getuto \
 && install -dm775 -o root -g portage /var/cache/distfiles \
 # curl because stage3 ships only wget and the DeadUrl recheck needs it; portage-utils for
 # the --version smoke, iwdevtools for qa-vdb
 && emerge --quiet --getbinpkg --autounmask=y --autounmask-write=y --autounmask-continue=y \
      dev-lang/ruby dev-vcs/git dev-util/pkgdev dev-util/pkgcheck app-portage/portage-utils \
      app-portage/iwdevtools dev-util/github-cli app-misc/jq net-misc/curl \
      app-portage/cpuid2cpuflags x11-base/xorg-server \
 && rm -rf /var/db/repos/gentoo /var/cache/distfiles/* /var/cache/binpkgs/*
