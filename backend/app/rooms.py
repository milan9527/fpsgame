"""Atomic room directory and admission leases for one Redis deployment."""
import hashlib
import json
import secrets
import uuid
from typing import Annotated, Literal

from fastapi import HTTPException
from pydantic import BaseModel, Field, model_validator
from .protocol import BuildInfo, BUILD


class RoomHeartbeat(BuildInfo):
    room_id: str = Field(min_length=1, max_length=64, pattern=r'^[a-zA-Z0-9_-]+$')
    instance_id: uuid.UUID
    generation: uuid.UUID
    revision: int = Field(strict=True, ge=0, le=2147483647)
    host: str = Field(min_length=1, max_length=253, pattern=r'^[a-zA-Z0-9.:-]+$')
    port: int = Field(strict=True, ge=1, le=65535)
    capacity: int = Field(strict=True, ge=1, le=16)
    phase: Literal['waiting', 'lobby', 'live', 'finished']
    mode: Literal['solo', 'duo'] = 'solo'
    players: list[uuid.UUID] = Field(default_factory=list, max_length=16)

    session_versions: dict[uuid.UUID, Annotated[int, Field(strict=True, ge=0, le=9223372036854775806)]] = Field(default_factory=dict, max_length=16)
    reconnectable: dict[uuid.UUID, Annotated[int, Field(strict=True, ge=1, le=30)]] = Field(default_factory=dict, max_length=16)

    @model_validator(mode='after')
    def valid_players(self):
        if len(self.players) != len(set(self.players)) or len(self.players) > self.capacity:
            raise ValueError('Players must be unique and fit room capacity')
        if self.mode == 'duo' and self.capacity % 2:
            raise ValueError('Duo capacity must contain complete two-player teams')
        if self.reconnectable:
            if self.phase != 'live':
                raise ValueError('Reconnect seats require a live match')
            if not self.reconnectable.keys() <= set(self.players):
                raise ValueError('Reconnect seats must occupy player slots')
            if not self.reconnectable.keys() <= self.session_versions.keys():
                raise ValueError('Reconnect seats require session versions')
        return self


class RoomJoin(BuildInfo):
    room_id: str = Field(default='', max_length=64, pattern=r'^[a-zA-Z0-9_-]*$')
    mode: Literal['solo', 'duo'] = 'solo'


class RoomTicket(BuildInfo):
    room_id: str = Field(min_length=1, max_length=64, pattern=r'^[a-zA-Z0-9_-]+$')
    instance_id: uuid.UUID
    generation: uuid.UUID
    ticket: str = Field(min_length=20, max_length=128)
    mode: Literal['solo', 'duo'] = 'solo'


class CancelRoomTicket(BaseModel):
    ticket: str = Field(min_length=20, max_length=128)


class PartyMember(BaseModel):
    uid: uuid.UUID
    username: str = Field(min_length=3, max_length=24, pattern=r'^[a-zA-Z0-9_]+$')
    session_version: int = Field(default=0, strict=True, ge=0, le=9223372036854775806)


