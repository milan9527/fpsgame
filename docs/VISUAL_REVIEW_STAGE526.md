# Stage 526 — Android grass instance color

The Android 0.52.6 source snapshot includes the current environment, building,
weapon and mobile improvements, plus an instance-color correction for grass in Compatibility
rendering. Desktop captures confirm improvement; Android parity remains incomplete.

Both the main grass and roadside grass MultiMesh batches use custom instance
data. An isolated rendering probe showed that the mesh's authored vertex colors
rendered black in this configuration. Enabling instance colors and setting each
instance color to white preserved those authored colors. Both batches now apply
that change.

Evidence under `artifacts/realism526-validation/`:

- `diagnostic/grass-probe.png`: original and custom-data variants appeared black.
- `diagnostic/grass-probe-white.png`: explicit white instance colors restored color.
- `before/grass-bank-eye-level.png` and `after/grass-bank-eye-level.png`: the same
  world view before and after the fix; the final image was visually reviewed.

The world capture passed. It shows green grass instead of black clumps.
This is an incremental rendering correction; it does not establish completion
of the broader realistic graphics goal.

Android release evidence is stored separately in
`artifacts/android-latest-20260925-r8/`. The signed APK is
`IronMeridian-Android-0.52.6-20260925.apk`, version code `20260928`, SHA-256
`6ad45ae28d1c6fe8df1f69abfe576b185ff6ce02a1d8e6762682ce24a7204523`.
Native test and publication outcomes must be read from that directory's
result files; a successful source test alone is not native Android validation.

Native Android and publication verification completed:

- Pixel 10 Device Farm fuzz and scripted native walkthrough both PASSED.
- Manually reviewed `02-solo.png`, `03-fire.png`, and `04-look.png`: world and
  controls render, ammunition decreases 30/120 to 24/120, and look input rotates
  the camera while the game timer advances.
- Android roadside grass still appears very dark. This remains an open visual
  issue despite the desktop improvement.
- Packaged-source solo/duo network and login-memory checks passed on Linux;
  native Android online play, physical gyro handling and FPS are not verified.
- UI, aiming and gyro logic checks passed. Publication passed, including full
  public APK SHA-256 verification and absence of a website login form.
- Download page and QR now link to 0.52.6. No GitHub push was performed.
