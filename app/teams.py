from flask import Blueprint, flash, redirect, render_template, request, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import clean_text, flash_database_error, required_fields


teams_bp = Blueprint("teams", __name__, url_prefix="/equipos")


def form_options():
    return {
        "tournaments": fetch_all("SELECT id_torneo,nombre,anio,semestre,estado FROM torneo ORDER BY anio DESC,semestre DESC"),
        "faculties": fetch_all("SELECT id_facultad,nombre FROM facultad ORDER BY nombre"),
    }


@teams_bp.get("")
@role_required("administrador")
def index():
    teams = fetch_all(
        """
        SELECT e.id_equipo,e.nombre,t.nombre AS torneo,f.nombre AS facultad,
               CONCAT(j.nombre,' ',j.apellido) AS capitan, COUNT(ej.ci_jugador) AS jugadores
          FROM equipo e
          JOIN torneo t ON t.id_torneo=e.id_torneo
          JOIN facultad f ON f.id_facultad=e.id_facultad
          LEFT JOIN jugador j ON j.ci=e.ci_capitan
          LEFT JOIN equipo_jugador_torneo ej ON ej.id_equipo=e.id_equipo
         GROUP BY e.id_equipo,e.nombre,t.nombre,f.nombre,j.nombre,j.apellido
         ORDER BY t.anio DESC,t.semestre DESC,e.nombre
        """
    )
    return render_template("teams.html", teams=teams)


@teams_bp.route("/nuevo", methods=["GET", "POST"])
@role_required("administrador")
def create():
    if request.method == "POST" and required_fields(request.form, ("nombre", "id_torneo", "id_facultad")):
        try:
            execute(
                "INSERT INTO equipo(nombre,id_torneo,id_facultad,ci_capitan) VALUES(%s,%s,%s,NULL)",
                (clean_text(request.form["nombre"]), request.form["id_torneo"], request.form["id_facultad"]),
            )
            flash("Equipo creado. Ahora carga su plantel.", "success")
            return redirect(url_for("teams.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("team_form.html", team=None, **form_options())


@teams_bp.route("/<int:team_id>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit(team_id):
    team = fetch_one("SELECT * FROM equipo WHERE id_equipo=%s", (team_id,))
    if not team:
        flash("Equipo inexistente.", "danger")
        return redirect(url_for("teams.index"))
    if request.method == "POST" and required_fields(request.form, ("nombre", "id_facultad")):
        try:
            execute(
                "UPDATE equipo SET nombre=%s,id_facultad=%s WHERE id_equipo=%s",
                (clean_text(request.form["nombre"]), request.form["id_facultad"], team_id),
            )
            flash("Equipo actualizado.", "success")
            return redirect(url_for("teams.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("team_form.html", team=team, **form_options())


@teams_bp.post("/<int:team_id>/eliminar")
@role_required("administrador")
def delete(team_id):
    try:
        execute("DELETE FROM equipo WHERE id_equipo=%s", (team_id,))
        flash("Equipo eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("teams.index"))


@teams_bp.get("/<int:team_id>/plantel")
@role_required("administrador")
def roster(team_id):
    team = fetch_one(
        """SELECT e.*,t.nombre AS torneo,f.nombre AS facultad,t.estado
             FROM equipo e JOIN torneo t ON t.id_torneo=e.id_torneo
             JOIN facultad f ON f.id_facultad=e.id_facultad WHERE e.id_equipo=%s""",
        (team_id,),
    )
    if not team:
        flash("Equipo inexistente.", "danger")
        return redirect(url_for("teams.index"))
    players = fetch_all(
        """SELECT ej.ci_jugador,ej.numero_camiseta,j.nombre,j.apellido,j.tipo,
                  (ej.ci_jugador=e.ci_capitan) AS es_capitan
             FROM equipo_jugador_torneo ej JOIN jugador j ON j.ci=ej.ci_jugador
             JOIN equipo e ON e.id_equipo=ej.id_equipo
            WHERE ej.id_equipo=%s ORDER BY ej.numero_camiseta""",
        (team_id,),
    )
    candidates = fetch_all(
        """SELECT j.ci,j.nombre,j.apellido,j.tipo FROM jugador j
            WHERE j.id_facultad=%s AND NOT EXISTS(
              SELECT 1 FROM equipo_jugador_torneo ej
               WHERE ej.id_torneo=%s AND ej.ci_jugador=j.ci)
            ORDER BY j.apellido,j.nombre""",
        (team["id_facultad"], team["id_torneo"]),
    )
    return render_template("roster.html", team=team, players=players, candidates=candidates)


@teams_bp.post("/<int:team_id>/plantel/agregar")
@role_required("administrador")
def add_player(team_id):
    team = fetch_one("SELECT id_torneo FROM equipo WHERE id_equipo=%s", (team_id,))
    if team and required_fields(request.form, ("ci_jugador", "numero_camiseta")):
        try:
            execute(
                "INSERT INTO equipo_jugador_torneo(id_equipo,ci_jugador,id_torneo,numero_camiseta) VALUES(%s,%s,%s,%s)",
                (team_id, request.form["ci_jugador"], team["id_torneo"], request.form["numero_camiseta"]),
            )
            flash("Jugador agregado al plantel.", "success")
        except Exception as error:
            flash_database_error(error)
    return redirect(url_for("teams.roster", team_id=team_id))


@teams_bp.post("/<int:team_id>/plantel/<ci>/quitar")
@role_required("administrador")
def remove_player(team_id, ci):
    try:
        execute("DELETE FROM equipo_jugador_torneo WHERE id_equipo=%s AND ci_jugador=%s", (team_id, ci))
        flash("Jugador quitado del plantel.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("teams.roster", team_id=team_id))


@teams_bp.post("/<int:team_id>/capitan")
@role_required("administrador")
def captain(team_id):
    if required_fields(request.form, ("ci_capitan",)):
        try:
            execute("UPDATE equipo SET ci_capitan=%s WHERE id_equipo=%s", (request.form["ci_capitan"], team_id))
            flash("Capitán actualizado.", "success")
        except Exception as error:
            flash_database_error(error)
    return redirect(url_for("teams.roster", team_id=team_id))
