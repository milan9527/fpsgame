"""Short-lived, authenticated duo invitations with atomic Redis membership."""
import hashlib
import json
import secrets
import uuid
from fastapi import HTTPException
from pydantic import BaseModel, Field, StrictBool
from .protocol import BuildInfo


class AcceptInvitation(BaseModel):
    invitation: str = Field(min_length=32, max_length=64, pattern=r'^[A-Za-z0-9_-]+$')

class ReserveParty(BuildInfo):
    room_id: str = Field(default='', max_length=64, pattern=r'^[a-zA-Z0-9_-]*$')

class PartyReady(BaseModel):
    ready: StrictBool

class ResetParty(BuildInfo):
    group_id: uuid.UUID


SCRIPT = """
local prefix, op, uid = ARGV[1], ARGV[2], ARGV[3]
local index = prefix .. 'user:' .. uid
local current = redis.call('GET', index)
local function read(id)
  if not id then return nil end
  local raw = redis.call('GET', prefix .. 'party:' .. id)
  if raw then return cjson.decode(raw) end
  return nil
end
local function cancel_reservation(p)
  if p.reservation then
    local reservation=p.reservation
    local rp=reservation.room_prefix
    for _,member in ipairs(reservation.members) do
      local key=rp..'ticket:'..member.digest
      local raw=redis.call('GET',key)
      if raw then
        local ticket=cjson.decode(raw)
        if ticket.group_id==reservation.group_id then
          local owner=ticket.room_id..'/'..ticket.instance_id..'/'..ticket.generation
          if redis.call('GET',rp..'user:'..ticket.uid)==owner and tonumber(redis.call('GET',rp..'user_version:'..ticket.uid) or '0')==tonumber(ticket.session_version) then
            redis.call('ZREM',rp..'held:'..ticket.room_id,ticket.uid)
            redis.call('DEL',rp..'user:'..ticket.uid,rp..'user_version:'..ticket.uid)
          end
          redis.call('DEL',key)
        end
      end
    end
    redis.call('DEL',rp..'group:'..reservation.group_id)
  end
end
local function disband(p)
  cancel_reservation(p)
  for _, m in ipairs(p.members) do
    local key = prefix .. 'user:' .. m.uid
    if redis.call('GET', key) == p.id then redis.call('DEL', key) end
  end
  redis.call('DEL', prefix .. 'invite:' .. p.invite_hash, prefix .. 'party:' .. p.id)
end
local p = read(current)
if current and not p then redis.call('DEL', index) end
if op == 'get' then return p and cjson.encode(p) or '{}' end
if op == 'revoke' then
  if p then
    for _, m in ipairs(p.members) do
      if m.uid == uid and m.version < tonumber(ARGV[4]) then disband(p); break end
    end
  end
  return '{}'
end
if op == 'leave' then
  if p then disband(p) end
  return '{}'
end
if op == 'ready' then
  if not p then return 'no_party' end
  if p.reservation then return 'already_reserved' end
  for _, m in ipairs(p.members) do
    if m.uid == uid then m.ready = ARGV[4] == 'true' end
  end
  redis.call('SET', prefix .. 'party:' .. p.id, cjson.encode(p), 'KEEPTTL')
  return cjson.encode(p)
end
if op == 'reset' then
  if not p then return 'no_party' end
  if p.leader~=uid then return 'leader_only' end
  if not p.reservation then return cjson.encode(p) end
  local r=p.reservation
  if r.group_id~=ARGV[4] then return 'reservation_changed' end
  for _,m in ipairs(r.members) do
    local owner=redis.call('GET',r.room_prefix..'user:'..m.uid)
    if owner then
      local raw=redis.call('GET',r.room_prefix..'ticket:'..m.digest)
      if not raw then return 'members_busy' end
      local ticket=cjson.decode(raw)
      local expected=ticket.room_id..'/'..ticket.instance_id..'/'..ticket.generation
      local version=tonumber(redis.call('GET',r.room_prefix..'user_version:'..m.uid) or '-1')
      if owner~=expected or ticket.group_id~=r.group_id or version~=tonumber(m.session_version) then return 'members_busy' end
    end
  end
  cancel_reservation(p)
  p.reservation=nil
  for _,m in ipairs(p.members) do m.ready=false end
  redis.call('SET',prefix..'party:'..p.id,cjson.encode(p),'KEEPTTL')
  return cjson.encode(p)
end
if p then return 'already_in_party' end
if op == 'create' then
  p = cjson.decode(ARGV[4])
  local ttl = tonumber(ARGV[5])
  redis.call('SET', prefix .. 'party:' .. p.id, cjson.encode(p), 'PX', ttl)
  redis.call('SET', prefix .. 'invite:' .. p.invite_hash, p.id, 'PX', ttl)
  redis.call('SET', index, p.id, 'PX', ttl)
  return cjson.encode(p)
end
if op == 'accept' then
  local id = redis.call('GET', prefix .. 'invite:' .. ARGV[4])
  p = read(id)
  if not p or #p.members ~= 1 then return 'invalid_invitation' end
  local ttl = redis.call('PTTL', prefix .. 'party:' .. id)
  if ttl <= 0 then return 'invalid_invitation' end
  table.insert(p.members, cjson.decode(ARGV[5]))
  for _, m in ipairs(p.members) do m.ready = false end
  redis.call('SET', prefix .. 'party:' .. id, cjson.encode(p), 'PX', ttl)
  redis.call('SET', index, id, 'PX', ttl)
  redis.call('DEL', prefix .. 'invite:' .. p.invite_hash)
  return cjson.encode(p)
end
return 'invalid_operation'
"""


