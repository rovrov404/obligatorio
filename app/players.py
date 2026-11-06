from flask import Blueprint, flash, redirect, render_template, request, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import clean_text, flash_database_error, required_fields, valid_date


players_bp = Blueprint("players", __name__, url_prefix="/jugadores")
PLAYER_TYPES = ("grado", "posgrado", "docente", "funcionario")


def faculties():
    return fetch_all("SELECT id_facultad, nombre FROM facultad ORDER BY nombre")


@players_bp.get("")
@role_required("administrador")
def index():
    players = fetch_all(
        """
        SELECT j.ci, j.nombre, j.apellido, j.email, j.fecha_nacimiento,
               j.tipo, f.nombre AS facultad
          FROM jugador j JOIN facultad f ON f.id_facultad=j.id_facultad
         ORDER BY j.apellido, j.nombre
        """
    )
    return render_template("players.html", players=players)


@players_bp.route("/nuevo", methods=["GET", "POST"])
@role_required("administrador")
def create():
    if request.method == "POST":
        fields = ("ci", "nombre", "apellido", "email", "fecha_nacimiento", "id_facultad", "tipo")
        if required_fields(request.form, fields):
            ci = clean_text(request.form["ci"])
            birth_date = request.form["fecha_nacimiento"]
            player_type = request.form["tipo"]
            if not ci.isdigit() or len(ci) not in (7, 8):
                flash("La cédula debe tener 7 u 8 números, sin puntos ni guion.", "warning")
            elif not valid_date(birth_date):
                flash("La fecha de nacimiento no es válida.", "warning")
            elif player_type not in PLAYER_TYPES:
                flash("El tipo de jugador no es válido.", "warning")
            else:
                try:
                    execute(
                        """INSERT INTO jugador
                           (ci,nombre,apellido,email,fecha_nacimiento,id_facultad,tipo)
                           VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                        (ci, clean_text(request.form["nombre"]), clean_text(request.form["apellido"]),
                         clean_text(request.form["email"]).lower(), birth_date,
                         request.form["id_facultad"], player_type),
                    )
                    flash("Jugador creado correctamente.", "success")
                    return redirect(url_for("players.index"))
                except Exception as error:
                    flash_database_error(error)
    return render_template("player_form.html", player=None, faculties=faculties(), player_types=PLAYER_TYPES)


@players_bp.route("/<ci>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit(ci):
    player = fetch_one("SELECT * FROM jugador WHERE ci=%s", (ci,))
    if not player:
        flash("Jugador inexistente.", "danger")
        return redirect(url_for("players.index"))
    if request.method == "POST" and required_fields(
        request.form, ("nombre", "apellido", "email", "fecha_nacimiento", "id_facultad", "tipo")
    ):
        try:
            execute(
                """UPDATE jugador SET nombre=%s, apellido=%s, email=%s,
                   fecha_nacimiento=%s, id_facultad=%s, tipo=%s WHERE ci=%s""",
                (clean_text(request.form["nombre"]), clean_text(request.form["apellido"]),
                 clean_text(request.form["email"]).lower(), request.form["fecha_nacimiento"],
                 request.form["id_facultad"], request.form["tipo"], ci),
            )
            flash("Jugador actualizado.", "success")
            return redirect(url_for("players.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("player_form.html", player=player, faculties=faculties(), player_types=PLAYER_TYPES)


@players_bp.post("/<ci>/eliminar")
@role_required("administrador")
def delete(ci):
    try:
        execute("DELETE FROM jugador WHERE ci=%s", (ci,))
        flash("Jugador eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("players.index"))
