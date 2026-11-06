"""Prueba rápida de las pantallas usando la base real."""

import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app


app = create_app({"TESTING": True})
client = app.test_client()

response = client.post(
    "/login",
    data={"email": "admin@torneo.ucu", "password": "AdminApp_2026!"},
    follow_redirects=True,
)
assert response.status_code == 200

admin_urls = [
    "/dashboard",
    "/jugadores",
    "/jugadores/nuevo",
    "/equipos",
    "/equipos/1/plantel",
    "/complejos",
    "/partidos",
    "/partidos/nuevo",
    "/planillas",
    "/planillas/1",
    "/sanciones",
    "/sanciones/nueva",
    "/reportes?torneo=2",
]

for url in admin_urls:
    response = client.get(url)
    assert response.status_code == 200, f"Falló {url}: {response.status_code}"

client.post("/logout")
response = client.post(
    "/login",
    data={"email": "planillero@torneo.ucu", "password": "PlanillaApp_2026!"},
    follow_redirects=True,
)
assert response.status_code == 200
assert client.get("/planillas").status_code == 200
assert client.get("/jugadores").status_code == 302

print("SMOKE_TEST_OK")
