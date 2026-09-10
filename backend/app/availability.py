"""Translate dependency outages without exposing connection strings or query data."""
import logging
from fastapi import Request
from fastapi.responses import JSONResponse

logger = logging.getLogger('iron.availability')


def dependency_unavailable(request: Request, error: Exception):
    # Exception strings may contain credentials, SQL parameters or hostnames.
    logger.warning('dependency_unavailable category=%s', type(error).__name__)
    return JSONResponse(status_code=503, content={
        'detail': 'Online services are temporarily unavailable. Please try again shortly.',
    }, headers={'Retry-After': '3', 'Cache-Control': 'no-store'})
