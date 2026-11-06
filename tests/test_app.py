import pytest
from werkzeug.security import generate_password_hash

from app import create_app


@pytest.fixture()
def app():
    return create_app({"TESTING": True, "SECRET_KEY": "test-secret"})


@pytest.fixture()
def client(app):
    return app.test_client()


def test_root_redirects_to_login(client):
    response = client.get("/")
    assert response.status_code == 302
    assert response.headers["Location"].endswith("/login")


def test_dashboard_requires_login(client):
    response = client.get("/dashboard")
    assert response.status_code == 302
    assert response.headers["Location"].endswith("/login")


def test_login_rejects_empty_form(client):
    response = client.post("/login", data={"email": "", "password": ""})
    assert response.status_code == 200
    assert "Completa el correo" in response.get_data(as_text=True)


def test_login_and_roles(client, monkeypatch):
    fake_user = {
        "correo": "admin@ucu.edu.uy",
        "contrasena": generate_password_hash("clave-segura"),
        "rol": "administrador",
    }
    monkeypatch.setattr("app.auth.find_login_by_email", lambda email: fake_user)

    response = client.post(
        "/login",
        data={"email": "admin@ucu.edu.uy", "password": "clave-segura"},
        follow_redirects=True,
    )

    assert response.status_code == 200
    text = response.get_data(as_text=True)
    assert "Bienvenido al Torneo F5" in text
    assert "Jugadores" in text


def test_planillero_cannot_open_administration(client):
    with client.session_transaction() as session:
        session["user_email"] = "planillero@ucu.edu.uy"
        session["user_role"] = "planillero"

    response = client.get("/administracion")
    assert response.status_code == 302
    assert response.headers["Location"].endswith("/dashboard")

