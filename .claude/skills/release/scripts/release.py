#!/usr/bin/env python3
"""Doner Kebab Map yayin yardimcisi.

Kullanim:
  release.py check [--skip-build]          on kontroller (+ Release derlemesi)
  release.py bump patch|minor|major|X.Y.Z  surumu ayarla, build numarasini +1
"""
import json, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
PBX = ROOT / "donerkebabmap.xcodeproj/project.pbxproj"
APP = ROOT / "donerkebabmap"
CATALOG = APP / "Localizable.xcstrings"
NOTES = ROOT / "docs/app-review-notes.txt"
NOTES_LIMIT = 4000

def versions():
    s = PBX.read_text(encoding="utf-8")
    mv = set(re.findall(r"MARKETING_VERSION = ([^;]+);", s))
    bv = set(re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", s))
    return mv, bv

def check(skip_build):
    problems, warnings = [], []

    mv, bv = versions()
    if len(mv) != 1 or len(bv) != 1:
        problems.append(f"Debug/Release surumleri farkli: MARKETING_VERSION={mv}, BUILD={bv}")
    print(f"Surum: {', '.join(mv)}  |  Build: {', '.join(bv)}")

    dirty = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip()
    if dirty:
        warnings.append(f"Commit edilmemis {len(dirty.splitlines())} degisiklik var")

    # 1) Kullaniciya gorunen metinlerde "doner" yerine ö'lu yazim
    for f in APP.rglob("*.swift"):
        if f.name == "PlacesSearchService.swift":   # arama anahtar kelimeleri bilerek ö'lu
            continue
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for lit in re.findall(r'"([^"\n]*)"', line):
                if re.search(r"[dD]öner", lit):
                    problems.append(f'Ö\'lu "döner": {f.relative_to(ROOT)}:{n} -> "{lit}"')
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    for key in cat:
        if re.search(r"[dD]öner", key):
            problems.append(f'Ö\'lu "döner" katalog anahtarinda: "{key}"')

    # 2) Eksik DE/FR ceviri (harf icermeyen anahtarlar haric: "%lld", "•")
    for key, v in sorted(cat.items()):
        if not re.search(r"[A-Za-z]{2,}", re.sub(r"%(\d+\$)?[@dlfs]+", "", key)):
            continue
        locs = v.get("localizations", {})
        missing = [l for l in ("de", "fr") if not locs.get(l, {}).get("stringUnit", {}).get("value")]
        if missing:
            problems.append(f'Ceviri eksik ({"/".join(missing)}): "{key}"')

    # 3) App Review Notes uzunlugu
    if NOTES.exists():
        n = len(NOTES.read_text(encoding="utf-8"))
        print(f"Review Notes: {n}/{NOTES_LIMIT} karakter")
        if n > NOTES_LIMIT:
            problems.append(f"Review Notes {n} karakter, sinir {NOTES_LIMIT}")
    else:
        warnings.append("docs/app-review-notes.txt bulunamadi")

    # 4) Release derlemesi (imzasiz)
    if not skip_build:
        print("Release derlemesi calisiyor...")
        with tempfile.TemporaryDirectory() as dd:
            r = subprocess.run(
                ["xcodebuild", "-project", str(ROOT / "donerkebabmap.xcodeproj"),
                 "-scheme", "donerkebabmap", "-configuration", "Release",
                 "-destination", "generic/platform=iOS", "-derivedDataPath", dd,
                 "build", "CODE_SIGNING_ALLOWED=NO"],
                capture_output=True, text=True)
        if "BUILD SUCCEEDED" in r.stdout:
            print("Release derlemesi: BASARILI")
        else:
            errs = [l for l in r.stdout.splitlines() if "error:" in l][:10]
            problems.append("Release derlemesi BASARISIZ:\n    " + "\n    ".join(errs or ["(ayrinti yok)"]))

    print()
    for w in warnings: print(f"UYARI: {w}")
    for p in problems: print(f"SORUN: {p}")
    print("\nSONUC:", "HAZIR" if not problems else f"{len(problems)} SORUN VAR")
    return 0 if not problems else 1

def bump(kind):
    mv, bv = versions()
    cur = next(iter(mv)).strip()
    parts = [int(x) for x in (cur.split(".") + ["0", "0"])[:3]]
    if kind == "major":   new = f"{parts[0]+1}.0"
    elif kind == "minor": new = f"{parts[0]}.{parts[1]+1}"
    elif kind == "patch": new = f"{parts[0]}.{parts[1]}.{parts[2]+1}"
    elif re.fullmatch(r"\d+(\.\d+){1,2}", kind): new = kind
    else: sys.exit("bump: patch | minor | major | X.Y.Z")
    build = max(int(b) for b in bv) + 1
    s = PBX.read_text(encoding="utf-8")
    s = re.sub(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {new};", s)
    s = re.sub(r"CURRENT_PROJECT_VERSION = [^;]+;", f"CURRENT_PROJECT_VERSION = {build};", s)
    PBX.write_text(s, encoding="utf-8")
    print(f"Surum {cur} -> {new}, build {max(int(b) for b in bv)} -> {build}")
    return 0

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["check"]:
        sys.exit(check("--skip-build" in a))
    if a[:1] == ["bump"] and len(a) == 2:
        sys.exit(bump(a[1]))
    sys.exit(__doc__)
