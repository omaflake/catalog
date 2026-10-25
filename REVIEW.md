# Reviewing a recipe, a module, key bindings or a look

What the core team checks before anything is merged. CI (`tools/catalog.py --check`) covers the structure – every
field, references and versions, overlapping keys and the key rule – and prints warnings for patterns worth a look;
everything else is a reviewer's judgement. An entry is merged when two things hold: we would run it ourselves, and it
gives users something the catalog does not have yet.

**Modules are code** – the closest look goes to them. Recipes, key bindings and looks are data.

## Modules: safety

A module's Nix code is evaluated on the user's computer and its result runs in their VM, often with a shared folder and
network. Read every file.

- [ ] Every fetch is pinned with a hash (`fetchFromGitHub`, `fetchurl` with `hash`); no `builtins.fetch*` without
      one; nothing downloaded and run at run time (`curl … | sh`, self-updating installers, `npm install -g` at
      first start).
- [ ] Nothing reads the Mac it is evaluated on: no `builtins.getEnv`, no absolute paths, no `builtins.readFile`
      outside the recipe's folder.
- [ ] No secrets, keys, tokens, personal data; no telemetry, analytics or tracking switched on.
- [ ] omaflake's platform and agent are left alone (not disabled, not replaced, no extra open ports towards the
      Mac); SSH stays key-only.
- [ ] Network services in the guest listen only where the recipe says they do and why; no new users with passwords.
- [ ] `allowUnfree` / insecure packages only where named and needed; the description says so.
- [ ] Scripts, binaries and assets: scripts are readable; no prebuilt binaries – packages come from nixpkgs or are
      built from pinned sources; icons and plists are what they claim to be.

## Modules: fitness

- [ ] The folder is `modules/<author>/<platform>/<name>/`, `author` is the submitter's GitHub name.
- [ ] It does one thing (a program, a tool set) and says what it provides and needs with the existing capabilities;
      what it does for other modules (`enhances`) is set only when the recipe has them (`omaflake.has`).
- [ ] Its actions have sensible default keys that follow the key rule; an editor's own keys are marked `own_keys`.
- [ ] The look reaches it where the program has colours (`lookColors`, `lookParts`, the files under
      `/etc/omaflake/look/`).
- [ ] `version` is raised with every change.

## Recipes

- [ ] The folder is `recipes/<author>/<platform>/<name>/`, recipe.toml its only file.
- [ ] It builds and a VM starts from it on the platform it claims (macOS: on a current macOS base); the submitter said
      what they tried, and a reviewer tried it. `omaf recipes show` lists no warnings that matter.
- [ ] Requirements are honest: what a VM needs at least (no 32 GB for an editor); `[vm]` matches the purpose.
- [ ] Version limits on references only where needed – the newest is the default.
- [ ] Description in English says what it is for and what is inside; tags fit (new tags in tags.toml are worth adding).

## Key bindings

- [ ] Every action exists in the module named; the keys follow the key rule; CI found no overlaps in the recipes here.

## Added value

- [ ] Not a near-copy of an entry already here – then a change to that entry is the better pull request.
- [ ] A clear purpose (a language's toolchain, a kind of work, a tool) rather than one person's dotfiles.

## License

- [ ] `license` is one of source.toml's licenses, and the submitter can put the entry under it (no copied configs
      under other terms).

## After merging

`catalog.json` comes with the pull request, so the merge publishes it. A module that later turns out unsafe is
removed at once (its folder goes, catalog.json follows); omaflake shows installed entries that disappeared from their
source.

## Looks

A look is data – CI checks every field against what omaflake supports, so there is no code to read. The reviewer
checks what CI cannot:

- [ ] It is readable: text on background and on surface, the terminal's colours on its background (aim for WCAG AA,
      4.5:1 for text); the selection stays visible.
- [ ] `appearance` matches the background; the editor themes chosen fit it (a light look with a light variant).
- [ ] A look after another theme (Catppuccin, Rosé Pine, Nord, …) uses that theme's published palette, says so in a
      comment with a link, and its license allows it.
- [ ] It adds something the catalog does not have yet; a preview.png (optional) shows the look, nothing else.
