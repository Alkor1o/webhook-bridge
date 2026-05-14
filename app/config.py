from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://webhook:password@localhost/webhookbridge"
    redis_url: str = "redis://localhost:6379"
    secret_key: str = "cambia-esto-en-produccion"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 dias

    class Config:
        env_file = ".env"

    @property
    def async_database_url(self) -> str:
        # Railway entrega postgresql://, SQLAlchemy async necesita postgresql+asyncpg://
        url = self.database_url
        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


settings = Settings()
