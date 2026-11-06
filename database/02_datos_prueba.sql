-- =====================================================================
-- Torneo Interfacultades de Fútbol 5 - UCU
-- Base de Datos 1 - Segundo Semestre 2026
-- Script 02: datos de prueba (MySQL 8.0+)
--
-- Requiere haber ejecutado antes 01_schema.sql.
-- ORDEN DE EJECUCIÓN: ejecutar ESTE script ANTES de crear los triggers
-- (o con los triggers deshabilitados). Las sanciones automáticas
-- (roja / 3 amarillas) ya se cargan acá a mano, y la planilla se inserta
-- con partidos que ya figuran como 'jugado'; con los triggers activos se
-- duplicarían sanciones o se rechazarían inserts.
--
-- Todos los datos (personas, CI, mails) son FICTICIOS.
--
-- Contenido:
--   * 6 facultades, 6 equipos (7 jugadores c/u), 42 jugadores
--   * 2 torneos: 2026-S1 (finalizado, vacío) y 2026-S2 (en curso)
--   * 3 complejos, 6 canchas
--   * 16 partidos: 9 jugados (fechas 1 a 3), 1 postergado, 1 cancelado,
--     5 programados (fechas 4 a 6; la 6 es la recuperación del cancelado)
--   * planillas, 29 goles (1 autogol), 20 tarjetas, 6 sanciones
-- =====================================================================

USE torneo_f5;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Facultades
-- ---------------------------------------------------------------------
INSERT INTO facultad (id_facultad, nombre) VALUES
    (1, 'Ingeniería y Tecnologías'),
    (2, 'Ciencias Empresariales'),
    (3, 'Derecho'),
    (4, 'Psicología'),
    (5, 'Ciencias de la Salud'),
    (6, 'Humanidades');

