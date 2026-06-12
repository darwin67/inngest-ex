{
  description = "Elixir SDK for Inngest";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            beam.packages.erlang_28.elixir
            beam.packages.erlang_28.rebar3
            erlang_28

            # LSPs
            beamPackages.expert
            erlang-language-platform

            # Tools
            (callPackage ./nix/inngest-cli.nix { })
            yamllint
            shfmt
            shellcheck
            git-cliff
          ];

          shellHook = ''
            export MIX_HOME="$PWD/.nix/mix"
            export HEX_HOME="$PWD/.nix/hex"
            export REBAR_CACHE_DIR="$PWD/.nix/rebar3"
            export ERL_AFLAGS="-kernel shell_history enabled"

            mkdir -p "$MIX_HOME" "$HEX_HOME" "$REBAR_CACHE_DIR"
          '';
        };
      }
    );
}
