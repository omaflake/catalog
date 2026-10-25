# Your own catalog

omaflake reads recipes and looks from **sources**. A source is a URL where a `catalog.json` lives, with the recipe
and look folders next to it – nothing more. A source may offer recipes, looks or both. This repository is the default
source; you can add others in omaflake's settings
(Settings → Recipe Sources) and switch each one on or off. Use your own source for recipes your team shares, for
recipes you do not want to publish, or to run a curated catalog of your own.

Recipes from other sources are **not reviewed by the omaflake team**. Their Nix code runs on your computer when you build
them – add only sources you trust. omaflake marks recipes as official only when they are by `omaflake` *and* come
from this repository; an author name alone is not enough.

## Option 1: fork this repository

You get everything: the official recipes, the checks, the CI and the pull request checklist.

1. Fork `omaflake/catalog` on GitHub.
2. Edit `source.toml`: your source's `name`, `description` and `homepage`, and the `licenses` you accept.
3. Add recipes under `recipes/<author>/<kind>/<name>/` and looks under `looks/<author>/<name>/` (CONTRIBUTING.md) –
   remove the ones you do not want.
4. Run `python3 tools/catalog.py`, commit `catalog.json` with your changes, push.
5. In omaflake, add the source – Settings → Recipe Sources, or `omaf sources add https://github.com/<you>/catalog`
   (another branch: `…/tree/<branch>`, or `--branch`).

To pick up new official recipes, use GitHub's "Sync fork" (or `git pull upstream main`) and run the tool again. If
you keep the official recipes in your fork, omaflake shows them from your source without the official mark – the
copy in this repository keeps it.

## Option 2: a repository of your own

Use this repository as a template ("Use this template" on GitHub), or start empty with this layout:

```
catalog.json
source.toml         name = "…"  description = "…"  (homepage, licenses optional)
tags.toml           [tags] with the tags your recipes use, [looks] with your looks' tags
recipes/<author>/<kind>/<name>/recipe.toml
recipes/<author>/<kind>/<name>/default.nix
looks/<author>/<name>/look.toml
tools/catalog.py    copied from this repository
```

Then run `python3 tools/catalog.py`, commit, push and add the repository as above (on another host: the HTTPS URL of
your `catalog.json`). The CI workflow in `.github/workflows/check.yml` works unchanged if you copy it too.

## Hosting elsewhere

omaflake fetches `catalog.json` and then each recipe file at `<folder of catalog.json>/<path>/<file>`, and checks
every file's SHA-256 against the catalog. Any HTTPS server that serves the files as they are in the repository works:
GitHub Pages, Codeberg, GitLab, your own web server or bucket. Only HTTPS URLs are accepted.

## Testing with a local folder

A source can also be a local folder – a checkout of your repository. omaflake uses its recipes as they are on
disk (no `catalog.json` needed), so a change is built the next time. That is the quickest way to try a recipe before
you push or open a pull request.

## Private sources

A private GitHub repository works as a source: in Settings → Recipe Sources tick "Private repository" and enter a
fine-grained token that has **Contents: Read-only** on that repository (nothing else). omaflake checks it against the
repository and the catalog before it keeps the source, stores it in your Keychain (never in a file) and reads the
repository over the GitHub API with it. On the command line: `omaf sources add https://github.com/<you>/catalog
--private` reads the token from stdin. Other private hosts: OPEN – use a local clone meanwhile.

## Status

omaflake reads recipe sources since plan B107 (its spec §11.3). The format here – `catalog.json` (`catalog/v3`), the folder
layouts, `recipe.toml` (`recipe/v1`) and `look.toml` (`look/v1`; schemas on omaflake.dev/schema) – is what it reads (looks:
OPEN, plan B140); until the first public release it can still change.
