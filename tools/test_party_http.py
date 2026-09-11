"""Exercise invitation reservations against the isolated running duo service."""
import httpx
from test_accounts import account

BASE = "http://127.0.0.1:8001"


def run():
    identities = [account(f"duo-network-{i}", base=BASE) for i in range(2)]
    with httpx.Client(base_url=BASE, timeout=10) as client:
        headers = [{"Authorization": "Bearer " + identity["token"]} for identity in identities]
        build_response = client.get("/protocol")
        build_response.raise_for_status()
        build = build_response.json()
        for auth in headers:
            client.delete("/parties/current", headers=auth).raise_for_status()
        try:
            created = client.post("/parties", headers=headers[0])
            created.raise_for_status()
            joined = client.post("/parties/accept", headers=headers[1],
                                 json={"invitation": created.json()["invitation"]})
            joined.raise_for_status()
            payload = dict(build, room_id="room-27031")
            assert client.post("/parties/reserve", headers=headers[1], json=payload).status_code == 403
            reserved = client.post("/parties/reserve", headers=headers[0], json=payload)
            reserved.raise_for_status()
            repeated = client.post("/parties/reserve", headers=headers[0], json=payload)
            repeated.raise_for_status()
            member = client.get("/parties/current", headers=headers[1])
            member.raise_for_status()
            first, second = reserved.json()["admission"], member.json()["admission"]
            assert first["ticket"] == repeated.json()["admission"]["ticket"]
            assert first["ticket"] != second["ticket"]
            assert first["ticket"] not in member.text and second["ticket"] not in reserved.text
            for field in ["party_id", "group_id", "room_id", "instance_id", "generation"]:
                assert first[field] == second[field]
            assert first["mode"] == second["mode"] == "duo"
            for response in [reserved, repeated, member]:
                assert response.headers["cache-control"] == "no-store"
                assert "reservation" not in response.json() and "digest" not in response.text
            client.delete("/parties/current", headers=headers[1]).raise_for_status()
            for auth in headers:
                assert client.get("/parties/current", headers=auth).json() == {}
            # Both released slots can immediately be reserved by the same users.
            for auth in headers:
                response = client.post("/matchmaking/rooms/join", headers=auth,
                                       json=dict(payload, mode="duo"))
                response.raise_for_status()
                ticket = response.json()["ticket"]
                client.post("/matchmaking/rooms/cancel", headers=auth,
                            json={"ticket": ticket}).raise_for_status()
            print("PARTY_HTTP_PASS authenticated=2 leader_only=ok idempotent=ok "
                  "private_tickets=ok same_room=ok disband_capacity=ok")
        finally:
            for auth in headers:
                client.delete("/parties/current", headers=auth).raise_for_status()


if __name__ == "__main__":
    run()
