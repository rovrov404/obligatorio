# Torneo Interfacultades de Fútbol 5

Aplicación web del obligatorio de Base de Datos 1. Permite administrar el torneo, registrar planillas y consultar reportes.

## Tecnologías

- Python 3 y Flask.
- MySQL 8.
- MySQL Connector para consultas SQL directas.
- HTML, Jinja y CSS.
- bcrypt para contraseñas.
- pytest para pruebas.
- Docker y Docker Compose como forma opcional de ejecución.

No se utiliza ORM.

## Funcionalidades

### Administrador

- ABM de jugadores.
- ABM de equipos y planteles.
- Asignación de capitán.
- ABM de complejos y canchas.
- ABM de partidos.
- Registro de planillas, goles y tarjetas.
- ABM de sanciones.
- Reportes solicitados y reportes adicionales.

### Planillero

- Consulta de partidos.
- Marcado de partidos como jugados.
- Registro de participantes, goles y tarjetas.
- No puede entrar en las pantallas administrativas.

Las reglas importantes también están controladas por claves, restricciones y triggers de MySQL.

## Ejecución normal en Windows

### 1. Preparar Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### 2. Configurar la aplicación

```powershell
Copy-Item .env.example .env
```

Revisar dentro de `.env` los datos de la conexión MySQL.

### 3. Crear la base

Ejecutar en MySQL, en orden, los archivos de `database`:

1. `01_schema.sql`
2. `02_datos_prueba.sql`
3. `03_triggers.sql`
4. `04_usuarios.sql`
5. `05_reportes.sql`
6. `06_login_app.sql`

### 4. Iniciar

```powershell
python run.py
```

Abrir <http://127.0.0.1:5000>.

## Usuarios de prueba

Administrador:

```text
admin@torneo.ucu
AdminApp_2026!
```

Planillero:

```text
planillero@torneo.ucu
PlanillaApp_2026!
```

## Pruebas

```powershell
pytest
$env:PYTHONPATH=(Get-Location).Path
python tools\smoke_test.py
```

## Docker

Con Docker Desktop abierto:

```powershell
docker compose up --build
```

La aplicación queda en <http://127.0.0.1:5000>. MySQL usa el puerto externo `3307` para no chocar con una instalación local.

Para detener:

```powershell
docker compose down
```

Para recrear la base desde cero:

```powershell
docker compose down -v
docker compose up --build
```

## Estructura

```text
app/
  auth.py          login y roles
  db.py            conexión y consultas
  players.py       jugadores
  teams.py         equipos y planteles
  venues.py        complejos y canchas
  matches.py       partidos
  sheets.py        planillas, goles y tarjetas
  sanctions.py     sanciones
  reports.py       reportes
  templates/       pantallas HTML
  static/          estilos CSS
database/          scripts MySQL
tests/             pruebas automáticas
tools/             herramientas auxiliares
```
