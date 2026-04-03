{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    forSystems = fn:
      nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ] (system: fn nixpkgs.legacyPackages.${system});
    defaultForSystems = fn: forSystems (pkgs: {default = fn pkgs;});
    treefmtEval = forSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    devShells = defaultForSystems (pkgs:
      pkgs.mkShell {
        nativeBuildInputs = with pkgs; [elixir erlang];
      });

    formatter = forSystems (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);
  };
}
