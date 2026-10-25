# Recipe: lab (macOS) – omaflake's development recipe for macOS guests, like nixos/lab: everything of minimal,
# plus the "omaflake Test" app (sound, microphone, clipboard status; in the Dock and via Spotlight) and debug tools.
{ lib, pkgs, ... }:

let
  infoPlist = pkgs.writeText "Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleExecutable</key><string>omaflake-test</string>
      <key>CFBundleIdentifier</key><string>org.omaflake.test</string>
      <key>CFBundleName</key><string>omaflake Test</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleIconFile</key><string>omaflake-test</string>
      <key>NSMicrophoneUsageDescription</key><string>omaflake Test records 4 seconds to check the microphone.</string>
    </dict></plist>
  '';

  # An app bundle from a shell script: Launch Services runs Contents/MacOS/<name>; the Info.plist carries the
  # microphone usage text that macOS in the guest shows when the app records
  omaflakeTest = pkgs.runCommand "omaflake-test" { } ''
    app="$out/Applications/omaflake Test.app/Contents"
    mkdir -p "$app/MacOS"
    install -m755 ${./omaflake-test.sh} "$app/MacOS/omaflake-test"
    substituteInPlace "$app/MacOS/omaflake-test" --replace-fail "export LANG=en_US.UTF-8" \
      "export LANG=en_US.UTF-8 PATH=${lib.makeBinPath [ pkgs.ffmpeg ]}:/usr/bin:/bin:/usr/sbin:/sbin"
    cp ${infoPlist} "$app/Info.plist"
    # omaflake's icon (a copy of brand/macos/omaflake.icns – the recipes flake cannot reach outside recipes/)
    install -Dm644 ${./omaflake-test.icns} "$app/Resources/omaflake-test.icns"
  '';
in
{
  imports = [ ../minimal ];

  networking.hostName = lib.mkForce "lab";

  environment.systemPackages = [ omaflakeTest ] ++ (with pkgs; [ ffmpeg python3 file lsof ]);

  system.defaults.dock.persistent-apps = lib.mkAfter [ "/Applications/Nix Apps/omaflake Test.app" ];
}