-- ---------------------------------------------------------------------
-- Jugadores (7 por equipo; CI sin puntos ni guión)
-- ---------------------------------------------------------------------
INSERT INTO jugador (ci, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo) VALUES
    ('4112468', 'Mateo', 'Pereira', 'mateo.pereira@correo.ucu.edu.uy', '2002-01-01', 1, 'grado'),
    ('4113825', 'Santiago', 'Cabrera', 'santiago.cabrera@correo.ucu.edu.uy', '2003-02-02', 1, 'grado'),
    ('4115182', 'Joaquín', 'Rivero', 'joaquin.rivero@correo.ucu.edu.uy', '2004-03-03', 1, 'grado'),
    ('4116539', 'Facundo', 'Méndez', 'facundo.mendez@correo.ucu.edu.uy', '2002-04-04', 1, 'grado'),
    ('4117896', 'Nicolás', 'Rocha', 'nicolas.rocha@correo.ucu.edu.uy', '2003-05-05', 1, 'grado'),
    ('4119253', 'Agustín', 'Giménez', 'agustin.gimenez@correo.ucu.edu.uy', '1999-06-06', 1, 'posgrado'),
    ('4120610', 'Bruno', 'Machado', 'bruno.machado@correo.ucu.edu.uy', '1980-07-07', 1, 'docente'),
    ('4223579', 'Lucas', 'Mora', 'lucas.mora@correo.ucu.edu.uy', '2003-08-08', 2, 'grado'),
    ('4224936', 'Martín', 'Fernández', 'martin.fernandez@correo.ucu.edu.uy', '2004-09-09', 2, 'grado'),
    ('4226293', 'Tomás', 'Díaz', 'tomas.diaz@correo.ucu.edu.uy', '2002-10-10', 2, 'grado'),
    ('4227650', 'Diego', 'Castro', 'diego.castro@correo.ucu.edu.uy', '2003-11-11', 2, 'grado'),
    ('4229007', 'Franco', 'Sosa', 'franco.sosa@correo.ucu.edu.uy', '2004-12-12', 2, 'grado'),
    ('4230364', 'Andrés', 'Ferreira', 'andres.ferreira@correo.ucu.edu.uy', '1980-01-13', 2, 'docente'),
    ('4231721', 'Emiliano', 'Cardozo', 'emiliano.cardozo@correo.ucu.edu.uy', '1986-02-14', 2, 'funcionario'),
    ('4334690', 'Rodrigo', 'Peralta', 'rodrigo.peralta@correo.ucu.edu.uy', '2004-03-15', 3, 'grado'),
    ('4336047', 'Gonzalo', 'Arrieta', 'gonzalo.arrieta@correo.ucu.edu.uy', '2002-04-16', 3, 'grado'),
    ('4337404', 'Sebastián', 'Paiva', 'sebastian.paiva@correo.ucu.edu.uy', '2003-05-17', 3, 'grado'),
    ('4338761', 'Ignacio', 'Silva', 'ignacio.silva@correo.ucu.edu.uy', '2004-06-18', 3, 'grado'),
    ('4340118', 'Federico', 'López', 'federico.lopez@correo.ucu.edu.uy', '2002-07-19', 3, 'grado'),
    ('4341475', 'Matías', 'Acosta', 'matias.acosta@correo.ucu.edu.uy', '1998-08-20', 3, 'posgrado'),
    ('4342832', 'Pablo', 'Olivera', 'pablo.olivera@correo.ucu.edu.uy', '2004-09-21', 3, 'grado'),
    ('4445801', 'Ramiro', 'Píriz', 'ramiro.piriz@correo.ucu.edu.uy', '2002-10-22', 4, 'grado'),
    ('4447158', 'Valentín', 'Rossi', 'valentin.rossi@correo.ucu.edu.uy', '2003-11-23', 4, 'grado'),
    ('4448515', 'Maximiliano', 'Duarte', 'maximiliano.duarte@correo.ucu.edu.uy', '2004-12-24', 4, 'grado'),
    ('4449872', 'Gabriel', 'Quintana', 'gabriel.quintana@correo.ucu.edu.uy', '2002-01-25', 4, 'grado'),
    ('4451229', 'Leandro', 'González', 'leandro.gonzalez@correo.ucu.edu.uy', '2003-02-26', 4, 'grado'),
    ('4452586', 'Camilo', 'Suárez', 'camilo.suarez@correo.ucu.edu.uy', '1999-03-27', 4, 'posgrado'),
    ('4453943', 'Álvaro', 'Techera', 'alvaro.techera@correo.ucu.edu.uy', '1985-04-01', 4, 'funcionario'),
    ('4556912', 'Felipe', 'Correa', 'felipe.correa@correo.ucu.edu.uy', '2003-05-02', 5, 'grado'),
    ('4558269', 'Cristian', 'Álvarez', 'cristian.alvarez@correo.ucu.edu.uy', '2004-06-03', 5, 'grado'),
    ('4559626', 'Ezequiel', 'Bentancor', 'ezequiel.bentancor@correo.ucu.edu.uy', '2002-07-04', 5, 'grado'),
    ('4560983', 'Lautaro', 'Vázquez', 'lautaro.vazquez@correo.ucu.edu.uy', '2003-08-05', 5, 'grado'),
    ('4562340', 'Marcelo', 'Lacuesta', 'marcelo.lacuesta@correo.ucu.edu.uy', '1999-09-06', 5, 'posgrado'),
    ('4563697', 'Gustavo', 'Rodríguez', 'gustavo.rodriguez@correo.ucu.edu.uy', '1997-10-07', 5, 'posgrado'),
    ('4565054', 'Hernán', 'Martínez', 'hernan.martinez@correo.ucu.edu.uy', '1981-11-08', 5, 'docente'),
    ('4668023', 'Ariel', 'Núñez', 'ariel.nunez@correo.ucu.edu.uy', '2004-12-09', 6, 'grado'),
    ('4669380', 'Julián', 'Moreira', 'julian.moreira@correo.ucu.edu.uy', '2002-01-10', 6, 'grado'),
    ('4670737', 'Darío', 'Barrios', 'dario.barrios@correo.ucu.edu.uy', '2003-02-11', 6, 'grado'),
    ('4672094', 'Esteban', 'Viera', 'esteban.viera@correo.ucu.edu.uy', '2004-03-12', 6, 'grado'),
    ('4673451', 'Fabián', 'Ramos', 'fabian.ramos@correo.ucu.edu.uy', '2002-04-13', 6, 'grado'),
    ('4674808', 'Mauricio', 'Ibarra', 'mauricio.ibarra@correo.ucu.edu.uy', '2003-05-14', 6, 'grado'),
    ('4676165', 'Pedro', 'Benítez', 'pedro.benitez@correo.ucu.edu.uy', '1982-06-15', 6, 'docente');

