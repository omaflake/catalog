#!/usr/bin/env python3
"""Check every recipe and look in this repository and write catalog.json – the one file omaflake reads to browse it.

  python3 tools/catalog.py           # check, then write catalog.json
  python3 tools/catalog.py --check   # check, and fail if catalog.json is not up to date (CI)

Needs Python 3.11 or newer (tomllib) and nothing else, so forks and own catalogs can run it anywhere. Without a
recent Python: `nix run nixpkgs#python3 -- tools/catalog.py`. Errors fail the run; warnings are for the reviewers.
The output has no timestamps or commit hashes, so it only changes when a recipe changes.
"""

import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECIPES = ROOT / "recipes"
LOOKS = ROOT / "looks"
CATALOG = ROOT / "catalog.json"
# The JSON Schemas (omaflake/omaflake docs/schema/, published on omaflake.dev): what this catalog is, and what each
# recipe.toml names in "$schema" – as omaflake's image flake reads it
SCHEMA = "https://omaflake.dev/schema/catalog/v3.json"      # v2: systems per recipe; v3: looks
RECIPE_SCHEMA = "https://omaflake.dev/schema/recipe/v1.json"
LOOK_SCHEMA = "https://omaflake.dev/schema/look/v1.json"

KINDS = ("nixos", "macos")
# What a recipe of each kind can be built for (Nix system names); <system>.nix next to default.nix is the variant
SYSTEMS = {"nixos": ("aarch64-linux", "x86_64-linux"), "macos": ("aarch64-darwin",)}
NAME = re.compile(r"[a-z0-9][a-z0-9-]*")
TAG = re.compile(r"[a-z0-9][a-z0-9+.-]*")
REF = re.compile(r"([a-z0-9][a-z0-9-]*)/(nixos|macos)/([a-z0-9][a-z0-9-]*)")

# recipe.toml: what the catalog lists about a recipe; everything else is how a VM from it runs (its defaults)
META = {"$schema", "author", "license", "description", "tags", "lab", "requires", "homepage", "systems"}
REQUIRED = ("$schema", "author", "license", "description", "tags", "systems", "cpus", "memory_gb", "disk_gb", "network", "share",
            "ephemeral")
CHOICES = {"network": ("shared", "isolated", "none"), "display": ("none", "window", "gpu")}
BOOLS = ("share", "ephemeral", "lab", "audio", "microphone", "clipboard", "camera")
COUNTS = ("cpus", "memory_gb", "disk_gb")

MAX_FILE = 1024 * 1024           # per file
MAX_RECIPE = 5 * 1024 * 1024     # per recipe folder
# Files a recipe never contains: its own flake (a recipe is a module on omaflake's flake), keys, secrets
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


def check_recipe(folder: Path, data: dict, tags: set[str], licenses: list[str], errors: list[str],
                 warnings: list[str]) -> None:
    where = folder.relative_to(ROOT)
    author, kind, name = folder.relative_to(RECIPES).parts
    if not NAME.fullmatch(author) or not NAME.fullmatch(name):
        errors.append(f"{where}: author and name use lowercase letters, digits and -")
    if kind not in KINDS:
        errors.append(f"{where}: the kind folder is nixos or macos, not {kind}")
    if data.get("author") != author:
        errors.append(f"{where}: author = \"{data.get('author')}\" in recipe.toml, but the folder says {author}")
    for key in REQUIRED:
        if key not in data:
            errors.append(f"{where}: recipe.toml needs {key}")
    if "$schema" in data and data["$schema"] != RECIPE_SCHEMA:
        errors.append(f"{where}: \"$schema\" = {data['$schema']!r} – recipe.toml names \"{RECIPE_SCHEMA}\"")
    allowed = SYSTEMS.get(kind, ())
    systems = data.get("systems", [])
    if not isinstance(systems, list) or not systems or any(s not in allowed for s in systems):
        errors.append(f"{where}: systems lists some of {', '.join(allowed)}")
        systems = []
    for variant in sorted(folder.glob("*-*.nix")):
        if variant.stem in allowed and variant.stem not in systems:
            errors.append(f"{where}/{variant.name}: a variant for {variant.stem}, which systems does not list")
    for key, choices in CHOICES.items():
        if key in data and data[key] not in choices:
            errors.append(f"{where}: {key} is one of {', '.join(choices)}")
    if kind == "macos" and data.get("network") == "isolated":
        errors.append(f"{where}: network = \"isolated\" exists for NixOS only")
    for key in BOOLS:
        if key in data and not isinstance(data[key], bool):
            errors.append(f"{where}: {key} is true or false")
    for key in COUNTS:
        if key in data and (not isinstance(data[key], int) or isinstance(data[key], bool) or data[key] < 1):
            errors.append(f"{where}: {key} is a whole number of at least 1")
    if not isinstance(data.get("description", ""), str) or not data.get("description", "x").strip():
        errors.append(f"{where}: description is a sentence in English")
    if licenses and data.get("license") not in licenses:
        errors.append(f"{where}: license \"{data.get('license')}\" is not one of source.toml's licenses")
    recipe_tags = data.get("tags", [])
    if not isinstance(recipe_tags, list) or not recipe_tags:
        errors.append(f"{where}: tags is a list of at least one word")
        recipe_tags = []
    for tag in recipe_tags:
        if not isinstance(tag, str) or not TAG.fullmatch(tag):
            errors.append(f"{where}: tag {tag!r} – lowercase letters, digits and -")
        elif tag not in tags:
            errors.append(f"{where}: tag \"{tag}\" is not in tags.toml – add it there in the same pull request")
    for ref in data.get("requires", []):
        m = REF.fullmatch(ref) if isinstance(ref, str) else None
        if not m:
            errors.append(f"{where}: requires {ref!r} – write <author>/<kind>/<name>")
        elif m.group(2) != kind:
            errors.append(f"{where}: requires {ref} – a recipe can only build on one of its own kind")
        elif not (RECIPES / ref / "recipe.toml").is_file():
            errors.append(f"{where}: requires {ref}, which is not in this repository")
    if not (folder / "default.nix").is_file():
        errors.append(f"{where}: default.nix is missing")


