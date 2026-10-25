# omaflake recipes

The official catalog of recipes for [omaflake](https://github.com/omaflake/omaflake) – disposable NixOS and macOS
VMs on Mac and Linux. A recipe declares what a VM is: what is inside it (a NixOS or nix-darwin module) and how it runs
(CPUs, memory, network, …). omaflake builds an image from a recipe and starts VMs from that image.

omaflake does not ship recipes in the app. It knows this repository as its default **recipe source**: the Recipes tab
lists what is here, and you download the recipes you want. Recipes by `omaflake` from this repository are marked as
official and suggested at the first start. Anyone can propose a recipe by pull request (CONTRIBUTING.md); the core
team reviews it (REVIEW.md) before it is merged. You can also run a catalog of your own (FORKING.md).

How recipes work – `recipe.toml`, architectures, variants, recipe sources: [Writing recipes](https://omaflake.dev/recipes/)
on omaflake.dev.

## Layout

```
catalog.json                    generated – the one file omaflake reads to browse this source
source.toml                     name and description of this source, allowed licenses
tags.toml                       the tags recipes ([tags]) and looks ([looks]) may use
recipes/<author>/<kind>/<name>/ one folder per recipe
  recipe.toml                   metadata and how a VM from it runs
  default.nix                   what is inside it: a NixOS module (kind nixos) or a nix-darwin module (kind macos)
  …                             its own files: scripts, configs, icons, assets
looks/<author>/<name>/          one folder per look
  look.toml                     its colours and choices (schema look/v1)
  preview.png                   optional: a screenshot
tools/catalog.py                checks every recipe and look and writes catalog.json
.github/                        CI (the same check) and the pull request checklist
```

- `<author>` is the GitHub name of whoever submitted the recipe (`omaflake` for the core team's). The folder is the
  recipe's identity: its ID is `<author>.<kind>.<name>`, shown as `<author>/<kind>/<name>`, so recipes of different
  authors never collide.
- `<kind>` is the guest kind, `nixos` or `macos`. A recipe for both kinds is two folders.
- A recipe is a module on top of omaflake's own guest modules (guest hardware, the omaflake agent, user, keys, locale),
  never a flake of its own. It can build on another recipe of the same kind (`requires`, then `imports = [ ../neovim-minimal ]`).

## Looks

| Look | |
|---|---|
| `omaflake/omaflake` | omaflake's own – black and high contrast, red and cyan as fine accents |
| `omaflake/catppuccin` | Catppuccin Mocha – soothing pastel on a dark base |
| `omaflake/rose-pine-dawn` | Rosé Pine Dawn – light and mild: cream, rose, iris and gold |
| `omaflake/vanilla` | every program in its own colours (`plain = true`) |

No look is built into omaflake: every one is installed from here and can be removed. omaflake's Doctor recommends
`omaflake/omaflake` and `omaflake/catppuccin` when none is installed (plan B140, B141).

## Recipes

| Recipe | |
|---|---|
| `omaflake/nixos/neovim-minimal` | NixOS with the Hyprland desktop and the neovim line (Neovim, Zellij) |
| `omaflake/nixos/neovim-research` | TeX Live and Typst with a live PDF beside neovim, Jupyter, pandas, pandoc |
| `omaflake/nixos/emacs-minimal` | NixOS with the Hyprland desktop and the emacs line (Emacs with Vertico, Magit, Eglot) |
| `omaflake/macos/minimal` | macOS with Nix, terminal tools, a minimal Dock and a dark look |
| `omaflake/macos/research` | TeX Live, VS Code for LaTeX and Typst, WezTerm with Zellij, Homebrew |
| `omaflake/nixos/lab`, `omaflake/macos/lab` | for developing omaflake itself (shown in developer mode only); `nixos/lab` brings omaflake's Linux app and `omaf ui` to try them (VMs cannot start inside it) |

## How omaflake uses `catalog.json`

`catalog.json` (schema `catalog/v3`) lists every recipe with its metadata (description, tags, license, guest kind,
defaults) and every look with its title, appearance and main colours (`swatches`, for a preview), each with a
`version` and its files with size and SHA-256. omaflake

1. fetches `catalog.json` from the source's URL – only when you open or search the Recipes or Looks tab, never in the
   background;
2. searches and filters it locally (name, description, tags, guest kind, appearance, author);
3. downloads an entry's files next to `catalog.json` (`<url>/<path>/<file>`) and checks every SHA-256 before it
   keeps them, together with the recipes a recipe `requires`;
4. compares an installed entry's `version` with the catalog's to offer updates.

A public source needs no GitHub API, so it works from any static web server. A private GitHub repository works too:
omaflake reads it over the GitHub API with a fine-grained token (Contents: Read-only), which it checks when you add
the source and keeps in your Keychain. A **local folder** (a checkout of this repository, or any folder with
`recipes/<author>/<kind>/<name>/`) needs no `catalog.json`: omaflake uses its recipes as they are on disk, so a
change is built the next time – that is how recipes are written and tested. Downloaded recipes live in omaflake's
data folder (`recipes/<author>/<kind>/<name>/`); omaflake's spec §11.3 describes sources, installing and updates.

## Checking

```sh
python3 tools/catalog.py           # check every recipe and look, write catalog.json
python3 tools/catalog.py --check   # check, and fail if catalog.json is not up to date (CI does this)
```

It needs Python 3.11 or newer; the Python that comes with macOS is older – `nix run nixpkgs#python3 -- tools/catalog.py`.

## License

The repository is MIT licensed (LICENSE). Each recipe and look states its own license (`recipe.toml`, `look.toml`);
the allowed ones are in `source.toml`.
