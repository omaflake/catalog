# omaflake catalog

The official catalog of [omaflake](https://github.com/omaflake/omaflake) – disposable NixOS and macOS VMs on Mac and
Linux: **recipes**, the **modules** they are made of, **key bindings** and **looks**. A recipe declares what a VM is –
a platform, its modules, a suggested look and key bindings, what a VM needs and how it runs; omaflake builds an image
from a recipe and starts VMs from that image.

omaflake ships none of it. It knows this repository as its default **source**: the Recipes, Modules and Looks tabs list
what is here, and installing a recipe brings what it is made of. Entries by `omaflake` from this repository are marked
as official and suggested at the first start. Anyone can propose a recipe, a module, key bindings or a look by pull
request (CONTRIBUTING.md); the core team reviews it (REVIEW.md) before it is merged. You can also run a catalog of your
own (FORKING.md).

How recipes work: [Writing recipes](https://omaflake.dev/recipes/) on omaflake.dev.

## Layout

```
catalog.json                        generated – the one file omaflake reads to browse this source
source.toml                         name and description of this source, allowed licenses
tags.toml                           the tags recipes and modules ([tags]) and looks ([looks]) may use
capabilities.toml                   what modules may provide and need (desktop, terminal, editor, …)
recipes/<author>/<platform>/<name>/ one folder per recipe
  recipe.toml                       what is in it, how it looks, which keys, what a VM needs – data only
modules/<author>/<platform>/<name>/ one folder per module
  module.toml                       its version, capabilities, actions with default keys
  default.nix                       a NixOS module (platform nixos) or a nix-darwin module (platform macos)
  …                                 its own files: scripts, configs, icons, assets
keymaps/<author>/<name>/            one folder per key binding set
  keymap.toml                       keys for modules' actions
looks/<author>/<name>/              one folder per look
  look.toml                         its colours and choices (schema look/v1)
  preview.png                       optional: a screenshot
tools/catalog.py                    checks everything (also overlapping keys) and writes catalog.json
.github/                            CI (the same check) and the pull request checklist
```

- `<author>` is the GitHub name of whoever submitted it (`omaflake` for the core team's). The folder is its identity:
  a recipe's ID is `<author>.<platform>.<name>`, a module's too; recipes name modules, key bindings and looks as
  `<author>/<name>` (a module of the recipe's platform).
- `<platform>` is `nixos` or `macos`. A recipe or module for both is two folders.
- A recipe is data; the Nix is in modules, on top of omaflake's platform (guest hardware, the omaflake agent, user,
  keys, locale, the look's files), never a flake of its own.

## Recipes

| Recipe | Modules |
|---|---|
| `omaflake/nixos/neovim-minimal` | hyprland, shell, wezterm, zellij, neovim |
| `omaflake/nixos/neovim-research` | as neovim-minimal + zathura, latex, typst, python-data, pandoc |
| `omaflake/nixos/emacs-minimal` | hyprland, shell, wezterm, emacs |
| `omaflake/macos/minimal` | desktop, shell |
| `omaflake/macos/research` | desktop, shell, wezterm, zellij, neovim, latex, typst, vscode, pandoc, lazygit, homebrew |
| `omaflake/nixos/lab`, `omaflake/macos/lab` | for developing omaflake itself (shown in developer mode only): + omaflake-dev |

All with the look `omaflake/omaflake` and the key bindings `omaflake/default`.

## Modules

| NixOS | |
|---|---|
| `hyprland` | the desktop: Hyprland, Waybar, Fuzzel, Mako, PipeWire, the window following the VM's size |
| `shell` | zsh, Starship, ripgrep, fd, bat, eza, fzf, jq, btop, fastfetch |
| `wezterm` | the terminal |
| `zellij` | the multiplexer with keys that leave the editor's alone (Ctrl+g unlocks) |
| `neovim` | Neovim, preconfigured; the default editor |
| `emacs` | Emacs (pure GTK), preconfigured; the default editor |
| `zathura` | the PDF viewer |
| `latex` | TeX Live (full), texlab; vimtex with Neovim, SyncTeX with zathura |
| `typst` | Typst, tinymist; a live PDF with Neovim |
| `python-data` | numpy, pandas, matplotlib, JupyterLab |
| `pandoc` | pandoc |
| `omaflake-dev` | omaflake itself, the omaflake Test app, debug tools (for developing omaflake) |

| macOS | |
|---|---|
| `desktop` | a minimal Dock, Finder, the look's appearance, no widgets, a quiet menu bar, a private Safari |
| `shell` | git, Neovim, ripgrep, fd, jq, htop |
| `wezterm`, `zellij`, `neovim` | the terminal, the multiplexer, the editor with the look |
| `latex`, `typst` | TeX Live and Typst; vimtex with Neovim, LaTeX Workshop and Tinymist with VS Code |
| `vscode` | VS Code with LTeX+, GitLens, Nix IDE (not free software) |
| `homebrew`, `pandoc`, `lazygit` | one thing each |
| `omaflake-dev` | the omaflake Test app and tools |

Key bindings: `omaflake/default` – omaflake's keys (Super or Ctrl first; Zellij unlocks with Ctrl+g; Neovim's leader
is Space).

## Looks

| Look | |
|---|---|
| `omaflake/omaflake` | omaflake's own – black and high contrast, red and cyan as fine accents |
| `omaflake/catppuccin` | Catppuccin Mocha – soothing pastel on a dark base |
| `omaflake/rose-pine-dawn` | Rosé Pine Dawn – light and mild: cream, rose, iris and gold |
| `omaflake/vanilla` | every program in its own colours (`plain = true`) |

No look is built into omaflake: every one is installed from here and can be removed. omaflake's Doctor recommends
`omaflake/omaflake` and `omaflake/catppuccin` when none is installed (plan B140, B141).

## How omaflake uses `catalog.json`

`catalog.json` (schema `catalog/v5`) lists every recipe (what it is made of, its requirements and how a VM runs),
module (version, capabilities, actions), key binding set, look (title, appearance, main colours for a preview) and the
capabilities, each with its files' sizes and SHA-256 and a content hash. omaflake

1. fetches `catalog.json` from the source's URL – only when you open or refresh the Recipes, Modules or Looks tab,
   never in the background;
2. searches and filters it locally;
3. downloads an entry's files next to `catalog.json` (`<url>/<path>/<file>`) and checks every SHA-256 before it keeps
   them; installing a recipe brings the modules, key bindings and look it is made of that are not there yet, from the
   first source that has each in a version the recipe allows (this catalog last);
4. compares an installed entry's content hash with the catalog's to offer updates.

A public source needs no GitHub API, so it works from any static web server. A private GitHub repository works too:
omaflake reads it over the GitHub API with a fine-grained token (Contents: Read-only), which it checks when you add
the source and keeps in your Keychain. A **local folder** (a checkout of this repository, or any folder laid out like
it) needs no `catalog.json`: omaflake uses its recipes and modules as they are on disk, so a change is built the next
time – that is how they are written and tested. omaflake's spec §11.3 describes sources, installing and updates.

## Checking

```sh
python3 tools/catalog.py           # check everything, write catalog.json
python3 tools/catalog.py --check   # check, and fail if catalog.json is not up to date (CI does this)
```

It needs Python 3.11 or newer; the Python that comes with macOS is older – `nix run nixpkgs#python3 -- tools/catalog.py`.

## License

The repository is MIT licensed (LICENSE). Each recipe, module, key binding set and look states its own license; the
allowed ones are in `source.toml`.
