"""One build manifest shared with the packaged Godot project."""
import json
from pathlib import Path
from fastapi import HTTPException
from pydantic import BaseModel, Field

path = Path(__file__).with_name('protocol.json')
if not path.exists():
    path = Path(__file__).resolve().parents[2] / 'client' / 'protocol.json'
BUILD = json.loads(path.read_text())


class BuildInfo(BaseModel):
    protocol: int | None = Field(default=None, strict=True, ge=1)
    content_revision: str | None = Field(default=None, min_length=1, max_length=64)
    client_version: str = Field(default='', max_length=64)


def require_compatible(build: BuildInfo):
    if build.protocol != BUILD['protocol'] or build.content_revision != BUILD['content_revision']:
        raise HTTPException(409, {'message': 'Client/server build mismatch; update the game', 'required': BUILD})
