"""Public validation errors contain guidance, never submitted values or context."""
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


def validation_error(request: Request, error: RequestValidationError):
    issues = []
    for item in error.errors()[:20]:
        location = item.get('loc', ())
        field = location[1] if len(location) > 1 and isinstance(location[1], str) else 'request'
        # These names are schema fields, not arbitrary keys supplied in a body.
        if field not in {'username', 'password', 'room_id', 'instance_id', 'generation', 'revision',
                         'host', 'port', 'capacity', 'phase', 'players', 'ticket', 'match_id',
                         'protocol', 'content_revision', 'client_version'}:
            field = 'request'
        if field == 'username':
            message = 'Username must contain 3–24 letters, digits or underscores.'
        elif field == 'password':
            message = 'Password must contain 10–128 characters.'
        elif item.get('type') == 'json_invalid':
            message = 'Request body must contain valid JSON.'
        else:
            message = 'Invalid or missing ' + field.replace('_', ' ') + '.'
        issue = {'field': field, 'message': message}
        if issue not in issues:
            issues.append(issue)
    return JSONResponse(status_code=422, content={
        'detail': issues[0]['message'] if issues else 'Invalid request.', 'errors': issues,
    }, headers={'Cache-Control': 'no-store'})