# look.toml (schema look/v1): a look is data – colours and a few choices; omaflake's image flake turns it into each
# program's configuration, so a look runs no code
COLOR = re.compile(r"#[0-9a-fA-F]{6}")
LOOK_META = {"$schema", "author", "license", "title", "description", "tags", "homepage", "appearance"}
LOOK_REQUIRED = ("$schema", "author", "license", "title", "description", "tags", "appearance", "colors", "terminal")
LOOK_COLORS = ("background", "surface", "selection", "text", "subtext", "muted", "accent", "urgent")
LOOK_TABLES = {"colors", "terminal", "desktop", "neovim", "emacs"}
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
    for key in LOOK_REQUIRED:
        if key not in data:
            errors.append(f"{where}: look.toml needs {key}")
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


def recipe_files(folder: Path, errors: list[str], warnings: list[str]) -> list[dict]:
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
            errors.append(f"{where}/{rel}: does not belong in a recipe (own flake, keys, secrets, local/)")
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
    if total > MAX_RECIPE:
        errors.append(f"{where}: {total} bytes in all – at most {MAX_RECIPE} per recipe")
    return files


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

    recipes = []
    for toml in sorted(RECIPES.rglob("recipe.toml")):
        folder = toml.parent
        if len(folder.relative_to(RECIPES).parts) != 3:
            errors.append(f"{toml.relative_to(ROOT)}: recipes live in recipes/<author>/<kind>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_recipe(folder, data, tags, licenses, errors, warnings)
        files = recipe_files(folder, errors, warnings)
        author, kind, name = folder.relative_to(RECIPES).parts
        descriptions = {k.removeprefix("description_"): v for k, v in data.items() if k.startswith("description_")}
        recipes.append({
            "id": f"{author}.{kind}.{name}",
            "author": author,
            "kind": kind,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "description": data.get("description", ""),
            "descriptions": descriptions,
            "tags": data.get("tags", []),
            "license": data.get("license", ""),
            "lab": data.get("lab", False),
            "systems": data.get("systems", []),
            "requires": data.get("requires", []),
            "homepage": data.get("homepage", ""),
            "defaults": {k: v for k, v in data.items() if k not in META and not k.startswith("description_")},
            # Changes whenever any file of the recipe changes: how omaflake sees that an installed recipe has an update
            "version": sha256("".join(f"{f['path']}\0{f['sha256']}\n" for f in files).encode()),
            "files": files,
        })
    looks = []
    for toml in sorted(LOOKS.rglob("look.toml")) if LOOKS.is_dir() else []:
        folder = toml.parent
        if len(folder.relative_to(LOOKS).parts) != 2:
            errors.append(f"{toml.relative_to(ROOT)}: looks live in looks/<author>/<name>/")
            continue
        data = load_toml(toml, errors)
        check_look(folder, data, look_tags, licenses, errors)
        files = recipe_files(folder, errors, warnings)
        for f in files:
            if f["path"] not in LOOK_FILES:
                errors.append(f"{folder.relative_to(ROOT)}/{f['path']}: a look has look.toml and maybe preview.png only")
        author, name = folder.relative_to(LOOKS).parts
        descriptions = {k.removeprefix("description_"): v for k, v in data.items() if k.startswith("description_")}
        c, t = data.get("colors", {}), data.get("terminal", {})
        looks.append({
            "id": f"{author}.look.{name}",
            "author": author,
            "name": name,
            "path": folder.relative_to(ROOT).as_posix(),
            "title": data.get("title", ""),
            "description": data.get("description", ""),
            "descriptions": descriptions,
            "tags": data.get("tags", []),
            "license": data.get("license", ""),
            "appearance": data.get("appearance", ""),
            "homepage": data.get("homepage", ""),
            # For a preview without downloading: the main colours and the terminal's
            "swatches": {"background": c.get("background", ""), "surface": c.get("surface", ""),
                         "text": c.get("text", ""), "accent": c.get("accent", ""), "urgent": c.get("urgent", ""),
                         "terminal": t.get("normal", []) + t.get("bright", [])},
            "version": sha256("".join(f"{f['path']}\0{f['sha256']}\n" for f in files).encode()),
            "files": files,
        })
    catalog = {
        "$schema": SCHEMA,
        "source": {k: source.get(k, "") for k in ("name", "description", "homepage")},
        "recipes": recipes,
        "looks": looks,
    }
    return catalog, errors, warnings


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
        print(f"ok: {len(catalog['recipes'])} recipes, {len(catalog['looks'])} looks, catalog.json up to date")
    else:
        CATALOG.write_text(text, encoding="utf-8")
        print(f"ok: {len(catalog['recipes'])} recipes, {len(catalog['looks'])} looks written to catalog.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
