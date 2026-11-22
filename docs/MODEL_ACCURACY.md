# Accuracy and source-tracing notes

## Grounded from the architectural source A-201

- Project: Heath Chick-fil-A FSR #06213, P14 LS Base, 775 Hebron Rd, Heath OH 43056.
- Sheet: A-201 Floor Plan, C4; drawing scale 1/4" = 1'-0".
- Overall horizontal dimension printed along upper and lower chain: 123'-6".
- Overall vertical dimension printed at plan edges: 47'-8".
- Wall-framing legend: W4/6/8/10 = corresponding nominal wood-stud types, M4 = 3-5/8" metal stud, M6 = 6", M8 = 8", M10 = 10" metal stud.
- A.1: unless otherwise noted, dimensions shown are to framing (face of stud or jamb).
- `+` next to wall designation indicates additional sheathing/furring layer.
- Notes reference structural sheets, finish plans, and wall sections for additional assemblies and finishes.
- Plan visibly labels dining, play, meal fulfillment, serving, queue, entry vestibule, kitchen, walk-in freezer (WIF), walk-in cooler (WIC), service, men, women, restroom vestibule, office, flex space, tech closet and team member room.

## What is approximate in the included JSON

- Each wall endpoint in the provided 56-segment file was placed by eye from the PDF image. These have **not** been tested against the full dimension chain, secondary details or original Revit CAD coordinates. Project is NOT a validated as-built BIM.
- All wall heights set to **10 ft as a placeholder**, not a value established from A-201. Wall types use frame depth, not finished assemblies.
- Door openings, storefront windows and roof geometry are not modeled as geometric cutouts. A visual/virtual walkthrough does not prevent walking through walls.
- The 17 colored electrical-device shapes are **demonstration markers** placed in room regions visible on A-201. They do not represent exact positions detected from E-104/E-801. No circuit numbers are assigned unless verified; all markers remain unverified.
- The 2-point AR calibration assumes the user selected the correct building-plan origin and a second measured point along the building's horizontal X axis. It doesn't account for phone-to-mark offsets, drift, true survey coordinates or grade changes. Alignment discrepancy is reported, not scaled away.

## Plan coordinate conventions

- 3D `(x, y, z)` is metric. `x` runs left-to-right across A-201; `z` runs top-to-bottom; `y` is height above slab.
- Plan (0,0) is an approximate upper-left main exterior wall reference, not a surveyed control point.
- World-to-plan registration is ephemeral while AR is open.
- Correct source-of-truth for any site task remains approved/current construction plans, control points, field layout and measuring equipment.

## Recommended verification sequence

1. Check 123'-6" and 47'-8" dimension reference lines and locate the actual origin they reference. Verify the north meal-fulfillment projection and RR vestibule bump separately.
2. Use all explicit architectural dimension strings to reconstruct exterior and interior wall center/face positions; record whether each refers to face of frame, rough opening or finished surface.
3. Assign W/M wall tags, include substrate and finishes from wall details/sections, and obtain heights from elevations/sections.
4. Model door openings and storefront glazing. Align to structural gridlines or foundation corners before onsite overlay.
5. Register E-104 and E-801 to A-201, then annotate electrical device symbols and mounting heights with source-sheet references. Resolve conflicts by plan revision and field coordination.
6. Require visual review/approval before changing from unverified to field-usable status, and still independently verify on site.
