{...}: {
  projectRootFile = "flake.nix";
  programs.alejandra.enable = true;
  programs.mix-format.enable = true;
  programs.prettier.enable = true;

  settings.formatter.prettier.proseWrap = "always";
}
