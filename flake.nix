{
  description = "XTIDE Universal BIOS (unemu fork): the r638 XT+ option ROM configured for the unemu machines";

  # Same nixpkgs revision as unemu-at-bios and unemupc98's devShell (nasm 3.01):
  # the ROM bytes depend on the nasm version.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f system);
      pkgsFor = system: import nixpkgs { inherit system; };

      # The ROM is assembled from these two upstream directories only; the
      # makefile includes Assembly_Library through relative paths.
      romSource = pkgs: pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.unions [ ./Assembly_Library ./XTIDE_Universal_BIOS ];
      };

      # r638's commit date (2026-06-09 09:36:36 UTC). The download centre's
      # builds embed their build date through NASM's __DATE__; defining it as
      # this date reproduces the r638 downloads byte for byte.
      sourceDate = "2026-06-09";

      # One target of upstream's XTIDE_Universal_BIOS/makefile, built with the
      # makefile's own flags and defines. The output is upstream's image as the
      # download centre publishes it: shorter than its declared ROM size and
      # without a checksum.
      upstreamFor = system: { target, file, size, sha256 }:
        let pkgs = pkgsFor system; in
        pkgs.stdenv.mkDerivation {
          pname = "xtide-universal-bios-${target}";
          version = "r638";
          src = romSource pkgs;
          nativeBuildInputs = [ pkgs.nasm pkgs.gnumake ];
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            # Git keeps no empty directories; the makefile expects Build/. A
            # path: flake may carry a local build's outputs, so start empty.
            rm -rf XTIDE_Universal_BIOS/Build
            mkdir XTIDE_Universal_BIOS/Build
            make -C XTIDE_Universal_BIOS ${target} AS="nasm -D__DATE__='\"${sourceDate}\"'"
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp XTIDE_Universal_BIOS/Build/${file}.bin $out/${file}.bin
            cp XTIDE_Universal_BIOS/Build/${file}.lst $out/${file}.lst
            actual_size=$(wc -c < $out/${file}.bin)
            if [ "$actual_size" -ne ${toString size} ]; then
              echo "unexpected size of ${file}.bin: $actual_size bytes (expected ${toString size})" >&2
              exit 1
            fi
            sha256sum $out/${file}.bin | cut -d' ' -f1 > $out/${file}.bin.sha256
            if [ "$(cat $out/${file}.bin.sha256)" != "${sha256}" ]; then
              echo "SHA-256 of ${file}.bin is $(cat $out/${file}.bin.sha256), pinned ${sha256}" >&2
              exit 1
            fi
            runHook postInstall
          '';
        };

      # The XT+ image configured for the unemu open AT machines, as the XTIDE
      # configurator would write it, zero-padded to the declared 8 KiB and
      # checksummed. Same bytes as unemupc98's vendor/xtide-universal-bios
      # fetch.sh output (catalogue entry xub-r638-xtp-ata1f0). No code changes:
      # ROMVARS (XTIDE_Universal_BIOS/Inc/RomVars.inc) is the configuration
      # block at the start of the image, and the XT/XT+ defaults in Src/Main.asm
      # cannot be selected by a define, so the bytes are set after assembly.
      configuredFor = system: { upstream, sha256 }:
        let pkgs = pkgsFor system; in
        pkgs.runCommand "xtide-universal-bios-r638-xtp-ata1f0" { } ''
          raw=${upstream}/ide_xtp.bin
          rom=ide_xtp-r638-ata1f0-8k.bin
          byte_at() { od -An -tx1 -j "$2" -N "$3" "$1" | tr -d ' \n'; }
          byte_sum() {
            od -An -v -tu1 "$1" | awk '{for (i = 1; i <= NF; i++) sum += $i} END {print sum % 256}'
          }
          # The declared size: 55 AA, then 10h blocks of 512 bytes.
          if [ "$(byte_at "$raw" 0 3)" != "55aa10" ]; then
            echo "unexpected option-ROM header: $(byte_at "$raw" 0 3)" >&2
            exit 1
          fi
          # Upstream's XT+ defaults the configuration replaces: boot drive 80h
          # (ROMVARS.bBootDrv, offset 49h) and ideVars0 (offsets 4Eh-53h) for
          # an XT-CF card in 8-bit PIO mode at 300h without IRQ.
          if [ "$(byte_at "$raw" 73 1)" != "80" ] \
            || [ "$(byte_at "$raw" 78 6)" != "000300000e00" ]; then
            echo "unexpected ROMVARS defaults: $(byte_at "$raw" 73 1) $(byte_at "$raw" 78 6)" >&2
            exit 1
          fi
          # Zero padding keeps every assembled byte and gives the checksum a
          # neutral starting value; the last byte belongs to the checksum.
          dd if=/dev/zero of="$rom" bs=8192 count=1 2>/dev/null
          dd if="$raw" of="$rom" conv=notrunc 2>/dev/null
          # ROMVARS.bBootDrv = 00h: boot from diskette A:, because the
          # machine's hard disk need not be bootable.
          printf '\000' | dd of="$rom" bs=1 seek=73 count=1 conv=notrunc 2>/dev/null
          # ROMVARS.ideVars0: command block 1F0h, control block 3F0h (the
          # driver adds 6 for 3F6h), DEVICE_16BIT_ATA (0), IRQ 0. XT+ has no
          # MODULE_IRQ, so the driver polls.
          printf '\360\001\360\003\000\000' \
            | dd of="$rom" bs=1 seek=78 count=6 conv=notrunc 2>/dev/null
          sum=$(byte_sum "$rom")
          checksum=$(( (256 - sum) % 256 ))
          printf "\\$(printf '%03o' "$checksum")" \
            | dd of="$rom" bs=1 seek=8191 count=1 conv=notrunc 2>/dev/null
          if [ "$(wc -c < "$rom")" -ne 8192 ] || [ "$(byte_sum "$rom")" -ne 0 ]; then
            echo "invalid option ROM: expected 8192 bytes with byte sum 0 mod 256" >&2
            exit 1
          fi
          mkdir -p $out
          cp "$rom" $out/"$rom"
          sha256sum $out/"$rom" | cut -d' ' -f1 > $out/"$rom".sha256
          if [ "$(cat $out/"$rom".sha256)" != "${sha256}" ]; then
            echo "SHA-256 of $rom is $(cat $out/"$rom".sha256), pinned ${sha256}" >&2
            exit 1
          fi
        '';

      variants = system: rec {
        # Upstream's small XT+ build (makefile target xtplus), byte for byte the
        # r638 download https://www.xtideuniversalbios.org/binaries/r638/ide_xtp.bin.
        ide-xtp = upstreamFor system {
          target = "xtplus";
          file = "ide_xtp";
          size = 6629;
          sha256 = "338f70795a7c881a839ce25365678db0f2a356f2f255b7493a07f58f3ac65ec4";
        };
        # Upstream's small AT build (target at), byte for byte the r638
        # download ide_at.bin. Built as a check that this tree is the source of
        # both downloads unemupc98 uses.
        ide-at = upstreamFor system {
          target = "at";
          file = "ide_at";
          size = 6646;
          sha256 = "6d5007bca3be0bffeb210969a299b67199368b4845f554b5a00715e2718dfea8";
        };
        # The option ROM of the unemu open AT machines (see README.unemu.md).
        xtp-ata1f0 = configuredFor system {
          upstream = ide-xtp;
          sha256 = "54975501e6887c836b8d57e7aad78421e745a9b71e250f94d5d1f9631eab1513";
        };
      };
    in
    {
      packages = forAll (system: (variants system) // { default = (variants system).xtp-ata1f0; });

      # `nix flake check` rebuilds every pinned image and fails on any byte change.
      checks = forAll (system: variants system);

      devShells = forAll (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = [ pkgs.nasm pkgs.gnumake pkgs.gnutar ];
          };
        });
    };
}
