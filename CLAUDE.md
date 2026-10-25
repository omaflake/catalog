# CLAUDE.md – project rules for Claude Code

## Context

`omaflake/catalog`: the official catalog of omaflake – recipes and looks (plan B140; it replaces the archived
`omaflake/recipes`) – and the template for other sources. omaflake itself (app, CLI, guest modules, the image flake
that builds images and turns looks into configuration) lives in `omaflake/omaflake`, checked out next to this one as
`../omaflake`; its design for sources is `../omaflake/docs/spec.md` §11.3, the catalog decision plan B140.

## Working rules

- **Language:** everything in this repository is English. Talk to the maintainer in German.
- **Public from day one:** no personal data in tracked files (names, home paths, host names, keys).
- **The format is an interface.** `catalog.json` (`$schema` catalog/v3), the folder layouts `recipes/<author>/<kind>/<name>/`
  and `looks/<author>/<name>/`, the `recipe.toml` fields (`"$schema"` recipe/v1) and the `look.toml` fields (look/v1) are
  what omaflake reads; the JSON Schemas live in omaflake's
  `docs/schema/`. Change them only together with omaflake, and raise the version in `tools/catalog.py` for changes an
  older omaflake would misread.
- **After every change:** `python3 tools/catalog.py` (or `nix run nixpkgs#python3 -- tools/catalog.py`) and commit
  `catalog.json` with the change; `--check` must pass.
- **Looks are data:** a `look.toml` holds colours and choices only (no code); `tools/catalog.py` checks every field
  against what omaflake's image flake supports (editor themes, GTK theme, cursors). omaflake's own look and Vanilla
  live in the image flake, not here.
- **Recipes:** omaflake's own recipes are under `recipes/omaflake/`. A change to them is tested by building an image
  in omaflake (CONTRIBUTING.md, "Testing your recipe").
- **Never delete (your own actions):** move files to `_to_delete/` (git-ignored) instead.
- **Verified before claimed:** mark what is not verified as `OPEN`.
