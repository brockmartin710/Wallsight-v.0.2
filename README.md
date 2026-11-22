# WallSight — Full iPhone MVP (Heath Chick-fil-A draft)

**Status: Source deliverable, not Xcode-compiled or field-validated in this environment.**

## Features included

1. **Off-site 3D viewer:** 56 draft A-201 wall segments, 17 room labels, 17 provisional electrical markers, orbit/zoom/pan and first-person movement, tap-to-inspect wall tags and device info.
2. **On-site blueprint AR preview:** shared 3D geometry, two measured reference points, yaw/height adjustment, tracking-state warnings. No automatic survey registration, gridline detection or construction-grade accuracy.
3. **LiDAR house scanner:** live mesh, first-floor wall snapshot, continuous upstairs scan, show walls below, torch toggle and tracking warnings. Not intended to determine drilling locations without independent measurements.
4. **PDF drawing library:** import multiple PDF sheets from iOS Files into local storage, preview in PDFKit, report text-recognized tags/references/dimension-like text, and manually correct sheet IDs.
5. **Manual model correction and JSON import:** edit wall endpoints/heights and electrical-device coordinates (feet) on the phone, saved in the app's private Documents storage. Import compatible JSON models generated externally; a reset restores the bundled A-201 draft.
6. **GitHub Actions:** macOS XcodeGen build of unsigned iOS IPA for AltStore-based signing and sideloading.

## Important model facts

- Architectural source: **A-201, Floor Plan, FSR #06213, Heath, OH, dated 2026-04-24**.
- A-201 overall horizontal dimension: **123 ft 6 in**.
- A-201 shows an overall vertical dimension **47 ft 8 in** along its main building elevation; the footprint has projections and setbacks, and should not be treated as a plain rectangle.
- Framing legend: **W4=2×4, W6=2×6, W8=2×8, W10=2×10 wood studs**; **M4=3⅝ in, M6=6 in, M8=8 in, M10=10 in metal studs**. These are **framing designations, not finished wall thicknesses**.
- A-201 general note A.1: dimensions are **face of framing / jamb unless otherwise noted**.
- The 56 wall segments are **a manually estimated interpretation** from the visible architectural sheet, not a CAD-grade trace and not independently dimension-checked. Height is a **10-foot placeholder**. Exterior wall assemblies, doors, glazing and ceiling elevations are not fully modeled.
- The **17 electrical devices are illustrative markers** in plausible areas. They are **not extracted approved box locations**, and circuit fields are explicitly unverified. Sheet references E-104 and E-801 indicate where to research, not confirmed point coordinates.

See `docs/MODEL_ACCURACY.md` for exact boundaries and caveats.

## Setup on Windows (VS Code + GitHub Actions + AltStore)

1. **Back up your existing WallSight project.** This package is a **complete replacement project**. Preserve any custom files from your earlier working version separately.
2. Extract this ZIP and open **WallSight_Complete_MVP** in VS Code. The `project.yml`, all 11 Swift files, and the `Resources/HeathChickFilA_DRAFT.json` resource must remain together in this folder.
3. Open the GitHub repository that currently builds your iPhone IPA. Upload the **contents of this folder**, **not** the ZIP as a single file. Preserve the `.github/workflows/ios-build.yml` subfolders. If your repository already has another GitHub Actions workflow, remove or disable that previous workflow to avoid confusion.
4. Commit to your `main` branch (or change the workflow branch trigger to your branch). GitHub → **Actions → WallSight iOS IPA Build → Run workflow**. A commit to `main` also triggers a build.
5. When successful, open the workflow run → **Artifacts → WallSight-iOS-Test**, download the artifact ZIP, and extract the `WallSight-unsigned.ipa` file.
6. Sign/sideload using the **same AltStore process that worked for your previous build**. The IPA is deliberately unsigned; ordinary iOS installation requires signing.
7. Launch WallSight. Open **3D Building & Walkthrough**, test Overview and Walkthrough; then open Drawing Library to import the actual A-201 and electrical PDFs via Files on your phone.

> **Privacy/security:** the PDFs you uploaded may be proprietary commercial construction documentation. This ZIP deliberately **does not bundle the original PDFs**. Upload them *into the app on your phone*, not into a public GitHub repository. The bundled JSON contains draft interpretation/metadata and is also best kept in a private repository.

## Build troubleshooting

- First find the **first `error:` line** in GitHub Actions' Compile unsigned iPhone app step, not just `BUILD FAILED`.
- `HeathChickFilA_DRAFT.json not found`: ensure the `Resources` folder and JSON are uploaded, and `project.yml` includes the resource entry.
- `No module named ARKit`: GitHub Actions must build for iOS with a macOS runner, not Windows or Linux.
- Permissions: camera permission is requested by iOS when AR starts. PDF import is user initiated; imported files are copied into the app sandbox.
- App installation: an unsigned IPA **must be signed** by AltStore or an equivalent signing process. The build workflow does not create a developer-signed IPA.

## What we have not implemented (next milestones)

- Fully automatic multi-sheet **PDF-to-BIM / 3D extraction** (interpreting construction symbols, leader notes, dimension chains, and relationships across disciplines).
- Reliable door/window cutouts, full finishes and materials, production-quality kitchen equipment, or accurate heights from architectural sections.
- Verified electrical box positions, mounting heights, circuit associations, automatically extracted conduit runs, or as-built coordination.
- Survey-grade AR alignment / persistent anchors / reliable long-distance tracking.
- Construction-grade layout/placement. **Always physically verify before drilling, cutting, or setting stub-ups.**

For a true automated import pipeline, implement a backend (vector PDF parser + detection + human review) that outputs the same JSON schema. Do not silently treat detected text as precise 3D geometry.

## Folder map

```
WallSight_Complete_MVP/
  WallSightApp.swift
  ContentView.swift
  HouseScanView.swift
  ContinuousScannerView.swift
  BuildingModel.swift
  BuildingSceneFactory.swift
  BuildingViewerView.swift
  BlueprintARView.swift
  ProjectStore.swift
  DrawingLibraryView.swift
  ModelEditorView.swift
  Resources/HeathChickFilA_DRAFT.json
  project.yml
  .github/workflows/ios-build.yml
  docs/MODEL_ACCURACY.md
  docs/SHEET_INVENTORY.csv
  tools/generate_heath_model.py
  tools/validate_model.py
```
