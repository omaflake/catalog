# SPDX-License-Identifier: MIT
# Module: hyprland – the desktop. Hyprland (started from the shell after the auto-login on TTY1), Waybar, Fuzzel,
# Mako, PipeWire, fonts, and a helper that follows the VM window's size. Its colours are the guest look's; its keys
# are the recipe's (module.toml's defaults, overridden by the recipe's key bindings). Other modules' launchers
# (`omaflake.launchers`, e.g. Emacs on Super+e) are bound here too.
{ config, lib, pkgs, settings, omaflake, ... }:

let
  keys = omaflake.keys;
  bind = key: action: ''hl.bind("${omaflake.keyLib.hyprland key}", ${action})'';
  # One binding per arrow or digit for the keys with a placeholder (Super+Arrow, Super+Digit)
  each = key: f: lib.concatMapStringsSep "\n" (k: bind k.key (f k)) (omaflake.keyLib.expand key);
  terminal = config.omaflake.terminal;
  # The look's desktop colours ("RRGGBB"; null: Vanilla – every program its own)
  d = config.omaflake.lookColors;
  rgba = c: "rgba(${c}ff)";
in
{
  # ---------- System: Hyprland, audio, fonts ----------
  programs.hyprland.enable = true;
  hardware.graphics.enable = true;

  # Auto-login on TTY1; Hyprland is started from zsh (below)
  services.getty.autologinUser = settings.user;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # dconf: GTK's light/dark preference of the look
  programs.dconf.enable = true;

  # Electron/Chromium apps natively on Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
  ];

  environment.systemPackages = with pkgs; [
    swaybg        # background
    wl-clipboard  # wl-copy / wl-paste
    grim slurp    # screenshots
    brightnessctl
    pavucontrol
  ];

  # ---------- The user's desktop ----------
  home-manager.users.${settings.user} = { osConfig, ... }:
    let
      # The VM's window changes size → QEMU offers that size as the output's preferred mode (virtio-gpu, a DRM change
      # event), but Hyprland keeps the mode of an output that stays connected ("Skipping connector …", aquamarine with
      # Hyprland 0.56; omaflake plan B128). This follows the preferred mode of every connected output and keeps its
      # scale: with scale "auto" Hyprland chose 2 from 1920×1080 on (QEMU's GTK UI gives the EDID no physical size), so
      # a big window turned into a small picture with huge text – the scale chosen at the start stays (Retina on a Mac,
      # 1 elsewhere).
      followDisplay = pkgs.writeShellApplication {
        name = "omaflake-follow-display";
        runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.systemd osConfig.programs.hyprland.package ];
        text = ''
          apply() {
            for c in /sys/class/drm/card*-*; do
              [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
              name=''${c##*/}
              output=''${name#card*-}
              want=$(head -n 1 "$c/modes" 2>/dev/null || true)
              [ -n "$want" ] || continue
              read -r have scale < <(hyprctl -j monitors |
                jq -r --arg o "$output" '.[] | select(.name == $o) | "\(.width)x\(.height) \(.scale)"') || true
              if [ -n "''${have:-}" ] && [ "$have" != "$want" ]; then
                hyprctl eval "hl.monitor({ output = \"$output\", mode = \"$want\", position = \"auto\", scale = $scale })" >/dev/null
              fi
            done
          }
          apply
          udevadm monitor --udev --subsystem-match=drm | while read -r line; do
            case "$line" in
              *change*) sleep 0.3; apply ;;
            esac
          done
        '';
      };
    in
    lib.mkMerge [
      {
        # Hyprland ≥ 0.56 reads ~/.config/hypr/hyprland.lua; with stateVersion 26.05 home-manager generates Lua
        # (configType = "lua"). Every key in `settings` becomes a call hl.<name>(...); key bindings and autostart are
        # Lua in extraConfig. API: share/hypr/stubs/hl.meta.lua in the package.
        wayland.windowManager.hyprland = {
          enable = true;
          package = null;        # package comes from the NixOS module
          portalPackage = null;
          configType = "lua";

          settings = {
            # Window size and Retina scale come via EDID (QEMU patch dynamic-display)
            monitor = { output = ""; mode = "preferred"; position = "auto"; scale = "auto"; };

            env = { _args = [ "XCURSOR_SIZE" "24" ]; };

            config = {
              input = {
                # The keyboards of the guest's locale (omaflake's platform: the Mac variant, Option as level 3)
                kb_layout = osConfig.services.xserver.xkb.layout;
                kb_variant = osConfig.services.xserver.xkb.variant;
                kb_options = osConfig.services.xserver.xkb.options;
                follow_mouse = 1;
                touchpad.natural_scroll = true;
              };

              # needed in VMs, otherwise the cursor is invisible or flickers
              cursor.no_hardware_cursors = true;

              general = {
                gaps_in = 5;
                gaps_out = 10;
                border_size = 2;
                layout = "dwindle";
              };

              decoration = {
                rounding = 10;
                # blur and shadows cost noticeable performance in a VM – test before enabling
                blur.enabled = false;
                shadow.enabled = false;
              };

              animations.enabled = true;
              dwindle.preserve_split = true;
              # The background colour (the look's) is drawn by Hyprland itself: it always fills the output, also after
              # the window of the VM changed size (swaybg kept its first size there)
              misc = { disable_hyprland_logo = true; disable_splash_rendering = true; };
            };
          };

          extraConfig = ''
            -- Keys: the recipe's (module.toml's defaults and the recipe's key bindings). Every key omaflake binds starts
            -- with SUPER (the Mac's Cmd) or CTRL, optionally with SHIFT; plain keys only inside a mode (resize below)
            hl.on("hyprland.start", function()
              hl.exec_cmd("waybar")
              hl.exec_cmd("mako")
              hl.exec_cmd("${followDisplay}/bin/omaflake-follow-display")
              -- a wallpaper: hl.exec_cmd("swaybg -i ~/wallpaper.png -m fill") (misc.background_color is the plain colour)
            end)

            ${bind keys.terminal ''hl.dsp.exec_cmd("${terminal.open}")''}
            ${bind keys.launcher ''hl.dsp.exec_cmd("fuzzel")''}
            ${bind keys.close "hl.dsp.window.close()"}
            ${bind keys.exit "hl.dsp.exit()"}
            ${bind keys.fullscreen "hl.dsp.window.fullscreen()"}
            ${bind keys.float ''hl.dsp.window.float({ action = "toggle" })''}
            ${bind keys.pseudo "hl.dsp.window.pseudo()"}
            ${bind keys.split ''hl.dsp.layout("togglesplit")''}
            ${bind keys.screenshot ''hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]])''}
            ${each keys.focus (k: ''hl.dsp.focus({ direction = "${lib.toLower k.arrow}" })'')}
            ${each keys.move (k: ''hl.dsp.window.move({ direction = "${lib.toLower k.arrow}" })'')}
            ${each keys.workspace (k: "hl.dsp.focus({ workspace = ${k.digit} })")}
            ${each keys.to-workspace (k: "hl.dsp.window.move({ workspace = ${k.digit} })")}

            -- Resize mode (as Zellij's): arrows or h j k l, held down they repeat; right/down grow, left/up shrink;
            -- Esc or Enter leaves it
            ${bind keys.resize ''hl.dsp.submap("resize")''}
            hl.define_submap("resize", function()
              local steps = {
                { keys = { "right", "l" }, x = 40,  y = 0 },
                { keys = { "left",  "h" }, x = -40, y = 0 },
                { keys = { "down",  "j" }, x = 0,   y = 40 },
                { keys = { "up",    "k" }, x = 0,   y = -40 },
              }
              for _, s in ipairs(steps) do
                for _, key in ipairs(s.keys) do
                  hl.bind(key, hl.dsp.window.resize({ x = s.x, y = s.y, relative = true }), { repeating = true })
                end
              end
              hl.bind("escape", hl.dsp.submap("reset"))
              hl.bind("Return", hl.dsp.submap("reset"))
            end)

            hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
            hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

            -- Other modules' launchers
            ${lib.concatMapStringsSep "\n" (l: bind l.key ''hl.dsp.exec_cmd("${l.command}")'') config.omaflake.launchers}
          '';
        };

        # ---------- Launcher ----------
        programs.fuzzel = {
          enable = true;
          settings = {
            main = { font = "JetBrainsMono Nerd Font:size=12"; terminal = terminal.run; };
            border = { width = 2; radius = 10; };
          };
        };

        # ---------- Notifications ----------
        services.mako = {
          enable = true;
          settings = {
            border-radius = 10;
            default-timeout = 5000;
            font = "JetBrainsMono Nerd Font 11";
          };
        };

        # ---------- Status bar ----------
        programs.waybar = {
          enable = true;
          settings.mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "clock" ];
            # The active keyboard when the locale has several (Super+Space switches)
            modules-right =
              lib.optional (builtins.length (lib.splitString "," osConfig.services.xserver.xkb.layout) > 1) "hyprland/language"
              ++ [ "cpu" "memory" "network" "pulseaudio" ];
            "hyprland/language".format = "󰌌 {short}";
            clock.format = "{:%a %d.%m.  %H:%M}";
            cpu.format = " {usage}%";
            memory.format = " {percentage}%";
            network = { format-ethernet = "󰈀 {ipaddr}"; format-disconnected = "󰖪"; };
            pulseaudio.format = " {volume}%";
          };
          style = ''
            * { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; }
            #workspaces button { padding: 0 8px; }
            #clock, #cpu, #memory, #network, #pulseaudio { padding: 0 10px; }
          '';
        };

        # Start Hyprland after the auto-login on TTY1 (the login shell is zsh, omaflake's platform)
        programs.zsh = {
          enable = true;
          profileExtra = ''
            if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
              exec start-hyprland  # wrapper with watchdog; starting Hyprland directly warns since 0.5x
            fi
          '';
        };
      }

      # ---------- The look ----------
      (lib.mkIf (d != null) {
        wayland.windowManager.hyprland.settings.config = {
          general.col = {
            active_border = { colors = map rgba d.border; angle = 45; };
            inactive_border = rgba d.inactiveBorder;
          };
          misc.background_color = "rgb(${d.base})";
        };

        programs.waybar.style = lib.mkAfter (''
          window#waybar { background: alpha(#${d.base}, 0.9); color: #${d.text}; }
          #workspaces button { color: #${d.muted}; }
          #workspaces button.active { color: #${d.accent}; }
          #clock { color: #${d.clock}; }
        '' + lib.optionalString (d.split != null) ''
          /* the hero's RGB split, finely: the active workspace's number in white with a red and a cyan edge */
          #workspaces button.active {
            color: #${d.text};
            text-shadow: -1px 0 #${builtins.elemAt d.split 0}, 1px 0 #${builtins.elemAt d.split 1};
          }
        '');

        programs.fuzzel.settings.colors = {
          background = "${d.base}f2";
          text = "${d.text}ff";
          match = "${d.accent}ff";
          selection = "${d.selection}ff";
          selection-text = "${d.text}ff";
          border = "${d.accent}ff";
        };

        services.mako.settings = {
          background-color = "#${d.base}";
          text-color = "#${d.text}";
          border-color = "#${d.accent}";
          "urgency=high" = { border-color = "#${d.urgent}"; };
        };
      })

      (lib.mkIf (d != null && d.gtk != null) {
        gtk = {
          enable = true;
          theme = { inherit (d.gtk) name package; };
        };
        dconf.settings."org/gnome/desktop/interface".color-scheme = if d.dark then "prefer-dark" else "prefer-light";
      })

      (lib.mkIf (d != null && d.cursor != null) {
        home.pointerCursor = {
          enable = true;
          inherit (d.cursor) name package;
          size = 24;
          gtk.enable = true;
        };
      })
    ];
}
