-- =====================================================================
-- Torneo Interfacultades de Fútbol 5 - UCU
-- Base de Datos 1 - Segundo Semestre 2026
-- Script 05: reportes (MySQL 8.0+)
--
-- Ejecutar DESPUÉS de 01, 02, 03 y 04. Crea dos vistas auxiliares y luego
-- ejecuta los 12 reportes sobre la edición indicada en @torneo.
-- Con los datos de 02_datos_prueba.sql, cada reporte indica el resultado
-- esperado en un comentario.
--
-- En la aplicación, @torneo pasa a ser un parámetro de la consulta (%s).
--
-- Reportes de la letra: 1 a 9. Reportes adicionales propuestos: 10 a 12.
-- =====================================================================

USE torneo_f5;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Vistas auxiliares
-- El resultado de un partido se calcula a partir de los goles
-- registrados; un autogol suma al rival del equipo del jugador.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_resultado_partido AS
SELECT p.id_partido, p.id_torneo, p.numero_fecha,
       p.id_equipo_local, p.id_equipo_visitante,
       COUNT(CASE WHEN (pl.id_equipo = p.id_equipo_local     AND g.autogol = 0)
                    OR (pl.id_equipo = p.id_equipo_visitante AND g.autogol = 1)
                  THEN 1 END) AS goles_local,
       COUNT(CASE WHEN (pl.id_equipo = p.id_equipo_visitante AND g.autogol = 0)
                    OR (pl.id_equipo = p.id_equipo_local     AND g.autogol = 1)
                  THEN 1 END) AS goles_visitante
  FROM partido p
  LEFT JOIN gol g              ON g.id_partido  = p.id_partido
  LEFT JOIN planilla_partido pl ON pl.id_partido = g.id_partido
                               AND pl.ci_jugador = g.ci_jugador
 WHERE p.estado = 'jugado'
 GROUP BY p.id_partido;

-- Una fila por equipo y partido jugado (gf = goles a favor, gc = en contra)
CREATE OR REPLACE VIEW v_resultado_equipo AS
SELECT id_torneo, id_partido, numero_fecha,
       id_equipo_local AS id_equipo,
       goles_local AS gf, goles_visitante AS gc
  FROM v_resultado_partido
UNION ALL
SELECT id_torneo, id_partido, numero_fecha,
       id_equipo_visitante, goles_visitante, goles_local
  FROM v_resultado_partido;

-- Edición a consultar (2 = Semestre 2 de 2026 en los datos de prueba)
SET @torneo = 2;

-- =====================================================================
-- 1) Tabla de posiciones
--    Orden: puntos, diferencia de goles, goles a favor.
-- =====================================================================
SELECT x.equipo, x.pj, x.pg, x.pe, x.pp, x.gf, x.gc,
       x.gf - x.gc AS dg,
       x.pg * 3 + x.pe AS pts
  FROM (SELECT e.id_equipo, e.nombre AS equipo,
               COUNT(r.id_partido)                          AS pj,
               COUNT(CASE WHEN r.gf >  r.gc THEN 1 END)     AS pg,
               COUNT(CASE WHEN r.gf =  r.gc THEN 1 END)     AS pe,
               COUNT(CASE WHEN r.gf <  r.gc THEN 1 END)     AS pp,
               COALESCE(SUM(r.gf), 0)                       AS gf,
               COALESCE(SUM(r.gc), 0)                       AS gc
          FROM equipo e
          LEFT JOIN v_resultado_equipo r ON r.id_equipo = e.id_equipo
         WHERE e.id_torneo = @torneo
         GROUP BY e.id_equipo, e.nombre) x
 ORDER BY pts DESC, dg DESC, gf DESC, equipo;
-- ESPERADO:
--   Los Contables    PJ 3 G 2 E 1 P 0 GF 8 GC 3 DG +5 Pts 7
--   Mente Sana FC    PJ 3 G 2 E 1 P 0 GF 7 GC 3 DG +4 Pts 7
--   Ingenieros FC    PJ 3 G 2 E 1 P 0 GF 6 GC 3 DG +3 Pts 7
--   Salud Total      PJ 3 G 1 E 1 P 1 GF 5 GC 3 DG +2 Pts 4
--   Humanistas FC    PJ 3 G 0 E 0 P 3 GF 2 GC 8 DG -6 Pts 0
--   Derecho United   PJ 3 G 0 E 0 P 3 GF 1 GC 9 DG -8 Pts 0

