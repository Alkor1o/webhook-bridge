import json
import redis.asyncio as aioredis
from app.config import settings

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    return _redis


async def enqueue_order(user_id: int, order_data: dict) -> None:
    r = await get_redis()
    await r.rpush(f"orders:{user_id}", json.dumps(order_data))


async def dequeue_order(user_id: int) -> dict | None:
    r = await get_redis()
    data = await r.lpop(f"orders:{user_id}")
    return json.loads(data) if data else None
