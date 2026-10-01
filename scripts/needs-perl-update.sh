#!/usr/bin/env bash
# usage: needs-perl-update.sh <atom>; exit 0 if the atom's binpkg dependencies would replace dev-lang/perl.

atom=${1:?atom}
# A masked package never reports its dependencies, so accept every keyword and license.
output=$(ACCEPT_KEYWORDS="~$(portageq envvar ARCH)" ACCEPT_LICENSE="*" FEATURES="getbinpkg" \
	emerge --pretend --quiet --onlydeps "${atom}" 2>&1)
grep -q 'dev-lang/perl[-:]' <<<"${output}"
