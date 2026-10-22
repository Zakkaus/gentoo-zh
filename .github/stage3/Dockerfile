ARG PROFILE
FROM gentoo/stage3:${PROFILE} AS update

# stage3 has no world file: @world covers only @system, and depclean would drop the rest.
# The Gentoo tree stays, so a job does not sync its own copy of the same daily snapshot.
RUN emerge-webrsync --no-pgp-verify \
 && getuto \
 && FEATURES="getbinpkg" emerge --quiet --update --deep --newuse --with-bdeps=y @installed \
 && FEATURES="getbinpkg" emerge --quiet @preserved-rebuild \
 && rm -rf /var/cache/distfiles/* /var/cache/binpkgs/*

# one layer, as gentoo/stage3 itself is built: the update layer would duplicate every replaced file
FROM scratch
COPY --from=update / /
CMD ["/bin/bash"]
