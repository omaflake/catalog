# Module: pandoc
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.pandoc ];
}
