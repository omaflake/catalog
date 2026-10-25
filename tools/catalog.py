#!/usr/bin/env python3
"""Check every recipe, module, key binding set and look in this repository and write catalog.json – the one file
omaflake reads to browse it.

  python3 tools/catalog.py           # check, then write catalog.json
  python3 tools/catalog.py --check   # check, and fail if catalog.json is not up to date (CI)

Needs Python 3.11 or newer (tomllib) and nothing else, so forks and own catalogs can run it anywhere. Without a
recent Python: `nix run nixpkgs#python3 -- tools/catalog.py`. Errors fail the run; warnings are for the reviewers.
The output has no timestamps or commit hashes, so it only changes when something in here changes.
"""

import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECIPES = ROOT / "recipes"
MODULES = ROOT / "modules"
KEYMAPS = ROOT / "keymaps"
LOOKS = ROOT / "looks"
CATALOG = ROOT / "catalog.json"
# The JSON Schemas (omaflake/omaflake docs/schema/, published on omaflake.dev): what this catalog is, and what each
# file names in "$schema" – as omaflake's image flake reads it
SCHEMA = "https://omaflake.dev/schema/catalog/v4.json"      # v2: systems; v3: looks; v4: modules, key bindings, recipe v2
RECIPE_SCHEMA = "https://omaflake.dev/schema/recipe/v2.json"
MODULE_SCHEMA = "https://omaflake.dev/schema/module/v1.json"
KEYMAP_SCHEMA = "https://omaflake.dev/schema/keymap/v1.json"
LOOK_SCHEMA = "https://omaflake.dev/schema/look/v1.json"

PLATFORMS = ("nixos", "macos")
# What a recipe of each platform can be built for (Nix system names)
SYSTEMS = {"nixos": ("aarch64-linux", "x86_64-linux"), "macos": ("aarch64-darwin",)}
NAME = re.compile(r"[a-z0-9][a-z0-9-]*")
TAG = re.compile(r"[a-z0-9][a-z0-9+.-]*")
# A reference to a module, look or key binding set: <author>/<name> (a module's platform is the recipe's)
REF = re.compile(r"([a-z0-9][a-z0-9-]*)/([a-z0-9][a-z0-9-]*)")
VERSION = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")

# recipe.toml (v2): data only – what is in it, how it looks, which keys, what a VM needs and how it runs
RECIPE_KEYS = {"$schema", "author", "license", "description", "tags", "lab", "homepage", "platform", "systems",
               "modules", "look", "keymaps", "requirements", "vm", "locales"}
REQUIRED = ("$schema", "author", "license", "description", "tags", "platform", "systems", "modules", "requirements", "vm")
REQUIREMENTS = ("cpus", "memory_gb", "disk_gb")
VM_CHOICES = {"network": ("shared", "isolated", "none"), "display": ("none", "window", "gpu")}
VM_BOOLS = ("share", "ephemeral", "audio", "microphone", "clipboard", "camera")
VM_REQUIRED = ("network", "share", "ephemeral")
LANGUAGE = re.compile(r"[a-z]{2,3}")

MAX_FILE = 1024 * 1024           # per file
MAX_FOLDER = 5 * 1024 * 1024     # per module, recipe or look folder
# Files a module never contains: its own flake (a module is a module on omaflake's flake), keys, secrets
FORBIDDEN = re.compile(r"(^|/)(flake\.nix|flake\.lock|\.env|id_[a-z0-9]+|.*\.(pem|key|p12))$|(^|/)local/")
# Worth a reviewer's look, not an error
LINT = [
    (re.compile(r"builtins\.(fetchTarball|fetchGit|fetchurl)\b"), "builtins fetcher – pin it with a hash"),
    (re.compile(r"builtins\.getEnv\b"), "reads the environment of the Mac it is evaluated on"),
    (re.compile(r"(curl|wget)[^\n|]*\|\s*(ba|z)?sh\b"), "downloads and runs a script"),
    (re.compile(r"omaflake-agent|clipboard-agent|camera-agent"), "touches omaflake's guest agents"),
    (re.compile(r"allowUnfree|allowInsecure"), "allows unfree or insecure packages"),
]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_toml(path: Path, errors: list[str]) -> dict:
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except (tomllib.TOMLDecodeError, UnicodeDecodeError) as e:
        errors.append(f"{path.relative_to(ROOT)}: {e}")
        return {}


def version_of(text) -> tuple[int, ...] | None:
    m = VERSION.fullmatch(text) if isinstance(text, str) else None
    return tuple(int(x) for x in m.groups()) if m else None


