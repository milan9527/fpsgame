"""Iron Meridian account, matchmaking, and authoritative results service."""
import hashlib
import os
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import jwt
import redis
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError, InvalidHashError
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from .validation import validation_error
from .availability import dependency_unavailable
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import select, text, update
from sqlalchemy.exc import IntegrityError, OperationalError, TimeoutError as DatabaseTimeout
from sqlalchemy.orm import Session
from .models import User, Match, Result
from .database import engine
from .protocol import BUILD, BuildInfo, require_compatible
from .rooms import CancelRoomTicket, RoomDirectory, RoomHeartbeat, RoomJoin, RoomTicket

JWT_SECRET = os.environ['JWT_SECRET']
SERVER_SECRET = os.environ['SERVER_SECRET']
cache = redis.Redis.from_url(os.environ['REDIS_URL'], decode_responses=True, socket_connect_timeout=2, socket_timeout=2, retry_on_timeout=False)
rooms = RoomDirectory(cache)
passwords = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)
# One real verification for unknown accounts keeps timing comparable.
DUMMY_HASH = passwords.hash(secrets.token_urlsafe(32))


app = FastAPI(title='Iron Meridian Services', version='0.1.0')
app.add_exception_handler(RequestValidationError, validation_error)
for dependency_error in (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError, OperationalError, DatabaseTimeout):
    app.add_exception_handler(dependency_error, dependency_unavailable)
auth = HTTPBearer()


def db():
    with Session(engine) as session:
        yield session


def limit(key: str, maximum: int, seconds: int):
    # Atomic counter + expiry; failed requests count too.
    count = cache.eval("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n", 1, key, seconds)
    if count > maximum:
        raise HTTPException(429, 'Too many requests; try later')


def decode_session(credentials):
    try:
        data = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=['HS256'], audience='iron-meridian', options={'require': ['exp', 'sub', 'aud']})
        version = data.get('ver', 0)  # Pre-migration tokens belong to generation zero.
        if type(version) is not int or version < 0 or version > 9223372036854775806:
            raise ValueError('Invalid session generation')
        return str(uuid.UUID(data['sub'])), version
    except (jwt.PyJWTError, ValueError, KeyError, TypeError):
        raise HTTPException(401, 'Session expired; sign in again')


def user_token(request: Request, credentials: HTTPAuthorizationCredentials = Depends(auth), session: Session = Depends(db)):
    uid, version = decode_session(credentials)
    # A shared row lock serializes authenticated operations with logout, while
    # allowing ordinary requests to run concurrently with one another.
    user = session.scalar(select(User).where(User.id == uid).with_for_update(read=True))
    if user is None or user.session_version != version:
        raise HTTPException(401, 'Session expired; sign in again')
    request.state.session_version = version
    return uid


def validate_ticket_session(data, session):
    user = session.get(User, data['uid'])
    if user is None or user.session_version != int(data.get('session_version', 0)):
        raise HTTPException(401, 'Session expired; sign in again')
    return data


@app.post('/auth/logout-all')
def logout_all(credentials: HTTPAuthorizationCredentials = Depends(auth), session: Session = Depends(db)):
    uid, version = decode_session(credentials)
    # Conditional update avoids shared-lock upgrades and makes concurrent
    # requests with the same generation idempotently unauthorized after one wins.
    changed = session.scalar(update(User).where(User.id == uid, User.session_version == version)
                             .values(session_version=User.session_version + 1).returning(User.session_version))
    if changed is None:
        raise HTTPException(401, 'Session expired; sign in again')
    session.commit()
    rooms.revoke_reservation(uid, changed)
    return {'status': 'signed_out'}


def server_auth(x_server_key: str = Header(default='')):
    if not secrets.compare_digest(x_server_key, SERVER_SECRET):
        raise HTTPException(403, 'Dedicated server credentials required')


class Credentials(BaseModel):
    username: str = Field(min_length=3, max_length=24, pattern=r'^[A-Za-z0-9_]+$')
    password: str = Field(min_length=10, max_length=128)


def token(user: User):
    return {'token': jwt.encode({'sub': user.id, 'ver': user.session_version, 'aud': 'iron-meridian', 'exp': datetime.now(timezone.utc) + timedelta(hours=12)}, JWT_SECRET, algorithm='HS256'), 'username': user.username, 'user_id': user.id}


@app.get('/health')
def health(session: Session = Depends(db)):
    session.execute(text('SELECT 1'))
    cache.ping()
    return {'status': 'ok', 'protocol': BUILD['protocol'], 'schema_revision': session.scalar(text('SELECT version_num FROM alembic_version'))}


@app.post('/auth/register', status_code=201)
def register(body: Credentials, request: Request, session: Session = Depends(db)):
    limit('register:' + request.client.host, 20, 3600)
    user = User(id=str(uuid.uuid4()), username=body.username.lower(), password=passwords.hash(body.password))
    session.add(user)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, 'Username is already registered')
    return token(user)


@app.post('/auth/login')
def login(body: Credentials, request: Request, session: Session = Depends(db)):
    limit('login:' + request.client.host, 30, 60)
    user = session.scalar(select(User).where(User.username == body.username.lower()))
    try:
        passwords.verify(user.password if user else DUMMY_HASH, body.password)
    except (VerificationError, InvalidHashError):
        raise HTTPException(401, 'Invalid username or password')
    if not user:
        raise HTTPException(401, 'Invalid username or password')
    return token(user)


@app.get('/profile')
def profile(uid: str = Depends(user_token), session: Session = Depends(db)):
    user = session.get(User, uid)
    if not user:
        raise HTTPException(404, 'Account not found')
    return {'username': user.username, 'matches': user.matches, 'wins': user.wins, 'kills': user.kills}


