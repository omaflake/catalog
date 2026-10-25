<!-- One recipe or one look per pull request, please. The reviewers go through REVIEW.md; the boxes below are your part. -->

**Recipe** `<author>/<kind>/<name>` **or look** `<author>/<name>`:

**What it is for** (one or two sentences):

**Tested:** omaflake version / macOS version, NixOS or macOS guest, what you tried in the VM:

- [ ] The folder is `recipes/<my GitHub name>/<kind>/<name>/` or `looks/<my GitHub name>/<name>/`, and `author` is my GitHub name
- [ ] I built an image from it (a look: with a recipe of my choice) and started a VM (on every guest kind it claims)
- [ ] Every download is pinned (Nix fetchers with a hash; nothing fetched at run time from changing URLs)
- [ ] No secrets, keys, personal data, telemetry or tracking
- [ ] `python3 tools/catalog.py` ran and catalog.json is part of this pull request
- [ ] It is mine to share under the `license` in its recipe.toml / look.toml