def reference(value, what: str, where, errors: list[str]) -> dict | None:
    """A reference as written – "author/name" or { id, version | min | max } – as {id, version?, min?, max?}"""
    ref = {"id": value} if isinstance(value, str) else dict(value) if isinstance(value, dict) else None
    if ref is None or not isinstance(ref.get("id"), str) or not REF.fullmatch(ref["id"]):
        errors.append(f"{where}: {what} {value!r} – write \"<author>/<name>\" or {{ id = \"<author>/<name>\", min = \"1.0.0\" }}")
        return None
    extra = set(ref) - {"id", "version", "min", "max"}
    if extra:
        errors.append(f"{where}: {what} {ref['id']} has no {', '.join(sorted(extra))} (id, version, min, max)")
    if "version" in ref and ("min" in ref or "max" in ref):
        errors.append(f"{where}: {what} {ref['id']}: an exact version or a minimum and/or maximum, not both")
    for k in ("version", "min", "max"):
        if k in ref and version_of(ref[k]) is None:
            errors.append(f"{where}: {what} {ref['id']}: {k} is a version like \"1.2.0\"")
    if "min" in ref and "max" in ref and version_of(ref["min"]) and version_of(ref["max"]) \
            and version_of(ref["min"]) > version_of(ref["max"]):
        errors.append(f"{where}: {what} {ref['id']}: min is above max")
    return ref


def satisfies(version: str, ref: dict) -> bool:
    v = version_of(version)
    if v is None:
        return False
    if "version" in ref:
        return v == version_of(ref["version"])
    return (("min" not in ref or v >= version_of(ref["min"])) and ("max" not in ref or v <= version_of(ref["max"])))


def common(where, data: dict, schema: str, tags: set[str] | None, licenses: list[str], errors: list[str],
           author: str, what: str) -> None:
    """What every module, key binding set and look has: $schema, author, license, title/description, tags"""
    if data.get("$schema") != schema:
        errors.append(f"{where}: {what} needs \"$schema\" = \"{schema}\"")
    if data.get("author") != author:
        errors.append(f"{where}: author = \"{data.get('author')}\" in {what}, but the folder says {author}")
    if licenses and data.get("license") not in licenses:
        errors.append(f"{where}: license \"{data.get('license')}\" is not one of source.toml's licenses")
    if not isinstance(data.get("description", ""), str) or not data.get("description", "").strip():
        errors.append(f"{where}: description is a sentence in English")
    if tags is not None:
        given = data.get("tags", [])
        if not isinstance(given, list):
            errors.append(f"{where}: tags is a list")
            given = []
        for tag in given:
            if not isinstance(tag, str) or not TAG.fullmatch(tag):
                errors.append(f"{where}: tag {tag!r} – lowercase letters, digits and -")
            elif tag not in tags:
                errors.append(f"{where}: tag \"{tag}\" is not in tags.toml – add it there in the same pull request")


# ---------- Keys (module.toml's actions, keymap.toml) ----------
# A key is a chord – modifiers and a key joined by "+" ("Super+Shift+Return", "Ctrl+g") – or, for editors, a sequence
# of chords separated by spaces ("Space f f"). Digit and Arrow stand for 1–9 and the four arrows.
MODIFIERS = ("Super", "Ctrl", "Alt", "Shift")
NAMED = {"Return", "Space", "Escape", "Tab", "Backspace", "Left", "Right", "Up", "Down", "Digit", "Arrow"} \
    | {f"F{i}" for i in range(1, 13)}
SINGLE = re.compile(r"[a-z0-9`\-=\[\];',./\\]")


def parse_key(key) -> list[tuple[frozenset, str]] | None:
    if not isinstance(key, str) or not key.strip():
        return None
    out = []
    for chord in key.split():
        parts = chord.split("+")
        mods, name = parts[:-1], parts[-1]
        if any(m not in MODIFIERS for m in mods) or len(set(mods)) != len(mods):
            return None
        if name not in NAMED and not SINGLE.fullmatch(name):
            return None
        out.append((frozenset(mods), name))
    return out


def expand(seq: list[tuple[frozenset, str]]) -> list[tuple]:
    """Every concrete sequence a key stands for (Digit → 1–9, Arrow → the arrows)"""
    result = [()]
    for mods, name in seq:
        names = [str(i) for i in range(1, 10)] if name == "Digit" else ["Left", "Right", "Up", "Down"] if name == "Arrow" else [name]
        result = [r + ((mods, n),) for r in result for n in names]
    return result


def check_actions(where, actions, own_keys: bool, errors: list[str]) -> None:
    if not isinstance(actions, dict):
        errors.append(f"{where}: [actions.<name>] tables")
        return
    for name, a in actions.items():
        if not NAME.fullmatch(name) or not isinstance(a, dict):
            errors.append(f"{where}: action {name!r} – lowercase letters, digits and -, a table")
            continue
        extra = set(a) - {"title", "key", "mode", "desktop", "context"}
        if extra:
            errors.append(f"{where}: action {name} has no {', '.join(sorted(extra))}")
        if not isinstance(a.get("title"), str) or not a["title"].strip():
            errors.append(f"{where}: action {name} needs a title")
        if parse_key(a.get("key")) is None:
            errors.append(f"{where}: action {name}: key {a.get('key')!r} – e.g. \"Super+Shift+Return\", \"Ctrl+g\", \"Space f f\"")
        if "mode" in a and (not isinstance(a["mode"], str) or not NAME.fullmatch(a["mode"])):
            errors.append(f"{where}: action {name}: mode is a name")
        if "desktop" in a and not isinstance(a["desktop"], bool):
            errors.append(f"{where}: action {name}: desktop is true or false")
        if "context" in a and (not isinstance(a["context"], str) or not REF.fullmatch(a["context"])):
            errors.append(f"{where}: action {name}: context is a module, \"<author>/<name>\"")