-- ---------------------------------------------------------------------
-- Torneos. El 2026-S2 se crea en 'inscripcion' para poder cargar los
-- planteles y luego pasa a 'en_curso'.
-- ---------------------------------------------------------------------
INSERT INTO torneo (id_torneo, nombre, anio, semestre, fecha_inicio, fecha_fin, estado) VALUES
    (1, 'Torneo Interfacultades F5 2026 - Semestre 1', 2026, 1, '2026-03-16', '2026-06-26', 'finalizado'),
    (2, 'Torneo Interfacultades F5 2026 - Semestre 2', 2026, 2, '2026-10-05', '2026-11-30', 'inscripcion');

-- ---------------------------------------------------------------------
-- Equipos (capitán se asigna después de cargar el plantel)
-- ---------------------------------------------------------------------
INSERT INTO equipo (id_equipo, nombre, id_torneo, id_facultad, ci_capitan) VALUES
    (1, 'Ingenieros FC', 2, 1, NULL),
    (2, 'Los Contables', 2, 2, NULL),
    (3, 'Derecho United', 2, 3, NULL),
    (4, 'Mente Sana FC', 2, 4, NULL),
    (5, 'Salud Total', 2, 5, NULL),
    (6, 'Humanistas FC', 2, 6, NULL);

-- ---------------------------------------------------------------------
-- Planteles (equipo_jugador_torneo)
-- ---------------------------------------------------------------------
INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
    (1, '4112468', 2, 1),
    (1, '4113825', 2, 7),
    (1, '4115182', 2, 9),
    (1, '4116539', 2, 10),
    (1, '4117896', 2, 11),
    (1, '4119253', 2, 5),
    (1, '4120610', 2, 3),
    (2, '4223579', 2, 1),
    (2, '4224936', 2, 7),
    (2, '4226293', 2, 9),
    (2, '4227650', 2, 10),
    (2, '4229007', 2, 11),
    (2, '4230364', 2, 5),
    (2, '4231721', 2, 3),
    (3, '4334690', 2, 1),
    (3, '4336047', 2, 7),
    (3, '4337404', 2, 9),
    (3, '4338761', 2, 10),
    (3, '4340118', 2, 11),
    (3, '4341475', 2, 5),
    (3, '4342832', 2, 3),
    (4, '4445801', 2, 1),
    (4, '4447158', 2, 7),
    (4, '4448515', 2, 9),
    (4, '4449872', 2, 10),
    (4, '4451229', 2, 11),
    (4, '4452586', 2, 5),
    (4, '4453943', 2, 3),
    (5, '4556912', 2, 1),
    (5, '4558269', 2, 7),
    (5, '4559626', 2, 9),
    (5, '4560983', 2, 10),
    (5, '4562340', 2, 11),
    (5, '4563697', 2, 5),
    (5, '4565054', 2, 3),
    (6, '4668023', 2, 1),
    (6, '4669380', 2, 7),
    (6, '4670737', 2, 9),
    (6, '4672094', 2, 10),
    (6, '4673451', 2, 11),
    (6, '4674808', 2, 5),
    (6, '4676165', 2, 3);

-- Capitanes: el jugador 1 de cada plantel

