"""Schemas for authentication and user management."""

from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    display_name: str
    is_active: bool
    is_admin: bool


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=256)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if "@" not in normalized or "." not in normalized.rsplit("@", 1)[-1]:
            raise ValueError("Gecerli bir e-posta girin.")
        return normalized


class AuthSessionRead(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class UserCreate(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    display_name: str = Field(min_length=2, max_length=160)
    password: str = Field(min_length=12, max_length=256)
    is_admin: bool = False

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if "@" not in normalized or "." not in normalized.rsplit("@", 1)[-1]:
            raise ValueError("Gecerli bir e-posta girin.")
        return normalized
