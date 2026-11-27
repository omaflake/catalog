# SPDX-License-Identifier: MIT
# Module: xcode (macOS) – Xcode from the Nix store copied to /Applications/Xcode.app and put in the Dock, selected with
# xcode-select, its licence accepted and its first launch done, so `xcodebuild`, `swift` and Xcode itself work from the
# first login.
#
# Apple does not allow passing Xcode on, so no cache has it: whoever builds the image downloads the .xip with their
# Apple Account and adds the unpacked Xcode.app to the Nix store once (the build stops with these steps until then).
# `requireFile` directly (the same fixed-output path as nixpkgs' `darwin.requireXcode`), its unfree licence taken out of
# its meta: allowing it would need an unfree predicate, and nix-darwin merges `nixpkgs.config` with recursiveUpdate –
# a second predicate (the vscode module has one) silently replaces the first. Nobody gets Xcode unasked: module.toml
# says `unfree`, so omaflake shows it, and the file is only there when its user downloaded it.
{ lib, pkgs, ... }:

let
  release = "27.2";
  xip = "Xcode_${release}.xip";
  # The NAR hash of the unpacked Xcode.app (`nix hash path Xcode.app`) – the same for everyone with Apple's file
  xcode = (pkgs.requireFile {
    name = "Xcode.app";
    hashMode = "recursive";
    hash = "sha256-zs5OMdddog5+11qHlkkDMC7liJ4qllxmF4qiVy4zdf8=";
    url = "https://developer.apple.com/download/all/?q=Xcode%20${release}";
    message = ''
      Xcode ${release} is not in the Nix store yet – Apple does not allow passing it on, so download it yourself
      (about 5 GB, your Apple Account): ${xip} from https://developer.apple.com/download/all/?q=Xcode%20${release}
      Then, on this Mac, in the folder with the download (unpacking and storing take a while):

        open -W ${xip}
        nix-store --add-fixed --recursive sha256 Xcode.app

      and build again. Afterwards Xcode.app and ${xip} can go to the Trash – the Nix store keeps its copy.
    '';
  }).overrideAttrs (old: { meta = removeAttrs old.meta [ "license" ]; });
  developer = "/Applications/Xcode.app/Contents/Developer";
in
{
  # A copy, not a link (1.0.1): with a link into the Nix store Spotlight and the Apps view did not list Xcode, and macOS
  # named its extensions after the store folder ("<hash>-Xcode"). The copy costs Xcode's size once more on the guest's
  # disk; it is made again only when the store path changes (a new Xcode), noted in /var/db/omaflake-xcode. A real
  # Xcode.app someone put there by hand (no note) stays. Checked in a VM of 1.0.0 (2026-11-27): xcode-select,
  # `xcodebuild -version` (27.2), licence and first launch done, `swift run` of a SwiftUI package, Xcode starts with its
  # Components window. OPEN: building and running an app on a simulator.
  system.defaults.dock.persistent-apps = lib.mkAfter [ "/Applications/Xcode.app" ];

  system.activationScripts.postActivation.text = lib.mkAfter ''
    note=/var/db/omaflake-xcode
    app=/Applications/Xcode.app
    if [ -L "$app" ] || [ ! -e "$app" ] || { [ -f "$note" ] && [ "$(cat "$note")" != "${xcode}" ]; }; then
      if [ -L "$app" ] || [ -f "$note" ]; then rm -rf "$app"; fi
      echo "Copying Xcode ${release} to $app (a few minutes)"
      /usr/bin/ditto ${xcode} "$app"
      chmod -R u+w "$app"
      chown -R root:wheel "$app"
      echo "${xcode}" > "$note"
    fi
    /usr/bin/xcode-select --switch ${developer}
    ${developer}/usr/bin/xcodebuild -license check >/dev/null 2>&1 || ${developer}/usr/bin/xcodebuild -license accept
    # The system packages Xcode installs at its first start (MobileDevice and others) – asked for once, without a
    # dialog; the simulators' runtimes are not part of it (Xcode → Settings → Components, or
    # `xcodebuild -downloadPlatform iOS`)
    ${developer}/usr/bin/xcodebuild -checkFirstLaunchStatus || ${developer}/usr/bin/xcodebuild -runFirstLaunch
  '';
}
