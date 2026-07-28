{
  description = "ZT's yazi config — plugins, flavors, dual-compat config, as a Nix package";

  inputs = {
    # Pinned to the fleet baseline (yazi 26.5.6) — the stable schema this
    # config targets. The config is dual-compat with yazi nightly; nightly
    # consumers bring their own binary and point it at this config.
    nixpkgs.url = "github:NixOS/nixpkgs/9ae611a455b90cf061d8f332b977e387bda8e1ca";
  };

  nixConfig = {
    extra-substituters = [
      # Public niks3 cache (R2 CDN) — CI pushes every build here.
      "https://cache.0xtau.com"
    ];
    extra-trusted-public-keys = [
      "cache.0xtau.com-1:M4y9SWhqZED/M9nvrYvJuxAlEj0umdXnxRYMgoXZxfU="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      # The config dir yazi reads (YAZI_CONFIG_HOME). Explicit fileset: repo
      # tooling (flake, tests, CI) stays out, and a local gitignored vfs.toml
      # can never leak into the store even from a dirty working tree.
      configFileset = lib.fileset.unions [
        ./init.lua
        ./yazi.toml
        ./keymap.toml
        ./theme.toml
        ./package.toml
        ./plugins
        ./flavors
      ];

      # Force-parse every TOML at eval time — `nix flake check` (and any
      # build) fails on a syntax error before yazi ever runs.
      tomlFiles = [
        ./yazi.toml
        ./keymap.toml
        ./theme.toml
        ./package.toml
      ];
      tomlParsed = builtins.deepSeq (map (f: builtins.fromTOML (builtins.readFile f)) tomlFiles) "ok";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          config =
            pkgs.runCommandLocal "cyazi-config"
              {
                src = lib.fileset.toSource {
                  root = ./.;
                  fileset = configFileset;
                };
              }
              ''
                cp -r $src $out
              '';

          # yazi/ya wrapped onto this config. --set-default keeps an explicit
          # YAZI_CONFIG_HOME override (e.g. a live checkout) working.
          yazi-wrapped =
            pkgs.runCommand "cyazi"
              {
                nativeBuildInputs = [ pkgs.makeWrapper ];
              }
              ''
                mkdir -p $out/bin
                makeWrapper ${pkgs.yazi}/bin/yazi $out/bin/yazi \
                  --set-default YAZI_CONFIG_HOME ${config}
                makeWrapper ${pkgs.yazi}/bin/ya $out/bin/ya \
                  --set-default YAZI_CONFIG_HOME ${config}
              '';
        in
        {
          default = config;
          inherit config;
          yazi = yazi-wrapped;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.yazi}/bin/yazi";
        };
      });

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Compile-check every Lua file with the same Lua yazi embeds (5.4).
          lua-syntax =
            pkgs.runCommandLocal "cyazi-lua-syntax"
              {
                src = self.packages.${system}.config;
                nativeBuildInputs = [ pkgs.lua5_4 ];
              }
              ''
                fail=0
                while IFS= read -r f; do
                  luac -p "$f" || { echo "SYNTAX ERROR: $f"; fail=1; }
                done < <(find $src -name '*.lua')
                [ $fail -eq 0 ]
                touch $out
              '';

          # Eval-time TOML parse, surfaced as a buildable check.
          toml-parse = pkgs.runCommandLocal "cyazi-toml-parse" { } ''
            echo ${tomlParsed} > $out
          '';

          # End-to-end: boot yazi headlessly on this config inside tmux,
          # assert the UI draws, the count linemode renders, the layout-cycle
          # plugin responds to <Tab>, quit is clean, and the log is error-free.
          smoke =
            pkgs.runCommand "cyazi-smoke"
              {
                nativeBuildInputs = [
                  pkgs.tmux
                  pkgs.yazi
                  # the git fetcher runs `git` on every dir; absent it logs errors
                  pkgs.git
                ];
              }
              ''
                export YAZI_CONFIG_HOME=${self.packages.${system}.config}
                export SMOKE_TMP=$TMPDIR/smoke
                bash ${./tests/smoke.sh}
                touch $out
              '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Everything tests/smoke.sh needs, plus lua for syntax checks.
          default = pkgs.mkShell {
            packages = [
              pkgs.yazi
              pkgs.tmux
              pkgs.lua5_4
            ];
          };
        }
      );
    };
}
