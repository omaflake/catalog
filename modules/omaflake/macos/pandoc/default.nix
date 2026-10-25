# Module: pandoc (macOS)
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.pandoc ];
}