-- =====================================================================
-- 2) Tabla de goleadores (top 10; los autogoles no cuentan al jugador)
-- =====================================================================
SELECT j.ci,
       CONCAT(j.nombre, ' ', j.apellido) AS jugador,
       e.nombre                          AS equipo,
       COUNT(*)                          AS goles
  FROM gol g
  JOIN partido p                 ON p.id_partido = g.id_partido
  JOIN jugador j                 ON j.ci = g.ci_jugador
  JOIN equipo_jugador_torneo ej  ON ej.ci_jugador = j.ci AND ej.id_torneo = p.id_torneo
  JOIN equipo e                  ON e.id_equipo = ej.id_equipo
 WHERE p.id_torneo = @torneo
   AND g.autogol = 0
 GROUP BY j.ci, j.nombre, j.apellido, e.nombre
 ORDER BY goles DESC, jugador
 LIMIT 10;
-- ESPERADO (hay muchos jugadores con 1 gol, por eso el décimo puesto
-- se desempata por nombre):
--   4 goles  Santiago Cabrera (Ingenieros FC)
--   4 goles  Valentín Rossi (Mente Sana FC)
--   3 goles  Felipe Correa (Salud Total)
--   3 goles  Martín Fernández (Los Contables)
--   2 goles  Diego Castro (Los Contables)
--   2 goles  Leandro González (Mente Sana FC)
--   2 goles  Tomás Díaz (Los Contables)
--   1 goles  Ariel Núñez (Humanistas FC)
--   1 goles  Darío Barrios (Humanistas FC)
--   1 goles  Ezequiel Bentancor (Salud Total)

-- =====================================================================
-- 3) Fair play por equipo: 1 punto por amarilla, 3 por roja.
--    El mejor equipo es el de menor puntaje.
-- =====================================================================
SELECT e.nombre AS equipo,
       COUNT(CASE WHEN t.color = 'amarilla' THEN 1 END) AS amarillas,
       COUNT(CASE WHEN t.color = 'roja'     THEN 1 END) AS rojas,
       COUNT(CASE WHEN t.color = 'amarilla' THEN 1 END)
         + 3 * COUNT(CASE WHEN t.color = 'roja' THEN 1 END) AS puntos_fair_play
  FROM equipo e
  LEFT JOIN planilla_partido pl ON pl.id_equipo = e.id_equipo
  LEFT JOIN tarjeta t           ON t.id_partido = pl.id_partido
                               AND t.ci_jugador = pl.ci_jugador
 WHERE e.id_torneo = @torneo
 GROUP BY e.id_equipo, e.nombre
 ORDER BY puntos_fair_play ASC, equipo;
-- ESPERADO (el primero es el mejor fair play; el orden entre iguales es alfabético):
--   Los Contables    amarillas 2 rojas 0 puntos 2
--   Ingenieros FC    amarillas 3 rojas 0 puntos 3
--   Salud Total      amarillas 3 rojas 0 puntos 3
--   Derecho United   amarillas 5 rojas 0 puntos 5
--   Mente Sana FC    amarillas 2 rojas 1 puntos 5
--   Humanistas FC    amarillas 3 rojas 1 puntos 6

-- =====================================================================
-- 4) Promedio de goles por partido, por fecha y en toda la edición
-- =====================================================================
SELECT fecha, partidos, goles, promedio
  FROM (SELECT numero_fecha AS orden,
               CONCAT('Fecha ', numero_fecha) AS fecha,
               COUNT(*) AS partidos,
               SUM(goles_local + goles_visitante) AS goles,
               ROUND(AVG(goles_local + goles_visitante), 2) AS promedio
          FROM v_resultado_partido
         WHERE id_torneo = @torneo
         GROUP BY numero_fecha
        UNION ALL
        SELECT 999, 'Toda la edición',
               COUNT(*),
               SUM(goles_local + goles_visitante),
               ROUND(AVG(goles_local + goles_visitante), 2)
          FROM v_resultado_partido
         WHERE id_torneo = @torneo) x
 ORDER BY orden;
