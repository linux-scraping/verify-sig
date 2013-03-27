#!/bin/bash -e

usage() {
	echo "Simple script to verify a grsecurity signature" >&2
	echo "usage: $0 [git-commit]" >&2
	exit 1
}

COMMIT="${1:-HEAD}"
git cat-file commit "${COMMIT}" >/dev/null

SIG_TREE="$(git cat-file commit "${COMMIT}" | awk '$1=="Signature-tree:" { print $2 }')"

NEW_TREE="$(git cat-file blob "${SIG_TREE}:new")"
[ "$(git cat-file commit "${COMMIT}" | awk 'NR==1 && $1=="tree" { print $2 }')" == "${NEW_TREE}" ]

ORIG_TAG="$(git cat-file blob "${SIG_TREE}:orig")"
PATCH="$(git log -1 --format=%s "${COMMIT}" | awk '$1=="Import" { print $2 }')"
if [ -z "${PATCH}" ]; then
	usage
fi
LINUX_VERSION="$(git describe "${ORIG_TAG}")"
if [ -z "${LINUX_VERSION}" ]; then
	usage
fi

echo "Patch: ${PATCH}"
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
git diff --patience --full-index "${ORIG_TAG}" "${NEW_TREE}" > "${TMP}"
patch "${TMP}" < <(git cat-file blob "${SIG_TREE}:diff") >/dev/null
gpg --verify <(git cat-file blob "${SIG_TREE}:sig") "${TMP}"