def overlaps(bindings: list[dict], modules: dict[str, dict]) -> list[str]:
    """Key bindings of one recipe that can be active at once and collide (the same key, or one a prefix of the other).
    Active at once: the same context and mode; a desktop-wide one with any binding without a mode; a program's binding
    without a mode with one of a program that runs inside it (`runs_in` names a capability the outer one provides)."""
    def provides(ref):
        return set(modules.get(ref, {}).get("provides", []))

    def runs_in(ref):
        return set(modules.get(ref, {}).get("runs_in", []))

    def together(a, b) -> bool:
        if a["mode"] or b["mode"]:
            return a["context"] == b["context"] and a["mode"] == b["mode"]
        if a["context"] == b["context"] or "desktop" in (a["context"], b["context"]):
            return True
        return bool(provides(a["context"]) & runs_in(b["context"])) or bool(provides(b["context"]) & runs_in(a["context"]))

    found = []
    for i, a in enumerate(bindings):
        for b in bindings[i + 1:]:
            if not together(a, b):
                continue
            hit = next(((x, y) for x in a["keys"] for y in b["keys"]
                        if x[:len(y)] == y or y[:len(x)] == x), None)
            if hit:
                found.append(f"{a['module']} {a['action']} ({a['key']}) and {b['module']} {b['action']} ({b['key']})")
    return found


def key_rule(binding: dict, modules: dict[str, dict]) -> str | None:
    """omaflake's key rule: without a mode a key starts with Super or Ctrl – except an editor's own keys"""
    if binding["mode"] or modules.get(binding["context"], {}).get("own_keys"):
        return None
    seq = parse_key(binding["key"]) or []
    if len(seq) != 1 or not ({"Super", "Ctrl"} & seq[0][0]):
        return f"{binding['module']} {binding['action']} ({binding['key']}): without a mode a key starts with Super or Ctrl"
    return None


def bindings_of(platform: str, refs: list[str], keymaps: list[dict], modules: dict[str, dict]) -> list[dict]:
    """A recipe's key bindings: each module's defaults, then its key binding sets in order (a later one wins)"""
    out = []
    for ref in refs:
        m = modules.get(f"{platform}:{ref}")
        if not m:
            continue
        for action, a in m.get("actions", {}).items():
            key = a.get("key")
            for km in keymaps:
                key = km.get("keys", {}).get(ref, {}).get(action, key)
            seq = parse_key(key)
            if seq is None:
                continue
            context = "desktop" if a.get("desktop") or m.get("desktop") else a.get("context", ref)
            out.append({"module": ref, "action": action, "key": key, "keys": expand(seq), "mode": a.get("mode"),
                        "context": context})
    return out


def check_module(folder: Path, data: dict, tags: set[str], licenses: list[str], capabilities: dict,
                 errors: list[str]) -> None:
    where = folder.relative_to(ROOT)
    author, platform, name = folder.relative_to(MODULES).parts
    if not NAME.fullmatch(author) or not NAME.fullmatch(name):
        errors.append(f"{where}: author and name use lowercase letters, digits and -")
    if platform not in PLATFORMS:
        errors.append(f"{where}: the platform folder is nixos or macos, not {platform}")
    common(where, data, MODULE_SCHEMA, tags, licenses, errors, author, "module.toml")
    extra = set(data) - {"$schema", "version", "author", "license", "title", "description", "tags", "homepage",
                         "provides", "needs", "enhances", "runs_in", "desktop", "own_keys", "unfree", "actions"}
    for key in sorted(extra):
        if not key.startswith("description_"):
            errors.append(f"{where}: module.toml has no {key}")
    if version_of(data.get("version")) is None:
        errors.append(f"{where}: version is a version like \"1.0.0\" – raise it with every change")
    if not isinstance(data.get("title"), str) or not data.get("title", "").strip():
        errors.append(f"{where}: title is a short name")
    for key in ("provides", "needs", "runs_in"):
        for c in data.get(key, []):
            if c not in capabilities:
                errors.append(f"{where}: {key} {c!r} is not in capabilities.toml")
    for ref in data.get("enhances", []):
        if not isinstance(ref, str) or not REF.fullmatch(ref):
            errors.append(f"{where}: enhances {ref!r} – write <author>/<name>")
    for key in ("desktop", "own_keys", "unfree"):
        if key in data and not isinstance(data[key], bool):
            errors.append(f"{where}: {key} is true or false")
    check_actions(where, data.get("actions", {}), data.get("own_keys", False), errors)
    if not (folder / "default.nix").is_file():
        errors.append(f"{where}: default.nix is missing")


