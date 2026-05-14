from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User, Order
from app.schemas import WebhookPayload
from app.redis_client import enqueue_order

router = APIRouter()

VALID_ACTIONS = {"buy", "sell", "close", "modify"}


@router.post("/wh/{token}", status_code=status.HTTP_202_ACCEPTED)
async def receive_webhook(
    token: str,
    payload: WebhookPayload,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.webhook_token == token))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Token invalido")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Suscripcion inactiva")

    if payload.action not in VALID_ACTIONS:
        raise HTTPException(status_code=422, detail=f"Accion no valida: {payload.action}")

    order = Order(
        user_id=user.id,
        action=payload.action,
        symbol=payload.symbol.upper(),
        lot=payload.lot,
        sl=payload.sl,
        tp=payload.tp,
        comment=payload.comment,
        status="pending",
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    await enqueue_order(user.id, {
        "order_id": order.id,
        "action": order.action,
        "symbol": order.symbol,
        "lot": order.lot,
        "sl": order.sl,
        "tp": order.tp,
        "comment": order.comment,
    })

    return {"ok": True, "order_id": order.id}
