from flask import Blueprint, flash, redirect, render_template, request, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import flash_database_error, required_fields, valid_date


matches_bp = Blueprint("matches", __name__, url_prefix="/partidos")
STATES = ("programado", "jugado", "postergado", "cancelado")


def options():
    return {
        "tournaments": fetch_all("SELECT * FROM torneo ORDER BY anio DESC,semestre DESC"),
        "teams": fetch_all("SELECT id_equipo,nombre,id_torneo FROM equipo ORDER BY nombre"),
        "courts": fetch_all(
            """SELECT c.nombre_cancha,c.id_complejo,co.nombre AS complejo
                 FROM cancha c JOIN complejo co USING(id_complejo)
                ORDER BY co.nombre,c.nombre_cancha"""
        ),
        "turns": fetch_all("SELECT * FROM turno ORDER BY hora_inicio"),
        "states": STATES,
    }


def parse_court(value):
    complex_id, court_name = value.split("|", 1)
    return int(complex_id), court_name


@matches_bp.get("")
@role_required("administrador")
def index():
    matches = fetch_all(
        """SELECT p.id_partido,p.numero_fecha,p.dia,p.estado,t.nombre AS torneo,
                  el.nombre AS local,ev.nombre AS visitante,co.nombre AS complejo,
                  p.nombre_cancha,tu.hora_inicio
             FROM partido p JOIN torneo t USING(id_torneo)
             JOIN equipo el ON el.id_equipo=p.id_equipo_local
             JOIN equipo ev ON ev.id_equipo=p.id_equipo_visitante
             JOIN complejo co ON co.id_complejo=p.id_complejo
             JOIN turno tu USING(id_turno)
            ORDER BY p.dia DESC,tu.hora_inicio"""
    )
    return render_template("matches.html", matches=matches)


@matches_bp.route("/nuevo", methods=["GET", "POST"])
@role_required("administrador")
def create():
    required = ("id_torneo", "numero_fecha", "id_equipo_local", "id_equipo_visitante", "dia", "id_turno", "court")
    if request.method == "POST" and required_fields(request.form, required):
        try:
            if not valid_date(request.form["dia"]):
                raise ValueError("La fecha del partido no es válida.")
            complex_id, court_name = parse_court(request.form["court"])
            execute(
                """INSERT INTO partido(id_torneo,numero_fecha,id_equipo_local,id_equipo_visitante,
                   dia,id_turno,nombre_cancha,id_complejo,estado)
                   VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                (request.form["id_torneo"], request.form["numero_fecha"], request.form["id_equipo_local"],
                 request.form["id_equipo_visitante"], request.form["dia"], request.form["id_turno"],
                 court_name, complex_id, request.form.get("estado", "programado")),
            )
            flash("Partido creado.", "success")
            return redirect(url_for("matches.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("match_form.html", match=None, **options())


@matches_bp.route("/<int:match_id>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit(match_id):
    match = fetch_one("SELECT * FROM partido WHERE id_partido=%s", (match_id,))
    if not match:
        flash("Partido inexistente.", "danger")
        return redirect(url_for("matches.index"))
    if request.method == "POST":
        try:
            complex_id, court_name = parse_court(request.form["court"])
            execute(
                """UPDATE partido SET numero_fecha=%s,id_equipo_local=%s,id_equipo_visitante=%s,
                   dia=%s,id_turno=%s,nombre_cancha=%s,id_complejo=%s,estado=%s WHERE id_partido=%s""",
                (request.form["numero_fecha"], request.form["id_equipo_local"], request.form["id_equipo_visitante"],
                 request.form["dia"], request.form["id_turno"], court_name, complex_id,
                 request.form["estado"], match_id),
            )
            flash("Partido actualizado.", "success")
            return redirect(url_for("matches.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("match_form.html", match=match, **options())


@matches_bp.post("/<int:match_id>/eliminar")
@role_required("administrador")
def delete(match_id):
    try:
        execute("DELETE FROM partido WHERE id_partido=%s", (match_id,))
        flash("Partido eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("matches.index"))
