# Recipe: minimal (macOS) – the base plus Nix, terminal tools, a minimal Dock, the guest look's system appearance
# (light or dark, accent, icons, folders, wallpaper) and a private-by-default Safari with google.com as start page.
# Keys were read from a guest after setting them by hand in System Settings (plan BM22).
{ config, lib, pkgs, settings, ... }:

let
  user = settings.macUser;
  # The guest look's macOS part (omaflake's modules/look.nix, plan B141): { dark; accent; icons; folders; wallpaper };
  # null – no look, Vanilla – leaves macOS' own appearance
  look = config.omaflake.lookMacos or null;
  is = key: value: look != null && look.${key} == value;
in
{
  networking.hostName = "minimal";

  environment.systemPackages = with pkgs; [ git neovim ripgrep fd jq htop ];

  # ---------- Dock: Finder, Apps, Safari, Mail, Terminal, System Settings | Trash ----------
  system.defaults.dock = {
    persistent-apps = [
      "/System/Applications/Apps.app"
      # the real path – /Applications/Safari.app is a symlink and shows an alias arrow in the Dock
      "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Utilities/Terminal.app"
      "/System/Applications/System Settings.app"
    ];
    persistent-others = [ ]; # no Downloads stack
    show-recents = false;
    autohide = false;
    tilesize = 50;
    magnification = false;
  };

  # ---------- Finder: new windows open Downloads instead of Recents ----------
  system.defaults.finder = {
    ShowPathbar = true;
    NewWindowTarget = "Other";
    NewWindowTargetPath = "file:///Users/${user}/Downloads/";
  };

  # ---------- Appearance: from the guest's look – values checked in a guest (BM22) ----------
  system.defaults.NSGlobalDomain = {
    NSTableViewDefaultSizeMode = 2;
  } // lib.optionalAttrs (is "dark" true) {
    AppleInterfaceStyle = "Dark";
  } // lib.optionalAttrs (is "dark" true && is "icons" "clear") {
    # OPEN: clear icons in a light look (the key's light value, not checked yet)
    AppleIconAppearanceTheme = "ClearDark";
  };
  system.defaults.CustomUserPreferences.NSGlobalDomain = lib.optionalAttrs (is "accent" "graphite") {
    AppleAccentColor = -1;
    AppleAquaColorVariant = 6;
    AppleHighlightColor = "0.847059 0.847059 0.862745 Graphite";
  } // lib.optionalAttrs (is "folders" "graphite") {
    AppleIconAppearanceTintColor = "Graphite";
  } // lib.optionalAttrs (is "icons" "clear") {
    NSGlassTintAmount = 0.0;
  };

  # ---------- Desktop & windows ----------
  system.defaults.WindowManager = {
    AppWindowGroupingBehavior = true;
    AutoHide = false;
    EnableTiledWindowMargins = false;
    HideDesktop = true;
    StandardHideDesktopIcons = true; # no "Macintosh HD" etc. on the desktop
  };

  # ---------- Wallpaper (solid black when the look says so) and Safari ----------
  # No nix-darwin options (plan BM1, BM24): the wallpaper store is a per-user file; Safari keeps its
  # settings in its sandbox container (created by the first login in the base) and its favorites in
  # Bookmarks.plist. WallpaperAgent and Safari are stopped so that they do not write old state back.
  system.activationScripts.postActivation.text = ''
    home="/Users/${user}"
  '' + lib.optionalString (is "wallpaper" "black") ''
    wp="$home/Library/Application Support/com.apple.wallpaper/Store"
    mkdir -p "$wp"
    /usr/bin/plutil -convert binary1 -o "$wp/Index.plist" ${./assets/wallpaper-black.plist}
    chown -R ${user}:staff "$home/Library/Application Support/com.apple.wallpaper"
    /usr/bin/killall -u ${user} WallpaperAgent 2>/dev/null || true
  '' + ''

    # Safari imports its default favorites on its first launch and overwrites any bookmarks file put
    # there before (BM24). So: launch it once, wait for the import, quit, then empty Favorites and
    # the bookmarks menu – emptied after the import, they stay empty.
    bm="$home/Library/Safari/Bookmarks.plist"
    pb=/usr/libexec/PlistBuddy
    imported() { /usr/bin/plutil -p "$bm" 2>/dev/null | grep -q URLString; }
    if ! imported; then
      # Safari starts the import only when a bookmarks file exists – seed an empty one
      if [ ! -f "$bm" ]; then
        mkdir -p "$home/Library/Safari"
        /usr/bin/plutil -convert binary1 -o "$bm" ${./assets/safari-bookmarks-seed.plist}
        chown ${user}:staff "$home/Library/Safari" "$bm"
      fi
      /bin/launchctl asuser "$(/usr/bin/id -u ${user})" /usr/bin/sudo -u ${user} /usr/bin/open -g -a Safari
      for _ in $(seq 1 120); do imported && break; sleep 1; done
      imported || echo "warning: Safari did not import its default bookmarks" >&2
    fi
    /usr/bin/killall -u ${user} Safari 2>/dev/null || true
    sleep 3
    i=0
    while title=$($pb -c "Print :Children:$i:Title" "$bm" 2>/dev/null); do
      case "$title" in
        BookmarksBar|BookmarksMenu)
          $pb -c "Delete :Children:$i:Children" "$bm" 2>/dev/null || true
          $pb -c "Add :Children:$i:Children array" "$bm" ;;
      esac
      i=$((i + 1))
    done

    # Desktop widgets: the base's first login placed Calendar, Weather and Photos; without the
    # `widgets` entry Notification Center adds them again, so write an empty one (BM26). Notification
    # Center is paused while writing and killed afterwards so that it cannot save its old state.
    nc="$home/Library/Containers/com.apple.notificationcenterui/Data/Library/Preferences/com.apple.notificationcenterui"
    empty=$(/usr/bin/plutil -convert binary1 -o - ${./assets/widgets-empty-placement.plist} | /usr/bin/base64)
    /usr/bin/killall -u ${user} -STOP NotificationCenter 2>/dev/null || true
    /usr/bin/sudo -u ${user} /usr/bin/defaults write "$nc" widgets \
      "<dict><key>DesktopWidgetPlacementStorage</key><data>$empty</data><key>instances</key><array/><key>vers</key><integer>1</integer></dict>"
    /usr/bin/killall -u ${user} -9 NotificationCenter 2>/dev/null || true

    safari="$home/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari"
    w() { /usr/bin/sudo -u ${user} /usr/bin/defaults write "$safari" "$@"; }
    w HomePage -string "https://www.google.com/"
    w NewWindowBehavior -int 0          # new windows: homepage
    w NewTabBehavior -int 0             # new tabs: homepage
    w NewTabPageSetByUserGesture -bool true
    w AlwaysRestoreSessionAtLaunch -bool false
    w OpenPrivateWindowWhenNotRestoringSessionAtLaunch -bool true
    w ExcludePrivateWindowWhenRestoringSessionAtLaunch -bool false
    w HistoryAgeInDaysLimit -int 1
    w ShowBackgroundImageInFavorites -bool false
    w ShowSidebarInNewWindows -bool false
  '';

  # ---------- Menu bar: hide Focus, Display, Screen Mirroring, Timer ----------
  # Control Center stores these per host (ByHost/…<hardware UUID>.plist, 8 = hidden), and every
  # instance gets a new UUID (plan BM23). Written to the any-host domain instead, which preferences
  # fall back to while the per-host file has no value – OPEN until checked in a clone (BM25).
  system.defaults.CustomUserPreferences."com.apple.controlcenter" = {
    FocusModes = 8;
    Display = 8;
    ScreenMirroring = 8;
    Timer = 8;
  };
}