-- ESPERADO:
--   Fecha 1: 3 partidos, 10 goles, promedio 3.33
--   Fecha 2: 3 partidos, 10 goles, promedio 3.33
--   Fecha 3: 3 partidos, 9 goles, promedio 3.00
--   Toda la edición: 9 partidos, 29 goles, promedio 3.22

-- =====================================================================
-- 5a) Canchas más utilizadas (partidos programados o jugados)
-- =====================================================================
SELECT c.nombre AS complejo, p.nombre_cancha AS cancha, COUNT(*) AS partidos
  FROM partido p
  JOIN complejo c ON c.id_complejo = p.id_complejo
 WHERE p.id_torneo = @torneo
   AND p.estado IN ('programado', 'jugado')
 GROUP BY c.id_complejo, c.nombre, p.nombre_cancha
 ORDER BY partidos DESC, complejo, cancha;
-- ESPERADO:
--   Complejo Cancha Central / Cancha 1: 6
--   Complejo Cancha Central / Cancha 2: 3
--   Parque Deportivo Ruta 8 / Cancha Norte: 2
--   Arena 5 Malvín / Cancha A: 1
--   Arena 5 Malvín / Cancha B: 1
--   Parque Deportivo Ruta 8 / Cancha Sur: 1

-- 5b) Turnos más utilizados
SELECT CONCAT(TIME_FORMAT(t.hora_inicio, '%H:%i'), ' a ',
              TIME_FORMAT(t.hora_fin,    '%H:%i')) AS turno,
       COUNT(*) AS partidos
  FROM partido p
  JOIN turno t ON t.id_turno = p.id_turno
 WHERE p.id_torneo = @torneo
   AND p.estado IN ('programado', 'jugado')
 GROUP BY t.id_turno, t.hora_inicio, t.hora_fin
 ORDER BY partidos DESC, t.hora_inicio;
-- ESPERADO (turnos sin partidos no aparecen):
--   20:00: 10
--   19:00: 2
--   21:00: 2

-- =====================================================================
-- 6) Cantidad de jugadores por facultad y por tipo
--    (todos los jugadores registrados)
-- =====================================================================
SELECT f.nombre AS facultad,
       COUNT(j.ci) AS total,
       COUNT(CASE WHEN j.tipo = 'grado'       THEN 1 END) AS grado,
       COUNT(CASE WHEN j.tipo = 'posgrado'    THEN 1 END) AS posgrado,
       COUNT(CASE WHEN j.tipo = 'docente'     THEN 1 END) AS docente,
       COUNT(CASE WHEN j.tipo = 'funcionario' THEN 1 END) AS funcionario
  FROM facultad f
  LEFT JOIN jugador j ON j.id_facultad = f.id_facultad
 GROUP BY f.id_facultad, f.nombre
 ORDER BY f.nombre;
-- ESPERADO: 6 facultades con 7 jugadores cada una (42 en total)

-- =====================================================================
-- 7) Jugadores inscriptos en un plantel que nunca figuraron en una planilla
-- =====================================================================
SELECT j.ci,
       CONCAT(j.nombre, ' ', j.apellido) AS jugador,
       e.nombre AS equipo,
       j.tipo,
       ej.numero_camiseta
  FROM equipo_jugador_torneo ej
  JOIN jugador j ON j.ci = ej.ci_jugador
  JOIN equipo e  ON e.id_equipo = ej.id_equipo
 WHERE ej.id_torneo = @torneo
   AND NOT EXISTS (SELECT 1
                     FROM planilla_partido pl
                    WHERE pl.ci_jugador = ej.ci_jugador
                      AND pl.id_equipo  = ej.id_equipo)
 ORDER BY equipo, jugador;
