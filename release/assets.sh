#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 unemu contributors.
#
# Build the release assets of one tag of this repository:
#   ide_xtp-r638-ata1f0-8k.bin          the xtp-ata1f0 flake output (8 KiB ROM)
#   xtide-universal-bios-r638-src.tar   its corresponding source
#   SHA256SUMS                          the SHA-256 of both
#
# The source archive is the upstream r638 trunk, unmodified, plus a NOTICE
# (release/source-notice.txt), in a GNU tar ustar archive with fixed member
# order, timestamps (r638's commit time), owners and modes. The trunk is taken
# from the git-svn commit of r638, an ancestor of every release tag; the
# release tag may add files of its own but must not change upstream's. The
# archived trunk must assemble to the same upstream images the ROM is made
# from. The recipe and the NOTICE are the ones unemupc98's firmware fetch
# script pins, so both give the same bytes; the script checks the ROM and the
# archive against those pins before it writes anything.
#
# Usage: release/assets.sh <tag> <output directory>
# Run it from a clone that has the tag and its history, inside `nix develop`
# (GNU tar, nasm, make; git from the host).
set -euo pipefail

if [ $# -ne 2 ]; then
	echo "usage: $0 <tag> <output directory>" >&2
	exit 2
fi
TAG="$1"
OUT="$2"

unset TAR_OPTIONS
case "$(tar --version 2>/dev/null)" in
	*"GNU tar"*) ;;
	*)
		echo "GNU tar is required: run this script inside nix develop" >&2
		exit 1
		;;
esac
for tool in nasm make git; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "missing $tool: run this script inside nix develop" >&2
		exit 1
	fi
done

# The upstream revision every release of this branch is built from: the
# git-svn commit of trunk r638 and the date its downloads embed.
SVN_ID="git-svn-id: https://www.xtideuniversalbios.org/svn/xtideuniversalbios/trunk@638 143130fb-dee8-9d2b-0d25-209ee59ef9c5"
UPSTREAM_COMMIT="c144a2a1b796b9e3d38e9d080d0369202018f776"
SOURCE_DATE="2026-06-09"
SOURCE_NAME="xtide-universal-bios-r638-src"
ROM_NAME="ide_xtp-r638-ata1f0-8k.bin"
# The bytes unemupc98 pins (catalogue entry xub-r638-xtp-ata1f0 and its
# fetch script), also quoted in the NOTICE. A release must reproduce both.
ROM_SHA256="54975501e6887c836b8d57e7aad78421e745a9b71e250f94d5d1f9631eab1513"
SOURCE_ARCHIVE_SHA256="7bbd5de269f4e1d52ae30b52531fcda842709b9ae49166ac249f9b37187b91e8"
# Directories of the r638 trunk that hold no files. Subversion exports them,
# git cannot record them.
EMPTY_DIRS=(
	Assembly_Library/Build
	BIOS_Drive_Information_Tool/Build
	BIOS_Drive_Information_Tool/Inc
	Configurator/Build
	Serial_Server/build
	XTIDE_Universal_BIOS/Build
	XTIDE_Universal_BIOS_Configurator_v2/Build
)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
REVISION="$(git -C "$REPO" rev-parse --verify "refs/tags/$TAG^{commit}")"
# The path goes into a flake URL unencoded.
case "$REPO$TAG" in
	*[!A-Za-z0-9._/+-]*)
		echo "the clone path and the tag may only use A-Z a-z 0-9 . _ / + -: $REPO, $TAG" >&2
		exit 1
		;;
esac
FLAKE="git+file://$REPO?ref=refs/tags/$TAG&rev=$REVISION"
NIX=(nix --extra-experimental-features "nix-command flakes")

if ! git -C "$REPO" cat-file -e "$UPSTREAM_COMMIT^{commit}" 2>/dev/null \
	|| ! git -C "$REPO" log -1 --format=%B "$UPSTREAM_COMMIT" | grep -qxF "$SVN_ID"; then
	echo "$UPSTREAM_COMMIT is not the git-svn commit of r638 in this clone (fetch the full history)" >&2
	exit 1
fi
if ! git -C "$REPO" merge-base --is-ancestor "$UPSTREAM_COMMIT" "$REVISION"; then
	echo "$TAG does not descend from r638 ($UPSTREAM_COMMIT)" >&2
	exit 1
