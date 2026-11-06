import mysql.connector
from flask import current_app, session


def get_connection(connection_type="auth"):
    """Abre una conexión usando el usuario de base correspondiente."""
    credentials = {
        "auth": (
            current_app.config["MYSQL_AUTH_USER"],
            current_app.config["MYSQL_AUTH_PASSWORD"],
        ),
        "administrador": (
            current_app.config["MYSQL_ADMIN_USER"],
            current_app.config["MYSQL_ADMIN_PASSWORD"],
        ),
        "planillero": (
            current_app.config["MYSQL_PLANILLERO_USER"],
            current_app.config["MYSQL_PLANILLERO_PASSWORD"],
        ),
    }

    if connection_type not in credentials:
        raise ValueError("Tipo de conexión desconocido")

    user, password = credentials[connection_type]
    return mysql.connector.connect(
        host=current_app.config["MYSQL_HOST"],
        port=current_app.config["MYSQL_PORT"],
        database=current_app.config["MYSQL_DATABASE"],
        user=user,
        password=password,
        autocommit=False,
    )


def find_login_by_email(email):
    """Busca un usuario de la aplicación mediante una consulta parametrizada."""
    connection = get_connection("auth")
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT correo, contrasena, rol FROM login WHERE correo = %s",
            (email,),
        )
        return cursor.fetchone()
    finally:
        cursor.close()
        connection.close()


def current_role():
    """Devuelve el usuario de base que corresponde a la sesión actual."""
    return session.get("user_role", "auth")


def fetch_all(sql, params=(), connection_type=None):
    connection = get_connection(connection_type or current_role())
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(sql, params)
        return cursor.fetchall()
    finally:
        cursor.close()
        connection.close()


def fetch_one(sql, params=(), connection_type=None):
    connection = get_connection(connection_type or current_role())
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(sql, params)
        return cursor.fetchone()
    finally:
        cursor.close()
        connection.close()


def execute(sql, params=(), connection_type=None):
    """Ejecuta INSERT, UPDATE, DELETE o CALL y confirma la transacción."""
    connection = get_connection(connection_type or current_role())
    cursor = connection.cursor()
    try:
        cursor.execute(sql, params)
        connection.commit()
        return cursor.lastrowid
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()

