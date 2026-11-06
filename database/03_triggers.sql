-- =====================================================================
-- Torneo Interfacultades de Fútbol 5 - UCU
-- Base de Datos 1 - Segundo Semestre 2026
-- Script 03: triggers y procedimientos de validación (MySQL 8.0+)
--
-- Ejecutar DESPUÉS de 01_schema.sql y 02_datos_prueba.sql.
-- Es re-ejecutable: borra los triggers/procedimientos si ya existen.
--
-- Reglas que implementa (las que el esquema dejó pendientes):
--   PLANTEL   máx. 10 jugadores, máx. 2 docentes/funcionarios, misma
--             facultad que el equipo, un jugador en un solo equipo por
--             edición (mensaje claro), modificación solo en 'inscripcion'.
--   EQUIPO    alta solo en inscripción; el capitán debe pertenecer al
--             plantel (se asigna con UPDATE luego de cargar el plantel).
--   TORNEO    estados solo hacia adelante; para pasar a 'en_curso' todos
--             los equipos deben tener capitán y al menos 5 jugadores.
--   PARTIDO   torneo en curso, equipos con >= 5 jugadores, no enfrentarse
--             a sí mismo, un partido por equipo y fecha, no repetir rival
--             (salvo cancelado), cancha libre en día y turno, 'jugado'
--             solo si día y turno ya pasaron, no eliminar ni modificar
--             un partido jugado.
--   PLANILLA  solo partidos 'jugado'; el equipo debe ser local o
--   GOL       visitante; jugador no suspendido; planilla, goles y tarjetas
--   TARJETA   solo pueden registrarse/corregirse hasta 48 hs después de
--             terminado el turno del partido.
--   SANCIONES roja o cada 3 amarillas en la edición generan una sanción
--             automática de 1 fecha desde la fecha siguiente del torneo.
-- =====================================================================

USE torneo_f5;

DROP TRIGGER IF EXISTS trg_jugador_bu;
DROP TRIGGER IF EXISTS trg_torneo_bu;
DROP TRIGGER IF EXISTS trg_equipo_bi;
DROP TRIGGER IF EXISTS trg_equipo_bu;
DROP TRIGGER IF EXISTS trg_equipo_bd;
DROP TRIGGER IF EXISTS trg_plantel_bi;
DROP TRIGGER IF EXISTS trg_plantel_bu;
DROP TRIGGER IF EXISTS trg_plantel_bd;
DROP TRIGGER IF EXISTS trg_partido_bi;
DROP TRIGGER IF EXISTS trg_partido_bu;
DROP TRIGGER IF EXISTS trg_partido_bd;
DROP TRIGGER IF EXISTS trg_planilla_bi;
DROP TRIGGER IF EXISTS trg_planilla_bu;
DROP TRIGGER IF EXISTS trg_planilla_bd;
DROP TRIGGER IF EXISTS trg_gol_bi;
DROP TRIGGER IF EXISTS trg_gol_bu;
DROP TRIGGER IF EXISTS trg_gol_bd;
DROP TRIGGER IF EXISTS trg_tarjeta_bi;
DROP TRIGGER IF EXISTS trg_tarjeta_bu;
DROP TRIGGER IF EXISTS trg_tarjeta_bd;
DROP TRIGGER IF EXISTS trg_tarjeta_ai;
DROP TRIGGER IF EXISTS trg_sancion_bi;
DROP TRIGGER IF EXISTS trg_sancion_bu;
DROP PROCEDURE IF EXISTS sp_validar_partido;
DROP PROCEDURE IF EXISTS sp_validar_ventana_partido;
DROP PROCEDURE IF EXISTS sp_validar_planilla;

DELIMITER $$

-- =====================================================================
-- PROCEDIMIENTOS AUXILIARES (los triggers los invocan con CALL)
-- Nota: MESSAGE_TEXT admite como máximo 128 caracteres.
-- =====================================================================

-- Planilla, goles y tarjetas: el partido debe estar 'jugado' y la
-- edición solo se permite hasta 48 hs después de finalizado el turno.
CREATE PROCEDURE sp_validar_ventana_partido(IN p_id_partido INT)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_fin DATETIME;

    SET v_estado = (SELECT estado FROM partido WHERE id_partido = p_id_partido);
    SET v_fin = (SELECT TIMESTAMP(p.dia, t.hora_fin)
                   FROM partido p
                   JOIN turno t ON t.id_turno = p.id_turno
                  WHERE p.id_partido = p_id_partido);

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido indicado no existe';
    END IF;
    IF v_estado <> 'jugado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Planilla, goles y tarjetas solo se registran en partidos en estado jugado';
    END IF;
    IF NOW() > v_fin + INTERVAL 48 HOUR THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pasaron más de 48 horas desde la disputa del partido: ya no puede modificarse';
    END IF;
