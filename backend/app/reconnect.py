"""Redis-only reconnect admission primitives, separate from fresh room admission."""

CHECK = """
local function eligible(p,uid,version,id,instance,generation,mode,protocol,content)
    local raw=redis.call('GET',p..'room:'..id)
    local saved=redis.call('GET',p..'reconnect:'..id)
    if not raw or not saved then return nil end
    local room=cjson.decode(raw)
    local retention=cjson.decode(saved)
    if room.phase~='live' or room.instance_id~=instance or room.generation~=generation then return nil end
    if room.mode~=mode or tostring(room.protocol)~=protocol or room.content_revision~=content then return nil end
    if retention.instance_id~=instance or retention.generation~=generation then return nil end
    if not (room.reconnectable or {})[uid] then return nil end
    if tonumber((room.session_versions or {})[uid])~=tonumber(version) then return nil end
    local present=false
    for _,player in ipairs(room.players) do if player==uid then present=true end end
    if not present then return nil end
    local owner=id..'/'..instance..'/'..generation
    if redis.call('GET',p..'user:'..uid)~=owner then return nil end
    if tonumber(redis.call('GET',p..'user_version:'..uid))~=tonumber(version) then return nil end
    local clock=redis.call('TIME')
    local now=tonumber(clock[1])*1000+math.floor(tonumber(clock[2])/1000)
    local deadline=tonumber(retention.deadlines[uid] or 0)
    if deadline<=now then return nil end
    local epoch=(retention.epochs or {})[uid]
    if not epoch then return nil end
    return room,deadline,now,epoch
end
"""

ISSUE = CHECK + """
local p=ARGV[1]; local uid=ARGV[2]; local version=ARGV[3]
local room,deadline,now,epoch=eligible(p,uid,version,ARGV[4],ARGV[5],ARGV[6],ARGV[7],ARGV[8],ARGV[9])
if not room then return {'unavailable'} end
local claim=p..'reconnect_claim:'..room.instance_id..'/'..room.generation..'/'..uid..'/'..epoch
if redis.call('EXISTS',claim)==1 then return {'claimed'} end
local ttl=math.min(10000,deadline-now)
local ticket={uid=uid,username=ARGV[10],session_version=tonumber(version),room_id=room.room_id,
    instance_id=room.instance_id,generation=room.generation,mode=room.mode,
    protocol=room.protocol,content_revision=room.content_revision,kind='reconnect',epoch=epoch}
redis.call('SET',p..'reconnect_ticket:'..ARGV[11],cjson.encode(ticket),'PX',ttl)
return {'ok',cjson.encode(room),tostring(ttl)}
"""

CONSUME = CHECK + """
local p=ARGV[1]; local key=p..'reconnect_ticket:'..ARGV[2]
local raw=redis.call('GET',key)
if not raw then return {'expired'} end
local ticket=cjson.decode(raw)
if ticket.room_id~=ARGV[3] or ticket.instance_id~=ARGV[4] or ticket.generation~=ARGV[5] then return {'binding'} end
if ticket.mode~=ARGV[6] or tostring(ticket.protocol)~=ARGV[7] or ticket.content_revision~=ARGV[8] then return {'binding'} end
local room,deadline,now,epoch=eligible(p,ticket.uid,ticket.session_version,ticket.room_id,
    ticket.instance_id,ticket.generation,ticket.mode,ARGV[7],ARGV[8])
if not room then return {'unavailable'} end
if ticket.epoch~=epoch then return {'binding'} end
local claim=p..'reconnect_claim:'..room.instance_id..'/'..room.generation..'/'..ticket.uid..'/'..epoch
if not redis.call('SET',claim,'consumed','NX','PX',deadline-now) then return {'claimed'} end
redis.call('DEL',key)
return {'ok',raw}
"""
