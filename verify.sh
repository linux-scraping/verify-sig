#!/bin/bash -e
#
# verify.sh - Simple script to verify a grsecurity signature
#
# Copyright (C) 2013  Mickaël Salaün <mic@digikod.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details: <http://gnu.org/licenses/>.


usage() {
	local msg="$1"
	if [ -n "${msg}" ]; then
		echo "${msg}"
		echo
	fi
	echo "usage: $0 [git-commit]" >&2
	exit 1
}

error() {
	echo "$*" >&2
	exit 1
}

COMMIT="${1:-HEAD}"
if ! git cat-file commit "${COMMIT}" &>/dev/null; then
	usage "Bad commit"
fi

SIG_TREE="$(git cat-file commit "${COMMIT}" | awk '$1=="Signature-tree:" { print $2 }')"
if [ -z "${SIG_TREE}" ]; then
	usage "No Signature-tree in commit"
fi

NEW_TREE="$(git cat-file blob "${SIG_TREE}:new")"
if [ "$(git cat-file commit "${COMMIT}" | awk 'NR==1 && $1=="tree" { print $2 }')" != "${NEW_TREE}" ]; then
	error "Inconsistent commit and Signature-tree"
fi

PATCH="$(git log -1 --format=%s "${COMMIT}" | awk '$1=="grsec:" && $2=="Import" { print $3 }')"
if [ -z "${PATCH}" ]; then
	usage "No patch import in commit"
fi

ORIG_TAG="$(git cat-file blob "${SIG_TREE}:orig")"
LINUX_VERSION="$(git describe -- "${ORIG_TAG}")"
if [ -z "${LINUX_VERSION}" ]; then
	error "No Linux tag"
fi

#DIFF_OPTS="$(git cat-file blob "${SIG_TREE}:params")"
#if [ "$(echo -n "${DIFF_OPTS}" | sed -r 's/(--(patience|full-index) ?)+/'


echo "Patch: ${PATCH}"
echo "Tree: ${NEW_TREE}"
echo "Linux: ${LINUX_VERSION}"

# Extra tag verification
git verify-tag "${ORIG_TAG}"

# Index diff only
if [ "$(sed -r '/^(---|\+\+\+|@@|-index|\+index) /d' <(git cat-file blob "${SIG_TREE}:delta") | wc -l)" -ne 0 ]; then
	error "Suspicious Signature-tree content"
fi

TMP="$(mktemp 2>/dev/null || echo ./grsec.patch)"
cleanup() {
	trap - QUIT INT TERM EXIT
	rm -f -- "${TMP}" 2>/dev/null
}
trap cleanup QUIT INT TERM EXIT

# PGP signature
git diff --patience --full-index "${ORIG_TAG}" "${NEW_TREE}" > "${TMP}"
patch "${TMP}" < <(git cat-file blob "${SIG_TREE}:delta") >/dev/null
gpg --verify <(git cat-file blob "${SIG_TREE}:sig") "${TMP}"