END$$

-- Planilla: equipo del partido y jugador no suspendido.
CREATE PROCEDURE sp_validar_planilla(
    IN p_id_partido INT,
    IN p_id_equipo  INT,
    IN p_ci_jugador VARCHAR(8))
BEGIN
    DECLARE v_torneo INT;
    DECLARE v_fecha  INT;
    DECLARE v_local  INT;
    DECLARE v_visita INT;

    CALL sp_validar_ventana_partido(p_id_partido);

    SELECT id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante
      INTO v_torneo, v_fecha, v_local, v_visita
      FROM partido
     WHERE id_partido = p_id_partido;

    IF p_id_equipo <> v_local AND p_id_equipo <> v_visita THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El equipo indicado no es local ni visitante de este partido';
    END IF;

    IF EXISTS (SELECT 1
                 FROM sancion_jugador s
                WHERE s.ci_jugador = p_ci_jugador
                  AND s.id_torneo  = v_torneo
                  AND v_fecha BETWEEN s.numero_fecha_inicio
                                  AND s.numero_fecha_inicio + s.cantidad_fechas - 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Jugador suspendido: no puede figurar en la planilla de esta fecha';
    END IF;
END$$

-- Partido: reglas de programación (se usa en INSERT y UPDATE).
CREATE PROCEDURE sp_validar_partido(
    IN p_id_partido   INT,
    IN p_id_torneo    INT,
    IN p_numero_fecha INT,
    IN p_local        INT,
    IN p_visitante    INT,
    IN p_dia          DATE,
    IN p_id_turno     INT,
    IN p_cancha       VARCHAR(50),
    IN p_id_complejo  INT,
    IN p_estado       VARCHAR(20))
BEGIN
    DECLARE v_id      INT DEFAULT IFNULL(p_id_partido, 0);
    DECLARE v_estado_torneo VARCHAR(20);
    DECLARE v_ini     DATE;
    DECLARE v_fin     DATE;
    DECLARE v_hora_fin TIME;

    IF p_local = p_visitante THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un equipo no puede enfrentarse a sí mismo';
    END IF;

    SET v_estado_torneo = (SELECT estado       FROM torneo WHERE id_torneo = p_id_torneo);
    SET v_ini           = (SELECT fecha_inicio FROM torneo WHERE id_torneo = p_id_torneo);
    SET v_fin           = (SELECT fecha_fin    FROM torneo WHERE id_torneo = p_id_torneo);

    IF v_estado_torneo IS NULL OR v_estado_torneo <> 'en_curso' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El torneo debe estar en curso para programar o modificar partidos';
    END IF;

    IF p_dia < v_ini OR p_dia > v_fin THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El día del partido debe estar dentro de las fechas del torneo';
    END IF;

    IF (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_local) < 5
       OR (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = p_visitante) < 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ambos equipos deben tener al menos 5 jugadores en su plantel';
    END IF;

    IF p_estado <> 'cancelado' THEN
        -- un equipo no puede jugar más de un partido por fecha
        IF EXISTS (SELECT 1
                     FROM partido
                    WHERE id_torneo    = p_id_torneo
                      AND numero_fecha = p_numero_fecha
                      AND id_partido  <> v_id
                      AND estado      <> 'cancelado'
                      AND (id_equipo_local     IN (p_local, p_visitante)
                        OR id_equipo_visitante IN (p_local, p_visitante))) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Alguno de los equipos ya tiene un partido en esa fecha del torneo';
        END IF;

        -- no repetir rival en la edición (salvo partido cancelado)
        IF EXISTS (SELECT 1
                     FROM partido
                    WHERE id_torneo = p_id_torneo
                      AND id_partido <> v_id
                      AND estado     <> 'cancelado'
                      AND ((id_equipo_local = p_local     AND id_equipo_visitante = p_visitante)
                        OR (id_equipo_local = p_visitante AND id_equipo_visitante = p_local))) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Estos equipos ya tienen un partido en la edición (no cancelado)';
        END IF;
    END IF;

    IF p_estado IN ('programado', 'jugado') THEN
        -- cancha libre en ese día y turno
        IF EXISTS (SELECT 1
                     FROM partido
                    WHERE id_partido    <> v_id
                      AND estado        IN ('programado', 'jugado')
                      AND dia            = p_dia
                      AND id_turno       = p_id_turno
                      AND nombre_cancha  = p_cancha
                      AND id_complejo    = p_id_complejo) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La cancha ya tiene un partido asignado en ese día y turno';
        END IF;
    END IF;

    IF p_estado = 'jugado' THEN
        SET v_hora_fin = (SELECT hora_fin FROM turno WHERE id_turno = p_id_turno);
        IF TIMESTAMP(p_dia, v_hora_fin) > NOW() THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No puede marcarse como jugado: el día y turno del partido aún no pasaron';
        END IF;
    END IF;
END$$

-- =====================================================================
-- JUGADOR
-- =====================================================================
CREATE TRIGGER trg_jugador_bu BEFORE UPDATE ON jugador
FOR EACH ROW
BEGIN
    -- no cambiar la facultad de un jugador ya inscripto en un plantel
    IF NEW.id_facultad <> OLD.id_facultad
       AND EXISTS (SELECT 1 FROM equipo_jugador_torneo WHERE ci_jugador = OLD.ci) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar la facultad de un jugador inscripto en un plantel';
    END IF;

    -- pasar a docente/funcionario no puede romper el máximo de 2 por plantel
    IF NEW.tipo IN ('docente', 'funcionario')
       AND OLD.tipo NOT IN ('docente', 'funcionario')
       AND EXISTS (SELECT 1
                     FROM equipo_jugador_torneo ej
                    WHERE ej.ci_jugador = OLD.ci
                      AND (SELECT COUNT(*)
                             FROM equipo_jugador_torneo ej2
                             JOIN jugador j ON j.ci = ej2.ci_jugador
                            WHERE ej2.id_equipo = ej.id_equipo
                              AND j.tipo IN ('docente', 'funcionario')) >= 2) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El cambio de tipo supera el máximo de 2 docentes/funcionarios en un plantel';
    END IF;
END$$

-- =====================================================================
-- TORNEO: ciclo de vida
-- =====================================================================
CREATE TRIGGER trg_torneo_bu BEFORE UPDATE ON torneo
FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        IF NOT ((OLD.estado = 'inscripcion' AND NEW.estado = 'en_curso')
             OR (OLD.estado = 'en_curso'    AND NEW.estado = 'finalizado')) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Transición de estado inválida (inscripcion > en_curso > finalizado)';
        END IF;

        IF NEW.estado = 'en_curso' THEN
            IF (SELECT COUNT(*) FROM equipo WHERE id_torneo = OLD.id_torneo) < 2 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Para iniciar el torneo se necesitan al menos 2 equipos inscriptos';
            END IF;
            IF EXISTS (SELECT 1
                         FROM equipo e
                        WHERE e.id_torneo = OLD.id_torneo
                          AND (e.ci_capitan IS NULL
                               OR (SELECT COUNT(*)
                                     FROM equipo_jugador_torneo ej
                                    WHERE ej.id_equipo = e.id_equipo) < 5)) THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Todos los equipos deben tener capitán y al menos 5 jugadores para iniciar';
            END IF;
        END IF;
    END IF;
END$$

-- =====================================================================
-- EQUIPO
-- =====================================================================
CREATE TRIGGER trg_equipo_bi BEFORE INSERT ON equipo
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET v_estado = (SELECT estado FROM torneo WHERE id_torneo = NEW.id_torneo);

    IF v_estado <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden crear equipos mientras el torneo está en inscripción';
    END IF;
    IF NEW.ci_capitan IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cree el equipo sin capitán, cargue el plantel y luego asigne el capitán (UPDATE)';
    END IF;
END$$

CREATE TRIGGER trg_equipo_bu BEFORE UPDATE ON equipo
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET v_estado = (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo);

    IF NEW.id_torneo <> OLD.id_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el torneo de un equipo';
    END IF;

    IF NEW.id_facultad <> OLD.id_facultad
       AND EXISTS (SELECT 1 FROM equipo_jugador_torneo WHERE id_equipo = OLD.id_equipo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar la facultad de un equipo que ya tiene plantel';
    END IF;

    IF NEW.ci_capitan IS NOT NULL AND NOT (NEW.ci_capitan <=> OLD.ci_capitan) THEN
        IF NOT EXISTS (SELECT 1
                         FROM equipo_jugador_torneo
                        WHERE id_equipo  = OLD.id_equipo
                          AND ci_jugador = NEW.ci_capitan) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El capitán debe ser un jugador del plantel del equipo';
        END IF;
    END IF;

    IF NEW.ci_capitan IS NULL AND OLD.ci_capitan IS NOT NULL AND v_estado <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede quitar el capitán una vez iniciado el torneo';
    END IF;
END$$

CREATE TRIGGER trg_equipo_bd BEFORE DELETE ON equipo
FOR EACH ROW
BEGIN
    IF (SELECT estado FROM torneo WHERE id_torneo = OLD.id_torneo) <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden eliminar equipos mientras el torneo está en inscripción';
    END IF;
END$$

-- =====================================================================
-- PLANTEL (equipo_jugador_torneo)
-- =====================================================================
CREATE TRIGGER trg_plantel_bi BEFORE INSERT ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    DECLARE v_estado     VARCHAR(20);
    DECLARE v_fac_equipo INT;
    DECLARE v_fac_jug    INT;
    DECLARE v_tipo       VARCHAR(20);

    SET v_estado = (SELECT t.estado
                      FROM equipo e
                      JOIN torneo t ON t.id_torneo = e.id_torneo
                     WHERE e.id_equipo = NEW.id_equipo);
    IF v_estado <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo está en inscripción';
    END IF;

    IF (SELECT COUNT(*) FROM equipo_jugador_torneo WHERE id_equipo = NEW.id_equipo) >= 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El plantel ya tiene el máximo de 10 jugadores';
    END IF;

    IF EXISTS (SELECT 1 FROM equipo_jugador_torneo
                WHERE id_torneo = NEW.id_torneo AND ci_jugador = NEW.ci_jugador) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador ya integra un equipo en esta edición del torneo';
    END IF;

    IF EXISTS (SELECT 1 FROM equipo_jugador_torneo
                WHERE id_equipo = NEW.id_equipo AND numero_camiseta = NEW.numero_camiseta) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El número de camiseta ya está en uso en este equipo';
    END IF;

    SET v_fac_equipo = (SELECT id_facultad FROM equipo  WHERE id_equipo = NEW.id_equipo);
    SET v_fac_jug    = (SELECT id_facultad FROM jugador WHERE ci = NEW.ci_jugador);
    SET v_tipo       = (SELECT tipo        FROM jugador WHERE ci = NEW.ci_jugador);

    IF v_fac_jug <> v_fac_equipo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador debe pertenecer a la facultad que representa el equipo';
    END IF;

    IF v_tipo IN ('docente', 'funcionario') THEN
        IF (SELECT COUNT(*)
              FROM equipo_jugador_torneo ej
              JOIN jugador j ON j.ci = ej.ci_jugador
             WHERE ej.id_equipo = NEW.id_equipo
               AND j.tipo IN ('docente', 'funcionario')) >= 2 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El plantel ya tiene el máximo de 2 docentes/funcionarios';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_plantel_bu BEFORE UPDATE ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    IF (SELECT t.estado
          FROM equipo e
          JOIN torneo t ON t.id_torneo = e.id_torneo
         WHERE e.id_equipo = OLD.id_equipo) <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo está en inscripción';
    END IF;

    IF NEW.id_equipo <> OLD.id_equipo
       OR NEW.ci_jugador <> OLD.ci_jugador
       OR NEW.id_torneo <> OLD.id_torneo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo puede modificarse el número de camiseta; elimine y vuelva a agregar al jugador';
    END IF;
END$$

CREATE TRIGGER trg_plantel_bd BEFORE DELETE ON equipo_jugador_torneo
FOR EACH ROW
BEGIN
    IF (SELECT t.estado
          FROM equipo e
          JOIN torneo t ON t.id_torneo = e.id_torneo
         WHERE e.id_equipo = OLD.id_equipo) <> 'inscripcion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los planteles solo pueden modificarse mientras el torneo está en inscripción';
    END IF;

    IF EXISTS (SELECT 1 FROM equipo
                WHERE id_equipo = OLD.id_equipo AND ci_capitan = OLD.ci_jugador) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador es el capitán del equipo: asigne otro capitán antes de quitarlo';
    END IF;
END$$

-- =====================================================================
-- PARTIDO
-- =====================================================================
CREATE TRIGGER trg_partido_bi BEFORE INSERT ON partido
FOR EACH ROW
BEGIN
    CALL sp_validar_partido(NEW.id_partido, NEW.id_torneo, NEW.numero_fecha,
                            NEW.id_equipo_local, NEW.id_equipo_visitante,
                            NEW.dia, NEW.id_turno, NEW.nombre_cancha,
                            NEW.id_complejo, NEW.estado);
END$$

CREATE TRIGGER trg_partido_bu BEFORE UPDATE ON partido
FOR EACH ROW
BEGIN
    IF OLD.estado = 'jugado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un partido jugado no puede modificarse (solo se corrigen sus goles dentro de 48 hs)';
    ELSEIF OLD.estado = 'cancelado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un partido cancelado no puede modificarse: programe uno nuevo';
    ELSE
        CALL sp_validar_partido(NEW.id_partido, NEW.id_torneo, NEW.numero_fecha,
                                NEW.id_equipo_local, NEW.id_equipo_visitante,
                                NEW.dia, NEW.id_turno, NEW.nombre_cancha,
                                NEW.id_complejo, NEW.estado);
    END IF;
END$$

CREATE TRIGGER trg_partido_bd BEFORE DELETE ON partido
FOR EACH ROW
BEGIN
    IF OLD.estado = 'jugado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un partido jugado no puede eliminarse';
    END IF;
END$$

-- =====================================================================
-- PLANILLA, GOL, TARJETA
-- =====================================================================
CREATE TRIGGER trg_planilla_bi BEFORE INSERT ON planilla_partido
FOR EACH ROW
BEGIN
    CALL sp_validar_planilla(NEW.id_partido, NEW.id_equipo, NEW.ci_jugador);
END$$

CREATE TRIGGER trg_planilla_bu BEFORE UPDATE ON planilla_partido
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
    CALL sp_validar_planilla(NEW.id_partido, NEW.id_equipo, NEW.ci_jugador);
END$$

CREATE TRIGGER trg_planilla_bd BEFORE DELETE ON planilla_partido
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
END$$

CREATE TRIGGER trg_gol_bi BEFORE INSERT ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(NEW.id_partido);
END$$

CREATE TRIGGER trg_gol_bu BEFORE UPDATE ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
    CALL sp_validar_ventana_partido(NEW.id_partido);
END$$

CREATE TRIGGER trg_gol_bd BEFORE DELETE ON gol
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
END$$

CREATE TRIGGER trg_tarjeta_bi BEFORE INSERT ON tarjeta
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(NEW.id_partido);
END$$

CREATE TRIGGER trg_tarjeta_bu BEFORE UPDATE ON tarjeta
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
    CALL sp_validar_ventana_partido(NEW.id_partido);
END$$

CREATE TRIGGER trg_tarjeta_bd BEFORE DELETE ON tarjeta
FOR EACH ROW
BEGIN
    CALL sp_validar_ventana_partido(OLD.id_partido);
END$$

-- Sanciones automáticas:
--   * tarjeta roja -> 1 fecha de suspensión
--   * cada 3 amarillas acumuladas en la edición -> 1 fecha de suspensión
-- En ambos casos la suspensión se cumple en la fecha siguiente del torneo.
CREATE TRIGGER trg_tarjeta_ai AFTER INSERT ON tarjeta
FOR EACH ROW
BEGIN
    DECLARE v_torneo INT;
    DECLARE v_fecha  INT;
    DECLARE v_n      INT;

    SELECT id_torneo, numero_fecha
      INTO v_torneo, v_fecha
      FROM partido
     WHERE id_partido = NEW.id_partido;

    IF NEW.color = 'roja' THEN
        INSERT INTO sancion_jugador
            (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas)
        VALUES
            (NEW.ci_jugador, v_torneo, 'roja', v_fecha + 1, 1);
    ELSE
        SELECT COUNT(*)
          INTO v_n
          FROM tarjeta t
          JOIN partido p ON p.id_partido = t.id_partido
         WHERE t.ci_jugador = NEW.ci_jugador
           AND p.id_torneo  = v_torneo
           AND t.color      = 'amarilla';

        IF v_n MOD 3 = 0 THEN
            INSERT INTO sancion_jugador
                (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas)
            VALUES
                (NEW.ci_jugador, v_torneo, 'acumulacion_amarillas', v_fecha + 1, 1);
        END IF;
    END IF;
END$$

-- =====================================================================
-- SANCION_JUGADOR: el jugador debe estar inscripto en la edición
-- =====================================================================
CREATE TRIGGER trg_sancion_bi BEFORE INSERT ON sancion_jugador
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                    WHERE ci_jugador = NEW.ci_jugador AND id_torneo = NEW.id_torneo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador no está inscripto en ningún plantel de este torneo';
    END IF;
END$$

CREATE TRIGGER trg_sancion_bu BEFORE UPDATE ON sancion_jugador
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipo_jugador_torneo
                    WHERE ci_jugador = NEW.ci_jugador AND id_torneo = NEW.id_torneo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El jugador no está inscripto en ningún plantel de este torneo';
    END IF;
END$$

DELIMITER ;
