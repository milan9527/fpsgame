# Sixteen-client capacity gate

Run `.venv/bin/python tools/test_capacity.py` with the local Compose stack running and `room-27015` empty and waiting. The test uses reusable private QA accounts and production authentication, allocation, tickets, ENet and the normal dedicated server. It does not change server limits or the match clock. Repeated runs wait for sufficient login-rate capacity instead of resetting Redis counters.

Sixteen independent headless Godot processes must report sixteen human-controlled slots, distinct peer IDs and the same match ID. The orchestrator verifies the room directory also lists sixteen players. A seventeenth account must receive HTTP 503 when requesting this unavailable room. This check occurs after the round becomes live: it verifies rejection of a full live room, not independently the lobby's seventeenth-seat race.

After a shared barrier, clients send movement and fire input for eight wall-clock seconds. Each must observe movement from at least eight replicated actors, ammunition consumption, more than thirty prediction corrections and more than five seconds of server-clock advancement. Clients remain connected until every peer passes. They then leave normally, and the test checks all sixteen disconnects and room reuse with a new generation. RPC/engine errors, oversized packets and leaked Godot objects fail the gate.

Each run writes client logs, server logs and (on success) a JSON report to a unique `artifacts/capacity-*` directory. The last launcher output is usually redirected to `artifacts/capacity-test.log`. Failure artifacts are retained for diagnosis. The test cleans up its own processes on exit.

This is a short functional concurrency gate on one host. It does not measure graphical frame rate, sixteen people playing, WAN latency, packet loss, long-duration stability or a full sixteen-player match. Simulated-time progress is only a coarse overload check, not a percentile latency benchmark. Those remain separate release requirements.
