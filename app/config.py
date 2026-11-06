import os

from dotenv import load_dotenv


load_dotenv()


class Config:
    """Configuración leída desde el archivo .env."""

    SECRET_KEY = os.getenv("FLASK_SECRET_KEY", "solo-para-desarrollo")

    MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
    MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
    MYSQL_DATABASE = os.getenv("MYSQL_DATABASE", "torneo_f5")

    MYSQL_AUTH_USER = os.getenv("MYSQL_AUTH_USER", "torneo_auth")
    MYSQL_AUTH_PASSWORD = os.getenv("MYSQL_AUTH_PASSWORD", "")

    MYSQL_ADMIN_USER = os.getenv("MYSQL_ADMIN_USER", "torneo_admin")
    MYSQL_ADMIN_PASSWORD = os.getenv("MYSQL_ADMIN_PASSWORD", "")

    MYSQL_PLANILLERO_USER = os.getenv("MYSQL_PLANILLERO_USER", "torneo_planillero")
    MYSQL_PLANILLERO_PASSWORD = os.getenv("MYSQL_PLANILLERO_PASSWORD", "")

