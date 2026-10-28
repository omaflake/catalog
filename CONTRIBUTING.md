# Contributing a recipe, a module, key bindings or a look

1. Fork this repository and add yours in your GitHub name's folder: `recipes/<you>/<platform>/<name>/`,
   `modules/<you>/<platform>/<name>/`, `keymaps/<you>/<name>/` or `looks/<you>/<name>/` (`platform` is `nixos` or
   `macos`; names use lowercase letters, digits and `-`).
2. Write it (below) and test it in omaflake (below).
3. Run `python3 tools/catalog.py` and commit the updated `catalog.json` with it.
4. Open a pull request – one recipe, module, key binding set or look per pull request (a recipe may come with the
   modules it is made of) – and fill in the checklist.

The core team reviews everything against REVIEW.md: is it safe, does it work, does it add something the catalog does
not have yet. **Modules are code** and get the closest look; recipes, key bindings and looks are data. Changes to a
merged entry go the same way; only its author or the core team change it.

## Recipes are put together from building blocks

| Block | What | Here |
|---|---|---|
| **Platform** | what the guest is: `nixos`, or `macos` on a macOS base – omaflake's own part (guest hardware, the omaflake agent, user, keys, locale and keyboards, the look's files) | omaflake's image flake |
| **Module** | a piece of the guest – a desktop, a terminal, an editor, LaTeX … – in Nix | `modules/<author>/<platform>/<name>/` |
| **Key bindings** | keys for the actions modules offer | `keymaps/<author>/<name>/keymap.toml` |
| **Look** | colours and a few choices | `looks/<author>/<name>/look.toml` |
| **Recipe** | a platform, modules, a suggested look, key bindings, what a VM needs and how it runs | `recipes/<author>/<platform>/<name>/recipe.toml` |

A user's credential (who they are), locale (language, time zone, keyboards) and profile (CPU cores, RAM) are never in a
recipe: they are chosen when an image is built or a VM created.

## `recipe.toml`

A recipe is this one file – data, never code (Nix goes in a module):

```toml
"$schema" = "https://omaflake.dev/schema/recipe/v2.json"   # the version of this format – required
author = "your-github-name"      # the folder's author – required
license = "MIT"                  # SPDX identifier, one of source.toml's licenses – required
description = "Rust development: Neovim with the Rust language server, Zellij, the Hyprland desktop."   # English – required
description_de = "Rust-Entwicklung: Neovim mit Rust-Sprachserver, Zellij, der Hyprland-Desktop."     # optional, any language code
tags = ["rust", "neovim"]        # from tags.toml (add new ones there) – required
homepage = "https://…"           # optional: where to read more or report problems
lab = false                      # optional: true = development recipe, shown only in omaflake's developer mode
platform = "nixos"               # nixos | macos – the folder's – required
systems = ["aarch64-linux", "x86_64-linux"]   # what it is built and tested for – required (below)

modules = [                      # what is in it, in this order – required
  "omaflake/hyprland",           # the newest version
  "omaflake/shell",
  "omaflake/wezterm",
  { id = "omaflake/neovim", min = "1.0.0" },            # a minimum and/or a maximum (both included) …
  { id = "your-github-name/rust", version = "1.2.0" },  # … or exactly one version
]
look = "omaflake/omaflake"       # optional: suggested – the build may choose another installed look
keymaps = ["omaflake/default"]   # optional: key binding sets in order – a later one wins for the same action

[requirements]                   # the least a VM from it needs – required; a smaller profile gets a warning
cpus = 4
memory_gb = 8
disk_gb = 40

[vm]                             # how a VM from it runs – required
display = "gpu"                  # none (headless) | window | gpu (window with 3D, NixOS)
network = "shared"               # shared | isolated (NixOS only) | none – required
share = true                     # share a folder: /mnt/share (NixOS), ~/Share (macOS) – required
ephemeral = false                # discard changes at power-off – required
audio = true                     # optional: audio, microphone, clipboard, camera (camera: NixOS)

[locales]                        # optional: the locales it is made for – another one gets a warning at the build
rtl = false                      # not for right-to-left languages
languages = ["en", "de"]         # only these languages
```