def check_keymap(folder: Path, data: dict, licenses: list[str], modules: dict[str, dict], errors: list[str],
                 warnings: list[str]) -> None:
    where = folder.relative_to(ROOT)
    author, name = folder.relative_to(KEYMAPS).parts
    if not NAME.fullmatch(author) or not NAME.fullmatch(name):
        errors.append(f"{where}: author and name use lowercase letters, digits and -")
    common(where, data, KEYMAP_SCHEMA, None, licenses, errors, author, "keymap.toml")
    if version_of(data.get("version")) is None:
        errors.append(f"{where}: version is a version like \"1.0.0\" – raise it with every change")
    for ref, keys in data.get("keys", {}).items():
        if not REF.fullmatch(ref) or not isinstance(keys, dict):
            errors.append(f"{where}: [keys.\"<author>/<name>\"] tables, not {ref!r}")
            continue
        here = [m for k, m in modules.items() if k.split(":", 1)[1] == ref]
        if not here:
            warnings.append(f"{where}: {ref} is not a module of this catalog – its actions are not checked")
        for action, key in keys.items():
            if parse_key(key) is None:
                errors.append(f"{where}: {ref} {action}: key {key!r}")
            elif here and not any(action in m.get("actions", {}) for m in here):
                errors.append(f"{where}: {ref} has no action {action}")


def check_recipe(folder: Path, data: dict, tags: set[str], licenses: list[str], catalog: dict, errors: list[str],
                 warnings: list[str]) -> None:
    where = folder.relative_to(ROOT)
    author, platform, name = folder.relative_to(RECIPES).parts
    if not NAME.fullmatch(author) or not NAME.fullmatch(name):
        errors.append(f"{where}: author and name use lowercase letters, digits and -")
    if platform not in PLATFORMS:
        errors.append(f"{where}: the platform folder is nixos or macos, not {platform}")
    if data.get("author") != author:
        errors.append(f"{where}: author = \"{data.get('author')}\" in recipe.toml, but the folder says {author}")
    for key in REQUIRED:
        if key not in data:
            errors.append(f"{where}: recipe.toml needs {key}")
    for key in data:
        if key not in RECIPE_KEYS and not key.startswith("description_"):
            errors.append(f"{where}: recipe.toml has no {key} (a VM's values go in [requirements] and [vm])")
    if "$schema" in data and data["$schema"] != RECIPE_SCHEMA:
        errors.append(f"{where}: \"$schema\" = {data['$schema']!r} – recipe.toml names \"{RECIPE_SCHEMA}\"")
    if data.get("platform") != platform:
        errors.append(f"{where}: platform = {data.get('platform')!r}, but the folder says {platform}")
    allowed = SYSTEMS.get(platform, ())
    systems = data.get("systems", [])
    if not isinstance(systems, list) or not systems or any(s not in allowed for s in systems):
        errors.append(f"{where}: systems lists some of {', '.join(allowed)}")
    req = data.get("requirements", {})
    for key in REQUIREMENTS:
        v = req.get(key)
        if not isinstance(v, int) or isinstance(v, bool) or v < 1:
            errors.append(f"{where}: requirements.{key} is a whole number of at least 1")
    for key in set(req) - set(REQUIREMENTS):
        errors.append(f"{where}: requirements has no {key}")
    vm = data.get("vm", {})
    for key in VM_REQUIRED:
        if key not in vm:
            errors.append(f"{where}: vm.{key} is needed")
    for key, choices in VM_CHOICES.items():
        if key in vm and vm[key] not in choices:
            errors.append(f"{where}: vm.{key} is one of {', '.join(choices)}")
    for key in VM_BOOLS:
        if key in vm and not isinstance(vm[key], bool):
            errors.append(f"{where}: vm.{key} is true or false")
    for key in set(vm) - set(VM_CHOICES) - set(VM_BOOLS):
        errors.append(f"{where}: vm has no {key}")
    if platform == "macos" and vm.get("network") == "isolated":
        errors.append(f"{where}: network = \"isolated\" exists for NixOS only")
    if "lab" in data and not isinstance(data["lab"], bool):
        errors.append(f"{where}: lab is true or false")
    loc = data.get("locales", {})
    for key in set(loc) - {"rtl", "languages"}:
        errors.append(f"{where}: locales has no {key} (rtl, languages)")
    if "rtl" in loc and not isinstance(loc["rtl"], bool):
        errors.append(f"{where}: locales.rtl is true or false")
    if "languages" in loc and (not isinstance(loc["languages"], list)
                               or not all(isinstance(x, str) and LANGUAGE.fullmatch(x) for x in loc["languages"])):
        errors.append(f"{where}: locales.languages lists language codes, e.g. [\"en\", \"de\"]")
    common(where, {**data, "$schema": MODULE_SCHEMA}, MODULE_SCHEMA, tags, licenses, errors, author, "recipe.toml")

    # What it references: modules of its platform, a look, key binding sets – in this catalog, or (a warning) elsewhere
    modules = catalog["modules"]
    refs = []
    for value in data.get("modules", []) if isinstance(data.get("modules"), list) else []:
        ref = reference(value, "module", where, errors)
        if not ref:
            continue
        refs.append(ref["id"])
        m = modules.get(f"{platform}:{ref['id']}")
        if m is None:
            warnings.append(f"{where}: module {ref['id']} ({platform}) is not in this catalog – the user needs a source that has it")
        elif not satisfies(m["version"], ref):
            errors.append(f"{where}: module {ref['id']} is {m['version']} here, which the recipe's version does not allow")
    if len(set(refs)) != len(refs):
        errors.append(f"{where}: a module is listed twice")
    if not refs:
        errors.append(f"{where}: modules lists at least one module")
    if "look" in data:
        ref = reference(data["look"], "look", where, errors)
        if ref and ref["id"] not in catalog["looks"]:
            warnings.append(f"{where}: look {ref['id']} is not in this catalog")
        elif ref and not satisfies(catalog["looks"][ref["id"]], ref):
            errors.append(f"{where}: look {ref['id']} is {catalog['looks'][ref['id']]} here, which the recipe does not allow")
    keymaps = []
    for value in data.get("keymaps", []):
        ref = reference(value, "key bindings", where, errors)
        if not ref:
            continue
        km = catalog["keymaps"].get(ref["id"])
        if km is None:
            warnings.append(f"{where}: key bindings {ref['id']} are not in this catalog")
        else:
            keymaps.append(km)
            if not satisfies(km["version"], ref):
                errors.append(f"{where}: key bindings {ref['id']} are {km['version']} here, which the recipe does not allow")

    # Capabilities: what a module needs, exclusive ones twice (warnings – a recipe stays buildable)
    present = [modules[f"{platform}:{r}"] for r in refs if f"{platform}:{r}" in modules]
    provided = [c for m in present for c in m.get("provides", [])]
    for m in present:
        for c in m.get("needs", []):
            if c not in provided:
                warnings.append(f"{where}: {m['ref']} needs a {c} – no module of the recipe provides one")
    for c, info in catalog["capabilities"].items():
        if info.get("exclusive") and provided.count(c) > 1:
            who = [m["ref"] for m in present if c in m.get("provides", [])]
            warnings.append(f"{where}: {' and '.join(who)} both provide {c} – incompatible")
    # Keys: overlaps and the key rule
    bindings = bindings_of(platform, refs, keymaps, modules)
    by_ref = {m["ref"]: m for m in present}
    for o in overlaps(bindings, by_ref):
        errors.append(f"{where}: keys overlap – {o}")
    for b in bindings:
        problem = key_rule(b, by_ref)
        if problem:
            errors.append(f"{where}: {problem}")