UPDATE equipo SET ci_capitan = '4112468' WHERE id_equipo = 1;
UPDATE equipo SET ci_capitan = '4223579' WHERE id_equipo = 2;
UPDATE equipo SET ci_capitan = '4334690' WHERE id_equipo = 3;
UPDATE equipo SET ci_capitan = '4445801' WHERE id_equipo = 4;
UPDATE equipo SET ci_capitan = '4556912' WHERE id_equipo = 5;
UPDATE equipo SET ci_capitan = '4668023' WHERE id_equipo = 6;

-- Cierre de la inscripción: el torneo pasa a 'en_curso'
UPDATE torneo SET estado = 'en_curso' WHERE id_torneo = 2;

-- ---------------------------------------------------------------------
-- Complejos y canchas
-- ---------------------------------------------------------------------
INSERT INTO complejo (id_complejo, nombre, direccion, departamento) VALUES
    (1, 'Complejo Cancha Central', 'Av. Italia 3300', 'Montevideo'),
    (2, 'Arena 5 Malvín', 'Bulevar Artigas 1500', 'Montevideo'),
    (3, 'Parque Deportivo Ruta 8', 'Ruta 8 km 17', 'Canelones');

INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
    ('Cancha 1', 1, 'sintetico', TRUE),
    ('Cancha 2', 1, 'sintetico', FALSE),
    ('Cancha A', 2, 'parquet', TRUE),
    ('Cancha B', 2, 'parquet', TRUE),
    ('Cancha Norte', 3, 'sintetico', FALSE),
    ('Cancha Sur', 3, 'sintetico', TRUE);

-- ---------------------------------------------------------------------
-- Partidos (id_turno: 1=18-19, 2=19-20, 3=20-21, 4=21-22, 5=22-23)
-- Fechas 1 a 3: jugados | fecha 4: programados + 1 postergado
-- Fecha 5: programados + 1 cancelado | fecha 6: recuperación del cancelado
-- ---------------------------------------------------------------------
INSERT INTO partido (id_partido, id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante, dia, id_turno, nombre_cancha, id_complejo, estado) VALUES
    (1, 2, 1, 1, 6, '2026-10-05', 3, 'Cancha 1', 1, 'jugado'),
    (2, 2, 1, 2, 5, '2026-10-05', 3, 'Cancha 2', 1, 'jugado'),
    (3, 2, 1, 3, 4, '2026-10-06', 2, 'Cancha A', 2, 'jugado'),
    (4, 2, 2, 1, 5, '2026-10-12', 3, 'Cancha 1', 1, 'jugado'),
    (5, 2, 2, 6, 4, '2026-10-12', 4, 'Cancha 1', 1, 'jugado'),
    (6, 2, 2, 2, 3, '2026-10-13', 3, 'Cancha B', 2, 'jugado'),
    (7, 2, 3, 1, 4, '2026-10-19', 3, 'Cancha 1', 1, 'jugado'),
    (8, 2, 3, 5, 3, '2026-10-19', 2, 'Cancha Norte', 3, 'jugado'),
    (9, 2, 3, 6, 2, '2026-10-20', 3, 'Cancha Sur', 3, 'jugado'),
    (10, 2, 4, 1, 3, '2026-11-02', 3, 'Cancha 1', 1, 'programado'),
    (11, 2, 4, 4, 2, '2026-11-03', 3, 'Cancha A', 2, 'postergado'),
    (12, 2, 4, 5, 6, '2026-11-02', 4, 'Cancha 2', 1, 'programado'),
    (13, 2, 5, 1, 2, '2026-11-09', 3, 'Cancha 1', 1, 'programado'),
    (14, 2, 5, 3, 6, '2026-11-09', 2, 'Cancha B', 2, 'cancelado'),
    (15, 2, 5, 4, 5, '2026-11-10', 3, 'Cancha Norte', 3, 'programado'),
    (16, 2, 6, 3, 6, '2026-11-17', 3, 'Cancha 2', 1, 'programado');

