# XTIDE Universal BIOS — unemu fork

This repository is a git fork of the [XTIDE Universal BIOS](https://www.xtideuniversalbios.org/),
an option ROM that gives PC/XT and PC/AT-class machines an IDE (and serial, XT-CF,
JR-IDE and more) fixed-disk BIOS. Upstream is developed in Subversion by Tomi
Tilli (2009-2010) and the XTIDE Universal BIOS Team (2011-2026); see
`Copyrights.txt`, `license.txt` and the file headers.

The unemu family of emulators uses the r638 XT+ build, configured for a 16-bit
ATA controller at 1F0h, as the fixed-disk option ROM of the open AT machines of
**unemupc98** (catalogue entry `xub-r638-xtp-ata1f0`). This fork exists so that
ROM has a git home with upstream's history, a reproducible Nix build and GitHub
release assets that other unemu projects download by SHA-256, instead of
transforming upstream's binary download themselves.

## Repository layout

- The **main** branch is upstream's trunk, converted with git-svn, followed by
  unemu commits. Every upstream commit carries its `git-svn-id:` line
  (`…/trunk@<revision> 143130fb-dee8-9d2b-0d25-209ee59ef9c5`).
- Upstream's files stay as r638 has them, at the top level (`Assembly_Library/`,
  `XTIDE_Universal_BIOS/`, `Configurator/`, …). unemu adds files beside them
  only: this README, `AGENTS.md`, `CLAUDE.md`, `flake.nix`, `flake.lock`,
  `release/`, `.github/`, `.gitignore`, `.beads/` (the issue tracker) and the
  coding-agent settings that point at it (`.agents/`, `.claude/`, `.codex/`,
  `.cursor/`).

## Conversion

Converted on 2026-11-16 from https://www.xtideuniversalbios.org/svn/xtideuniversalbios
(repository UUID `143130fb-dee8-9d2b-0d25-209ee59ef9c5`, latest revision 638 of
2026-06-09) with `git svn init --stdlayout --prefix=origin/` and `git svn fetch`,
with the full history:

- `trunk/` became **main**: 515 commits up to r638,
  `c144a2a1b796b9e3d38e9d080d0369202018f776`. `branches/` is empty upstream;
  `wiki/` (the project's wiki pages) lies outside the standard layout and is
  not converted.
- Authors are kept as git-svn records them: the Subversion user name, with
  `<name>@143130fb-dee8-9d2b-0d25-209ee59ef9c5` as e-mail address, which
  upstream never had. The committer equals the author, and every date is the
  Subversion commit date.
- The 15 Subversion tags became lightweight git tags of the same names (for
  example `XTIDE_Universal_BIOS_v1.1.5`, `v2.0.0_beta_3`), each on the commit
  git-svn made for the tag's own revision, so its message and author are
  upstream's. Thirteen of them copy a single subdirectory of trunk, so their
  trees hold only that directory; `v2.0.0_beta_2` and `v2.0.0_beta_3` copy the
  whole trunk.
- The tree of r638 equals `svn export -r 638 trunk` file for file (274 files,
  none executable; r638 sets no `svn:eol-style`, `svn:keywords` or
  `svn:executable`), except for seven empty directories git cannot record:
  `Assembly_Library/Build`, `BIOS_Drive_Information_Tool/Build`,
  `BIOS_Drive_Information_Tool/Inc`, `Configurator/Build`,
  `Serial_Server/build`, `XTIDE_Universal_BIOS/Build` and
  `XTIDE_Universal_BIOS_Configurator_v2/Build`. The build creates
  `XTIDE_Universal_BIOS/Build`, and the release script puts all seven back
  into the source archive.

Later upstream revisions can be fetched the same way into a clone set up with
`git svn init` and merged as a new release line.

## Build

```sh
nix build                 # result/ide_xtp-r638-ata1f0-8k.bin (8 KiB) and .sha256
nix build .#ide-xtp       # upstream XT+ image: ide_xtp.bin, ide_xtp.lst, .sha256
nix build .#ide-at        # upstream AT image: ide_at.bin, ide_at.lst, .sha256
nix flake check           # all three rebuilt and checked against their pins
```

`flake.nix` pins nixpkgs to the revision unemu-at-bios and unemupc98's devShell
use (`d407951`, NASM 3.01, GNU make 4.4.1). The images are assembled by
upstream's own makefile (`XTIDE_Universal_BIOS/makefile`, targets `xtplus` and
`at`) from `Assembly_Library/` and `XTIDE_Universal_BIOS/` only, with one
addition: `AS="nasm -D__DATE__='\"2026-06-09\"'"`. The download centre's builds
embed their build date through NASM's `__DATE__`; defining it as r638's commit
date reproduces the r638 downloads byte for byte.

