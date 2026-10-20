#!/usr/bin/env python3
"""Doner Kebab Map release helper.

Usage:
  release.py check [--skip-build]          preflight checks (+ Release build)
  release.py bump patch|minor|major|X.Y.Z  set the version, build number +1
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
        problems.append(f"Debug/Release versions differ: MARKETING_VERSION={mv}, BUILD={bv}")
    print(f"Version: {', '.join(mv)}  |  Build: {', '.join(bv)}")

    dirty = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip()
    if dirty:
        warnings.append(f"{len(dirty.splitlines())} uncommitted change(s)")

    # 1) "döner" spelled with ö in user-facing text (should be "doner")
    for f in APP.rglob("*.swift"):
        if f.name == "PlacesSearchService.swift":   # search keywords keep the ö on purpose
            continue
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for lit in re.findall(r'"([^"\n]*)"', line):
                if re.search(r"[dD]öner", lit):
                    problems.append(f'"döner" with ö: {f.relative_to(ROOT)}:{n} -> "{lit}"')
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    for key in cat:
        if re.search(r"[dD]öner", key):
            problems.append(f'"döner" with ö in catalog key: "{key}"')

    # 2) Missing DE/FR translations (keys without letters such as "%lld" and "•" are skipped)
    for key, v in sorted(cat.items()):
        if not re.search(r"[A-Za-z]{2,}", re.sub(r"%(\d+\$)?[@dlfs]+", "", key)):
            continue
        locs = v.get("localizations", {})
        missing = [l for l in ("de", "fr") if not locs.get(l, {}).get("stringUnit", {}).get("value")]
        if missing:
            problems.append(f'Missing translation ({"/".join(missing)}): "{key}"')

    # 3) App Review Notes length
    if NOTES.exists():
        n = len(NOTES.read_text(encoding="utf-8"))
        print(f"Review Notes: {n}/{NOTES_LIMIT} characters")
        if n > NOTES_LIMIT:
            problems.append(f"Review Notes are {n} characters, limit is {NOTES_LIMIT}")
    else:
        warnings.append("docs/app-review-notes.txt not found")

    # 4) Release build (unsigned)
    if not skip_build:
        print("Running Release build...")
        with tempfile.TemporaryDirectory() as dd:
            r = subprocess.run(
                ["xcodebuild", "-project", str(ROOT / "donerkebabmap.xcodeproj"),
                 "-scheme", "donerkebabmap", "-configuration", "Release",
                 "-destination", "generic/platform=iOS", "-derivedDataPath", dd,
                 "build", "CODE_SIGNING_ALLOWED=NO"],
                capture_output=True, text=True)
        if "BUILD SUCCEEDED" in r.stdout:
            print("Release build: SUCCEEDED")
        else:
            errs = [l for l in r.stdout.splitlines() if "error:" in l][:10]
            problems.append("Release build FAILED:\n    " + "\n    ".join(errs or ["(no details)"]))

    print()
    for w in warnings: print(f"WARNING: {w}")
    for p in problems: print(f"PROBLEM: {p}")
    print("\nRESULT:", "READY" if not problems else f"{len(problems)} PROBLEM(S)")
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
    print(f"Version {cur} -> {new}, build {max(int(b) for b in bv)} -> {build}")
    return 0

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["check"]:
        sys.exit(check("--skip-build" in a))
    if a[:1] == ["bump"] and len(a) == 2:
        sys.exit(bump(a[1]))
    sys.exit(__doc__)
