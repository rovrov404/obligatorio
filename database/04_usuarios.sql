-- =====================================================================
-- Torneo Interfacultades de Fútbol 5 - UCU
-- Base de Datos 1 - Segundo Semestre 2026
-- Script 04: usuarios de base de datos y permisos (MySQL 8.0+)
--
-- Ejecutar con un usuario con permisos de administración (root),
-- DESPUÉS de 01_schema.sql, 02_datos_prueba.sql y 03_triggers.sql.
-- Es re-ejecutable: elimina y vuelve a crear los usuarios.
--
-- IMPORTANTE: las contraseñas de abajo son de ejemplo. Cambiarlas, y en
-- la aplicación leerlas de variables de entorno (no dejarlas en el código).
--
-- Usuarios:
--   torneo_admin      administrador: lectura y escritura de toda la
--                     información del torneo (sin permisos de DDL: no
--                     puede crear, alterar ni borrar tablas).
--   torneo_planillero planillero: únicamente registra planillas, goles y
--                     tarjetas; solo lee lo necesario para hacerlo.
--   torneo_auth       solo lee la tabla login, para autenticar usuarios de
--                     la aplicación antes de saber su rol.
--
-- Host '%' para que funcione también desde otro contenedor Docker.
-- Los triggers y procedimientos se ejecutan con los permisos de su
-- DEFINER (root), por eso el planillero puede disparar la sanción
-- automática sin tener permisos de escritura sobre sancion_jugador.
-- =====================================================================

USE torneo_f5;

DROP USER IF EXISTS 'torneo_admin'@'%';
DROP USER IF EXISTS 'torneo_planillero'@'%';
DROP USER IF EXISTS 'torneo_auth'@'%';

CREATE USER 'torneo_admin'@'%'      IDENTIFIED BY 'Admin_torneo_2026!';
CREATE USER 'torneo_planillero'@'%' IDENTIFIED BY 'Planillero_torneo_2026!';
CREATE USER 'torneo_auth'@'%'       IDENTIFIED BY 'Auth_torneo_2026!';

-- ---------------------------------------------------------------------
-- Procedimiento para que el planillero marque un partido como jugado.
-- El planillero no tiene UPDATE sobre partido; esta es la única forma en
-- que puede cambiar su estado, y solo de 'programado' a 'jugado'. El
-- trigger de partido valida que el día y turno ya hayan pasado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_marcar_partido_jugado;

DELIMITER $$

CREATE PROCEDURE sp_marcar_partido_jugado(IN p_id_partido INT)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET v_estado = (SELECT estado FROM partido WHERE id_partido = p_id_partido);

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido indicado no existe';
    ELSEIF v_estado = 'programado' THEN
        UPDATE partido SET estado = 'jugado' WHERE id_partido = p_id_partido;
    ELSEIF v_estado <> 'jugado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo puede marcarse como jugado un partido programado';
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- ADMINISTRADOR: gestiona toda la información (incluida la tabla login)
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_f5.* TO 'torneo_admin'@'%';

-- ---------------------------------------------------------------------
-- PLANILLERO
--   * escribe solo planilla_partido, gol y tarjeta (corrige dentro de
--     la ventana de 48 hs que controla el trigger)
--   * lee lo necesario para armar la planilla; NO lee login
--   * marca partidos como jugados solo mediante el procedimiento
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_f5.planilla_partido TO 'torneo_planillero'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_f5.gol              TO 'torneo_planillero'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON torneo_f5.tarjeta          TO 'torneo_planillero'@'%';

GRANT SELECT ON torneo_f5.torneo                TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.partido               TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.turno                 TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.equipo                TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.equipo_jugador_torneo TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.jugador               TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.facultad              TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.complejo              TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.cancha                TO 'torneo_planillero'@'%';
GRANT SELECT ON torneo_f5.sancion_jugador       TO 'torneo_planillero'@'%';

GRANT EXECUTE ON PROCEDURE torneo_f5.sp_marcar_partido_jugado TO 'torneo_planillero'@'%';

-- ---------------------------------------------------------------------
-- AUTENTICACIÓN: solo puede leer la tabla login
-- ---------------------------------------------------------------------
GRANT SELECT ON torneo_f5.login TO 'torneo_auth'@'%';

-- Verificación
SHOW GRANTS FOR 'torneo_admin'@'%';
SHOW GRANTS FOR 'torneo_planillero'@'%';
SHOW GRANTS FOR 'torneo_auth'@'%';
