from datetime import date

from flask import flash
from mysql.connector import Error as MySQLError


def clean_text(value):
    return (value or "").strip()


def required_fields(form, names):
    missing = [name for name in names if not clean_text(form.get(name))]
    if missing:
        flash("Completa todos los campos obligatorios.", "warning")
        return False
    return True


def valid_date(value):
    try:
        date.fromisoformat(value)
        return True
    except (TypeError, ValueError):
        return False


def flash_database_error(error):
    if isinstance(error, MySQLError):
        message = error.msg or "MySQL rechazó la operación."
    else:
        message = str(error)
    flash(message, "danger")
