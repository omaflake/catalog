# Recipe: emacs-minimal – base and desktop with the emacs line, nothing else
# Emacs (pure GTK, native on Wayland) in the desktop's colours, with Vertico, Consult, Corfu, Magit, Eglot and
# tree-sitter; Cmd+E opens it, and $EDITOR in WezTerm opens files in it. The configuration is omaflake's
# (nix/home/emacs.nix in omaflake/omaflake); add your own on top in ~/.emacs.d/ or here.
{ ... }:

{
  networking.hostName = "emacs-minimal";
  omaflake.editor = "emacs";
}
