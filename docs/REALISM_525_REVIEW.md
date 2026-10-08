# Stage 525 — Compatibility meadow colour correction

The shared meadow shader stored dry-grass reflectance as linear constants but
used them directly with sRGB textures in Compatibility rendering. Convert only
those constants when `OUTPUT_IS_SRGB`, matching the grass and road shaders.
Forward+ retains the original linear values.

Reviewed `artifacts/realism525-validation/before/default-spawn.png` and
`after/default-spawn.png`. Their recorded camera poses match exactly. Both use
640×400 Compatibility rendering with MSAA and shadows enabled, with no diagnostic
material substitutions. Both capture logs report `DEFAULT_SPAWN_REVIEW_PASS`.
The dark olive ground becomes lighter dry-grass ground; the road, weapon and
buildings remain visually consistent. This corrects the colour mismatch but
does not resolve flat ground detail, sparse vegetation or repetitive scenery.
These software-rendered captures do not establish mobile frame rate.

Source aim alignment passed 108 samples across three weapons, including
transitions, recoil, lean and raycasts. Roof collision passed for 12 roofs,
slopes, shot blocking and doorways.

Local preview output:
`artifacts/visual-preview/c1fa59a12512-20260925T063819592364Z/`.
Its `verification.json` records packaging status and packaged Linux checks.
Windows execution is not verified.

Published Android 0.52.5 includes this shader correction. Evidence is in
`artifacts/android-latest-20260925-r7/`: the exact APK passed native installation,
startup, solo movement, firing and camera input checks. The distribution source
passed live AWS solo/duo two-client checks and four login-memory checks on Linux.
Native Android online play, physical gyro handling and FPS remain unverified.
The public APK hash matches the tested archive; the website and QR point to it.
Solo/duo ECS revision 5 adds ENet throttle configuration to the current protocol
server. No GitHub push occurred. Overall visual goal remains active.

Next: improve meadow surface breakup and grass coverage with close and wide
views, then address arm proportions and structural character/animation issues.
Avoid treating colour-only changes as completion of the realism target.
