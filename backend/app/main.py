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
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

DATABASE_URL = os.environ['DATABASE_URL']
JWT_SECRET = os.environ['JWT_SECRET']
SERVER_SECRET = os.environ['SERVER_SECRET']
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
cache = redis.Redis.from_url(os.environ['REDIS_URL'], decode_responses=True)
passwords = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)
# One real verification for unknown accounts keeps timing comparable.
DUMMY_HASH = passwords.hash(secrets.token_urlsafe(32))


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = 'users'
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    username: Mapped[str] = mapped_column(String(24), unique=True, index=True)
    password: Mapped[str] = mapped_column(String(256))
    created: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    matches: Mapped[int] = mapped_column(Integer, default=0)
    wins: Mapped[int] = mapped_column(Integer, default=0)
    kills: Mapped[int] = mapped_column(Integer, default=0)


class Match(Base):
    __tablename__ = 'matches'
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Result(Base):
    __tablename__ = 'results'
    __table_args__ = (UniqueConstraint('match_id', 'user_id'),)
    id: Mapped[int] = mapped_column(primary_key=True)
    match_id: Mapped[str] = mapped_column(ForeignKey('matches.id'))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    kills: Mapped[int] = mapped_column(Integer)
    rank: Mapped[int] = mapped_column(Integer)


app = FastAPI(title='Iron Meridian Services', version='0.1.0')
auth = HTTPBearer()


def db():
    with Session(engine) as session:
        yield session


def limit(key: str, maximum: int, seconds: int):
    # Atomic counter + expiry; failed requests count too.
    count = cache.eval("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n", 1, key, seconds)
    if count > maximum:
        raise HTTPException(429, 'Too many requests; try later')


def user_token(credentials: HTTPAuthorizationCredentials = Depends(auth)):
    try:
        data = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=['HS256'], audience='iron-meridian', options={'require': ['exp', 'sub', 'aud']})
        return str(uuid.UUID(data['sub']))
    except (jwt.PyJWTError, ValueError, KeyError):
        raise HTTPException(401, 'Session expired; sign in again')


def server_auth(x_server_key: str = Header(default='')):
    if not secrets.compare_digest(x_server_key, SERVER_SECRET):
        raise HTTPException(403, 'Dedicated server credentials required')


class Credentials(BaseModel):
    username: str = Field(min_length=3, max_length=24, pattern=r'^[A-Za-z0-9_]+$')
    password: str = Field(min_length=10, max_length=128)


def token(user: User):
    return {'token': jwt.encode({'sub': user.id, 'aud': 'iron-meridian', 'exp': datetime.now(timezone.utc) + timedelta(hours=12)}, JWT_SECRET, algorithm='HS256'), 'username': user.username, 'user_id': user.id}


@app.get('/health')
def health(session: Session = Depends(db)):
    session.execute(text('SELECT 1'))
    cache.ping()
    return {'status': 'ok', 'protocol': 1}


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


@app.post('/matchmaking/join')
def join(uid: str = Depends(user_token), session: Session = Depends(db)):
    limit('join:' + uid, 10, 60)
    user = session.get(User, uid)
    if not user:
        raise HTTPException(404, 'Account not found')
    ticket = secrets.token_urlsafe(32)
    cache.hset('ticket:' + hashlib.sha256(ticket.encode()).hexdigest(), mapping={'uid': uid, 'username': user.username})
    cache.expire('ticket:' + hashlib.sha256(ticket.encode()).hexdigest(), 45)
    return {'ticket': ticket, 'host': os.getenv('GAME_PUBLIC_HOST', '127.0.0.1'), 'port': int(os.getenv('GAME_PORT', '27015')), 'expires_in': 45}


class Ticket(BaseModel):
    ticket: str = Field(min_length=20, max_length=128)


@app.post('/internal/tickets/consume', dependencies=[Depends(server_auth)])
def consume(body: Ticket):
    key = 'ticket:' + hashlib.sha256(body.ticket.encode()).hexdigest()
    data = cache.eval("local v=redis.call('HGETALL',KEYS[1]); redis.call('DEL',KEYS[1]); return v", 1, key)
    if not data:
        raise HTTPException(401, 'Invalid or expired ticket')
    return dict(zip(data[::2], data[1::2]))


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
