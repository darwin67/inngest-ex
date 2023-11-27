{ pkgs ? import (fetchTarball
  "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz") { } }:

with pkgs;

mkShell {
  buildInputs = [
    # Elixir
    pkgs.elixir
    pkgs.erlang

    # LSPs
    pkgs.elixir-ls
    pkgs.erlang-ls

    # Tools
    pkgs.yamllint
    pkgs.shfmt
    pkgs.shellcheck
    pkgs.git-cliff
  ];
}
