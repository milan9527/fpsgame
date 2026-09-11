from concurrent.futures import ThreadPoolExecutor
import uuid
import pytest
from fastapi import HTTPException
from app.rooms import PartyMember
from test_rooms import directory, heartbeat, consume_body, rejected


def members():
    return [PartyMember(uid=uuid.uuid4(), username='member_' + str(index), session_version=index)
            for index in range(2)]


def test_whole_party_capacity_and_ticket_binding(directory):
    directory.heartbeat(heartbeat(capacity=2, mode='duo'))
    occupied_uid = str(uuid.uuid4())
    occupied = directory.allocate(occupied_uid, 'occupied', mode='duo')
    pair = members()
    rejected(503, lambda: directory.allocate_party(str(uuid.uuid4()), pair))
    assert all(directory.cache.get(directory.prefix + 'user:' + str(member.uid)) is None for member in pair)
    directory.cancel(occupied_uid, occupied['ticket'])
    party_id = str(uuid.uuid4())
    result = directory.allocate_party(party_id, pair)
    assert len(result['admissions']) == 2
    for member in pair:
        admission = result['admissions'][str(member.uid)]
        wrong = consume_body(admission).model_copy(update={'mode': 'solo'})
        rejected(409, lambda: directory.consume(wrong))
        ticket = directory.consume(consume_body(admission).model_copy(update={'mode': 'duo'}))
        assert ticket['party_id'] == party_id and ticket['group_id'] == result['group_id']
        assert ticket['uid'] == str(member.uid) and ticket['session_version'] == member.session_version
        assert ticket['generation'] == admission['generation']


def test_busy_member_leaves_no_partial_reservation(directory):
    directory.heartbeat(heartbeat(capacity=4, mode='duo'))
    pair = members()
    existing = directory.allocate(str(pair[1].uid), pair[1].username, mode='duo')
    rejected(409, lambda: directory.allocate_party(str(uuid.uuid4()), pair))
    assert directory.cache.get(directory.prefix + 'user:' + str(pair[0].uid)) is None
    assert directory.consume(consume_body(existing).model_copy(update={'mode': 'duo'}))['uid'] == str(pair[1].uid)


def test_concurrent_parties_never_split_or_overbook(directory):
    directory.heartbeat(heartbeat(capacity=6, mode='duo'))
    pairs = [members() for _ in range(12)]
    def allocate(pair):
        try:
            return directory.allocate_party(str(uuid.uuid4()), pair)
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=12) as executor:
        replies = list(executor.map(allocate, pairs))
    assert sum(isinstance(reply, dict) for reply in replies) == 3
    assert sum(reply == 503 for reply in replies) == 9
    assert directory.cache.zcard(directory.prefix + 'held:a') == 6
    for pair, reply in zip(pairs, replies):
        held = [directory.cache.exists(directory.prefix + 'user:' + str(member.uid)) for member in pair]
        assert held == ([1, 1] if isinstance(reply, dict) else [0, 0])


def test_cancel_releases_both_unconsumed_tickets(directory):
    directory.heartbeat(heartbeat(capacity=2, mode='duo'))
    pair = members()
    result = directory.allocate_party(str(uuid.uuid4()), pair)
    first = result['admissions'][str(pair[0].uid)]
    rejected(403, lambda: directory.cancel(str(uuid.uuid4()), first['ticket']))
    assert directory.cancel(str(pair[0].uid), first['ticket'])['status'] == 'cancelled'
    assert directory.cache.zcard(directory.prefix + 'held:a') == 0
    for member in pair:
        admission = result['admissions'][str(member.uid)]
        rejected(401, lambda: directory.consume(consume_body(admission).model_copy(update={'mode': 'duo'})))
    assert directory.allocate_party(str(uuid.uuid4()), pair)


def test_partial_admission_cancel_preserves_consumed_member(directory):
    directory.heartbeat(heartbeat(capacity=2, mode='duo'))
    pair = members()
    result = directory.allocate_party(str(uuid.uuid4()), pair)
    first, second = [result['admissions'][str(member.uid)] for member in pair]
    directory.consume(consume_body(first).model_copy(update={'mode': 'duo'}))
    directory.cancel(str(pair[1].uid), second['ticket'])
    assert directory.cache.exists(directory.prefix + 'user:' + str(pair[0].uid)) == 1
    assert directory.cache.exists(directory.prefix + 'user:' + str(pair[1].uid)) == 0
    assert directory.cache.zcard(directory.prefix + 'held:a') == 1


def test_party_shape_rejected_before_mutation(directory):
    pair = members()
    with pytest.raises(ValueError):
        directory.allocate_party(str(uuid.uuid4()), [pair[0], pair[0]])
    assert not list(directory.cache.scan_iter(directory.prefix + '*'))
