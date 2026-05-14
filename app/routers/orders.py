from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.database import get_db
from app.models import User, Order
from app.schemas import OrderResult, OrderOut
from app.redis_client import dequeue_order

router = APIRouter()


@router.get("/orders/pending/{token}")
async def get_pending_order(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.webhook_token == token))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Token invalido")

    order_data = await dequeue_order(user.id)

    if not order_data:
        return {"pending": False}

    return {"pending": True, "order": order_data}


@router.post("/orders/result/{token}")
async def report_order_result(
    token: str,
    body: OrderResult,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.webhook_token == token))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Token invalido")

    order_result = await db.execute(
        select(Order).where(Order.id == body.order_id, Order.user_id == user.id)
    )
    order = order_result.scalar_one_or_none()

    if not order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    order.status = body.status
    order.result = body.result
    order.executed_at = datetime.utcnow()
    await db.commit()

    return {"ok": True}


@router.get("/orders/log/{token}", response_model=list[OrderOut])
async def get_order_log(
    token: str,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.webhook_token == token))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Token invalido")

    orders_result = await db.execute(
        select(Order)
        .where(Order.user_id == user.id)
        .order_by(desc(Order.created_at))
        .limit(limit)
    )
    return orders_result.scalars().all()