| Output | Size | SHA-256 | Equals |
| --- | ---: | --- | --- |
| `ide-xtp` `ide_xtp.bin` | 6,629 | `338f70795a7c881a839ce25365678db0f2a356f2f255b7493a07f58f3ac65ec4` | r638 download `binaries/r638/ide_xtp.bin` |
| `ide-at` `ide_at.bin` | 6,646 | `6d5007bca3be0bffeb210969a299b67199368b4845f554b5a00715e2718dfea8` | r638 download `binaries/r638/ide_at.bin` |
| `xtp-ata1f0` `ide_xtp-r638-ata1f0-8k.bin` | 8,192 | `54975501e6887c836b8d57e7aad78421e745a9b71e250f94d5d1f9631eab1513` | unemupc98 `xub-r638-xtp-ata1f0` |

GitHub Actions (`.github/workflows/ci.yml`) runs `nix flake check` on
x86_64-linux for pushes to main, release tags and pull requests, prints the
SHA-256s and keeps the three images as a workflow artifact.

## Configuration of the unemu ROM

Upstream's image is shorter than the 8 KiB its header declares (`55 AA 10`) and
has no checksum. The XT and XT+ default settings in `Src/Main.asm` cannot be
chosen by a define, so `xtp-ata1f0` changes the configuration block (ROMVARS,
`Inc/RomVars.inc`) of the assembled image as the XTIDE configurator would, and
no code:

| Offset | Field | Upstream XT+ default | unemu |
| --- | --- | --- | --- |
| 49h | `ROMVARS.bBootDrv` | 80h (first hard disk) | 00h: diskette A:, the machine's disk need not be bootable |
| 4Eh-4Fh | `ideVars0.wBasePort` | 0300h | 01F0h: primary ATA command block |
| 50h-51h | `ideVars0.wControlBlockPort` | 0000h | 03F0h: control block (the driver adds 6 for 3F6h) |
| 52h | `ideVars0.bDevice` | 0Eh (`DEVICE_8BIT_XTCF_PIO8`) | 00h: `DEVICE_16BIT_ATA` |
| 53h | `ideVars0.bIRQ` | 00h | 00h: polling (XT+ has no `MODULE_IRQ`) |

The rest of the settings are upstream's defaults. The image is then padded
with zero bytes to 8,192 bytes, and the last byte (offset 1FFFh) is set so the
byte sum of the whole ROM is 0 modulo 256, the option-ROM checksum. The flake
checks the header, upstream's default bytes before it changes them, the size,
the checksum and the pinned SHA-256.

## Releases

A release is a tag `r<upstream revision>-unemu.<n>` on main (the first is
`r638-unemu.1`). Publishing a GitHub release for it runs
`.github/workflows/release-assets.yml`, which builds the assets with
`release/assets.sh` inside `nix develop` and attaches them:

- `ide_xtp-r638-ata1f0-8k.bin`: the `xtp-ata1f0` ROM;
- `xtide-universal-bios-r638-src.tar`: its corresponding source;
- `SHA256SUMS`.

The source archive holds `xtide-universal-bios-r638-src/trunk/`, the r638
trunk exactly as `svn export -r 638` gives it (taken from the git-svn commit of
r638, plus upstream's empty directories, which git cannot record), and
`xtide-universal-bios-r638-src/NOTICE` (`release/source-notice.txt`), which
states the downloads, the configuration bytes, the licence and the rebuild
command. It is a GNU tar ustar archive with sorted members, r638's commit time
as every timestamp, owner and group 0 and normalised modes, so every host
builds the same bytes: SHA-256
`7bbd5de269f4e1d52ae30b52531fcda842709b9ae49166ac249f9b37187b91e8`, the archive
unemupc98 pins. `release/assets.sh` refuses a tag that changes upstream's
files, checks that the archived trunk assembles to both upstream images, and
checks the ROM and the archive against unemupc98's two pins before it writes
them. It takes upstream's files from git without any line-ending conversion
(most r638 text files have CRLF line ends) and the NOTICE from the tag.

The workflow can also be started by hand (workflow_dispatch) for an existing
tag, with an optional expected SHA-256 of the source archive.

## Licence

The XTIDE Universal BIOS is distributed under the GNU General Public License,
version 2 (`license.txt`). Source files with a licence header also allow any
later version, but files without one fall under `license.txt` alone, so the ROM
and the source archive are distributed under **GPL-2.0-only**. unemu's own
files (the build and release scripts and documents) are GPL-2.0-or-later.

## Consumers

- **unemupc98** (`upc-dfs.7`): catalogue entry `xub-r638-xtp-ata1f0`, the ROM
  identity by SHA-256, and its `vendor/xtide-universal-bios/fetch.sh` recipe,
  which produces the same bytes from upstream's download.
- **unemu-media** (`um-7jx.12`): builds the firmware package
  `unemu/firmware/xub-r638-xtp-ata1f0` from this repository's release assets.
