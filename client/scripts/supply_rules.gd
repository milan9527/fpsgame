extends RefCounted

const DEFAULT_AMOUNT := [45.0, 1.0, 40.0, 1.0, 1.0, 1.0]
const LIMITS := [300.0, 5.0, 100.0, 4.0, 3.0, 3.0]
const FIELDS := ["reserve", "medkits", "armor", "grenades", "smokes", "grips"]
const NAMES := ["AMMUNITION", "MEDKIT", "ARMOR", "FRAG", "SMOKE", "FOREGRIP"]
const RANGE := 2.8

static func amount(item: Dictionary) -> float:
	return float(item.get("amount", DEFAULT_AMOUNT[int(item.kind)]))

static func capacity(actor, kind: int) -> float:
	return maxf(0, LIMITS[kind] - float(actor.get(FIELDS[kind])))

static func transfer(actor, item: Dictionary) -> float:
	var kind := int(item.kind)
	var taken := minf(amount(item), capacity(actor, kind))
	if taken <= 0:
		return 0
	var value := float(actor.get(FIELDS[kind])) + taken
	actor.set(FIELDS[kind], value if kind == 2 else int(value))
	item.amount = maxf(0, amount(item) - taken)
	return taken
