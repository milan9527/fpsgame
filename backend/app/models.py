from datetime import datetime, timezone
from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = 'users'
    __table_args__ = (CheckConstraint('matches >= 0 AND wins >= 0 AND kills >= 0 AND wins <= matches', name='ck_users_stats'),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    username: Mapped[str] = mapped_column(String(24), unique=True, index=True)
    session_version: Mapped[int] = mapped_column(BigInteger, default=0, server_default=text('0'))
    password: Mapped[str] = mapped_column(String(256))
    created: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    matches: Mapped[int] = mapped_column(Integer, default=0)
    wins: Mapped[int] = mapped_column(Integer, default=0)
    kills: Mapped[int] = mapped_column(Integer, default=0)


class Match(Base):
    __tablename__ = 'matches'
    __table_args__ = (CheckConstraint("mode IN ('solo', 'duo')", name='ck_matches_mode'),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    mode: Mapped[str] = mapped_column(String(8), default='solo', server_default=text("'solo'"))
    created: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Result(Base):
    __tablename__ = 'results'
    __table_args__ = (UniqueConstraint('match_id', 'user_id'), CheckConstraint('kills >= 0 AND rank >= 1 AND rank <= 64', name='ck_results_values'), CheckConstraint('team_id >= 0 AND team_id <= 32', name='ck_results_team'), Index('ix_results_user_id', 'user_id'))
    id: Mapped[int] = mapped_column(primary_key=True)
    match_id: Mapped[str] = mapped_column(ForeignKey('matches.id'))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    kills: Mapped[int] = mapped_column(Integer)
    rank: Mapped[int] = mapped_column(Integer)
    team_id: Mapped[int] = mapped_column(Integer, default=0, server_default=text('0'))

