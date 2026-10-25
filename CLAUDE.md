# CLAUDE.md – project rules for Claude Code

## Context

`omaflake/catalog`: the official catalog of omaflake – recipes, modules, key bindings and looks (plan B140, B142; it
replaces the archived `omaflake/recipes`) – and the template for other sources. omaflake itself (app, CLI, guest modules, the image flake
that builds images and turns looks into configuration) lives in `omaflake/omaflake`, checked out next to this one as
`../omaflake`; its design for sources is `../omaflake/docs/spec.md` §11.3, the catalog decision plan B140.

## Working rules

- **Language:** everything in this repository is English. Talk to the maintainer in German.
- **Public from day one:** no personal data in tracked files (names, home paths, host names, keys).
- **The format is an interface.** `catalog.json` (`$schema` catalog/v4), the folder layouts
  `recipes/<author>/<platform>/<name>/`, `modules/<author>/<platform>/<name>/`, `keymaps/<author>/<name>/` and
  `looks/<author>/<name>/`, the fields of `recipe.toml` (recipe/v2), `module.toml` (module/v1), `keymap.toml`
  (keymap/v1), `look.toml` (look/v1) and `capabilities.toml`, and the module arguments (`omaflake.keys`, `has`, …) are
  what omaflake and its image flake read; the JSON Schemas live in omaflake's
  `docs/schema/`. Change them only together with omaflake, and raise the version in `tools/catalog.py` for changes an
  older omaflake would misread.
- **After every change:** `python3 tools/catalog.py` (or `nix run nixpkgs#python3 -- tools/catalog.py`) and commit
  `catalog.json` with the change; `--check` must pass.
- **Recipes, key bindings and looks are data, modules are code.** A recipe is recipe.toml only; Nix goes in a module.
  `tools/catalog.py` checks every field, references and versions, capabilities (warnings), overlapping keys and the
  key rule (errors). omaflake's own look is generated in omaflake/omaflake (`brand/tokens.py`, copied here).
- **Versions:** raise a module's, key binding set's or look's `version` with every change.
- **Testing:** omaflake's own entries are under `*/omaflake/`. A change is tested in omaflake with this checkout as a
  local source (`omaf recipes show`, a build; CONTRIBUTING.md, "Testing"); omaflake's image flake is checked with
  `nix flake check "path:<omaflake>/nix" --override-input omaflake-catalog "path:$PWD"`.
- **Never delete (your own actions):** move files to `_to_delete/` (git-ignored) instead.
- **Verified before claimed:** mark what is not verified as `OPEN`.
