# SPDX-License-Identifier: MIT
# Module: zathura – the PDF viewer, the default for PDFs. It reloads a PDF when it changes; a dark look shows PDFs
# inverted in its colours.
{ config, lib, pkgs, settings, ... }:

let
  # The guest look's colours (omaflake's platform; null for Vanilla)
  look = config.omaflake.lookColors;
in
{
  environment.systemPackages = [ pkgs.zathura ];

  home-manager.users.${settings.user} = {
    programs.zathura = {
      enable = true;
      options = {
        selection-clipboard = "clipboard";
      } // lib.optionalAttrs (look != null) {
        default-bg = "#${look.base}";
      } // lib.optionalAttrs (look != null && look.dark) {
        recolor = true;
        recolor-keephue = true;
        recolor-darkcolor = "#${look.text}";
        recolor-lightcolor = "#${look.base}";
      };
    };
    xdg.mimeApps = {
      enable = true;
      defaultApplications."application/pdf" = "org.pwmt.zathura.desktop";
    };
  };
}
