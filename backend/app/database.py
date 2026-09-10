import os
from sqlalchemy import create_engine

engine = create_engine(os.environ['DATABASE_URL'], pool_pre_ping=True, pool_timeout=3, connect_args={"connect_timeout": 3})
