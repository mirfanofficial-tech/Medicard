from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    env: str = "dev"
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    database_url: str = "postgresql+asyncpg://medicard:medicard@localhost:5432/medicard"

    jwt_secret: str = "change-me-dev-only"
    jwt_alg: str = "HS256"
    access_token_ttl_min: int = 30
    refresh_token_ttl_days: int = 30

    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = "medicard"
    s3_secret_key: str = "medicard123"
    s3_bucket: str = "medicard-records"
    s3_region: str = "us-east-1"

    anthropic_api_key: str = ""
    claude_model: str = "claude-sonnet-5"

    grant_ttl_hours: int = 12

    fcm_credentials_file: str = ""

    is_test: bool = Field(default=False, exclude=True)


@lru_cache
def get_settings() -> Settings:
    return Settings()
