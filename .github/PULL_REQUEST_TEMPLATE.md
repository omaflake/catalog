<!-- One recipe, module, key binding set or look per pull request (a recipe may come with the modules it is made of).
The reviewers go through REVIEW.md; the boxes below are your part. -->

**What** – recipe `<author>/<platform>/<name>`, module `<author>/<platform>/<name>`, key bindings `<author>/<name>` or
look `<author>/<name>`:

**What it is for** (one or two sentences):

**Tested:** omaflake version / host, NixOS or macOS guest, what you tried in the VM:

- [ ] The folder is in my GitHub name's folder, and `author` is my GitHub name
- [ ] I built an image with it (a module, key bindings or a look: in a recipe of my choice) and started a VM (on every platform it claims)
- [ ] `omaf recipes show` lists no warnings I did not mean
- [ ] Modules: every download is pinned (Nix fetchers with a hash; nothing fetched at run time from changing URLs); its `version` is raised
- [ ] No secrets, keys, personal data, telemetry or tracking
- [ ] `python3 tools/catalog.py` ran and catalog.json is part of this pull request
- [ ] It is mine to share under its `license`
