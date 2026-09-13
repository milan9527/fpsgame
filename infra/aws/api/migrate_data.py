"""One-off, atomic import into an empty database; never overwrites player records."""
import hashlib
import json
import os
import boto3
import psycopg
from psycopg import sql
from aws_entrypoint import configure


def fingerprint(rows):
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main():
    configure()
    s3 = boto3.client("s3", region_name=os.environ["AWS_REGION"])
    response = s3.get_object(Bucket=os.environ["DATA_SNAPSHOT_BUCKET"], Key=os.environ["DATA_SNAPSHOT_KEY"])
    with response["Body"] as stream:
        raw = stream.read()
    if hashlib.sha256(raw).hexdigest() != os.environ["DATA_SNAPSHOT_SHA256"]:
        raise ValueError("Snapshot checksum mismatch")
    snapshot = json.loads(raw)
    tables = {
        "users": ["id", "username", "session_version", "password", "created", "matches", "wins", "kills"],
        "matches": ["id", "mode", "created"],
        "results": ["id", "match_id", "user_id", "kills", "rank", "team_id"],
    }
    if set(snapshot) != set(tables):
        raise ValueError("Unexpected snapshot tables")
    # psycopg accepts a standard postgres URI; SQLAlchemy's driver suffix is not used here.
    uri = os.environ["DATABASE_URL"].replace("postgresql+psycopg://", "postgresql://", 1)
    with psycopg.connect(uri) as conn:
        with conn.cursor() as cursor:
            cursor.execute("LOCK TABLE users, matches, results IN ACCESS EXCLUSIVE MODE")
            for table in tables:
                cursor.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(table)))
                if cursor.fetchone()[0] != 0:
                    raise ValueError("Migration requires an empty destination database")
            for table, columns in tables.items():
                rows = snapshot[table]
                if any(set(row) != set(columns) for row in rows):
                    raise ValueError("Unexpected snapshot columns")
                statement = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
                    sql.Identifier(table), sql.SQL(",").join(map(sql.Identifier, columns)),
                    sql.SQL(",").join(sql.Placeholder() for _ in columns))
                cursor.executemany(statement, [[row[column] for column in columns] for row in rows])
            for table in tables:
                cursor.execute(sql.SQL(
                    "SELECT COALESCE(json_agg(t),'[]') FROM (SELECT * FROM {} ORDER BY id) t"
                ).format(sql.Identifier(table)))
                if fingerprint(cursor.fetchone()[0]) != fingerprint(snapshot[table]):
                    raise ValueError("Imported row fingerprint mismatch")
            cursor.execute(
                "SELECT setval(pg_get_serial_sequence('results','id'),"
                "COALESCE((SELECT max(id) FROM results),1),(SELECT count(*)>0 FROM results))")
    print("AWS_DATA_IMPORT_PASS " + json.dumps({table: len(snapshot[table]) for table in tables}), flush=True)


if __name__ == "__main__":
    main()