-- ESPERADO (9 jugadores):
--   Bruno Machado (Ingenieros FC)
--   Emiliano Cardozo (Los Contables)
--   Pablo Olivera (Derecho United)
--   Camilo Suárez (Mente Sana FC)
--   Álvaro Techera (Mente Sana FC)
--   Gustavo Rodríguez (Salud Total)
--   Hernán Martínez (Salud Total)
--   Mauricio Ibarra (Humanistas FC)
--   Pedro Benítez (Humanistas FC)

-- =====================================================================
-- 8) Cantidad de sanciones por equipo y por motivo
-- =====================================================================
SELECT e.nombre AS equipo,
       s.motivo,
       COUNT(*) AS sanciones,
       SUM(s.cantidad_fechas) AS fechas_de_suspension
  FROM sancion_jugador s
  JOIN equipo_jugador_torneo ej ON ej.ci_jugador = s.ci_jugador
                               AND ej.id_torneo  = s.id_torneo
  JOIN equipo e                 ON e.id_equipo = ej.id_equipo
 WHERE s.id_torneo = @torneo
 GROUP BY e.id_equipo, e.nombre, s.motivo
 ORDER BY equipo, s.motivo;
-- ESPERADO (cantidad de sanciones):
--   Derecho United   acumulacion_amarillas: 1
--   Humanistas FC    acumulacion_amarillas: 1
--   Humanistas FC    roja: 1
--   Ingenieros FC    disciplinaria: 1
--   Mente Sana FC    roja: 1
--   Salud Total      disciplinaria: 1

-- =====================================================================
-- 9) Porcentaje de partidos jugados vs. postergados/cancelados
--    Los porcentajes se calculan sobre jugados + postergados + cancelados;
--    los partidos aún programados se informan aparte.
-- =====================================================================
SELECT COUNT(CASE WHEN estado = 'jugado'     THEN 1 END) AS jugados,
       COUNT(CASE WHEN estado = 'postergado' THEN 1 END) AS postergados,
       COUNT(CASE WHEN estado = 'cancelado'  THEN 1 END) AS cancelados,
       COUNT(CASE WHEN estado = 'programado' THEN 1 END) AS programados_pendientes,
       ROUND(100 * COUNT(CASE WHEN estado = 'jugado' THEN 1 END)
             / NULLIF(COUNT(CASE WHEN estado <> 'programado' THEN 1 END), 0), 2) AS pct_jugados,
       ROUND(100 * COUNT(CASE WHEN estado IN ('postergado', 'cancelado') THEN 1 END)
             / NULLIF(COUNT(CASE WHEN estado <> 'programado' THEN 1 END), 0), 2) AS pct_postergados_cancelados
  FROM partido
 WHERE id_torneo = @torneo;
-- ESPERADO: jugados 9, postergados 1, cancelados 1, programados 5,
--           pct_jugados 81.82, pct_postergados_cancelados 18.18

-- =====================================================================
-- REPORTES ADICIONALES PROPUESTOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 10) Fixture con resultados: todos los partidos de la edición con su
--     cancha, turno, estado y marcador (si ya se jugó).
--     Útil para la organización y para comunicar el calendario.
-- ---------------------------------------------------------------------
SELECT p.numero_fecha AS fecha,
       p.dia,
       CONCAT(TIME_FORMAT(t.hora_inicio, '%H:%i'), '-',
              TIME_FORMAT(t.hora_fin,    '%H:%i')) AS turno,
       c.nombre AS complejo,
       p.nombre_cancha AS cancha,
       el.nombre AS local,
       ev.nombre AS visitante,
       CONCAT(r.goles_local, ' - ', r.goles_visitante) AS resultado,
       p.estado
  FROM partido p
  JOIN turno t    ON t.id_turno = p.id_turno
  JOIN complejo c ON c.id_complejo = p.id_complejo
  JOIN equipo el  ON el.id_equipo = p.id_equipo_local
  JOIN equipo ev  ON ev.id_equipo = p.id_equipo_visitante
  LEFT JOIN v_resultado_partido r ON r.id_partido = p.id_partido
 WHERE p.id_torneo = @torneo
 ORDER BY p.numero_fecha, p.dia, t.hora_inicio;
-- ESPERADO: 16 partidos (9 con resultado)

