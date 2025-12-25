from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from .db import get_db
from . import models
from .security import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> models.User:
    try:
        payload = decode_token(token)
        email = payload.get("sub")
        if not email:
            raise ValueError("No subject")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive or missing user")
    return user

def require_roles(*required: str):
    def _check(user: models.User = Depends(get_current_user)) -> models.User:
        user_roles = {r.name for r in user.roles}
        if not user_roles.intersection(required):
            raise HTTPException(status_code=403, detail="Forbidden")
        return user
    return _check
