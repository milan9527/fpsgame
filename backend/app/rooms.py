"""Atomic room directory and admission leases for one Redis deployment."""
import hashlib
import json
import secrets
import uuid
from typing import Literal

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
    players: list[uuid.UUID] = Field(default_factory=list, max_length=16)

    @model_validator(mode='after')
    def valid_players(self):
        if len(self.players) != len(set(self.players)) or len(self.players) > self.capacity:
            raise ValueError('Players must be unique and fit room capacity')
        return self


class RoomJoin(BuildInfo):
    room_id: str = Field(default='', max_length=64, pattern=r'^[a-zA-Z0-9_-]*$')


class RoomTicket(BuildInfo):
    room_id: str = Field(min_length=1, max_length=64, pattern=r'^[a-zA-Z0-9_-]+$')
    instance_id: uuid.UUID
    generation: uuid.UUID
    ticket: str = Field(min_length=20, max_length=128)


class CancelRoomTicket(BaseModel):
    ticket: str = Field(min_length=20, max_length=128)


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
for _,uid in ipairs(room.players) do
    redis.call('SET',p..'user:'..uid,owner,'EX',15)
    redis.call('ZREM',held,uid)
end
redis.call('SET',key,ARGV[2],'EX',12)
redis.call('SADD',p..'directory',room.room_id)
return 'ok'
"""

ALLOCATE = """
local p=ARGV[1]; local uid=ARGV[2]
if redis.call('EXISTS',p..'user:'..uid)==1 then return {'busy'} end
local t=redis.call('TIME'); local now=tonumber(t[1])+tonumber(t[2])/1000000
local ids=redis.call('SMEMBERS',p..'directory'); table.sort(ids)
for _,id in ipairs(ids) do
    local raw=redis.call('GET',p..'room:'..id)
    if not raw then redis.call('SREM',p..'directory',id)
    elseif ARGV[6]=='' or ARGV[6]==id then
        local room=cjson.decode(raw)
        if (room.phase=='waiting' or room.phase=='lobby') and tostring(room.protocol)==ARGV[4] and room.content_revision==ARGV[5] then
            local held=p..'held:'..id
            redis.call('ZREMRANGEBYSCORE',held,'-inf',now)
            if #room.players+redis.call('ZCARD',held)<room.capacity then
                local owner=id..'/'..room.instance_id..'/'..room.generation
                local ticket={uid=uid,username=ARGV[3],room_id=id,instance_id=room.instance_id,generation=room.generation,protocol=room.protocol,content_revision=room.content_revision}
                redis.call('SET',p..'ticket:'..ARGV[7],cjson.encode(ticket),'EX',45)
                redis.call('SET',p..'user:'..uid,owner,'EX',45)
                redis.call('ZADD',held,now+45,uid)
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
local owner=ticket.room_id..'/'..ticket.instance_id..'/'..ticket.generation
-- An old generation must never release a newer reservation for the same user.
if redis.call('GET',p..'user:'..ticket.uid)==owner then
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

    def allocate(self, uid: str, username: str, requested_room=''):
        ticket = secrets.token_urlsafe(32)
        digest = hashlib.sha256(ticket.encode()).hexdigest()
        result = self.cache.eval(ALLOCATE, 0, self.prefix, uid, username,
                                 str(BUILD['protocol']), BUILD['content_revision'], requested_room, digest)
        if result[0] == 'busy':
            raise HTTPException(409, 'Already connected or holding a room reservation')
        if result[0] != 'ok':
            raise HTTPException(503, 'No available room; retry shortly')
        room = json.loads(result[1])
        return {'ticket': ticket, 'room_id': room['room_id'], 'instance_id': room['instance_id'],
                'generation': room['generation'], 'host': room['host'], 'port': room['port'],
                'expires_in': 45, 'build': BUILD}

    def consume(self, body: RoomTicket):
        digest = hashlib.sha256(body.ticket.encode()).hexdigest()
        result = self.cache.eval(CONSUME, 0, self.prefix, digest, body.room_id, str(body.instance_id),
                                 str(body.generation), str(BUILD['protocol']), BUILD['content_revision'])
        if result[0] == 'expired':
            raise HTTPException(401, 'Invalid or expired room ticket')
        if result[0] != 'ok':
            raise HTTPException(409, 'Ticket room binding or room availability changed')
        return json.loads(result[1])

    def cancel(self, uid: str, ticket: str):
        digest = hashlib.sha256(ticket.encode()).hexdigest()
        result = self.cache.eval(CANCEL, 0, self.prefix, digest, uid)
        if result == 'owner':
            raise HTTPException(403, 'Reservation belongs to another account')
        return {'status': result}
