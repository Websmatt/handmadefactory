from fastapi import Request
from sqlalchemy.orm import Session
from . import models

MUTATING = {"POST", "PUT", "PATCH", "DELETE"}

async def write_audit_log(request: Request, status_code: int, db: Session, user_id: int | None):
    if request.method not in MUTATING:
        return
    path = request.url.path
    if not path.startswith("/api/"):
        return
    ip = request.headers.get("x-forwarded-for", request.client.host if request.client else None)
    db.add(models.AuditLog(
        user_id=user_id,
        method=request.method,
        path=path,
        status_code=status_code,
        ip=ip[:64] if ip else None,
    ))
    db.commit()
