from flask import Blueprint, render_template, request

from .auth import role_required
from .db import fetch_all


reports_bp = Blueprint("reports", __name__, url_prefix="/reportes")


REPORTS = [
    ("1. Tabla de posiciones", """
      SELECT e.nombre AS equipo,COUNT(r.id_partido) pj,
       COUNT(CASE WHEN r.gf>r.gc THEN 1 END) pg,COUNT(CASE WHEN r.gf=r.gc THEN 1 END) pe,
       COUNT(CASE WHEN r.gf<r.gc THEN 1 END) pp,COALESCE(SUM(r.gf),0) gf,
       COALESCE(SUM(r.gc),0) gc,COALESCE(SUM(r.gf-r.gc),0) dg,
       COUNT(CASE WHEN r.gf>r.gc THEN 1 END)*3+COUNT(CASE WHEN r.gf=r.gc THEN 1 END) puntos
      FROM equipo e LEFT JOIN v_resultado_equipo r ON r.id_equipo=e.id_equipo
      WHERE e.id_torneo=%s GROUP BY e.id_equipo,e.nombre
      ORDER BY puntos DESC,dg DESC,gf DESC,e.nombre""", 1),
    ("2. Goleadores", """
      SELECT CONCAT(j.nombre,' ',j.apellido) jugador,e.nombre equipo,COUNT(*) goles
      FROM gol g JOIN partido p USING(id_partido) JOIN jugador j ON j.ci=g.ci_jugador
      JOIN equipo_jugador_torneo ej ON ej.ci_jugador=j.ci AND ej.id_torneo=p.id_torneo
      JOIN equipo e ON e.id_equipo=ej.id_equipo
      WHERE p.id_torneo=%s AND g.autogol=0 GROUP BY j.ci,j.nombre,j.apellido,e.nombre
      ORDER BY goles DESC,jugador LIMIT 10""", 1),
    ("3. Fair play", """
      SELECT e.nombre equipo,COUNT(CASE WHEN ta.color='amarilla' THEN 1 END) amarillas,
       COUNT(CASE WHEN ta.color='roja' THEN 1 END) rojas,
       COUNT(CASE WHEN ta.color='amarilla' THEN 1 END)+3*COUNT(CASE WHEN ta.color='roja' THEN 1 END) puntos
      FROM equipo e LEFT JOIN planilla_partido pl ON pl.id_equipo=e.id_equipo
      LEFT JOIN tarjeta ta ON ta.id_partido=pl.id_partido AND ta.ci_jugador=pl.ci_jugador
      WHERE e.id_torneo=%s GROUP BY e.id_equipo,e.nombre ORDER BY puntos,e.nombre""", 1),
    ("4. Promedio de goles por fecha", """
      SELECT numero_fecha fecha,COUNT(*) partidos,SUM(goles_local+goles_visitante) goles,
       ROUND(AVG(goles_local+goles_visitante),2) promedio
      FROM v_resultado_partido WHERE id_torneo=%s GROUP BY numero_fecha ORDER BY numero_fecha""", 1),
    ("5A. Canchas más utilizadas", """
      SELECT co.nombre complejo,p.nombre_cancha cancha,COUNT(*) partidos FROM partido p
      JOIN complejo co USING(id_complejo) WHERE p.id_torneo=%s AND p.estado IN('programado','jugado')
      GROUP BY co.id_complejo,co.nombre,p.nombre_cancha ORDER BY partidos DESC""", 1),
    ("5B. Turnos más utilizados", """
      SELECT CONCAT(TIME_FORMAT(t.hora_inicio,'%%H:%%i'),' a ',TIME_FORMAT(t.hora_fin,'%%H:%%i')) turno,
       COUNT(*) partidos FROM partido p JOIN turno t USING(id_turno)
      WHERE p.id_torneo=%s AND p.estado IN('programado','jugado')
      GROUP BY t.id_turno,t.hora_inicio,t.hora_fin ORDER BY partidos DESC""", 1),
    ("6. Jugadores por facultad y tipo", """
      SELECT f.nombre facultad,COUNT(j.ci) total,
       COUNT(CASE WHEN j.tipo='grado' THEN 1 END) grado,
       COUNT(CASE WHEN j.tipo='posgrado' THEN 1 END) posgrado,
       COUNT(CASE WHEN j.tipo='docente' THEN 1 END) docente,
       COUNT(CASE WHEN j.tipo='funcionario' THEN 1 END) funcionario
      FROM facultad f LEFT JOIN jugador j USING(id_facultad)
      GROUP BY f.id_facultad,f.nombre ORDER BY f.nombre""", 0),
    ("7. Jugadores que nunca jugaron", """
      SELECT CONCAT(j.nombre,' ',j.apellido) jugador,e.nombre equipo,j.tipo,ej.numero_camiseta
      FROM equipo_jugador_torneo ej JOIN jugador j ON j.ci=ej.ci_jugador
      JOIN equipo e USING(id_equipo) WHERE ej.id_torneo=%s AND NOT EXISTS(
       SELECT 1 FROM planilla_partido pl WHERE pl.ci_jugador=ej.ci_jugador AND pl.id_equipo=ej.id_equipo)
      ORDER BY e.nombre,jugador""", 1),
    ("8. Sanciones por equipo y motivo", """
      SELECT e.nombre equipo,s.motivo,COUNT(*) sanciones,SUM(s.cantidad_fechas) fechas
      FROM sancion_jugador s JOIN equipo_jugador_torneo ej ON ej.ci_jugador=s.ci_jugador AND ej.id_torneo=s.id_torneo
      JOIN equipo e USING(id_equipo) WHERE s.id_torneo=%s
      GROUP BY e.id_equipo,e.nombre,s.motivo ORDER BY e.nombre,s.motivo""", 1),
    ("9. Estado de los partidos", """
      SELECT COUNT(CASE WHEN estado='jugado' THEN 1 END) jugados,
       COUNT(CASE WHEN estado='postergado' THEN 1 END) postergados,
       COUNT(CASE WHEN estado='cancelado' THEN 1 END) cancelados,
       COUNT(CASE WHEN estado='programado' THEN 1 END) pendientes,
       ROUND(100*COUNT(CASE WHEN estado='jugado' THEN 1 END)/NULLIF(COUNT(CASE WHEN estado<>'programado' THEN 1 END),0),2) porcentaje_jugados
      FROM partido WHERE id_torneo=%s""", 1),
    ("10. Fixture con resultados", """
      SELECT p.numero_fecha fecha,p.dia,el.nombre local,ev.nombre visitante,
       CONCAT(COALESCE(r.goles_local,'-'),' - ',COALESCE(r.goles_visitante,'-')) resultado,p.estado
      FROM partido p JOIN equipo el ON el.id_equipo=p.id_equipo_local
      JOIN equipo ev ON ev.id_equipo=p.id_equipo_visitante LEFT JOIN v_resultado_partido r USING(id_partido)
      WHERE p.id_torneo=%s ORDER BY p.numero_fecha,p.dia""", 1),
    ("11. Suspendidos en la próxima fecha", """
      SELECT CONCAT(j.nombre,' ',j.apellido) jugador,e.nombre equipo,s.motivo,
       s.numero_fecha_inicio desde,s.numero_fecha_inicio+s.cantidad_fechas-1 hasta
      FROM sancion_jugador s JOIN jugador j ON j.ci=s.ci_jugador
      JOIN equipo_jugador_torneo ej ON ej.ci_jugador=s.ci_jugador AND ej.id_torneo=s.id_torneo
      JOIN equipo e USING(id_equipo) WHERE s.id_torneo=%s AND
       (SELECT MIN(numero_fecha) FROM partido WHERE id_torneo=%s AND estado='programado')
       BETWEEN s.numero_fecha_inicio AND s.numero_fecha_inicio+s.cantidad_fechas-1
      ORDER BY e.nombre,jugador""", 2),
    ("12. Participación de jugadores", """
      SELECT CONCAT(j.nombre,' ',j.apellido) jugador,e.nombre equipo,COUNT(pl.id_partido) participaciones
      FROM equipo_jugador_torneo ej JOIN jugador j ON j.ci=ej.ci_jugador JOIN equipo e USING(id_equipo)
      LEFT JOIN planilla_partido pl ON pl.ci_jugador=ej.ci_jugador AND pl.id_equipo=ej.id_equipo
      WHERE ej.id_torneo=%s GROUP BY j.ci,j.nombre,j.apellido,e.id_equipo,e.nombre
      ORDER BY participaciones DESC,e.nombre,jugador""", 1),
]


@reports_bp.get("")
@role_required("administrador")
def index():
    tournaments = fetch_all("SELECT id_torneo,nombre,anio,semestre FROM torneo ORDER BY anio DESC,semestre DESC")
    tournament_id = request.args.get("torneo", type=int)
    if not tournament_id and tournaments:
        tournament_id = tournaments[0]["id_torneo"]
    results = []
    if tournament_id:
        for title, sql, parameter_count in REPORTS:
            rows = fetch_all(sql, tuple([tournament_id] * parameter_count))
            results.append({"title": title, "rows": rows, "columns": list(rows[0].keys()) if rows else []})
    return render_template("reports.html", tournaments=tournaments, tournament_id=tournament_id, results=results)
