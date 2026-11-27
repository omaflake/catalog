# SPDX-License-Identifier: MIT
# Module: xcode (macOS) – Xcode from the Nix store as /Applications/Xcode.app, selected with xcode-select, its licence
# accepted and its first launch done, so `xcodebuild`, `swift` and Xcode itself work from the first login.
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
  # A link, not a copy: Xcode is several GB and already in the image's Nix store. A real Xcode.app someone put there by
  # hand stays. Checked in a VM of the image (2026-11-27): xcode-select, `xcodebuild -version` (27.2), licence and first
  # launch done, `swift run` of a SwiftUI package, and Xcode itself starts (with its Components window for the platforms).
  # OPEN: macOS names Xcode's extensions after the store folder ("<hash>-Xcode" in the notice about added extensions);
  # building and running an app on a simulator.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [ -L /Applications/Xcode.app ] || [ ! -e /Applications/Xcode.app ]; then
      ln -sfn ${xcode} /Applications/Xcode.app
    fi
    /usr/bin/xcode-select --switch ${developer}
    ${developer}/usr/bin/xcodebuild -license check >/dev/null 2>&1 || ${developer}/usr/bin/xcodebuild -license accept
    # The system packages Xcode installs at its first start (MobileDevice and others) – asked for once, without a
    # dialog; the simulators' runtimes are not part of it (Xcode → Settings → Components, or
    # `xcodebuild -downloadPlatform iOS`)
    ${developer}/usr/bin/xcodebuild -checkFirstLaunchStatus || ${developer}/usr/bin/xcodebuild -runFirstLaunch
  '';
}
