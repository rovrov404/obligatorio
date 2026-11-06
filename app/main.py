from flask import Blueprint, redirect, render_template, session, url_for

from .auth import login_required, role_required
from .db import fetch_one


main_bp = Blueprint("main", __name__)


@main_bp.get("/")
def index():
    if "user_email" in session:
        return redirect(url_for("main.dashboard"))
    return redirect(url_for("auth.login"))


@main_bp.get("/dashboard")
@login_required
def dashboard():
    stats = fetch_one(
        """
        SELECT
          (SELECT COUNT(*) FROM jugador) AS jugadores,
          (SELECT COUNT(*) FROM equipo) AS equipos,
          (SELECT COUNT(*) FROM partido) AS partidos,
          (SELECT COUNT(*) FROM partido WHERE estado='jugado') AS jugados
        """
    )
    return render_template(
        "dashboard.html",
        email=session["user_email"],
        role=session["user_role"],
        stats=stats,
    )


@main_bp.get("/administracion")
@role_required("administrador")
def administration():
    return redirect(url_for("players.index"))