@app.get('/leaderboard')
def leaderboard(session: Session = Depends(db)):
    return [{'username': u.username, 'wins': u.wins, 'kills': u.kills, 'matches': u.matches} for u in session.scalars(select(User).order_by(User.wins.desc(), User.kills.desc(), User.username).limit(50))]


@app.get('/protocol')
def protocol():
    return BUILD


@app.post('/internal/build/check', dependencies=[Depends(server_auth)])
def check_server_build(body: BuildInfo):
    require_compatible(body)
    return BUILD


@app.post('/matchmaking/join')
def join(body: BuildInfo, request: Request, uid: str = Depends(user_token), session: Session = Depends(db)):
    require_compatible(body)
    limit('join:' + uid, 10, 60)
    user = session.get(User, uid)
    if not user:
        raise HTTPException(404, 'Account not found')
    ticket = secrets.token_urlsafe(32)
    key = 'ticket:' + hashlib.sha256(ticket.encode()).hexdigest()
    with cache.pipeline(transaction=True) as pipeline:
        pipeline.hset(key, mapping={'uid': uid, 'username': user.username, 'protocol': str(BUILD['protocol']), 'content_revision': BUILD['content_revision'], 'session_version': request.state.session_version})
        pipeline.expire(key, 45)
        pipeline.execute()
    return {'ticket': ticket, 'host': os.getenv('GAME_PUBLIC_HOST', '127.0.0.1'), 'port': int(os.getenv('GAME_PORT', '27015')), 'expires_in': 45, 'build': BUILD}


class Ticket(BuildInfo):
    ticket: str = Field(min_length=20, max_length=128)


@app.post('/internal/rooms/heartbeat', dependencies=[Depends(server_auth)])
def room_heartbeat(body: RoomHeartbeat, session: Session = Depends(db)):
    require_compatible(body)
    versions = dict(session.execute(select(User.id, User.session_version).where(User.id.in_([str(uid) for uid in body.players]))).all()) if body.players else {}
    revoked = [uid for uid in body.players if versions.get(str(uid)) != body.session_versions.get(uid, 0)]
    filtered = body.model_copy(update={'players': [uid for uid in body.players if uid not in revoked]})
    result = rooms.heartbeat(filtered)
    result['revoked'] = [str(uid) for uid in revoked]
    return result


@app.post('/matchmaking/rooms/join')
def room_join(body: RoomJoin, request: Request, uid: str = Depends(user_token), session: Session = Depends(db)):
    require_compatible(body)
    limit('room-join:' + uid, 10, 60)
    user = session.get(User, uid)
    if not user:
        raise HTTPException(404, 'Account not found')
    return rooms.allocate(uid, user.username, body.room_id, request.state.session_version, body.mode)


@app.post('/internal/rooms/tickets/consume', dependencies=[Depends(server_auth)])
def room_consume(body: RoomTicket, session: Session = Depends(db)):
    require_compatible(body)
    return validate_ticket_session(rooms.consume(body), session)


@app.post('/matchmaking/rooms/cancel')
def room_cancel(body: CancelRoomTicket, uid: str = Depends(user_token)):
    limit('room-cancel:' + uid, 30, 60)
    return rooms.cancel(uid, body.ticket)


@app.post('/internal/tickets/consume', dependencies=[Depends(server_auth)])
def consume(body: Ticket, session: Session = Depends(db)):
    require_compatible(body)
    key = 'ticket:' + hashlib.sha256(body.ticket.encode()).hexdigest()
    data = cache.eval("""
        local v=redis.call('HGETALL',KEYS[1]);
        if #v==0 then return v end;
        if redis.call('HGET',KEYS[1],'protocol')~=ARGV[1] or redis.call('HGET',KEYS[1],'content_revision')~=ARGV[2] then
            return {'__error__', 'build_mismatch'};
        end;
        redis.call('DEL',KEYS[1]); return v;
    """, 1, key, str(BUILD['protocol']), BUILD['content_revision'])
    if not data:
        raise HTTPException(401, 'Invalid or expired ticket')
    result = dict(zip(data[::2], data[1::2]))
    if '__error__' in result:
        raise HTTPException(409, 'Ticket was issued for a different build')
    return validate_ticket_session(result, session)


class PlayerResult(BaseModel):
    user_id: uuid.UUID
    kills: int = Field(ge=0, le=100)
    rank: int = Field(ge=1, le=64)


class MatchResult(BaseModel):
    match_id: uuid.UUID
    players: list[PlayerResult] = Field(min_length=1, max_length=32)


@app.post('/internal/results', dependencies=[Depends(server_auth)])
def results(body: MatchResult, session: Session = Depends(db)):
    if len({p.user_id for p in body.players}) != len(body.players):
        raise HTTPException(422, 'Duplicate player')
    if len({p.rank for p in body.players}) != len(body.players):
        raise HTTPException(422, 'Duplicate rank')
    match_id = str(body.match_id)
    if session.get(Match, match_id):
        return {'status': 'already_recorded'}
    session.add(Match(id=match_id))
    try:
        session.flush()
        # Deterministic locking prevents lost updates and deadlocks across matches.
        for p in sorted(body.players, key=lambda p: str(p.user_id)):
            user = session.scalar(select(User).where(User.id == str(p.user_id)).with_for_update())
            if not user:
                raise HTTPException(422, 'Unknown player')
            user.matches += 1
            user.kills += p.kills
            user.wins += int(p.rank == 1)
            session.add(Result(match_id=match_id, user_id=user.id, kills=p.kills, rank=p.rank))
        session.commit()
    except IntegrityError:
        session.rollback()
        if session.get(Match, match_id):
            return {'status': 'already_recorded'}
        raise
    return {'status': 'recorded'}