References point to the catalogs of the user's sources and to what is installed, with the official catalog always as
the fallback; a recipe never loads modules from a source the user has not added. Installing a recipe brings what it is
made of.

`systems` names the architectures the recipe is built and tested for, as Nix names them: `aarch64-linux` (NixOS on
a Mac with Apple silicon) and `x86_64-linux` for platform `nixos`, `aarch64-darwin` for `macos`. List only what you
have tested – omaflake shows a recipe only where it runs, and builds it only for a system it lists.

## Modules: `module.toml` and `default.nix`

```toml
"$schema" = "https://omaflake.dev/schema/module/v2.json"   # required
version = "1.0.0"                # required – raise it with every change (recipes may ask for a version)
author = "your-github-name"      # required
license = "MIT"                  # required
title = "Zathura"                # required – its name in lists
description = "The zathura PDF viewer: reloads a PDF when it changes."   # required
tags = ["pdf"]                   # from tags.toml
provides = ["pdf-viewer"]        # capabilities it provides (capabilities.toml)
needs = ["terminal"]             # capabilities a recipe with it needs – a warning when no module provides one
enhances = ["omaflake/neovim"]   # modules it adds to when the recipe has them too (<author>/<name>)
runs_in = ["terminal"]           # capabilities whose programs it runs inside – for overlapping keys
desktop = false                  # true: all its keys work on the whole desktop (a desktop module)
own_keys = false                 # true: an editor's own keys – the key rule does not apply
unfree = false                   # true: not free software (the user is told)

[actions.open]                   # an action people can bind a key to, with its default key
title = "Open zathura"
title_de = "Zathura öffnen"      # optional: the title in German (the app shows it there)
key = "Super+z"                  # or several keys, each doing it: ["h", "Left"]
desktop = true                   # optional: works everywhere on the desktop (a launcher)
# context = "omaflake/neovim"    # optional: bound inside another module's program
# own = true                     # optional: the program's own key, shown for reference – sets do not change it
```

A program with **modes** (Zellij's pane mode, Hyprland's resize submap) names them, and its actions say where they
work and where they lead – so that people can see the way to a key (Ctrl+g › p › n) and a key binding set can change
it:

```toml
[modes.locked]
title = "Locked"
title_de = "Gesperrt"
start = true                     # the mode the program starts in (exactly one)

[modes.pane]
title = "Pane"

[actions.new-pane]
title = "New pane"
key = "n"
mode = "pane"                    # only in this mode, or in several: ["pane", "tab"]
does = "NewPane"                 # optional: what it does in the program's own words
after = "locked"                 # optional: the mode afterwards; without it, it stays
```

**List all of a module's keys** – those it sets or changes, and the program's own keys one needs to work with it
(`own = true`), not every built-in one. Where a program's configuration has keys, the module writes it from its
actions (`omaflake.bindings`), so the list and the program cannot drift apart (`omaflake/nixos/zellij`).

**Capabilities** are a short, fixed list (`capabilities.toml`): `desktop` (exclusive), `terminal`, `multiplexer`,
`shell` (exclusive), `editor`, `default-editor` (exclusive – sets `$EDITOR`), `pdf-viewer`. Each says what a module
providing it promises – a `pdf-viewer` is the default for PDFs and reloads a changed file. Two modules providing an
exclusive one in a recipe are incompatible (a warning). A new capability is added rarely, in the same pull request as
the module that needs it.

`default.nix` is a NixOS module (platform `nixos`) or a nix-darwin module (platform `macos`). omaflake imports the
recipe's modules on top of its platform and hands each, besides `config`, `lib` and `pkgs` (omaflake's pinned
nixpkgs), these arguments:

| Argument | |
|---|---|
| `settings` | the user's values: `user`, `fullName`, `email`, `timeZone`, `locale`, `keyboard`, `keyboards`, `macUser` (macOS) |
| `omaflake.keys` | this module's actions → keys (its defaults, the recipe's key binding sets over them), e.g. `omaflake.keys.open` = `"Super+z"` (a list where the action has several) |
| `omaflake.bindings` | this module's actions as module.toml has them, with the recipe's key binding sets over `key` and `after` – to write a program's configuration |
| `omaflake.modes` | this module's `[modes]` |
| `omaflake.allKeys` | every module's keys in the recipe (`omaflake.allKeys."omaflake/zellij".session`) |
| `omaflake.has "<author>/<name>"` | whether the recipe has that module – for what it enhances |
| `omaflake.keyLib` | a key for Hyprland (`hyprland`), Zellij (`zellij`), WezTerm (`wezterm` → `{ key; mods; }`), Neovim (`neovim`), Emacs (`emacs`); `expand` for the `Digit` and `Arrow` placeholders |
| `nix-homebrew` | (macOS) the nix-homebrew flake |

The platform's options modules share: NixOS `omaflake.terminal.open`/`run` (set by the terminal module, used by the
desktop) and `omaflake.launchers` (`[{ key; command; }]` – keys that start a program anywhere on the desktop; the
desktop module binds them); macOS `omaflake.homeFiles` and `omaflake.homeLinks` (files and links put into the user's
home folder once, then theirs). The look's parts are `config.omaflake.lookColors` (the desktop's colours, null for a
plain look), `lookMacos` and `lookParts`. NixOS modules configure the user with home-manager:
`home-manager.users.${settings.user} = { … };`.

