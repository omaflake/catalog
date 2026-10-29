# SPDX-License-Identifier: MIT
# Module: typst (macOS) – Typst and tinymist; with VS Code the Tinymist extension (set only when the recipe has VS Code)
{ lib, pkgs, omaflake, ... }:

{
  config = lib.mkMerge [
    { environment.systemPackages = with pkgs; [ typst tinymist ]; }
    (lib.optionalAttrs (omaflake.has "omaflake/vscode") {
      omaflake.vscode.extensions = [ pkgs.vscode-extensions.myriad-dreamin.tinymist ];
    })
  ];
}