# look.toml (schema look/v1): a look is data – colours and a few choices; omaflake's image flake turns it into each
# program's configuration, so a look runs no code
COLOR = re.compile(r"#[0-9a-fA-F]{6}")
LOOK_META = {"$schema", "version", "author", "license", "title", "description", "tags", "homepage", "appearance", "plain"}
LOOK_REQUIRED = ("$schema", "version", "author", "license", "title", "description", "tags")
# A look that sets colours (not plain = true, Vanilla) needs these too
LOOK_COLORED = ("appearance", "colors", "terminal")
LOOK_COLORS = ("background", "surface", "selection", "text", "subtext", "muted", "accent", "urgent")
LOOK_TABLES = {"colors", "terminal", "desktop", "neovim", "emacs", "macos"}
# macOS guests: only values checked in a guest (plan BM22 in omaflake/omaflake)
MACOS = {"accent": ("multicolor", "graphite"), "icons": ("default", "clear"), "folders": ("default", "graphite"),
         "wallpaper": ("default", "black")}
GTK = ("adw-gtk3", "adw-gtk3-dark")
CURSORS = tuple(f"Bibata-{a}-{b}" for a in ("Modern", "Original") for b in ("Classic", "Ice", "Amber"))
# Editor themes omaflake's image flake knows (nixpkgs), with their options; without one the theme comes from the colours
EDITOR_THEMES = {
    "neovim": {"catppuccin": {"flavour": ("latte", "frappe", "macchiato", "mocha")},
               "rose-pine": {"variant": ("main", "moon", "dawn")},
               "modus": {"style": ("modus_vivendi", "modus_operandi")}},
    "emacs": {"catppuccin": {"flavour": ("latte", "frappe", "macchiato", "mocha")},
              "modus": {"style": ("modus-vivendi", "modus-operandi")}},
}
LOOK_FILES = {"look.toml", "preview.png"}


