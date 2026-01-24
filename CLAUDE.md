# SquishPDF - Project Instructions for Claude

## Building Releases

When asked to build installers and create a release:

### v4.0+ (Native Compression - Default)

Native builds use Apple frameworks only (no Ghostscript, no AGPL, commercially distributable):

```bash
./build_app.sh  # Native is now default (~3 MB)
mv SquishPDF_Installer.dmg SquishPDF_vX.X.dmg
```

### Legacy Ghostscript Build (AGPL - Not for commercial use)

Only use this for users who specifically need selectable text output:

```bash
./build_app.sh --with-gs  # (~22 MB, AGPL licensed)
mv SquishPDF_Installer_GS.dmg SquishPDF_vX.X_GS.dmg
```

### Release Workflow

1. Commit changes with descriptive message
2. Push to main
3. Build: `./build_app.sh`
4. Rename: `mv SquishPDF_Installer.dmg SquishPDF_vX.X.dmg`
5. Create GitHub release with the DMG
6. Commit and push the version bump (build_app.sh auto-increments)

### Release Notes Template

```markdown
| File | Size | Description |
|------|------|-------------|
| `SquishPDF_vX.X.dmg` | ~3 MB | Native compression (commercially distributable) |
```

## Versioning

- Version format: `MAJOR.MINOR.BUILD`
- `AppVersion.swift` is auto-updated by `build_app.sh`
- Build number increments with each installer build
- Git commit hash is embedded for traceability

## Architecture Note

Currently builds are native to the build machine's architecture. Future consideration: provide separate Apple Silicon and Intel builds.

## Compression Engines

- **Native (default)**: Uses CoreGraphics/PDFKit. No dependencies. Text becomes non-selectable.
- **Ghostscript (legacy)**: Preserves text selectability. Requires `--with-gs` flag. AGPL licensed.
