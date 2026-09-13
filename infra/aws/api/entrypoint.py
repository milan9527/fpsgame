"""ECS runtime configuration for the verified API, without public documentation UI."""
import os
import subprocess
from urllib.parse import quote


def configure():
    os.environ["DATABASE_URL"] = (
        "postgresql+psycopg://ironapp:" + quote(os.environ["DB_PASSWORD"], safe="")
        + "@" + os.environ["DB_HOST"] + ":5432/iron?sslmode=require")
    os.environ["REDIS_URL"] = (
        "rediss://:" + quote(os.environ["CACHE_PASSWORD"], safe="")
        + "@" + os.environ["CACHE_HOST"] + ":6379/0")


if __name__ == "__main__":
    configure()
    subprocess.run(["python", "-m", "app.migrate"], check=True)
    from app.main import app
    # Remove HTML documentation and its OAuth redirect route as well as the schema.
    hidden = {"/docs", "/redoc", "/openapi.json", "/docs/oauth2-redirect"}
    app.router.routes[:] = [route for route in app.router.routes if route.path not in hidden]
    app.docs_url = app.redoc_url = app.openapi_url = None
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, proxy_headers=True, forwarded_allow_ips="*")