def check_look(folder: Path, data: dict, tags: set[str], licenses: list[str], errors: list[str]) -> None:
    where = folder.relative_to(ROOT)
    author, name = folder.relative_to(LOOKS).parts
    if not NAME.fullmatch(author) or not NAME.fullmatch(name):
        errors.append(f"{where}: author and name use lowercase letters, digits and -")
    if data.get("author") != author:
        errors.append(f"{where}: author = \"{data.get('author')}\" in look.toml, but the folder says {author}")
    plain = data.get("plain", False)
    if not isinstance(plain, bool):
        errors.append(f"{where}: plain is true or false")
    for key in LOOK_REQUIRED + (() if plain else LOOK_COLORED):
        if key not in data:
            errors.append(f"{where}: look.toml needs {key}")
    if version_of(data.get("version")) is None:
        errors.append(f"{where}: version is a version like \"1.0.0\" – raise it with every change")
    if plain:
        for key in sorted(LOOK_TABLES & set(data)):
            errors.append(f"{where}: a plain look sets no colours – no [{key}]")
        return
    if "$schema" in data and data["$schema"] != LOOK_SCHEMA:
        errors.append(f"{where}: \"$schema\" = {data['$schema']!r} – look.toml names \"{LOOK_SCHEMA}\"")
    for key in data:
        if key not in LOOK_META and key not in LOOK_TABLES and not key.startswith("description_"):
            errors.append(f"{where}: look.toml has no {key}")
    if data.get("appearance") not in (None, "dark", "light"):
        errors.append(f"{where}: appearance is dark or light")
    for key in ("title", "description"):
        if not isinstance(data.get(key, ""), str) or not data.get(key, "x").strip():
            errors.append(f"{where}: {key} is text in English")
    if licenses and data.get("license") not in licenses:
        errors.append(f"{where}: license \"{data.get('license')}\" is not one of source.toml's licenses")
    look_tags = data.get("tags", [])
    if not isinstance(look_tags, list) or not look_tags:
        errors.append(f"{where}: tags is a list of at least one word")
        look_tags = []
    for tag in look_tags:
        if tag not in tags:
            errors.append(f"{where}: tag \"{tag}\" is not in tags.toml's [looks] – add it there in the same pull request")

    def color(value, what: str) -> None:
        if not isinstance(value, str) or not COLOR.fullmatch(value):
            errors.append(f"{where}: {what} is a colour \"#RRGGBB\", not {value!r}")

    def colors(value, what: str, counts: tuple[int, ...]) -> None:
        if not isinstance(value, list) or len(value) not in counts:
            errors.append(f"{where}: {what} is a list of {' or '.join(map(str, counts))} colours")
            return
        for i, c in enumerate(value):
            color(c, f"{what}[{i}]")

    c = data.get("colors", {})
    for key in LOOK_COLORS:
        color(c.get(key), f"colors.{key}")
    for key in set(c) - set(LOOK_COLORS) - {"cursor"}:
        errors.append(f"{where}: colors has no {key}")
    if "cursor" in c:
        color(c["cursor"], "colors.cursor")
    t = data.get("terminal", {})
    colors(t.get("normal"), "terminal.normal", (8,))
    colors(t.get("bright"), "terminal.bright", (8,))
    for key in set(t) - {"normal", "bright"}:
        errors.append(f"{where}: terminal has no {key}")
    d = data.get("desktop", {})
    for key, value in d.items():
        if key == "border":
            colors(value, "desktop.border", (1, 2))
        elif key == "split":
            colors(value, "desktop.split", (2,))
        elif key in ("inactive_border", "clock"):
            color(value, f"desktop.{key}")
        elif key == "prompt":
            if not isinstance(value, dict) or set(value) - {"ok", "error", "directory"}:
                errors.append(f"{where}: desktop.prompt has ok, error and directory")
            else:
                for k, v in value.items():
                    color(v, f"desktop.prompt.{k}")
        elif key == "gtk":
            if value not in GTK:
                errors.append(f"{where}: desktop.gtk is one of {', '.join(GTK)}")
        elif key == "cursor_theme":
            if value not in CURSORS:
                errors.append(f"{where}: desktop.cursor_theme is one of {', '.join(CURSORS)}")
        else:
            errors.append(f"{where}: desktop has no {key}")
    for key, value in data.get("macos", {}).items():
        if key not in MACOS:
            errors.append(f"{where}: macos has no {key}")
        elif value not in MACOS[key]:
            errors.append(f"{where}: macos.{key} is one of {', '.join(MACOS[key])}")
    for editor, themes in EDITOR_THEMES.items():
        e = data.get(editor)
        if e is None:
            continue
        theme = e.get("theme") if isinstance(e, dict) else None
        if theme not in themes:
            errors.append(f"{where}: {editor}.theme is one of {', '.join(themes)} (or leave {editor} out: the theme comes from the colours)")
            continue
        for key, value in e.items():
            if key == "theme":
                continue
            if key not in themes[theme] or value not in themes[theme][key]:
                choices = "; ".join(f"{k}: {', '.join(v)}" for k, v in themes[theme].items())
                errors.append(f"{where}: {editor} with theme {theme} takes {choices}")