HEARTBEAT = """
local p=ARGV[1]; local room=cjson.decode(ARGV[2])
local key=p..'room:'..room.room_id; local raw=redis.call('GET',key)
local old=nil
if raw then
    old=cjson.decode(raw)
    if old.instance_id~=room.instance_id then return 'instance_conflict' end
    if old.revision>=room.revision then return 'stale_revision' end
    if old.host~=room.host or old.port~=room.port or old.protocol~=room.protocol or old.content_revision~=room.content_revision then return 'endpoint_conflict' end
    if old.generation==room.generation and old.capacity~=room.capacity then return 'capacity_conflict' end
    if (old.mode or 'solo')~=room.mode and (old.generation==room.generation or #old.players>0 or #room.players>0) then return 'mode_conflict' end
    if old.generation==room.generation and (old.phase=='live' or old.phase=='finished') and (room.phase=='waiting' or room.phase=='lobby') then return 'generation_required' end
end
local owner=room.room_id..'/'..room.instance_id..'/'..room.generation
for _,uid in ipairs(room.players) do
    local existing=redis.call('GET',p..'user:'..uid)
    if existing and existing~=owner then
        -- A new generation of the same process may carry connected players.
        local previous=old and old.room_id..'/'..old.instance_id..'/'..old.generation or ''
        if existing~=previous then return 'player_conflict' end
    end
end
local held=p..'held:'..room.room_id
if not old then
    for _,uid in ipairs(redis.call('ZRANGE',held,0,-1)) do
        local value=redis.call('GET',p..'user:'..uid)
        if value and string.sub(value,1,string.len(room.room_id)+1)==room.room_id..'/' then
            redis.call('DEL',p..'user:'..uid)
        end
    end
    redis.call('DEL',held)
end
if old then
    local previous=old.room_id..'/'..old.instance_id..'/'..old.generation
    local keep={}
    for _,uid in ipairs(room.players) do keep[uid]=true end
    for _,uid in ipairs(old.players) do
        if not keep[uid] and redis.call('GET',p..'user:'..uid)==previous then
            redis.call('DEL',p..'user:'..uid)
        end
    end
    if old.generation~=room.generation then
        for _,uid in ipairs(redis.call('ZRANGE',held,0,-1)) do
            if redis.call('GET',p..'user:'..uid)==previous then redis.call('DEL',p..'user:'..uid) end
        end
        redis.call('DEL',held)
    end
end
-- Admission must use Redis time, never a client's clock or a fresh TTL per poll.
-- Keep this separate from room JSON to preserve empty-array serialization.
local clock=redis.call('TIME')
local now=tonumber(clock[1])*1000+math.floor(tonumber(clock[2])/1000)
local reconnect_key=p..'reconnect:'..room.room_id
local previous_reconnect=redis.call('GET',reconnect_key)
local previous=nil
if previous_reconnect and old and old.generation==room.generation then
    previous=cjson.decode(previous_reconnect)
    if previous.instance_id~=room.instance_id or previous.generation~=room.generation then previous=nil end
end
local deadlines={}
for uid,seconds in pairs(room.reconnectable or {}) do
    local deadline=now+seconds*1000
    if previous and previous.deadlines[uid] and (old.session_versions or {})[uid]==room.session_versions[uid] then
        deadline=math.min(deadline,previous.deadlines[uid])
    end
    deadlines[uid]=deadline
end
redis.call('SET',reconnect_key,cjson.encode({instance_id=room.instance_id,generation=room.generation,
    deadlines=deadlines}),'EX',12)
for _,uid in ipairs(room.players) do
    redis.call('SET',p..'user:'..uid,owner,'EX',15)
    redis.call('SET',p..'user_version:'..uid,tostring((room.session_versions or {})[uid] or 0),'EX',15)
    redis.call('ZREM',held,uid)
end
redis.call('SET',key,ARGV[2],'EX',12)
redis.call('SADD',p..'directory',room.room_id)
return 'ok'
"""

ALLOCATE = """
local p=ARGV[1]; local uid=ARGV[2]
local members={{uid=uid,username=ARGV[3],digest=ARGV[7],session_version=tonumber(ARGV[8])}}
if ARGV[10] and ARGV[10]~='' then members=cjson.decode(ARGV[10]) end
local party=nil
local party_ttl=0
if ARGV[13] and ARGV[13]~='' then
    local current=redis.call('GET',ARGV[13])
    if not current then return {'party_changed'} end
    party=cjson.decode(current)
    if party.id~=ARGV[11] then return {'party_changed'} end
    if party.reservation then return {'existing',cjson.encode(party.reservation)} end
    if current~=ARGV[14] then return {'party_changed'} end
    for _, member in ipairs(party.members) do
        if member.ready~=true then return {'party_changed'} end
    end
    party_ttl=redis.call('PTTL',ARGV[13])
    if party_ttl<45000 then return {'party_changed'} end
end
for _,member in ipairs(members) do
    if redis.call('EXISTS',p..'user:'..member.uid)==1 then return {'busy'} end
end
local t=redis.call('TIME'); local now=tonumber(t[1])+tonumber(t[2])/1000000
local ids=redis.call('SMEMBERS',p..'directory'); table.sort(ids)
for _,id in ipairs(ids) do
    local raw=redis.call('GET',p..'room:'..id)
    if not raw then redis.call('SREM',p..'directory',id)
    elseif ARGV[6]=='' or ARGV[6]==id then
        local room=cjson.decode(raw)
        if (room.phase=='waiting' or room.phase=='lobby') and tostring(room.protocol)==ARGV[4] and room.content_revision==ARGV[5] and (room.mode or 'solo')==ARGV[9] then
            local held=p..'held:'..id
            redis.call('ZREMRANGEBYSCORE',held,'-inf',now)
            if #room.players+redis.call('ZCARD',held)+#members<=room.capacity then
                local owner=id..'/'..room.instance_id..'/'..room.generation
                for _,member in ipairs(members) do
                    local ticket={uid=member.uid,username=member.username,room_id=id,instance_id=room.instance_id,generation=room.generation,protocol=room.protocol,content_revision=room.content_revision,session_version=member.session_version,mode=room.mode or 'solo'}
                    if #members>1 then ticket.party_id=ARGV[11]; ticket.group_id=ARGV[12] end
                    redis.call('SET',p..'ticket:'..member.digest,cjson.encode(ticket),'EX',45)
                    redis.call('SET',p..'user:'..member.uid,owner,'EX',45)
                    redis.call('SET',p..'user_version:'..member.uid,tostring(member.session_version),'EX',45)
                    redis.call('ZADD',held,now+45,member.uid)
                end
                if #members>1 then redis.call('SET',p..'group:'..ARGV[12],cjson.encode(members),'EX',45) end
                if party then
                    local admissions={}
                    for _,member in ipairs(members) do
                        admissions[member.uid]={ticket=member.ticket,room_id=id,instance_id=room.instance_id,generation=room.generation,host=room.host,port=room.port,expires_in=45,mode='duo',party_id=ARGV[11],group_id=ARGV[12],build={protocol=room.protocol,content_revision=room.content_revision,client_version=room.client_version}}
                    end
                    party.reservation={party_id=ARGV[11],group_id=ARGV[12],admissions=admissions,members=members,room_prefix=p}
                    redis.call('SET',ARGV[13],cjson.encode(party),'PX',party_ttl)
                end
                redis.call('EXPIRE',held,60)
                return {'ok',raw}
            end
        end
    end
end
return {'unavailable'}
"""

