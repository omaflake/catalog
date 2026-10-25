# Reviewing a recipe or a look

What the core team checks before a recipe is merged. CI (`tools/catalog.py --check`) covers the structure and
prints warnings for patterns worth a look; everything else is a reviewer's judgement. A recipe is merged when two
things hold: we would run it ourselves, and it gives users something the catalog does not have yet.

## Safety

The recipe's Nix code is evaluated on the user's Mac and its result runs in their VM, often with a shared folder and
network. Read every file.

- [ ] Every fetch is pinned with a hash (`fetchFromGitHub`, `fetchurl` with `hash`); no `builtins.fetch*` without
      one; nothing downloaded and run at run time (`curl … | sh`, self-updating installers, `npm install -g` at
      first start).
- [ ] Nothing reads the Mac it is evaluated on: no `builtins.getEnv`, no absolute paths, no `builtins.readFile`
      outside the recipe's folder.
- [ ] No secrets, keys, tokens, personal data; no telemetry, analytics or tracking switched on.
- [ ] omaflake's guest modules and agent are left alone (not disabled, not replaced, no extra open ports towards the
      Mac); SSH stays key-only.
- [ ] Network services in the guest listen only where the recipe says they do and why; no new users with passwords.
- [ ] `allowUnfree` / insecure packages only where named and needed; the description says so.
- [ ] Scripts, binaries and assets: scripts are readable; no prebuilt binaries – packages come from nixpkgs or are
      built from pinned sources; icons and plists are what they claim to be.

## Fitness

- [ ] The folder is `recipes/<author>/<kind>/<name>/`, `author` is the submitter's GitHub name (CI checks the match;
      the reviewer checks the name is theirs).
- [ ] It builds and a VM starts from it on the guest kind it claims (macOS: on a current macOS base); the submitter
      said what they tried, and a reviewer tried it.
- [ ] Defaults are sensible: resources fit the content (no 32 GB for an editor), `network`, `share`, `ephemeral`
      and the switches match the purpose.
- [ ] `requires` is complete and the imports use the relative path.
- [ ] Description in English says what it is for and what is inside; tags fit (new tags in tags.toml are worth adding).

## Added value

- [ ] Not a near-copy of a recipe already here – then a change to that recipe is the better pull request.
- [ ] A clear purpose (a language's toolchain, a kind of work, a tool) rather than one person's dotfiles.

## License

- [ ] `license` is one of source.toml's licenses, and the submitter can put the recipe under it (no copied configs
      under other terms).

## After merging

`catalog.json` comes with the pull request, so the merge publishes the recipe. A recipe that later turns out unsafe
is removed at once (its folder goes, catalog.json follows); omaflake shows installed recipes that disappeared from
their source.

## Looks

A look is data – CI checks every field against what omaflake supports, so there is no code to read. The reviewer
checks what CI cannot:

- [ ] It is readable: text on background and on surface, the terminal's colours on its background (aim for WCAG AA,
      4.5:1 for text); the selection stays visible.
- [ ] `appearance` matches the background; the editor themes chosen fit it (a light look with a light variant).
- [ ] A look after another theme (Catppuccin, Rosé Pine, Nord, …) uses that theme's published palette, says so in a
      comment with a link, and its license allows it.
- [ ] It adds something the catalog does not have yet; a preview.png (optional) shows the look, nothing else.
