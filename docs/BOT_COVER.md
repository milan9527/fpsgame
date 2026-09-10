# Bot cover behavior

In offline and server-authoritative matches, bots below 65 health, with an empty magazine or while reloading seek nearby solid cover against their last visually observed threat. They sample 36 positions at three radii, reject unsafe or badly projected points, and require both standing and crouching sight lines to hit static geometry. Other players and smoke do not count as solid cover.

Up to six nearby candidates receive navigation path queries. The shortest reachable route within 18 metres wins. The target is held for at most eight seconds and rechecked periodically. After arriving, the bot crouches, stops firing and attempts ordinary treatment/reload actions. Normal healing, stock and action timers still apply. Zone evacuation overrides cover immediately. Recovered bots return to ordinary combat behavior.

Searches require a recently observed threat. An existing target may be retained briefly against the last observed position after visibility is lost; hidden enemies' current positions are never consulted. The tactic is transient navigator state and is recomputed after resuming an offline save.

`tests/bot_cover_rules.gd` creates a real solid barrier before navigation baking, then simulates an injured bot physically walking to cover and completing treatment. It also verifies unknown-threat and unsafe-point rejection, and zone evacuation priority. This behavior does not yet score exposure along the route, multiple attackers or coordinated team tactics.
