#!/bin/bash -e

usage() {
	echo "Simple script to verify a grsecurity signature" >&2
	echo "usage: $0 <grsecurity-version> [linux-git-directory]" >&2
	exit 1
}

GRSEC_VERSION="$1"
GIT_DIR="$2"
LINUX_VERSION="$(echo "${GRSEC_VERSION}" | sed -nr 's/[.0-9]+-([.0-9]+)-[0-9]+/\1/p')"

if [ -z "${LINUX_VERSION}" ]; then
	usage
fi
if ! cd "${GIT_DIR}"; then
	usage
fi
if [ ! -d ".git" ]; then
	usage
fi

TMP="$(mktemp 2>/dev/null || echo ./grsec.patch)"
cleanup() {
	trap - QUIT INT TERM EXIT
	rm -f -- "${TMP}" 2>/dev/null
}
trap cleanup QUIT INT TERM EXIT

SIG_TREE="$(git cat-file commit HEAD | awk '$1=="Signature-Tree:" { print $2 }')"
# Index diff only
[ "$(sed -r '/^(---|\+\+\+|@@|-index|\+index) /d' <(git cat-file blob "${SIG_TREE}:diff") | wc -l)" -eq 0 ]

# PGP signature
git diff --patience --full-index "v${LINUX_VERSION}" HEAD > "${TMP}"
patch "${TMP}" < <(git cat-file blob "${SIG_TREE}:diff") >/dev/null
gpg --verify <(git cat-file blob "${SIG_TREE}:sig") "${TMP}"
