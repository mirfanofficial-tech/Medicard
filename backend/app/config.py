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

    admin_api_key: str = "change-me-admin-dev-only"
    otp_ttl_min: int = 5
    otp_max_attempts: int = 5

    storage_backend: str = "s3"  # "s3" | "local"
    storage_local_dir: str = "./_storage"
    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = "medicard"
    s3_secret_key: str = "medicard123"
    s3_bucket: str = "medicard-records"
    s3_region: str = "us-east-1"

    anthropic_api_key: str = ""
    claude_model: str = "claude-sonnet-5"
    # When true (or when no API key is set), the AI features return a deterministic
    # stub instead of calling Claude — keeps the flow demoable offline.
    fake_extraction: bool = False
    fake_ai: bool = False

    grant_ttl_hours: int = 12
    break_glass_ttl_minutes: int = 60

    fcm_credentials_file: str = ""

    is_test: bool = Field(default=False, exclude=True)


@lru_cache
def get_settings() -> Settings:
    return Settings()
