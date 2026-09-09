from datetime import datetime, timezone
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = 'users'
    __table_args__ = (CheckConstraint('matches >= 0 AND wins >= 0 AND kills >= 0 AND wins <= matches', name='ck_users_stats'),)
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
    __table_args__ = (UniqueConstraint('match_id', 'user_id'), CheckConstraint('kills >= 0 AND rank >= 1 AND rank <= 64', name='ck_results_values'), Index('ix_results_user_id', 'user_id'))
    id: Mapped[int] = mapped_column(primary_key=True)
    match_id: Mapped[str] = mapped_column(ForeignKey('matches.id'))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    kills: Mapped[int] = mapped_column(Integer)
    rank: Mapped[int] = mapped_column(Integer)


