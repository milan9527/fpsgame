"""Keep the aiming marker on the ballistic center instead of the animated gun."""
from pathlib import Path


def apply(client: Path):
    path = client / 'scripts/first_person.gd'
    text = path.read_text()
    old = 'sight_dot.visible = desired not in ["Throw", "Heal"] and not actor.weapon_blocked'
    if old in text:
        text = text.replace(old, '# The HUD owns the ballistic reticle; the gun animation must not move it.\n\tsight_dot.visible = false', 1)
    path.write_text(text)
    path = client / 'scripts/interface.gd'
    text = path.read_text()
    old = 'elif not spectating and not vehicle_view and not sight_aiming:'
    if old in text:
        text = text.replace(old, '''elif not spectating and not vehicle_view and sight_aiming:
		# A fixed camera-center dot stays accurate during ADS transitions and kick.
		hud.draw_circle(center, 3.5, Color(0.03, 0.03, 0.03, 0.9))
		hud.draw_circle(center, 2.0, Color("ff4035"))
	elif not spectating and not vehicle_view:''', 1)
    path.write_text(text)
