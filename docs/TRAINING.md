# Basic training

Choose BASIC TRAINING from the deployment menu. Nine sequential tasks teach movement, crouching, three stationary shooting targets, ammunition pickup, reload completion, treatment, frag detonation, smoke deployment and setting a tactical-map waypoint. Hints use the current keyboard bindings.

The course uses the ordinary simulation and interaction systems. Targets appear on the central road for the shooting stage. Supplies are marked with a waypoint. Ammunition and required consumables are replenished as needed. Player damage is disabled; only player gunfire during target practice damages targets. There are no active opponents or advancing circle, and the course has no time limit. Escape pauses; after completion Escape returns directly to deployment.

Training is local, produces no match result and cannot be suspended into the saved-operation slot. Leaving training preserves a previously saved operation. Starting a normal offline operation restores normal rules. Training progress itself is not saved.

`tests/training_rules.gd` exercises all stages through real movement, shots, pickup, reload/heal timers, projectile fuses and smoke growth, then checks result isolation and resumes a saved normal operation. This is an introductory course, not advanced tactical or team training.
