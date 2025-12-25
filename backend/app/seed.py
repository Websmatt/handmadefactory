from sqlalchemy.orm import Session
from .db import SessionLocal
from . import models
from .security import hash_password
from .config import settings

DEFAULT_ROLES = ["admin", "editor", "viewer"]

def ensure_roles(db: Session):
    existing = {r.name for r in db.query(models.Role).all()}
    for name in DEFAULT_ROLES:
        if name not in existing:
            db.add(models.Role(name=name))
    db.commit()

def ensure_admin(db: Session):
    ensure_roles(db)
    admin = db.query(models.User).filter(models.User.email == settings.first_admin_email).first()
    if admin:
        return
    roles = db.query(models.Role).filter(models.Role.name.in_(["admin"])).all()
    admin = models.User(
        email=settings.first_admin_email,
        full_name=settings.first_admin_full_name,
        password_hash=hash_password(settings.first_admin_password),
        is_active=True,
    )
    admin.roles = roles
    db.add(admin)
    db.commit()

def main():
    db = SessionLocal()
    try:
        ensure_roles(db)
        ensure_admin(db)
    finally:
        db.close()

if __name__ == "__main__":
    main()
