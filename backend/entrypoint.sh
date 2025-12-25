#!/usr/bin/env sh
set -e

echo "Waiting for DB..."
python -c "import os,time; from sqlalchemy import create_engine,text; 
url=os.environ['DATABASE_URL']; 
for i in range(60):
    try:
        e=create_engine(url, pool_pre_ping=True)
        with e.connect() as c: c.execute(text('select 1'))
        print('DB OK'); break
    except Exception:
        time.sleep(1)
else:
    raise SystemExit('DB not reachable')"

echo "Running migrations..."
alembic upgrade head

echo "Seeding roles/admin (idempotent)..."
python -m app.seed

echo "Starting API..."
exec gunicorn -k uvicorn.workers.UvicornWorker app.main:app --bind 0.0.0.0:8000 --workers 2 --access-logfile - --error-logfile -
