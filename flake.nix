{
  description = "Elixir SDK for Inngest";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            elixir
            erlang_27
            nodejs_18 # need this to install inngest-cli for now

            # LSPs
            elixir-ls
            lexical
            erlang-ls

            # Tools
            yamllint
            shfmt
            shellcheck
            git-cliff
          ];
        };
      });
}