CONSUME = """
local p=ARGV[1]; local key=p..'ticket:'..ARGV[2]
local raw=redis.call('GET',key)
if not raw then return {'expired'} end
local ticket=cjson.decode(raw)
if ticket.room_id~=ARGV[3] or ticket.instance_id~=ARGV[4] or ticket.generation~=ARGV[5] then return {'binding'} end
local state=redis.call('GET',p..'room:'..ticket.room_id)
if not state then return {'unavailable'} end
local room=cjson.decode(state)
if room.instance_id~=ticket.instance_id or room.generation~=ticket.generation or (room.phase~='waiting' and room.phase~='lobby') then return {'unavailable'} end
if tostring(ticket.protocol)~=ARGV[6] or ticket.content_revision~=ARGV[7] then return {'binding'} end
if (ticket.mode or 'solo')~=ARGV[8] or (room.mode or 'solo')~=ARGV[8] then return {'binding'} end
local owner=ticket.room_id..'/'..ticket.instance_id..'/'..ticket.generation
if redis.call('GET',p..'user:'..ticket.uid)~=owner then return {'expired'} end
-- Keep the capacity lease until a heartbeat confirms the player or 45s elapse.
redis.call('DEL',key)
return {'ok',raw}
"""

CANCEL = """
local p=ARGV[1]; local key=p..'ticket:'..ARGV[2]
local raw=redis.call('GET',key)
if not raw then return 'inactive' end
local ticket=cjson.decode(raw)
if ticket.uid~=ARGV[3] then return 'owner' end
if ticket.group_id then
    local group=redis.call('GET',p..'group:'..ticket.group_id)
    if group then
        for _,member in ipairs(cjson.decode(group)) do
            local member_key=p..'ticket:'..member.digest
            local raw_member=redis.call('GET',member_key)
            if raw_member then
                local other=cjson.decode(raw_member)
                if other.group_id==ticket.group_id then
                    local expected=other.room_id..'/'..other.instance_id..'/'..other.generation
                    if redis.call('GET',p..'user:'..other.uid)==expected and tonumber(redis.call('GET',p..'user_version:'..other.uid) or '0')==tonumber(other.session_version or 0) then
                        redis.call('ZREM',p..'held:'..other.room_id,other.uid)
                        redis.call('DEL',p..'user:'..other.uid,p..'user_version:'..other.uid)
                    end
                    redis.call('DEL',member_key)
                end
            end
        end
        redis.call('DEL',p..'group:'..ticket.group_id)
    end
    return 'cancelled'
end
local owner=ticket.room_id..'/'..ticket.instance_id..'/'..ticket.generation
-- An old generation must never release a newer reservation for the same user.
if redis.call('GET',p..'user:'..ticket.uid)==owner and tonumber(redis.call('GET',p..'user_version:'..ticket.uid) or '0')==tonumber(ticket.session_version or 0) then
    redis.call('ZREM',p..'held:'..ticket.room_id,ticket.uid)
    redis.call('DEL',p..'user:'..ticket.uid)
end
redis.call('DEL',key)
return 'cancelled'
"""