-- ---------------------------------------------------------------------
-- Planillas de juego (solo partidos jugados)
-- Excluidos por suspensión: Humanistas (jugador 2) en el partido 9 y
-- Salud Total (jugador 5) en el partido 4.
-- Los jugadores 7 de cada plantel nunca figuran (reporte 'nunca jugaron').
-- ---------------------------------------------------------------------
INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo) VALUES
    (1, '4112468', 1),
    (1, '4113825', 1),
    (1, '4115182', 1),
    (1, '4116539', 1),
    (1, '4117896', 1),
    (1, '4119253', 1),
    (1, '4668023', 6),
    (1, '4669380', 6),
    (1, '4670737', 6),
    (1, '4672094', 6),
    (1, '4673451', 6),
    (2, '4223579', 2),
    (2, '4224936', 2),
    (2, '4226293', 2),
    (2, '4227650', 2),
    (2, '4229007', 2),
    (2, '4230364', 2),
    (2, '4556912', 5),
    (2, '4558269', 5),
    (2, '4559626', 5),
    (2, '4560983', 5),
    (2, '4562340', 5),
    (3, '4334690', 3),
    (3, '4336047', 3),
    (3, '4337404', 3),
    (3, '4338761', 3),
    (3, '4340118', 3),
    (3, '4341475', 3),
    (3, '4445801', 4),
    (3, '4447158', 4),
    (3, '4448515', 4),
    (3, '4449872', 4),
    (3, '4451229', 4),
    (4, '4112468', 1),
    (4, '4113825', 1),
    (4, '4115182', 1),
    (4, '4116539', 1),
    (4, '4117896', 1),
    (4, '4556912', 5),
    (4, '4558269', 5),
    (4, '4559626', 5),
    (4, '4560983', 5),
    (5, '4668023', 6),
    (5, '4669380', 6),
    (5, '4670737', 6),
    (5, '4672094', 6),
    (5, '4673451', 6),
    (5, '4445801', 4),
    (5, '4447158', 4),
    (5, '4448515', 4),
    (5, '4449872', 4),
    (5, '4451229', 4),
    (6, '4223579', 2),
    (6, '4224936', 2),
    (6, '4226293', 2),
    (6, '4227650', 2),
    (6, '4229007', 2),
    (6, '4230364', 2),
    (6, '4334690', 3),
    (6, '4336047', 3),
    (6, '4337404', 3),
    (6, '4338761', 3),
    (6, '4340118', 3),
    (7, '4112468', 1),
    (7, '4113825', 1),
    (7, '4115182', 1),
    (7, '4116539', 1),
    (7, '4117896', 1),
    (7, '4119253', 1),
    (7, '4445801', 4),
    (7, '4447158', 4),
    (7, '4448515', 4),
    (7, '4449872', 4),
    (7, '4451229', 4),
    (8, '4556912', 5),
    (8, '4558269', 5),
    (8, '4559626', 5),
    (8, '4560983', 5),
    (8, '4562340', 5),
    (8, '4334690', 3),
    (8, '4336047', 3),
    (8, '4337404', 3),
    (8, '4338761', 3),
    (8, '4340118', 3),
    (9, '4668023', 6),
    (9, '4670737', 6),
    (9, '4672094', 6),
    (9, '4673451', 6),
    (9, '4223579', 2),
    (9, '4224936', 2),
    (9, '4226293', 2),
    (9, '4227650', 2),
    (9, '4229007', 2);

-- ---------------------------------------------------------------------
-- Goles (el autogol del partido 6 suma al rival del jugador)
-- Resultados: P1 1-6 = 3-1; P2 2-5 = 2-2; P3 3-4 = 0-2; P4 1-5 = 1-0; P5 6-4 = 1-3; P6 2-3 = 4-1; P7 1-4 = 2-2; P8 5-3 = 3-0; P9 6-2 = 0-2
-- ---------------------------------------------------------------------
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
    (1, '4113825', 5, FALSE),
    (1, '4113825', 18, FALSE),
    (1, '4115182', 33, FALSE),
    (1, '4668023', 27, FALSE),
    (2, '4224936', 8, FALSE),
    (2, '4556912', 15, FALSE),
    (2, '4559626', 25, FALSE),
    (2, '4227650', 36, FALSE),
    (3, '4447158', 12, FALSE),
    (3, '4451229', 30, FALSE),
    (4, '4113825', 22, FALSE),
    (5, '4670737', 10, FALSE),
    (5, '4447158', 14, FALSE),
    (5, '4447158', 29, FALSE),
    (5, '4448515', 38, FALSE),
    (6, '4224936', 6, FALSE),
    (6, '4226293', 19, FALSE),
    (6, '4224936', 28, FALSE),
    (6, '4336047', 33, FALSE),
    (6, '4340118', 37, TRUE),
    (7, '4113825', 9, FALSE),
    (7, '4447158', 17, FALSE),
    (7, '4116539', 31, FALSE),
    (7, '4451229', 39, FALSE),
    (8, '4556912', 11, FALSE),
    (8, '4556912', 24, FALSE),
    (8, '4560983', 35, FALSE),
    (9, '4226293', 14, FALSE),
    (9, '4227650', 26, FALSE);