class PartyDirectory:
    def __init__(self, cache, prefix='parties:v1:', ttl_ms=900_000):
        self.cache = cache
        self.prefix = prefix
        self.ttl_ms = ttl_ms
        self.script = cache.register_script(SCRIPT)

    def execute(self, operation, uid, first='', second=''):
        raw = self.script(args=[self.prefix, operation, uid, first, second])
        if raw == 'already_in_party':
            raise HTTPException(409, 'Leave your current party first')
        if raw == 'invalid_invitation':
            raise HTTPException(404, 'Invitation expired or unavailable')
        if raw == 'no_party':
            raise HTTPException(404, 'No current party')
        if raw == 'already_reserved':
            raise HTTPException(409, 'Party already reserved; leave to cancel')
        if raw == 'leader_only':
            raise HTTPException(403, 'Only the party leader can reset matchmaking')
        if raw == 'reservation_changed':
            raise HTTPException(409, 'Reservation changed; refresh your party')
        if raw == 'members_busy':
            raise HTTPException(409, 'Both members must leave their operation before resetting')
        if not raw.startswith('{'):
            raise RuntimeError('Invalid party operation response')
        party = json.loads(raw)
        if party:
            reservation = party.pop('reservation', None)
            party['status'] = 'reserved' if reservation else 'forming'
            if reservation:
                party['reservation_id'] = reservation['group_id']
                admission = reservation['admissions'].get(uid)
                digest = hashlib.sha256(admission['ticket'].encode()).hexdigest() if admission else ''
                remaining = self.cache.ttl(reservation['room_prefix'] + 'ticket:' + digest)
                if admission and remaining > 0:
                    admission['expires_in'] = remaining
                    party['admission'] = admission
                else:
                    party['admission_status'] = 'consumed_or_expired'
            party.pop('invite_hash', None)
            if party['leader'] != uid or len(party['members']) != 1:
                party.pop('invitation', None)
            party['expires_in_ms'] = max(0, self.cache.pttl(self.prefix + 'party:' + party['id']))
            for member in party['members']:
                member.pop('version', None)
                member.setdefault('ready', False)
        return party

    def create(self, uid, username, version=0):
        invitation = secrets.token_urlsafe(32)
        party = {'id': str(uuid.uuid4()), 'mode': 'duo', 'leader': uid,
                 'invitation': invitation, 'invite_hash': hashlib.sha256(invitation.encode()).hexdigest(),
                 'members': [{'uid': uid, 'username': username, 'version': version, 'ready': False}]}
        return self.execute('create', uid, json.dumps(party), self.ttl_ms)

    def accept(self, uid, username, invitation, version=0):
        return self.execute('accept', uid, hashlib.sha256(invitation.encode()).hexdigest(),
                            json.dumps({'uid': uid, 'username': username, 'version': version}))

    def invitation_members(self, invitation):
        digest = hashlib.sha256(invitation.encode()).hexdigest()
        identity = self.cache.get(self.prefix + 'invite:' + digest)
        raw = self.cache.get(self.prefix + 'party:' + identity) if identity else None
        if not raw:
            raise HTTPException(404, 'Invitation expired or unavailable')
        return json.loads(raw)['members']

    def get(self, uid):
        return self.execute('get', uid)

    def ready(self, uid, ready):
        return self.execute('ready', uid, 'true' if ready else 'false')

    def reset(self, uid, group_id):
        return self.execute('reset', uid, str(group_id))

    def snapshot(self, uid):
        identity = self.cache.get(self.prefix + 'user:' + uid)
        key = self.prefix + 'party:' + identity if identity else ''
        raw = self.cache.get(key) if key else None
        if not raw:
            raise HTTPException(404, 'No current party')
        return key, raw, json.loads(raw)

    def leave(self, uid):
        return self.execute('leave', uid)

    def revoke(self, uid, minimum_version):
        return self.execute('revoke', uid, minimum_version)
