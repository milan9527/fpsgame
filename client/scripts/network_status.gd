extends RefCounted

var started := -1
var last_snapshot := -1
var rtt := -1.0
var variance := -1.0

func reset() -> void:
	started = -1
	last_snapshot = -1
	rtt = -1
	variance = -1

func begin(now: int) -> void:
	reset()
	started = now

func received(now: int) -> void:
	last_snapshot = now

func sample(milliseconds: float, variation: float) -> void:
	if is_finite(milliseconds) and is_finite(variation) and milliseconds >= 0 and variation >= 0:
		rtt = milliseconds
		variance = variation

func describe(now: int) -> Dictionary:
	if started < 0:
		return {"text": "", "severity": 0, "stalled": false}
	var age := maxi(0, now - (last_snapshot if last_snapshot >= 0 else started))
	var stalled := age >= 1000
	var measured := last_snapshot >= 0 and now - started >= 1000 and rtt >= 0
	var heading := "SERVER UPDATES DELAYED" if stalled else ("CONNECTED" if last_snapshot >= 0 else "SYNCING WITH SERVER")
	var severity := 2 if stalled else 0
	if not stalled and measured and (rtt >= 180 or variance >= 60):
		heading = "UNSTABLE NETWORK" if variance >= 60 else "HIGH LATENCY"
		severity = 1
	var timing := "MEASURING RTT"
	if measured:
		timing = "RTT %dms / VAR %dms" % [roundi(rtt), roundi(variance)]
	var age_text := ("LAST UPDATE %dms" if last_snapshot >= 0 else "WAITING %dms") % age
	return {"text": heading + "\n" + timing + "\n" + age_text, "severity": severity, "stalled": stalled}
