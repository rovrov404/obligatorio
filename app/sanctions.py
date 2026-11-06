from flask import Blueprint, flash, redirect, render_template, request, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import flash_database_error, required_fields


sanctions_bp = Blueprint("sanctions", __name__, url_prefix="/sanciones")
REASONS = ("roja", "acumulacion_amarillas", "disciplinaria")


def options():
    return {
        "players": fetch_all("SELECT ci,nombre,apellido FROM jugador ORDER BY apellido,nombre"),
        "tournaments": fetch_all("SELECT id_torneo,nombre,anio,semestre FROM torneo ORDER BY anio DESC,semestre DESC"),
        "reasons": REASONS,
    }


@sanctions_bp.get("")
@role_required("administrador")
def index():
    sanctions = fetch_all(
        """SELECT s.*,CONCAT(j.nombre,' ',j.apellido) AS jugador,t.nombre AS torneo
             FROM sancion_jugador s JOIN jugador j ON j.ci=s.ci_jugador
             JOIN torneo t USING(id_torneo) ORDER BY t.anio DESC,s.numero_fecha_inicio,j.apellido"""
    )
    return render_template("sanctions.html", sanctions=sanctions)


@sanctions_bp.route("/nueva", methods=["GET", "POST"])
@role_required("administrador")
def create():
    fields = ("ci_jugador", "id_torneo", "motivo", "numero_fecha_inicio", "cantidad_fechas")
    if request.method == "POST" and required_fields(request.form, fields):
        try:
            execute(
                """INSERT INTO sancion_jugador(ci_jugador,id_torneo,motivo,numero_fecha_inicio,cantidad_fechas)
                   VALUES(%s,%s,%s,%s,%s)""",
                tuple(request.form[name] for name in fields),
            )
            flash("Sanción creada.", "success")
            return redirect(url_for("sanctions.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("sanction_form.html", sanction=None, **options())


@sanctions_bp.route("/<int:sanction_id>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit(sanction_id):
    sanction = fetch_one("SELECT * FROM sancion_jugador WHERE id_sancion=%s", (sanction_id,))
    if request.method == "POST" and sanction:
        try:
            execute(
                """UPDATE sancion_jugador SET ci_jugador=%s,id_torneo=%s,motivo=%s,
                   numero_fecha_inicio=%s,cantidad_fechas=%s WHERE id_sancion=%s""",
                (request.form["ci_jugador"], request.form["id_torneo"], request.form["motivo"],
                 request.form["numero_fecha_inicio"], request.form["cantidad_fechas"], sanction_id),
            )
            flash("Sanción actualizada.", "success")
            return redirect(url_for("sanctions.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("sanction_form.html", sanction=sanction, **options())


@sanctions_bp.post("/<int:sanction_id>/eliminar")
@role_required("administrador")
def delete(sanction_id):
    try:
        execute("DELETE FROM sancion_jugador WHERE id_sancion=%s", (sanction_id,))
        flash("Sanción eliminada.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("sanctions.index"))
