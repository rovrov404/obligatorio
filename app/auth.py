from functools import wraps

import bcrypt
from flask import (
    Blueprint,
    flash,
    redirect,
    render_template,
    request,
    session,
    url_for,
)
from mysql.connector import Error as MySQLError
from werkzeug.security import check_password_hash

from .db import find_login_by_email


auth_bp = Blueprint("auth", __name__)


def verify_password(plain_password, stored_hash):
    """Acepta hashes bcrypt y hashes creados por Werkzeug."""
    if not stored_hash:
        return False

    if stored_hash.startswith(("$2a$", "$2b$", "$2y$")):
        try:
            return bcrypt.checkpw(
                plain_password.encode("utf-8"),
                stored_hash.encode("utf-8"),
            )
        except ValueError:
            return False

    try:
        return check_password_hash(stored_hash, plain_password)
    except (ValueError, TypeError):
        return False


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if "user_email" not in session:
            flash("Primero debes iniciar sesión.", "warning")
            return redirect(url_for("auth.login"))
        return view(*args, **kwargs)

    return wrapped_view


def role_required(*allowed_roles):
    def decorator(view):
        @wraps(view)
        def wrapped_view(*args, **kwargs):
            if "user_email" not in session:
                flash("Primero debes iniciar sesión.", "warning")
                return redirect(url_for("auth.login"))
            if session.get("user_role") not in allowed_roles:
                flash("No tienes permiso para entrar a esa sección.", "danger")
                return redirect(url_for("main.dashboard"))
            return view(*args, **kwargs)

        return wrapped_view

    return decorator


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if "user_email" in session:
        return redirect(url_for("main.dashboard"))

    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")

        if not email or not password:
            flash("Completa el correo y la contraseña.", "warning")
            return render_template("login.html", email=email)

        try:
            user = find_login_by_email(email)
        except MySQLError:
            flash(
                "No se pudo conectar con MySQL. Revisa la base y el archivo .env.",
                "danger",
            )
            return render_template("login.html", email=email)

        if not user or not verify_password(password, user["contrasena"]):
            flash("Correo o contraseña incorrectos.", "danger")
            return render_template("login.html", email=email)

        session.clear()
        session["user_email"] = user["correo"]
        session["user_role"] = user["rol"]
        return redirect(url_for("main.dashboard"))

    return render_template("login.html")


@auth_bp.post("/logout")
def logout():
    session.clear()
    flash("Sesión cerrada correctamente.", "success")
    return redirect(url_for("auth.login"))