-- ---------------------------------------------------------------------
-- 11a) Jugadores suspendidos en la próxima fecha a disputarse.
--      Ayuda a los planilleros y capitanes a saber quién no puede jugar.
-- ---------------------------------------------------------------------
SET @proxima_fecha = (SELECT MIN(numero_fecha)
                        FROM partido
                       WHERE id_torneo = @torneo AND estado = 'programado');

SELECT @proxima_fecha AS proxima_fecha,
       CONCAT(j.nombre, ' ', j.apellido) AS jugador,
       e.nombre AS equipo,
       s.motivo,
       s.numero_fecha_inicio AS desde_fecha,
       s.numero_fecha_inicio + s.cantidad_fechas - 1 AS hasta_fecha
  FROM sancion_jugador s
  JOIN jugador j                ON j.ci = s.ci_jugador
  JOIN equipo_jugador_torneo ej ON ej.ci_jugador = s.ci_jugador
                               AND ej.id_torneo  = s.id_torneo
  JOIN equipo e                 ON e.id_equipo = ej.id_equipo
 WHERE s.id_torneo = @torneo
   AND @proxima_fecha BETWEEN s.numero_fecha_inicio
                          AND s.numero_fecha_inicio + s.cantidad_fechas - 1
 ORDER BY equipo, jugador;
-- ESPERADO (próxima fecha = 4): 4 jugadores
--   2 por acumulación de amarillas (Derecho United y Humanistas),
--   1 por roja (Mente Sana) y 1 disciplinaria (Ingenieros, fechas 4 a 5)

-- 11b) Amarillas acumuladas y cuántas faltan para la próxima suspensión
SELECT CONCAT(j.nombre, ' ', j.apellido) AS jugador,
       e.nombre AS equipo,
       COUNT(*) AS amarillas,
       3 - (COUNT(*) MOD 3) AS faltan_para_suspension
  FROM tarjeta t
  JOIN partido p          ON p.id_partido = t.id_partido
  JOIN jugador j          ON j.ci = t.ci_jugador
  JOIN planilla_partido pl ON pl.id_partido = t.id_partido
                          AND pl.ci_jugador = t.ci_jugador
  JOIN equipo e           ON e.id_equipo = pl.id_equipo
 WHERE p.id_torneo = @torneo
   AND t.color = 'amarilla'
 GROUP BY j.ci, j.nombre, j.apellido, e.id_equipo, e.nombre
HAVING COUNT(*) MOD 3 <> 0
 ORDER BY amarillas DESC, faltan_para_suspension, equipo, jugador;
-- ESPERADO: jugadores con 1 amarilla (faltan 2), ninguno con 2 en estos datos

-- ---------------------------------------------------------------------
-- 12) Participación de jugadores: en cuántos de los partidos jugados de
--     su equipo figuraron en la planilla. Permite detectar planteles
--     con jugadores que nunca juegan o que concentran los minutos.
-- ---------------------------------------------------------------------
SELECT CONCAT(j.nombre, ' ', j.apellido) AS jugador,
       e.nombre AS equipo,
       COUNT(pl.id_partido) AS partidos_en_planilla,
       (SELECT COUNT(*) FROM v_resultado_equipo r
         WHERE r.id_equipo = e.id_equipo) AS partidos_del_equipo,
       ROUND(100 * COUNT(pl.id_partido)
             / NULLIF((SELECT COUNT(*) FROM v_resultado_equipo r
                        WHERE r.id_equipo = e.id_equipo), 0), 1) AS pct_participacion
  FROM equipo_jugador_torneo ej
  JOIN jugador j ON j.ci = ej.ci_jugador
  JOIN equipo e  ON e.id_equipo = ej.id_equipo
  LEFT JOIN planilla_partido pl ON pl.ci_jugador = ej.ci_jugador
                               AND pl.id_equipo  = ej.id_equipo
 WHERE ej.id_torneo = @torneo
 GROUP BY j.ci, j.nombre, j.apellido, e.id_equipo, e.nombre
 ORDER BY partidos_en_planilla DESC, equipo, jugador;
-- ESPERADO: 42 filas; los jugadores 1 a 5 de cada equipo con 100%, salvo los
--           2 que estuvieron suspendidos en una fecha (66.7%)