def folder_files(folder: Path, errors: list[str], warnings: list[str]) -> list[dict]:
    where = folder.relative_to(ROOT)
    files, total = [], 0
    for path in sorted(folder.rglob("*")):
        rel = path.relative_to(folder).as_posix()
        if path.is_symlink():
            errors.append(f"{where}/{rel}: no symbolic links")
            continue
        if path.is_dir() or path.name == ".DS_Store":
            continue
        if FORBIDDEN.search(rel):
            errors.append(f"{where}/{rel}: does not belong here (own flake, keys, secrets, local/)")
        data = path.read_bytes()
        total += len(data)
        if len(data) > MAX_FILE:
            errors.append(f"{where}/{rel}: {len(data)} bytes – at most {MAX_FILE} per file")
        if path.suffix in (".nix", ".sh", ".py", ".lua", ".toml", ".json"):
            text = data.decode("utf-8", errors="replace")
            for pattern, why in LINT:
                for m in pattern.finditer(text):
                    line = text.count("\n", 0, m.start()) + 1
                    warnings.append(f"{where}/{rel}:{line}: {why}")
        files.append({"path": rel, "size": len(data), "sha256": sha256(data)})
    if total > MAX_FOLDER:
        errors.append(f"{where}: {total} bytes in all – at most {MAX_FOLDER} per folder")
    return files


def content_hash(files: list[dict]) -> str:
    """Changes whenever any file changes: how omaflake sees that what it installed has an update"""
    return sha256("".join(f"{f['path']}\0{f['sha256']}\n" for f in files).encode())


def descriptions_of(data: dict) -> dict:
    return {k.removeprefix("description_"): v for k, v in data.items() if k.startswith("description_")}


