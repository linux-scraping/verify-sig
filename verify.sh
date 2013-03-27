#!/bin/bash -e

usage() {
	echo "Simple script to verify a grsecurity signature" >&2
	echo "usage: $0 [linux-git-directory]" >&2
	exit 1
}

GIT_DIR="${1:-.}"
if ! cd "${GIT_DIR}"; then
	usage
fi
if [ ! -d ".git" ]; then
	usage
fi

NEW_COMMIT="HEAD"
GRSEC_PATCH="$(git log -1 --format=%s | awk '$1=="Import" { print $2 }')"
SIG_TREE="$(git cat-file commit "${NEW_COMMIT}" | awk '$1=="Signature-tree:" { print $2 }')"

ORIG_TAG="$(git cat-file blob "${SIG_TREE}:orig")"
LINUX_VERSION="$(git describe "${ORIG_TAG}")"

if [ -z "${LINUX_VERSION}" ]; then
	usage
fi

echo "Patch: ${GRSEC_PATCH}"
echo "Linux: ${LINUX_VERSION}"

TMP="$(mktemp 2>/dev/null || echo ./grsec.patch)"
cleanup() {
	trap - QUIT INT TERM EXIT
	rm -f -- "${TMP}" 2>/dev/null
}
trap cleanup QUIT INT TERM EXIT

# Index diff only
[ "$(sed -r '/^(---|\+\+\+|@@|-index|\+index) /d' <(git cat-file blob "${SIG_TREE}:diff") | wc -l)" -eq 0 ]

# PGP signature
git diff --patience --full-index "${ORIG_TAG}" "${NEW_COMMIT}" > "${TMP}"
patch "${TMP}" < <(git cat-file blob "${SIG_TREE}:diff") >/dev/null
gpg --verify <(git cat-file blob "${SIG_TREE}:sig") "${TMP}"
