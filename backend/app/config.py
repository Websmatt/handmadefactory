from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    access_token_expire_minutes: int = 60
    first_admin_email: str = "admin@example.com"
    first_admin_password: str = "ChangeMeNow!123"
    first_admin_full_name: str = "Admin"

    class Config:
        env_prefix = ""
        case_sensitive = False

settings = Settings()
