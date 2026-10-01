#!/usr/bin/env bash
# usage: nvchecker-eix.sh
set -euo pipefail

echo "::group::eselect repository add and sync"
repo_name=$(cat profiles/repo_name)
eselect repository add "$repo_name" git "file://${PWD}"
emerge --sync "$repo_name"
egencache --jobs="$(nproc)" --update --repo "$repo_name" &> /dev/null
eix-update
echo "::endgroup::"
echo "::group::eix search packages"
pkgs=$(
    # Use availableversions minus live versions because bestversion selects 9999.
    # shellcheck disable=SC2016
    ACCEPT_LICENSE="*" ACCEPT_KEYWORDS="~amd64 ~arm64 ~loong ~riscv" EIX_LIMIT=0 \
    NONLIVE='{first}{!*nv}{}{!plainversion=9999}{!ishardmasked}{isstable}{*nv=<version>}{}{}{}{last}{$nv}<category>/<name>-<$nv>\n{}{}' \
        eix --pure-packages --in-overlay "$repo_name" --format '<availableversions:NONLIVE>' || [ "$?" -eq 1 ]
)
if [ -n "$pkgs" ]; then
    mapfile -t atoms <<< "$pkgs"
    pkgs=$(qatom -F "\"%{CATEGORY}/%{PN}\": \"%{PV}\"," "${atoms[@]}")
fi
pkgs="{ ${pkgs%,} }"
echo "$pkgs"
{
    echo 'pkgs<<EOF'
    echo "$pkgs"
    echo 'EOF'
} >> "$GITHUB_OUTPUT"
echo "::endgroup::"
