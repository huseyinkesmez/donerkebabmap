---
name: release
description: Prepares a new Doner Kebab Map release for TestFlight / the App Store — bumps the version and build number, checks translations, "doner" spelling, review notes length and the Release build, then gives the user an upload and App Review checklist. Use when the user says "/release", "new version", "send to TestFlight", or "submit to the store".
argument-hint: "[patch|minor|major|X.Y.Z]"
---

# /release — prepare a new version

Talk to the user **in Turkish**, simply and step by step. Everything you write
to files stays in English. This skill does not upload anything: archiving and
App Store Connect work happen in Xcode with the user's Apple account. Never ask
for credentials or accept agreements on the user's behalf.

Helper script: `.claude/skills/release/scripts/release.py` (run from the repo root).

## 1. Pick the release type
Use the argument if given. Otherwise ask the user:
- **patch** (1.0 → 1.0.1): bug fixes only
- **minor** (1.0 → 1.1): new features
- **major** (1.x → 2.0): big changes

## 2. Preflight (before changing anything)
```bash
python3 .claude/skills/release/scripts/release.py check --skip-build
```
Checks: Debug/Release versions match, no "döner" with ö in app text, no string
missing a DE/FR translation, review notes under 4000 characters, uncommitted changes.

Fix any **PROBLEM** first:
- "döner" with ö → change to "doner", and rename the catalog key the same way.
- Missing translation → add it to `Localizable.xcstrings`. German uses informal
  "du", French formal "vous". Proper names (Apple Maps, Doner Kebab Map) stay as-is.
- Notes over 4000 → shorten `docs/app-review-notes.txt`, but **never remove**
  the "results depend on location, test in a big city" paragraph.

## 3. Bump the version
```bash
python3 .claude/skills/release/scripts/release.py bump <patch|minor|major|X.Y.Z>
```
Always increments the build number. Ask the user: "What was the last build
number you uploaded to App Store Connect?" If the new build is not higher, raise
`CURRENT_PROJECT_VERSION` manually (otherwise the upload is rejected).

## 4. Full check (including the Release build)
```bash
python3 .claude/skills/release/scripts/release.py check
```
Don't move on until it prints **RESULT: READY**.

## 5. Change summary
Summarize what changed since the last tag:
```bash
git describe --tags --abbrev=0
git log <last-tag>..HEAD --oneline
```
Also suggest 2–4 English bullet points for the App Store "What's New" text.

## 6. Give the user the checklist (in Turkish)
Fill in the version and build numbers:

**Archive and upload (Xcode)**
1. Device selector: **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App → TestFlight & App Store Connect → Upload**
4. On errors: "PLA Update" → accept the agreement at developer.apple.com;
   "No iOS Distribution certificate" → Xcode Settings → Accounts →
   Manage Certificates → + Apple Distribution.

**App Store Connect**
- Create the new version and select the new build
- Paste the "What's New" text
- Review Notes: `docs/app-review-notes.txt` (plain text; copy with
  `pbcopy < docs/app-review-notes.txt`)
- Put the **map screenshot first**
- Submit for Review

**Don't**
- Re-upload the same build number
- Add features or change the bundle ID / app name while in review
- Remove the location paragraph from the Review Notes
- If Apple asks for a screen recording: don't use the simulator; record on a
  physical device, starting with the app closed, and show the location prompt

## 7. Commit and tag (only if the user agrees)
Ask first. If yes:
```bash
git add -A
git commit -m "Release <version> (build <n>)"
git tag -a v<version> -m "App Store release <version> (build <n>)"
git push origin main && git push origin v<version>
```
End the commit message with the current Co-Authored-By line.