def build() -> tuple[dict, list[str], list[str]]:
    errors, warnings = [], []
    source = load_toml(ROOT / "source.toml", errors)
    for key in ("name", "description"):
        if not source.get(key):
            errors.append(f"source.toml needs {key}")
    all_tags = load_toml(ROOT / "tags.toml", errors)
    tags = set(all_tags.get("tags", {}).keys())
    look_tags = set(all_tags.get("looks", {}).keys())
    licenses = source.get("licenses", [])
    capabilities = load_toml(ROOT / "capabilities.toml", errors).get("capabilities", {})
    for c, info in capabilities.items():
        if not NAME.fullmatch(c) or not isinstance(info.get("exclusive"), bool) or not info.get("description"):
            errors.append(f"capabilities.toml: {c} needs exclusive (true or false) and a description")

    modules, module_rows = {}, []
    for toml in sorted(MODULES.rglob("module.toml")) if MODULES.is_dir() else []:
        folder = toml.parent
        if len(folder.relative_to(MODULES).parts) != 3:
            errors.append(f"{toml.relative_to(ROOT)}: modules live in modules/<author>/<platform>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_module(folder, data, tags, licenses, capabilities, errors)
        files = folder_files(folder, errors, warnings)
        author, platform, name = folder.relative_to(MODULES).parts
        row = {
            "id": f"{author}.{platform}.{name}",
            "ref": f"{author}/{name}",
            "author": author,
            "platform": platform,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "version": data.get("version", ""),
            "title": data.get("title", ""),
            "description": data.get("description", ""),
            "descriptions": descriptions_of(data),
            "tags": data.get("tags", []),
            "license": data.get("license", ""),
            "homepage": data.get("homepage", ""),
            "provides": data.get("provides", []),
            "needs": data.get("needs", []),
            "enhances": data.get("enhances", []),
            "runs_in": data.get("runs_in", []),
            "desktop": data.get("desktop", False),
            "own_keys": data.get("own_keys", False),
            "unfree": data.get("unfree", False),
            "actions": data.get("actions", {}),
            "hash": content_hash(files),
            "files": files,
        }
        modules[f"{platform}:{author}/{name}"] = row
        module_rows.append(row)

    keymaps, keymap_rows = {}, []
    for toml in sorted(KEYMAPS.rglob("keymap.toml")) if KEYMAPS.is_dir() else []:
        folder = toml.parent
        if len(folder.relative_to(KEYMAPS).parts) != 2:
            errors.append(f"{toml.relative_to(ROOT)}: key bindings live in keymaps/<author>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_keymap(folder, data, licenses, modules, errors, warnings)
        files = folder_files(folder, errors, warnings)
        for f in files:
            if f["path"] != "keymap.toml":
                errors.append(f"{folder.relative_to(ROOT)}/{f['path']}: key bindings are keymap.toml only")
        author, name = folder.relative_to(KEYMAPS).parts
        row = {
            "id": f"{author}.keymap.{name}",
            "ref": f"{author}/{name}",
            "author": author,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "version": data.get("version", ""),
            "title": data.get("title", ""),
            "description": data.get("description", ""),
            "descriptions": descriptions_of(data),
            "license": data.get("license", ""),
            "keys": data.get("keys", {}),
            "hash": content_hash(files),
            "files": files,
        }
        keymaps[f"{author}/{name}"] = row
        keymap_rows.append(row)

    looks, look_rows = {}, []
    for toml in sorted(LOOKS.rglob("look.toml")) if LOOKS.is_dir() else []:
        folder = toml.parent
        if len(folder.relative_to(LOOKS).parts) != 2:
            errors.append(f"{toml.relative_to(ROOT)}: looks live in looks/<author>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_look(folder, data, look_tags, licenses, errors)
        files = folder_files(folder, errors, warnings)
        for f in files:
            if f["path"] not in LOOK_FILES:
                errors.append(f"{folder.relative_to(ROOT)}/{f['path']}: a look has look.toml and maybe preview.png only")
        author, name = folder.relative_to(LOOKS).parts
        c, t = data.get("colors", {}), data.get("terminal", {})
        looks[f"{author}/{name}"] = data.get("version", "")
        look_rows.append({
            "id": f"{author}.look.{name}",
            "ref": f"{author}/{name}",
            "author": author,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "version": data.get("version", ""),
            "title": data.get("title", ""),
            "description": data.get("description", ""),
            "descriptions": descriptions_of(data),
            "tags": data.get("tags", []),
            "license": data.get("license", ""),
            "appearance": data.get("appearance"),   # null for a plain look
            "plain": data.get("plain", False),
            "homepage": data.get("homepage", ""),
            # For a preview without downloading: the main colours and the terminal's
            "swatches": None if data.get("plain") else {"background": c.get("background", ""), "surface": c.get("surface", ""),
                         "text": c.get("text", ""), "accent": c.get("accent", ""), "urgent": c.get("urgent", ""),
                         "terminal": t.get("normal", []) + t.get("bright", [])},
            "hash": content_hash(files),
            "files": files,
        })

    context = {"modules": modules, "keymaps": keymaps, "looks": looks, "capabilities": capabilities}
    recipes = []
    for toml in sorted(RECIPES.rglob("recipe.toml")):
        folder = toml.parent
        if len(folder.relative_to(RECIPES).parts) != 3:
            errors.append(f"{toml.relative_to(ROOT)}: recipes live in recipes/<author>/<platform>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_recipe(folder, data, tags, licenses, context, errors, warnings)
        files = folder_files(folder, errors, warnings)
        for f in files:
            if f["path"] != "recipe.toml":
                errors.append(f"{folder.relative_to(ROOT)}/{f['path']}: a recipe is recipe.toml only – Nix goes in a module")
        author, platform, name = folder.relative_to(RECIPES).parts
        recipes.append({
            "id": f"{author}.{platform}.{name}",
            "author": author,
            "kind": platform,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "description": data.get("description", ""),
            "descriptions": descriptions_of(data),
            "tags": data.get("tags", []),
            "license": data.get("license", ""),
            "lab": data.get("lab", False),
            "systems": data.get("systems", []),
            "homepage": data.get("homepage", ""),
            "modules": [m if isinstance(m, dict) else {"id": m} for m in data.get("modules", [])],
            "look": (data["look"] if isinstance(data["look"], dict) else {"id": data["look"]}) if "look" in data else None,
            "keymaps": [k if isinstance(k, dict) else {"id": k} for k in data.get("keymaps", [])],
            "requirements": data.get("requirements", {}),
            "vm": data.get("vm", {}),
            "locales": data.get("locales", {}),
            "version": content_hash(files),
            "files": files,
        })
    catalog = {
        "$schema": SCHEMA,
        "source": {k: source.get(k, "") for k in ("name", "description", "homepage")},
        "capabilities": capabilities,
        "recipes": recipes,
        "modules": module_rows,
        "keymaps": keymap_rows,
        "looks": look_rows,
    }
    return catalog, errors, warnings


def counts(catalog: dict) -> str:
    return ", ".join(f"{len(catalog[k])} {k}" for k in ("recipes", "modules", "keymaps", "looks"))


def main() -> int:
    check = "--check" in sys.argv[1:]
    catalog, errors, warnings = build()
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    if errors:
        return 1
    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    if check:
        if not CATALOG.is_file() or CATALOG.read_text(encoding="utf-8") != text:
            print("error: catalog.json is not up to date – run python3 tools/catalog.py and commit it")
            return 1
        print(f"ok: {counts(catalog)}, catalog.json up to date")
    else:
        CATALOG.write_text(text, encoding="utf-8")
        print(f"ok: {counts(catalog)} written to catalog.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