-- ---------------------------------------------------------------------
-- Tarjetas
-- ---------------------------------------------------------------------
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
    (1, '4117896', 20, 'amarilla'),
    (1, '4672094', 31, 'amarilla'),
    (2, '4229007', 12, 'amarilla'),
    (2, '4558269', 28, 'amarilla'),
    (3, '4337404', 15, 'amarilla'),
    (3, '4334690', 33, 'amarilla'),
    (4, '4115182', 18, 'amarilla'),
    (4, '4559626', 35, 'amarilla'),
    (5, '4669380', 35, 'roja'),
    (5, '4672094', 22, 'amarilla'),
    (5, '4451229', 5, 'amarilla'),
    (6, '4337404', 20, 'amarilla'),
    (6, '4223579', 9, 'amarilla'),
    (7, '4116539', 25, 'amarilla'),
    (7, '4449872', 29, 'amarilla'),
    (7, '4445801', 38, 'roja'),
    (8, '4337404', 30, 'amarilla'),
    (8, '4560983', 8, 'amarilla'),
    (8, '4338761', 37, 'amarilla'),
    (9, '4672094', 16, 'amarilla');

-- ---------------------------------------------------------------------
-- Sanciones
--   * roja: Humanistas j2 (partido 5, fecha 2 -> suspendido fecha 3)
--           Mente Sana j1 (partido 7, fecha 3 -> suspendido fecha 4)
--   * acumulación de amarillas (3 en la edición):
--           Derecho United j3 (partidos 3, 6 y 8) y Humanistas j4 (1, 5 y 9)
--   * disciplinarias (cargadas por la organización):
--           Ingenieros j5, 2 fechas desde la fecha 4
--           Salud Total j5, 1 fecha en la fecha 2
-- ---------------------------------------------------------------------
INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas) VALUES
    ('4669380', 2, 'roja', 3, 1),
    ('4337404', 2, 'acumulacion_amarillas', 4, 1),
    ('4672094', 2, 'acumulacion_amarillas', 4, 1),
    ('4445801', 2, 'roja', 4, 1),
    ('4117896', 2, 'disciplinaria', 4, 2),
    ('4562340', 2, 'disciplinaria', 2, 1);

-- ---------------------------------------------------------------------
-- Verificación: tabla de posiciones esperada tras las 3 fechas jugadas
-- (ordenada por puntos, diferencia de goles y goles a favor)
--   Los Contables    PJ 3 G 2 E 1 P 0 GF 8 GC 3 DG +5 Pts 7
--   Mente Sana FC    PJ 3 G 2 E 1 P 0 GF 7 GC 3 DG +4 Pts 7
--   Ingenieros FC    PJ 3 G 2 E 1 P 0 GF 6 GC 3 DG +3 Pts 7
--   Salud Total      PJ 3 G 1 E 1 P 1 GF 5 GC 3 DG +2 Pts 4
--   Humanistas FC    PJ 3 G 0 E 0 P 3 GF 2 GC 8 DG -6 Pts 0
--   Derecho United   PJ 3 G 0 E 0 P 3 GF 1 GC 9 DG -8 Pts 0
-- ---------------------------------------------------------------------