fi
# The fork adds files beside upstream's but leaves upstream's top-level
# entries exactly as r638 has them.
mapfile -t UPSTREAM_ENTRIES < <(git -C "$REPO" ls-tree --name-only "$UPSTREAM_COMMIT")
if ! git -C "$REPO" diff --quiet "$UPSTREAM_COMMIT" "$REVISION" -- "${UPSTREAM_ENTRIES[@]}"; then
	echo "$TAG changes upstream files of r638:" >&2
	git -C "$REPO" diff --stat "$UPSTREAM_COMMIT" "$REVISION" -- "${UPSTREAM_ENTRIES[@]}" >&2
	exit 1
fi
SOURCE_EPOCH="$(git -C "$REPO" log -1 --format=%ct "$UPSTREAM_COMMIT")"

echo "building $TAG ($REVISION) from r638 ($UPSTREAM_COMMIT)"
ROM_STORE="$("${NIX[@]}" build --no-link --print-out-paths "$FLAKE#xtp-ata1f0")"
XTP_STORE="$("${NIX[@]}" build --no-link --print-out-paths "$FLAKE#ide-xtp")"
AT_STORE="$("${NIX[@]}" build --no-link --print-out-paths "$FLAKE#ide-at")"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null || true; rm -rf "$WORK"' EXIT

# The configured 8 KiB option ROM; the flake has already checked its pinned
# SHA-256, its header and its checksum.
cp "$ROM_STORE/$ROM_NAME" "$WORK/$ROM_NAME"
chmod 0644 "$WORK/$ROM_NAME"
SIZE="$(wc -c < "$WORK/$ROM_NAME" | tr -d '[:space:]')"
HEADER="$(od -An -tx1 -N3 "$WORK/$ROM_NAME" | tr -d ' \n')"
if [ "$SIZE" -ne 8192 ] || [ "$HEADER" != "55aa10" ]; then
	echo "invalid option ROM: expected 8192 bytes and header 55aa10" >&2
	exit 1
fi

STAGE="$WORK/source/$SOURCE_NAME"
mkdir -p "$STAGE/trunk"
# Upstream's bytes as committed: no line-ending conversion or attributes from
# the host's git configuration (most r638 text files have CRLF line ends).
git -C "$REPO" -c core.autocrlf=false -c core.eol=lf -c core.attributesFile=/dev/null \
	archive --format=tar "$UPSTREAM_COMMIT" | tar -x -C "$STAGE/trunk"
for dir in "${EMPTY_DIRS[@]}"; do
	if [ -e "$STAGE/trunk/$dir" ]; then
		echo "expected $dir to be absent from the git tree of r638" >&2
		exit 1
	fi
	mkdir -p "$STAGE/trunk/$dir"
done
# The NOTICE as the tag has it, not as the working tree does.
git -C "$REPO" show "$REVISION:release/source-notice.txt" > "$STAGE/NOTICE"

# The archived trunk must still assemble to both upstream images, as the
# NOTICE says. Build in a copy so no build output reaches the archive.
cp -R "$STAGE/trunk" "$WORK/check"
make -C "$WORK/check/XTIDE_Universal_BIOS" at xtplus \
	AS="nasm -D__DATE__='\"$SOURCE_DATE\"'" > /dev/null
for image in "$XTP_STORE/ide_xtp.bin" "$AT_STORE/ide_at.bin"; do
	if ! cmp -s "$image" "$WORK/check/XTIDE_Universal_BIOS/Build/$(basename "$image")"; then
		echo "the archived trunk does not assemble to $(basename "$image")" >&2
		exit 1
	fi
done

LC_ALL=C tar --create --file="$WORK/source.tar" --directory="$WORK/source" \
	--format=ustar --sort=name --hard-dereference --mtime="@$SOURCE_EPOCH" \
	--owner=0 --group=0 --numeric-owner --mode='a=rX,u+w,ug-s' "$SOURCE_NAME"

check_sha256() {
	local actual
	actual="$(sha256sum "$1" | awk '{print $1}')"
	if [ "$actual" != "$2" ]; then
		echo "SHA-256 of $(basename "$1") is $actual, expected $2" >&2
		exit 1
	fi
}
check_sha256 "$WORK/$ROM_NAME" "$ROM_SHA256"
check_sha256 "$WORK/source.tar" "$SOURCE_ARCHIVE_SHA256"

mv "$WORK/$ROM_NAME" "$OUT/$ROM_NAME"
mv "$WORK/source.tar" "$OUT/$SOURCE_NAME.tar"
(cd "$OUT" && sha256sum "$ROM_NAME" "$SOURCE_NAME.tar" > SHA256SUMS)
cat "$OUT/SHA256SUMS"
