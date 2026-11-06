from flask import Blueprint, flash, redirect, render_template, request, session, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import flash_database_error, required_fields


sheets_bp = Blueprint("sheets", __name__, url_prefix="/planillas")


@sheets_bp.get("")
@role_required("planillero", "administrador")
def index():
    matches = fetch_all(
        """SELECT p.id_partido,p.numero_fecha,p.dia,p.estado,el.nombre AS local,
                  ev.nombre AS visitante,t.hora_inicio,t.hora_fin
             FROM partido p JOIN equipo el ON el.id_equipo=p.id_equipo_local
             JOIN equipo ev ON ev.id_equipo=p.id_equipo_visitante
             JOIN turno t USING(id_turno)
            ORDER BY p.dia DESC,t.hora_inicio"""
    )
    return render_template("sheets.html", matches=matches)


@sheets_bp.post("/<int:match_id>/marcar-jugado")
@role_required("planillero", "administrador")
def mark_played(match_id):
    try:
        if session["user_role"] == "planillero":
            execute("CALL sp_marcar_partido_jugado(%s)", (match_id,))
        else:
            execute("UPDATE partido SET estado='jugado' WHERE id_partido=%s", (match_id,))
        flash("Partido marcado como jugado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("sheets.index"))


@sheets_bp.get("/<int:match_id>")
@role_required("planillero", "administrador")
def detail(match_id):
    match = fetch_one(
        """SELECT p.*,el.nombre AS local,ev.nombre AS visitante,t.hora_inicio,t.hora_fin
             FROM partido p JOIN equipo el ON el.id_equipo=p.id_equipo_local
             JOIN equipo ev ON ev.id_equipo=p.id_equipo_visitante JOIN turno t USING(id_turno)
            WHERE p.id_partido=%s""",
        (match_id,),
    )
    if not match:
        flash("Partido inexistente.", "danger")
        return redirect(url_for("sheets.index"))
    participants = fetch_all(
        """SELECT pl.ci_jugador,pl.id_equipo,j.nombre,j.apellido,e.nombre AS equipo
             FROM planilla_partido pl JOIN jugador j ON j.ci=pl.ci_jugador
             JOIN equipo e ON e.id_equipo=pl.id_equipo
            WHERE pl.id_partido=%s ORDER BY e.nombre,j.apellido""",
        (match_id,),
    )
    candidates = fetch_all(
        """SELECT ej.ci_jugador,j.nombre,j.apellido,ej.id_equipo,e.nombre AS equipo
             FROM equipo_jugador_torneo ej JOIN jugador j ON j.ci=ej.ci_jugador
             JOIN equipo e ON e.id_equipo=ej.id_equipo
            WHERE ej.id_equipo IN (%s,%s) AND NOT EXISTS(
              SELECT 1 FROM planilla_partido pl WHERE pl.id_partido=%s AND pl.ci_jugador=ej.ci_jugador)
            ORDER BY e.nombre,j.apellido""",
        (match["id_equipo_local"], match["id_equipo_visitante"], match_id),
    )
    goals = fetch_all(
        """SELECT g.id_gol,g.ci_jugador,g.minuto,g.autogol,CONCAT(j.nombre,' ',j.apellido) AS jugador
             FROM gol g JOIN jugador j ON j.ci=g.ci_jugador WHERE g.id_partido=%s ORDER BY g.minuto""",
        (match_id,),
    )
    cards = fetch_all(
        """SELECT t.id_tarjeta,t.ci_jugador,t.minuto,t.color,CONCAT(j.nombre,' ',j.apellido) AS jugador
             FROM tarjeta t JOIN jugador j ON j.ci=t.ci_jugador WHERE t.id_partido=%s ORDER BY t.minuto""",
        (match_id,),
    )
    return render_template(
        "sheet_detail.html", match=match, participants=participants,
        candidates=candidates, goals=goals, cards=cards,
    )


@sheets_bp.post("/<int:match_id>/participantes/agregar")
@role_required("planillero", "administrador")
def add_participant(match_id):
    if required_fields(request.form, ("player",)):
        try:
            team_id, ci = request.form["player"].split("|", 1)
            execute("INSERT INTO planilla_partido(id_partido,ci_jugador,id_equipo) VALUES(%s,%s,%s)",
                    (match_id, ci, team_id))
            flash("Participante agregado.", "success")
        except Exception as error:
            flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))


@sheets_bp.post("/<int:match_id>/participantes/<ci>/quitar")
@role_required("planillero", "administrador")
def remove_participant(match_id, ci):
    try:
        execute("DELETE FROM planilla_partido WHERE id_partido=%s AND ci_jugador=%s", (match_id, ci))
        flash("Participante eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))


@sheets_bp.post("/<int:match_id>/goles/agregar")
@role_required("planillero", "administrador")
def add_goal(match_id):
    if required_fields(request.form, ("ci_jugador", "minuto")):
        try:
            execute("INSERT INTO gol(id_partido,ci_jugador,minuto,autogol) VALUES(%s,%s,%s,%s)",
                    (match_id, request.form["ci_jugador"], request.form["minuto"], "autogol" in request.form))
            flash("Gol registrado.", "success")
        except Exception as error:
            flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))


@sheets_bp.post("/<int:match_id>/goles/<int:goal_id>/eliminar")
@role_required("planillero", "administrador")
def delete_goal(match_id, goal_id):
    try:
        execute("DELETE FROM gol WHERE id_gol=%s", (goal_id,))
        flash("Gol eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))


@sheets_bp.post("/<int:match_id>/tarjetas/agregar")
@role_required("planillero", "administrador")
def add_card(match_id):
    if required_fields(request.form, ("ci_jugador", "minuto", "color")):
        try:
            execute("INSERT INTO tarjeta(id_partido,ci_jugador,minuto,color) VALUES(%s,%s,%s,%s)",
                    (match_id, request.form["ci_jugador"], request.form["minuto"], request.form["color"]))
            flash("Tarjeta registrada.", "success")
        except Exception as error:
            flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))


@sheets_bp.post("/<int:match_id>/tarjetas/<int:card_id>/eliminar")
@role_required("planillero", "administrador")
def delete_card(match_id, card_id):
    try:
        execute("DELETE FROM tarjeta WHERE id_tarjeta=%s", (card_id,))
        flash("Tarjeta eliminada.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("sheets.detail", match_id=match_id))