**Setting another module's options:** only when the recipe has it – decided from the recipe, not the configuration:
`lib.mkIf (omaflake.has "omaflake/neovim") { programs.neovim = …; }` for options that always exist (home-manager's),
`lib.optionalAttrs (omaflake.has "omaflake/vscode") { omaflake.vscode.extensions = …; }` (inside `config =
lib.mkMerge [ … ]`) for options another module declares.

**Keys:** written as a chord – modifiers (`Super`, the Mac's Cmd; `Ctrl`; `Alt`; `Shift`) and a key joined by `+`:
`Super+Shift+Return`, `Ctrl+g` – or, for an editor, a sequence: `Space f f`. Keys are lowercase letters, digits,
punctuation, `Plus`, `Return`, `Space`, `Escape`, `Tab`, `Backspace`, `Left`/`Right`/`Up`/`Down`, `PageUp`/`PageDown`,
`F1`–`F12`, and the placeholders `Digit` (1–9; `{digit}` in `does`) and `Arrow`. A capital is `Shift+h`. **The key
rule:** without a mode a key is one chord starting with `Super` or `Ctrl` (optionally with `Shift`); plain keys only
inside a mode; an editor's own keys (`own_keys`, `own`) stay as they are. `tools/catalog.py` checks that no two keys of
a recipe overlap: the same context and a mode they share; a desktop-wide one with any key without a mode; a program's
key with one of a program that runs inside it (`runs_in`).

What a module must not do:

- bring its own flake, flake inputs or `flake.lock` – it uses omaflake's pinned inputs;
- fetch anything without a hash, or download and run code at run time (`curl … | sh`, unpinned installers);
- contain secrets, keys, personal data (names, e-mail addresses, host names, paths like `/Users/…`), telemetry or
  tracking;
- read anything from the computer it is evaluated on (`builtins.getEnv`, absolute paths);
- switch off or change omaflake's guest agent or platform.

Files: at most 1 MiB each and 5 MiB per module, no symbolic links.

## Key bindings: `keymap.toml`

```toml
"$schema" = "https://omaflake.dev/schema/keymap/v2.json"   # required
version = "1.0.0"                # required
author = "your-github-name"      # required
license = "MIT"                  # required
title = "Mine"                   # required
description = "Super+t opens a terminal."                    # required

[keys."omaflake/hyprland"]       # a module's actions → keys (any of them)
terminal = "Super+t"

[keys."omaflake/zellij"]
focus-left = ["h", "Left", "Ctrl+h"]   # several keys
new-pane = { after = "pane" }          # the mode afterwards: stay in pane mode (key unchanged)
```

A set gives keys (and `after`) only to the actions it names, never to a program's own keys; a recipe may combine
several (`keymaps = ["omaflake/default", "you/mine"]`), a later one wins.

## Testing

Add your fork's checkout as a local source – in omaflake's Settings → Sources ("Folder …"), or
`omaf sources add <path to your checkout> --first` – and look at what a recipe is made of (`omaf recipes show
<author>/<platform>/<name>`: its modules, keys and warnings), then build it from the Recipes tab or with `omaf build
<author>/<platform>/<name>`. A local folder is used as it is: change a file, build again. Put the folder first in the
list while it has an entry of the same name as another source.

## Contributing a look

A look is one file, `looks/<your GitHub name>/<name>/look.toml` (and, if you like, a `preview.png` next to it, at
most 1 MiB). It is data: omaflake's image flake turns it into the configuration of Hyprland, Waybar, Fuzzel, Mako,
the prompt, GTK, WezTerm, Zellij, Neovim and Emacs – and macOS guests take the terminal's and the editors' part. So a
look never breaks when omaflake changes how a program is configured, and it runs no code.

```toml
"$schema" = "https://omaflake.dev/schema/look/v1.json"   # the version of this format – required
version = "1.0.0"                # raise it with every change – recipes may ask for a version
author = "your-github-name"      # the folder's author – required
license = "MIT"                  # one of source.toml's licenses – required
title = "Nord"                   # its name as people know it – required
description = "An arctic, north-bluish palette."          # English – required
description_de = "Eine arktische, nordisch-bläuliche Palette."   # optional, any language code
tags = ["dark"]                  # from tags.toml's [looks] – required
homepage = "https://…"           # optional: the theme's own page
appearance = "dark"              # dark | light – required (not for plain = true)
# plain = true                   # instead of all colours: the look sets none (like Vanilla)

[colors]                         # every colour is "#RRGGBB" – all required but cursor
background = "#2e3440"           # desktop, terminal, editors
surface = "#3b4252"              # bars, panels, popups
selection = "#434c5e"
text = "#eceff4"
subtext = "#d8dee9"
muted = "#4c566a"                # comments, inactive things
accent = "#88c0d0"               # highlights, matches, the active workspace
urgent = "#bf616a"               # errors, urgent notifications
cursor = "#d8dee9"               # optional (default: accent)

[terminal]                       # the 16 colours: black, red, green, yellow, blue, magenta, cyan, white – required
normal = ["#3b4252", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0"]
bright = ["#4c566a", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"]

[desktop]                        # optional, NixOS's desktop
border = ["#88c0d0", "#81a1c1"]  # the active window: one colour, or two for a gradient
inactive_border = "#3b4252"
clock = "#88c0d0"
split = ["#bf616a", "#88c0d0"]   # optional: the active workspace's number with a fine two-colour shadow
prompt = { ok = "#a3be8c", error = "#bf616a", directory = "#88c0d0" }
gtk = "adw-gtk3-dark"            # adw-gtk3 | adw-gtk3-dark (default: after appearance)
cursor_theme = "Bibata-Modern-Classic"   # Bibata-Modern-/Bibata-Original- + Classic | Ice | Amber

[neovim]                         # optional: a theme from nixpkgs; left out, it is made from the colours
theme = "catppuccin"             # catppuccin (flavour) | rose-pine (variant) | modus (style)
flavour = "mocha"

[macos]                          # optional, macOS guests (light or dark: appearance); left out: graphite and clear
accent = "graphite"              #   icons for a dark look, macOS' own for a light one
icons = "clear"                  # accent: multicolor | graphite; icons: default | clear
folders = "graphite"             # folders: default | graphite; wallpaper: default | black
wallpaper = "black"              # (more values once they are checked in a guest)

[emacs]                          # optional, as [neovim]: catppuccin (flavour) | modus (style)
theme = "modus"
style = "modus-vivendi"
```

A look after a known theme uses that theme's published palette and links it in a comment. Test it in omaflake: add
your checkout as a local source, build an image with the look (the build page, or `omaf build <recipe> --look
<author>/<name>`) and look at the desktop, a terminal and an editor. The terminal's colours are what `ls`, `git`,
`bat` and the prompt use – check them on the background.

