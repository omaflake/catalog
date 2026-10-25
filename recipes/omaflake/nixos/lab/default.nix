# Recipe: lab – omaflake's development recipe
# Everything to check the Mac integrations (camera, sound, microphone, clipboard, 3D) plus debug tools, and omaflake
# itself (the Linux app `omaflake`, the CLI `omaf`, its TUI `omaf ui`) to try the Linux interfaces. VMs cannot start in
# here (no nested virtualisation; omaflake on a Linux host is still being brought up). The other recipes stay without
# these. Network, sharing, ephemeral mode and the integrations' defaults
# come from recipe.toml next to this file.
{ pkgs, lib, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  # "omaflake Test" (Cmd+D → fuzzel): camera, sound, microphone, status
  omaflakeTest = pkgs.stdenvNoCC.mkDerivation {
    pname = "omaflake-test";
    version = "1";
    src = ./omaflake-test.py;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook4 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk4 ];
    installPhase = ''
      install -Dm755 $src $out/bin/omaflake-test
      substituteInPlace $out/bin/omaflake-test --replace-fail '"""omaflake Test' '#!${python}/bin/python3
      """omaflake Test'
      install -Dm644 ${desktopItem}/share/applications/*.desktop -t $out/share/applications
    '';
    preFixup = ''
      # GTK's Vulkan renderer finds no device under virgl (like mpv, plan B39) – use its OpenGL renderer
      gappsWrapperArgs+=(--prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mpv pkgs.pipewire pkgs.pulseaudio pkgs.systemd ]}
                         --set-default GSK_RENDERER ngl)
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "omaflake-test";
    desktopName = "omaflake Test";
    comment = "Check camera, sound and microphone from the Mac";
    exec = "omaflake-test";
    icon = "camera-web";
    categories = [ "Utility" ];
  };
in
{
  networking.hostName = "lab";

  # omaflake (pkgs.omaflake from the image flake: in a checkout the code as it is on disk). Its core service is started
  # on demand – by the app, `omaf ui` or the waybar module below (`omaf serve --socket --idle-exit 300`); no unit is
  # declared, so this is the path a user without `omaf service install` takes. Cmd+D → fuzzel finds "omaflake".
  environment.systemPackages = [ pkgs.omaflake omaflakeTest ] ++ (with pkgs; [
    # media: camera, sound, microphone
    v4l-utils mpv ffmpeg pavucontrol pulseaudio alsa-utils
    # graphics
    mesa-demos vulkan-tools wayland-utils
    # clipboard, screenshots
    wl-clipboard grim slurp
    # system
    htop strace lsof pciutils usbutils file jq
  ]);

  # iced (wgpu) would take Mesa's software Vulkan (lavapipe) – virgl offers no Vulkan – and keep several cores busy;
  # its OpenGL backend goes through virgl to the Mac's GPU (like GSK_RENDERER above, plan B39)
  environment.sessionVariables.WGPU_BACKEND = "gl";

  # waybar: omaflake's status (running VMs, builds) and the tray for the app's icon
  home-manager.sharedModules = [
    ({ config, ... }: lib.mkIf config.programs.waybar.enable {
      programs.waybar.settings.mainBar = {
        modules-right = lib.mkAfter [ "custom/omaflake" "tray" ];
        "custom/omaflake" = {
          exec = "omaf status --waybar --follow";
          return-type = "json";
          format = "{icon} {text}"; # waybar ≥ 0.15 refuses "{}" next to "{icon}"
          format-icons = { idle = "❄"; running = "❄"; building = "⚒"; };
          on-click = "wezterm start -- omaf ui";
        };
        tray.spacing = 8;
      };
      programs.waybar.style = lib.mkAfter ''
        #custom-omaflake, #tray { padding: 0 10px; }
      '';
    })
  ];
}
