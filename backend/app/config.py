"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings

_DEV_PRIVATE_KEY = """-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCerh0wqKevXwth
zhV2cSOdTHlbKNaFdrt9PFZ75ja4d2lMbj/Hlv6HJw9epmrbaT+NvTUMTY1+/oGP
blYE+n3XAYIrjisE65fAiha7RdBhs/h6mYPcJmm8+0c5eCeELH6+D1/0P0VQfn2T
oyejCiA7HoJRBTpQy2a/EEJs08z7evgu0CAgAada+Z2DQH8DPeZSmvoBteKL6ZGP
rAIa88sHBVFr6yCytDRjOAjlh2CDiFbwyFJVkiaVukjABSeyStnholuspTeDUWs+
+UEGU1RSyQk49493ABJOEIPRx/1jixI71V++TOFbEhL7LIt7m+3u/cfQjPMP47LO
egPw4p31AgMBAAECggEABNS5tEfKNSNgYhWnXyACLNGNd0pGv7D189Hgsyx22YZf
KRHJNM8iyCQXCnNoGO57HhpW0V1SE731XVPHYCbtKlzUJPXS1vdCOz0pBIITXkof
pEHkuxDbUsLWsAf5sgM1x50Jt5Kujk0Pjy1eMU9HXG1pG8TcOeX7ZpE86HnJSZWw
RjkHDYaG6AospMS2kPZIcpCiZgVeEHykgq3FCM5CN4weyy4aoGYaQBXU1N2dt3lK
ETXHQGsFu5ytJvXbDnqZZu6txm+E1MM0qM1qLbwXaS28RS3Tdlr5eWvyUBGwnmah
hKy7yJhPLWu23MyQt4+JWDPtFtL9vnmZ4Ha095p3sQKBgQDZj4v/0rXmGfTz/rwl
ypWuHbPYFpKsF+cEtseL46P4GLcasIUL93/pBCL4yZntZaYwLU0Z3A51wHGKjX3e
uUxYM6cmA5LzRe6IKMTc+XqKnkhONUN8GpUl+gZRWogpI7NLKnAjGXa8XpF4wBiv
1R/HFeTBBnARXtdZ0Ius4V2vcQKBgQC6t1lC11dwekOKQC5XZw8A1KG5bSwecmEs
3btos8tAC/8yz/DNnjXIaY+KW7OjSJusvvJCnhw5x/vzZOtL4XZbwvLgEQZMzNOE
PIazYzF98EYqfXv9A0EFfUST6Uehr4g9Moeo9IB3VBWPWvBAWnbGbawGua30E1l6
T43dIZ5cxQKBgHN3w2cYj2A7wI1LUtJ/7edGbnAustPRr9QJqmjtfdYsT+pDa6nJ
R0MF5gXDAgZEX+rL8FLcP3RxmhFePULbd9CMQZdkaDbjk9ECSlG5uzcdAOU5UcLp
XOWWCIpfEUs8Xmlzcaa/Wgxp6K18zt1rsPz5+roTz6D4hDVwAOHVjuKRAoGAP4Km
JgpBf8zWtGvoV2qCu/GXoQ71dtXJIA279X1SoVJzV8FLU2WBPc5KOPHARMYpzbSV
ivtk9nKDzOKC9qiWLdg97OFdlzoEqHI+Dz6qUwArncBZMFKvB0L41KcA6opeeRJ6
+olQOUasnrp8Bie/Rvd/EDqQZPk/8k6lHpaU21ECgYEAgh23TOV/7i3PQ71E2drD
KRFtA/ieI5e9wKZgjUyDg+GruF0JAcehhcHah/OyRJiXBGRDeAsMjUzx2caELXiM
+MaQS0tcLsqxWjh0lyHYoQqMRb5swHZ0/ulto04LweASFVY93EBssOxtrkCyGMMh
wmr3khzNJeKGHIM9c4tWAss=
-----END PRIVATE KEY-----"""

_DEV_PUBLIC_KEY = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnq4dMKinr18LYc4VdnEj
nUx5WyjWhXa7fTxWe+Y2uHdpTG4/x5b+hycPXqZq22k/jb01DE2Nfv6Bj25WBPp9
1wGCK44rBOuXwIoWu0XQYbP4epmD3CZpvPtHOXgnhCx+vg9f9D9FUH59k6Mnowog
Ox6CUQU6UMtmvxBCbNPM+3r4LtAgIAGnWvmdg0B/Az3mUpr6AbXii+mRj6wCGvPL
BwVRa+sgsrQ0YzgI5Ydgg4hW8MhSVZImlbpIwAUnskrZ4aJbrKU3g1FrPvlBBlNU
UskJOPePdwASThCD0cf9Y4sSO9VfvkzhWxIS+yyLe5vt7v3H0IzzD+OyznoD8OKd
9QIDAQAB
-----END PUBLIC KEY-----"""


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.

    :ivar database_url: PostgreSQL connection string
    :ivar environment: Deployment environment name
    :ivar cors_origins: Comma-separated list of allowed CORS origins
    :ivar app_version: Application version string
    :ivar jwt_private_key: RS256 private key PEM for signing tokens
    :ivar jwt_public_key: RS256 public key PEM for verifying tokens
    :ivar access_token_expire_minutes: Access token lifetime in minutes
    :ivar refresh_token_expire_days: Refresh token lifetime in days
    :ivar redis_url: Redis connection URL for token blacklist
    :ivar admin_api_key: Static secret for X-Admin-Key header
    :ivar pgbouncer_url: PgBouncer connection URL (optional)
    """

    database_url: str = (
        "postgresql://ims:ims@localhost:5432/ims"
    )
    environment: str = "development"
    cors_origins: str = "*"
    app_version: str = "0.1.0"

    jwt_private_key: str = _DEV_PRIVATE_KEY
    jwt_public_key: str = _DEV_PUBLIC_KEY
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    redis_url: str = "redis://localhost:6379/0"
    admin_api_key: str = "dev-admin-key"
    pgbouncer_url: str = ""

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
