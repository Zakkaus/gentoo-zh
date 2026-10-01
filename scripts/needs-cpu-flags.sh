#!/usr/bin/env bash
# usage: needs-cpu-flags.sh <atom>; exit 0 if baseline flags leave REQUIRED_USE unsatisfied.

atom=${1:?atom}
# A masked package never reports REQUIRED_USE, so accept every keyword and license.
output=$(ACCEPT_KEYWORDS="~$(portageq envvar ARCH)" ACCEPT_LICENSE="*" \
	emerge --pretend --quiet --nodeps "${atom}" 2>&1)
grep -q REQUIRED_USE <<<"${output}"
