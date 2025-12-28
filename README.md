# HandmadeFactory Flutter Web + FastAPI + Postgres (Docker, prod)

## Start
```bash
cp .env.example .env
docker compose up -d --build
```

- App: http://localhost:8080
- API: http://localhost:8080/api/health

## Default admin
From `.env`:
- FIRST_ADMIN_EMAIL
- FIRST_ADMIN_PASSWORD

## Notes
- Nginx serves Flutter Web static files and proxies `/api/*` to backend.
- Backend uses JWT + RBAC + audit log.
- Password hashing: Argon2 (no bcrypt 72-byte limit).
