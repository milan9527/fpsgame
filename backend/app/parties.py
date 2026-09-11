"""Short-lived, authenticated duo invitations with atomic Redis membership."""
import hashlib
import json
import secrets
import uuid
from fastapi import HTTPException
from pydantic import BaseModel, Field


class AcceptInvitation(BaseModel):
    invitation: str = Field(min_length=32, max_length=64, pattern=r'^[A-Za-z0-9_-]+$')


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
local function disband(p)
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
        if not raw.startswith('{'):
            raise RuntimeError('Invalid party operation response')
        party = json.loads(raw)
        if party:
            party.pop('invite_hash', None)
            if party['leader'] != uid or len(party['members']) != 1:
                party.pop('invitation', None)
            party['expires_in_ms'] = max(0, self.cache.pttl(self.prefix + 'party:' + party['id']))
            for member in party['members']:
                member.pop('version', None)
        return party

    def create(self, uid, username, version=0):
        invitation = secrets.token_urlsafe(32)
        party = {'id': str(uuid.uuid4()), 'mode': 'duo', 'leader': uid,
                 'invitation': invitation, 'invite_hash': hashlib.sha256(invitation.encode()).hexdigest(),
                 'members': [{'uid': uid, 'username': username, 'version': version}]}
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

    def leave(self, uid):
        return self.execute('leave', uid)

    def revoke(self, uid, minimum_version):
        return self.execute('revoke', uid, minimum_version)