class RoomDirectory:
    def __init__(self, cache, prefix='im:rooms:'):
        self.cache = cache
        self.prefix = prefix

    def heartbeat(self, body: RoomHeartbeat):
        result = self.cache.eval(HEARTBEAT, 0, self.prefix, body.model_dump_json())
        if result != 'ok':
            raise HTTPException(409, 'Room heartbeat rejected: ' + result)
        return {'status': 'ok', 'expires_in': 12}

    def allocate(self, uid: str, username: str, requested_room='', session_version=0, mode='solo'):
        ticket = secrets.token_urlsafe(32)
        digest = hashlib.sha256(ticket.encode()).hexdigest()
        result = self.cache.eval(ALLOCATE, 0, self.prefix, uid, username,
                                 str(BUILD['protocol']), BUILD['content_revision'], requested_room, digest, str(session_version), mode)
        if result[0] == 'busy':
            raise HTTPException(409, 'Already connected or holding a room reservation')
        if result[0] != 'ok':
            raise HTTPException(503, 'No available room; retry shortly')
        room = json.loads(result[1])
        return {'ticket': ticket, 'room_id': room['room_id'], 'instance_id': room['instance_id'],
                'generation': room['generation'], 'host': room['host'], 'port': room['port'],
                'expires_in': 45, 'build': BUILD, 'mode': room.get('mode', 'solo')}

    def revoke_reservation(self, uid, version):
        self.cache.eval("""
            local key=ARGV[1]..'user:'..ARGV[2]
            local owner=redis.call('GET',key)
            local old=tonumber(redis.call('GET',ARGV[1]..'user_version:'..ARGV[2]) or '0')
            if owner and old<tonumber(ARGV[3]) then
                local room=string.match(owner,'^([^/]+)/')
                if room then redis.call('ZREM',ARGV[1]..'held:'..room,ARGV[2]) end
                redis.call('DEL',key,ARGV[1]..'user_version:'..ARGV[2])
            end
        """, 0, self.prefix, uid, str(version))

    def allocate_party(self, party_id: str, members: list[PartyMember], requested_room='', party_key='', expected_party=''):
        """Internal primitive; caller must authorize and freeze the party first."""
        party_id = str(uuid.UUID(party_id))
        if len(members) != 2 or len({member.uid for member in members}) != 2:
            raise ValueError('A duo reservation needs two distinct members')
        group_id = str(uuid.uuid4())
        tickets = {str(member.uid): secrets.token_urlsafe(32) for member in members}
        encoded = [
            dict(member.model_dump(mode='json'), ticket=tickets[str(member.uid)], digest=hashlib.sha256(tickets[str(member.uid)].encode()).hexdigest())
            for member in members
        ]
        result = self.cache.eval(ALLOCATE, 0, self.prefix, '', '', str(BUILD['protocol']),
                                 BUILD['content_revision'], requested_room, '', '0', 'duo',
                                 json.dumps(encoded), party_id, group_id, party_key, expected_party)
        if result[0] == 'existing':
            saved = json.loads(result[1])
            return {key: saved[key] for key in ('party_id', 'group_id', 'admissions')}
        if result[0] == 'party_changed':
            raise HTTPException(409, 'Party changed or is expiring; refresh and retry')
        if result[0] == 'busy':
            raise HTTPException(409, 'A party member is already connected or reserved')
        if result[0] != 'ok':
            raise HTTPException(503, 'No room has space for the entire party')
        room = json.loads(result[1])
        admissions = {
            uid: {'ticket': ticket, 'room_id': room['room_id'], 'instance_id': room['instance_id'],
                  'generation': room['generation'], 'host': room['host'], 'port': room['port'],
                  'expires_in': 45, 'build': BUILD, 'mode': 'duo', 'party_id': party_id, 'group_id': group_id}
            for uid, ticket in tickets.items()
        }
        return {'party_id': party_id, 'group_id': group_id, 'admissions': admissions}

    def consume(self, body: RoomTicket):
        digest = hashlib.sha256(body.ticket.encode()).hexdigest()
        result = self.cache.eval(CONSUME, 0, self.prefix, digest, body.room_id, str(body.instance_id),
                                 str(body.generation), str(BUILD['protocol']), BUILD['content_revision'], body.mode)
        if result[0] == 'expired':
            raise HTTPException(401, 'Invalid or expired room ticket')
        if result[0] != 'ok':
            raise HTTPException(409, 'Ticket room binding or room availability changed')
        ticket = json.loads(result[1])
        ticket.setdefault('mode', 'solo')
        return ticket

    def cancel(self, uid: str, ticket: str):
        digest = hashlib.sha256(ticket.encode()).hexdigest()
        result = self.cache.eval(CANCEL, 0, self.prefix, digest, uid)
        if result == 'owner':
            raise HTTPException(403, 'Reservation belongs to another account')
        return {'status': result}
