from datetime import datetime
from pydantic import BaseModel, EmailStr


class WebhookPayload(BaseModel):
    action: str
    symbol: str
    lot: float | None = None
    sl: float | None = None
    tp: float | None = None
    comment: str | None = None


class OrderOut(BaseModel):
    id: int
    action: str
    symbol: str
    lot: float | None
    sl: float | None
    tp: float | None
    comment: str | None
    status: str
    result: str | None
    created_at: datetime
    executed_at: datetime | None

    model_config = {"from_attributes": True}


class OrderResult(BaseModel):
    order_id: int
    status: str
    result: str | None = None


class UserRegister(BaseModel):
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    email: str
    webhook_token: str
    is_active: bool

    model_config = {"from_attributes": True}
