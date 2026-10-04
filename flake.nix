{
  description = "Narthex: pinned development shell and sandboxed measurement build (niltempus n002)";

  # The nixpkgs revision used for kleis: Nim 2.2.12 (the reviewed version),
  # nimble 0.24.1, nph 0.7.0 and gcc 14.4.0.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c59305bab2065cfecc4944690d9eedbb56f3a9fa";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      # The reviewed dependency manifest (niltempus, sha256 9ad81ca6...) and the
      # upstream revisions it records. Each package is rebuilt from that
      # source and must match the manifest file for file.
      manifest = ./nix/narthex.nim-deps;
      reviewed = {
        bigints = {
          dir = "bigints-1.0.0-d7aee76dba84419721566fd5413a02cca231a806";
          src = pkgs.fetchFromGitHub {
            owner = "nim-lang";
            repo = "bigints";
            rev = "d843ecfe1e2a62c3b0e29d211df09763da408cac";
            hash = "sha256-dwA2T/PLtmihZun1l39RYIMt5/EpHf2ia6GM3ghJtnY=";
          };
        };
        graphemes = {
          dir = "graphemes-0.12.0-5a12349aea7c9682c87a086989a8afe7c8ade36b";
          src = pkgs.fetchFromGitHub {
            owner = "nitely";
            repo = "nim-graphemes";
            rev = "cc868c314ced482ed88dca2b470aa019480ce4c9";
            hash = "sha256-g8P5wkSZglyNZHax+F6ZqLre02fxunAaMK48CtRVofY=";
          };
        };
        nimkdl = {
          dir = "nimkdl-2.1.0-7d7e1e14205fb29c301af77414d2a617e6c755bb";
          src = pkgs.fetchFromGitHub {
            owner = "greenm01";
            repo = "nimkdl";
            rev = "4755e537a848e5f91465ccb314013fc0a7ce7c2f";
            hash = "sha256-6ug30C2GpOef486Lin3lAS9TCXxkXrYBYOYLNGEWLwI=";
          };
        };
        unicodedb = {
          dir = "unicodedb-0.13.0-5c5fc0c8a83d270aca74fe41d33158e9042bb91a";
          src = pkgs.fetchFromGitHub {
            owner = "nitely";
            repo = "nim-unicodedb";
            rev = "15c5e25e2a49a924bc97647481ff50125bba2c76";
            hash = "sha256-0khAhu84SI+/noc0SzQggH2NGgZ9FMqu1ASq4nWtRo8=";
          };
        };
      };

      # Nimble reads its package registry before any task, even offline; one
      # pinned registry commit keeps that lookup offline and deterministic.
      registry = pkgs.fetchFromGitHub {
        owner = "nim-lang";
        repo = "packages";
        rev = "09f05a91e9fc09b3e4626aa4d8f9a067716552ed";
        hash = "sha256-dB/ntRX4nIhAXSlW5DAzdPiNLdO+T1020HVZ4JH0eC4=";
      };

      # No reviewed Narthex package contains an install-time executable.
      installTime = { };

      nimPackage = name: p:
        pkgs.runCommand p.dir { } ''
          ${pkgs.bash}/bin/bash ${./nix/install-reviewed-package.sh} \
            ${manifest} ${name} ${p.src} ${./nix/nimblemeta}/${name}.json $out \
            "${installTime.${name} or ""}"
        '';
      packageDirs = lib.mapAttrs nimPackage reviewed;

      # The Nimble package store the reviewed build used, as ~/.nimble/pkgs2.
      nimPackages = pkgs.linkFarm "narthex-nim-packages"
        (lib.mapAttrsToList (name: p: { name = p.dir; path = packageDirs.${name}; }) reviewed);

      # A private Nimble home with a fixed path: Nim keeps its cache beneath
      # HOME, and a random path changes the type-info hashes in the binary.
      nimbleHome = ''
        export HOME="''${TMPDIR:-/tmp}/narthex-nix-home"
        rm -rf "$HOME"
        mkdir -p "$HOME/.nimble/pkgs2"
        cp -rL ${nimPackages}/. "$HOME/.nimble/pkgs2/"
        cp ${registry}/packages.json "$HOME/.nimble/packages_official.json"
        chmod -R u+w "$HOME/.nimble"
      '';
      tools = [ pkgs.nim pkgs.nimble pkgs.nph ];
      gcc = "${pkgs.gcc14Stdenv.cc}/bin/gcc";

      # Measurement: Narthex built with the niltempus release builder's exact
      # Nim command (product_artifact.rs nim_command/nim_flags): no nimble
      # path, no user, parent or project configuration, an explicit stdlib,
      # gcc and dependency paths. The one deliberate change is a fixed
      # --nimcache path (n001). The bwrap-isolated release build remains the
      # deliverable; this binary links /nix/store.
      narthex = pkgs.gcc14Stdenv.mkDerivation {
        pname = "narthex";
        version = "0.0.0-nix-measurement";
        src = self;
        dontConfigure = true;
        buildPhase = ''
          runHook preBuild
          ${pkgs.nim-unwrapped}/bin/nim c -d:release --hints:off \
            --noNimblePath --clearNimblePath \
            --skipUserCfg:on --skipParentCfg:on --skipProjCfg:on \
            --lib:${pkgs.nim-unwrapped}/nim/lib \
            --cc:gcc --gcc.exe:${gcc} --gcc.linkerexe:${gcc} \
            ${lib.concatMapStringsSep " " (d: "--path:${d}") (lib.attrValues packageDirs)} \
            --path:src --parallelBuild:$NIX_BUILD_CORES \
            --nimcache:$TMPDIR/narthex-nimcache \
            -o:narthex src/narthex.nim
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          install -Dm755 narthex $out/bin/narthex
          runHook postInstall
        '';
      };
    in
    {
      packages.${system} = {
        inherit narthex;
        nim-packages = nimPackages;
        default = narthex;
      };

      # Narthex's own test task (layout and Sophia policy checks) and format
      # check, run in Nix's sandbox from the pinned closure.
      checks.${system} = {
        inherit narthex;
        tests = pkgs.gcc14Stdenv.mkDerivation {
          name = "narthex-tests";
          src = self;
          nativeBuildInputs = tools;
          dontConfigure = true;
          buildPhase = ''
            ${nimbleHome}
            nimble --offline --useSystemNim test
          '';
          installPhase = "touch $out";
        };
        format = pkgs.runCommand "narthex-format-check" { nativeBuildInputs = tools; } ''
          cd ${self}
          nph --check src tests narthex.nimble
          touch $out
        '';
      };

      # Tools and environment only: no filesystem, device or network isolation.
      devShells.${system}.default = pkgs.mkShell.override { stdenv = pkgs.gcc14Stdenv; } {
        packages = tools ++ [ pkgs.git ];
        shellHook = nimbleHome;
      };
    };
}
