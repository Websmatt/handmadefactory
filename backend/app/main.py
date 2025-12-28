from fastapi import FastAPI, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from .db import get_db
from . import models, schemas
from .security import verify_password, create_access_token
from .deps import get_current_user, require_roles
from .audit import write_audit_log

app = FastAPI(title="HandmadeFactory API")

@app.get("/api/health")
def health():
    return {"status": "ok"}

@app.post("/api/auth/login", response_model=schemas.Token)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token(subject=user.email)
    return schemas.Token(access_token=token)

@app.get("/api/auth/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    return schemas.UserOut(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        roles=[r.name for r in user.roles],
    )

@app.get("/api/items", response_model=list[schemas.ItemOut])
def list_items(db: Session = Depends(get_db), user: models.User = Depends(require_roles("admin","editor","viewer"))):
    items = db.query(models.Item).order_by(models.Item.id.desc()).all()
    return [schemas.ItemOut(id=i.id, name=i.name, description=i.description) for i in items]

@app.post("/api/items", response_model=schemas.ItemOut)
async def create_item(request: Request, payload: schemas.ItemIn, db: Session = Depends(get_db), user: models.User = Depends(require_roles("admin","editor"))):
    item = models.Item(name=payload.name, description=payload.description)
    db.add(item)
    db.commit()
    db.refresh(item)
    await write_audit_log(request, 200, db, user.id)
    return schemas.ItemOut(id=item.id, name=item.name, description=item.description)

@app.delete("/api/items/{item_id}")
async def delete_item(request: Request, item_id: int, db: Session = Depends(get_db), user: models.User = Depends(require_roles("admin"))):
    item = db.query(models.Item).filter(models.Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(item)
    db.commit()
    await write_audit_log(request, 200, db, user.id)
    return {"deleted": item_id}
