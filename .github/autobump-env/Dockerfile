# The bump workers' environment, built once and reused by every worker.
#
# Everything here is identical for all of them: the portage config, the trust keys and
# the ~80 tooling packages. Installing it per worker cost ~9.5 min each; from this image
# a worker starts ready.
#
# The gentoo tree is NOT kept: the workers webrsync it themselves, so a daily run gets a
# fresh tree from a weekly image. Removing it in the same layer that fetched it keeps the
# image from carrying a copy nobody reads.
FROM gentoo/stage3:amd64-desktop-openrc

RUN emerge-webrsync --no-pgp-verify \
 && { \
      # FEATURES keeps its ${...} so portage appends to the stage3 defaults. MAKEOPTS and
      # CPU_FLAGS_X86 are not set here: they depend on the runner, so the worker sets them.
      echo 'FEATURES="${FEATURES} getbinpkg buildpkg"'; \
      echo 'PORTAGE_ELOG_CLASSES="qa warn error"'; \
      echo 'PORTAGE_ELOG_SYSTEM="save"'; \
      # accept all licenses: several opted-in packages are non-free (-bin blobs,
      # CC-BY-NC, vendor EULAs). Without this emerge masks them and the bump churns
      # its retries then defers with a misleading "build failure" comment, forever.
      echo 'ACCEPT_LICENSE="*"'; \
    } >> /etc/portage/make.conf \
 && mkdir -p /etc/portage/package.use \
 # Align heavy-dep USE to the official binhost's binpkgs so getbinpkg actually USES them,
 # instead of rejecting a USE mismatch and rebuilding from source (which would blow the
 # op-timeout): the binhost builds webkit-gtk +keyring and qtwebengine +bindist, but the
 # desktop profile defaults them off. Keep this list in sync with emerge-on-pr's; extend
 # it if a heavy dep still shows [ebuild] in a real bump.
 && printf '%s\n' 'dev-qt/qtwebengine bindist' 'net-libs/webkit-gtk keyring' \
      > /etc/portage/package.use/ci-binhost \
 # Xvfb (minimal xorg-server) powers the advisory GUI launch probe: a GUI bump is
 # launched headless to see it does not crash on start. Drop the xorg-server line + this
 # package.use if the build cost is not worth it - the probe then just skips and the PR
 # still flags GUI apps for a manual check.
 && echo 'x11-base/xorg-server xvfb minimal -xorg' > /etc/portage/package.use/autobump-xvfb \
 && getuto \
 && install -dm775 -o root -g portage /var/cache/distfiles \
 # pkgdev/pkgcheck are dev-util/ now (pkgcore tools moved category); dev-lang/ruby runs
 # the engine. curl: the engine's finalize stage re-checks pkgcheck DeadUrl hits with it,
 # and stage3 ships only wget, so without it that probe crashes and defers the bump.
 # qlist (portage-utils) drives the --version smoke; qa-vdb (iwdevtools) checks RDEPEND
 # vs linked libs on source packages; cpuid2cpuflags is run per worker on its own CPU.
 && emerge --quiet --getbinpkg --autounmask=y --autounmask-write=y --autounmask-continue=y \
      dev-lang/ruby dev-vcs/git dev-util/pkgdev dev-util/pkgcheck app-portage/portage-utils \
      app-portage/iwdevtools dev-util/github-cli app-misc/jq net-misc/curl \
      app-portage/cpuid2cpuflags x11-base/xorg-server \
 && rm -rf /var/db/repos/gentoo /var/cache/distfiles/* /var/cache/binpkgs/*
