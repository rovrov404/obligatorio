from flask import Blueprint, flash, redirect, render_template, request, url_for

from .auth import role_required
from .db import execute, fetch_all, fetch_one
from .utils import clean_text, flash_database_error, required_fields


venues_bp = Blueprint("venues", __name__, url_prefix="/complejos")


@venues_bp.get("")
@role_required("administrador")
def index():
    complexes = fetch_all("SELECT * FROM complejo ORDER BY nombre")
    courts = fetch_all(
        """SELECT c.nombre_cancha,c.id_complejo,c.superficie,c.techada,
                  co.nombre AS complejo FROM cancha c JOIN complejo co USING(id_complejo)
             ORDER BY co.nombre,c.nombre_cancha"""
    )
    return render_template("venues.html", complexes=complexes, courts=courts)


@venues_bp.route("/nuevo", methods=["GET", "POST"])
@role_required("administrador")
def create_complex():
    if request.method == "POST" and required_fields(request.form, ("nombre", "direccion", "departamento")):
        try:
            execute(
                "INSERT INTO complejo(nombre,direccion,departamento) VALUES(%s,%s,%s)",
                tuple(clean_text(request.form[name]) for name in ("nombre", "direccion", "departamento")),
            )
            flash("Complejo creado.", "success")
            return redirect(url_for("venues.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("complex_form.html", complex_item=None)


@venues_bp.route("/<int:complex_id>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit_complex(complex_id):
    item = fetch_one("SELECT * FROM complejo WHERE id_complejo=%s", (complex_id,))
    if request.method == "POST" and item and required_fields(request.form, ("nombre", "direccion", "departamento")):
        try:
            execute(
                "UPDATE complejo SET nombre=%s,direccion=%s,departamento=%s WHERE id_complejo=%s",
                (clean_text(request.form["nombre"]), clean_text(request.form["direccion"]),
                 clean_text(request.form["departamento"]), complex_id),
            )
            flash("Complejo actualizado.", "success")
            return redirect(url_for("venues.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("complex_form.html", complex_item=item)


@venues_bp.post("/<int:complex_id>/eliminar")
@role_required("administrador")
def delete_complex(complex_id):
    try:
        execute("DELETE FROM complejo WHERE id_complejo=%s", (complex_id,))
        flash("Complejo eliminado.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("venues.index"))


@venues_bp.route("/canchas/nueva", methods=["GET", "POST"])
@role_required("administrador")
def create_court():
    if request.method == "POST" and required_fields(request.form, ("nombre_cancha", "id_complejo", "superficie")):
        try:
            execute(
                "INSERT INTO cancha(nombre_cancha,id_complejo,superficie,techada) VALUES(%s,%s,%s,%s)",
                (clean_text(request.form["nombre_cancha"]), request.form["id_complejo"],
                 request.form["superficie"], "techada" in request.form),
            )
            flash("Cancha creada.", "success")
            return redirect(url_for("venues.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("court_form.html", court=None, complexes=fetch_all("SELECT * FROM complejo ORDER BY nombre"))


@venues_bp.route("/<int:complex_id>/canchas/<path:name>/editar", methods=["GET", "POST"])
@role_required("administrador")
def edit_court(complex_id, name):
    court = fetch_one("SELECT * FROM cancha WHERE id_complejo=%s AND nombre_cancha=%s", (complex_id, name))
    if request.method == "POST" and court:
        try:
            execute(
                "UPDATE cancha SET superficie=%s,techada=%s WHERE id_complejo=%s AND nombre_cancha=%s",
                (request.form["superficie"], "techada" in request.form, complex_id, name),
            )
            flash("Cancha actualizada.", "success")
            return redirect(url_for("venues.index"))
        except Exception as error:
            flash_database_error(error)
    return render_template("court_form.html", court=court, complexes=fetch_all("SELECT * FROM complejo ORDER BY nombre"))


@venues_bp.post("/<int:complex_id>/canchas/<path:name>/eliminar")
@role_required("administrador")
def delete_court(complex_id, name):
    try:
        execute("DELETE FROM cancha WHERE id_complejo=%s AND nombre_cancha=%s", (complex_id, name))
        flash("Cancha eliminada.", "success")
    except Exception as error:
        flash_database_error(error)
    return redirect(url_for("venues.index"))
