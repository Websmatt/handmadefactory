from pydantic import BaseModel, EmailStr

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: int
    email: EmailStr
    full_name: str | None
    roles: list[str]

class ItemIn(BaseModel):
    name: str
    description: str | None = None

class ItemOut(ItemIn):
    id: int
