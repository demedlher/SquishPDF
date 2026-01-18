# SquishPDF - Project Instructions for Claude

## Building Releases

When asked to build installers and create a release:

### Two Installer Types (NOT architecture-specific)

1. **Full version** (with Ghostscript bundled, ~22MB):
   ```bash
   ./build_app.sh --with-gs  # or just ./build_app.sh
   mv SquishPDF_Installer.dmg SquishPDF_vX.X_Full.dmg
   ```

2. **Lean version** (without Ghostscript, ~3MB):
   ```bash
   ./build_app.sh --no-gs
   mv SquishPDF_Installer_Lean.dmg SquishPDF_vX.X_Lean.dmg
   ```

### Release Workflow

1. Commit changes with descriptive message
2. Push to main
3. Build Full version first: `./build_app.sh --with-gs`
4. Rename: `mv SquishPDF_Installer.dmg SquishPDF_vX.X_Full.dmg`
5. Build Lean version: `./build_app.sh --no-gs`
6. Rename: `mv SquishPDF_Installer_Lean.dmg SquishPDF_vX.X_Lean.dmg`
7. Create GitHub release with both DMGs
8. Commit and push the version bump (build_app.sh auto-increments)

### Release Notes Template

Include a download table:
```markdown
| File | Size | Description |
|------|------|-------------|
| `SquishPDF_vX.X_Full.dmg` | ~22 MB | **Recommended** - Includes bundled Ghostscript |
| `SquishPDF_vX.X_Lean.dmg` | ~3 MB | For users who already have Ghostscript (`brew install ghostscript`) |
```

## Versioning

- Version format: `MAJOR.MINOR.BUILD`
- `AppVersion.swift` is auto-updated by `build_app.sh`
- Build number increments with each installer build
- Git commit hash is embedded for traceability

## Architecture Note

Currently builds are native to the build machine's architecture. Future consideration: provide separate Apple Silicon and Intel builds (would be 4 total installers).
