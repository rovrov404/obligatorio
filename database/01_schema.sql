-- =====================================================================
-- Torneo Interfacultades de Fútbol 5 - UCU
-- Base de Datos 1 - Segundo Semestre 2026
-- Script 01: creación de la base de datos y las tablas (MySQL 8.0+)
-- =====================================================================

DROP DATABASE IF EXISTS torneo_f5;
CREATE DATABASE torneo_f5
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE torneo_f5;

-- ---------------------------------------------------------------------
-- login: usuarios de la aplicación (administrador / planillero)
-- La contraseña se guarda HASHEADA (bcrypt/argon2), nunca en texto plano.
-- ---------------------------------------------------------------------
CREATE TABLE login (
    correo      VARCHAR(100) NOT NULL,
    contrasena  VARCHAR(255) NOT NULL,
    rol         ENUM('administrador', 'planillero') NOT NULL,
    PRIMARY KEY (correo),
    CONSTRAINT chk_login_correo CHECK (correo REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$')
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- facultad
-- ---------------------------------------------------------------------
CREATE TABLE facultad (
    id_facultad INT NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100) NOT NULL,
    PRIMARY KEY (id_facultad),
    UNIQUE KEY uq_facultad_nombre (nombre)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- jugador
-- ---------------------------------------------------------------------
CREATE TABLE jugador (
    ci               VARCHAR(8)   NOT NULL,          -- sin puntos ni guión
    nombre           VARCHAR(60)  NOT NULL,
    apellido         VARCHAR(60)  NOT NULL,
    email            VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE         NOT NULL,
    id_facultad      INT          NOT NULL,
    tipo             ENUM('grado', 'posgrado', 'docente', 'funcionario') NOT NULL,
    PRIMARY KEY (ci),
    UNIQUE KEY uq_jugador_email (email),
    KEY idx_jugador_facultad (id_facultad),
    CONSTRAINT fk_jugador_facultad FOREIGN KEY (id_facultad)
        REFERENCES facultad (id_facultad),
    CONSTRAINT chk_jugador_ci CHECK (ci REGEXP '^[0-9]{7,8}$'),
    CONSTRAINT chk_jugador_email CHECK (email REGEXP '^[^@ ]+@[^@ ]+\\.[^@ ]+$'),
    CONSTRAINT chk_jugador_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0 AND CHAR_LENGTH(TRIM(apellido)) > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- torneo: una edición por semestre
-- ---------------------------------------------------------------------
CREATE TABLE torneo (
    id_torneo    INT          NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(100) NOT NULL,
    anio         SMALLINT     NOT NULL,
    semestre     TINYINT      NOT NULL,
    fecha_inicio DATE         NOT NULL,
    fecha_fin    DATE         NOT NULL,
    estado       ENUM('inscripcion', 'en_curso', 'finalizado') NOT NULL DEFAULT 'inscripcion',
    PRIMARY KEY (id_torneo),
    UNIQUE KEY uq_torneo_edicion (anio, semestre),
    CONSTRAINT chk_torneo_semestre CHECK (semestre IN (1, 2)),
    CONSTRAINT chk_torneo_anio CHECK (anio BETWEEN 2000 AND 2100),
    CONSTRAINT chk_torneo_fechas CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- equipo
-- ci_capitan admite NULL solo porque el equipo se crea ANTES de cargar
-- su plantel (dependencia circular). Un trigger valida que el capitán
-- pertenezca al plantel del equipo (ver script de triggers).
-- ---------------------------------------------------------------------
CREATE TABLE equipo (
    id_equipo   INT          NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100) NOT NULL,
    id_torneo   INT          NOT NULL,
    id_facultad INT          NOT NULL,
    ci_capitan  VARCHAR(8)   NULL,
    PRIMARY KEY (id_equipo),
    UNIQUE KEY uq_equipo_torneo_nombre (id_torneo, nombre),
    UNIQUE KEY uq_equipo_id_torneo (id_equipo, id_torneo),   -- soporta FK compuestas
    KEY idx_equipo_facultad (id_facultad),
    KEY idx_equipo_capitan (ci_capitan),
    CONSTRAINT fk_equipo_torneo   FOREIGN KEY (id_torneo)   REFERENCES torneo (id_torneo),
    CONSTRAINT fk_equipo_facultad FOREIGN KEY (id_facultad) REFERENCES facultad (id_facultad),
    CONSTRAINT fk_equipo_capitan  FOREIGN KEY (ci_capitan)  REFERENCES jugador (ci)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- equipo_jugador_torneo: plantel
--  * PK (id_equipo, ci_jugador)
--  * UNIQUE (id_torneo, ci_jugador): un jugador en un solo equipo por edición
--  * UNIQUE (id_equipo, numero_camiseta): camiseta no repetida en el equipo
--  * FK compuesta (id_equipo, id_torneo) garantiza que id_torneo coincida
--    con el torneo del equipo
-- Pendientes para triggers: 5-10 jugadores, máx. 2 docentes/funcionarios,
-- misma facultad que el equipo, modificación solo en etapa de inscripción.
-- ---------------------------------------------------------------------
CREATE TABLE equipo_jugador_torneo (
    id_equipo       INT        NOT NULL,
    ci_jugador      VARCHAR(8) NOT NULL,
    id_torneo       INT        NOT NULL,
    numero_camiseta TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (id_equipo, ci_jugador),
    UNIQUE KEY uq_plantel_jugador_torneo (id_torneo, ci_jugador),
    UNIQUE KEY uq_plantel_camiseta (id_equipo, numero_camiseta),
    KEY idx_plantel_jugador (ci_jugador),
    CONSTRAINT fk_plantel_equipo FOREIGN KEY (id_equipo, id_torneo)
        REFERENCES equipo (id_equipo, id_torneo),
    CONSTRAINT fk_plantel_jugador FOREIGN KEY (ci_jugador)
        REFERENCES jugador (ci),
    CONSTRAINT chk_plantel_camiseta CHECK (numero_camiseta BETWEEN 1 AND 99)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- complejo y cancha
-- ---------------------------------------------------------------------
CREATE TABLE complejo (
    id_complejo  INT          NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(100) NOT NULL,
    direccion    VARCHAR(150) NOT NULL,
    departamento VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id_complejo),
    UNIQUE KEY uq_complejo_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE cancha (
    nombre_cancha VARCHAR(50) NOT NULL,
    id_complejo   INT         NOT NULL,
    superficie    ENUM('sintetico', 'parquet') NOT NULL,
    techada       BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (nombre_cancha, id_complejo),
    CONSTRAINT fk_cancha_complejo FOREIGN KEY (id_complejo)
        REFERENCES complejo (id_complejo)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- turno: franjas de una hora entre 18:00 y 23:00
-- ---------------------------------------------------------------------
CREATE TABLE turno (
    id_turno    INT  NOT NULL AUTO_INCREMENT,
    hora_inicio TIME NOT NULL,
    hora_fin    TIME NOT NULL,
    PRIMARY KEY (id_turno),
    UNIQUE KEY uq_turno_inicio (hora_inicio),
    CONSTRAINT chk_turno_rango  CHECK (hora_inicio >= '18:00:00' AND hora_fin <= '23:00:00'),
    CONSTRAINT chk_turno_una_hora CHECK (TIMESTAMPDIFF(MINUTE, hora_inicio, hora_fin) = 60)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- partido
--  * local <> visitante
--  * cancha_slot (columna generada) + UNIQUE: una cancha no puede tener
--    más de un partido activo (programado/jugado) en el mismo día y turno.
--    Los partidos cancelados/postergados liberan la cancha (slot NULL).
-- Pendientes para triggers: mismo torneo y >= 5 jugadores, no repetir
-- rival (salvo cancelado), un partido por equipo por fecha, "jugado" solo
-- si día y turno ya pasaron, no eliminar jugados, corrección en 48 hs.
-- ---------------------------------------------------------------------
CREATE TABLE partido (
    id_partido          INT        NOT NULL AUTO_INCREMENT,
    id_torneo           INT        NOT NULL,
    numero_fecha        TINYINT UNSIGNED NOT NULL,
    id_equipo_local     INT        NOT NULL,
    id_equipo_visitante INT        NOT NULL,
    dia                 DATE       NOT NULL,
    id_turno            INT        NOT NULL,
    nombre_cancha       VARCHAR(50) NOT NULL,
    id_complejo         INT        NOT NULL,
    estado              ENUM('programado', 'jugado', 'postergado', 'cancelado')
                        NOT NULL DEFAULT 'programado',
    cancha_slot         VARCHAR(120) GENERATED ALWAYS AS (
        IF(estado IN ('programado', 'jugado'),
           CONCAT(id_complejo, '|', nombre_cancha, '|', dia, '|', id_turno),
           NULL)
    ) STORED,
    PRIMARY KEY (id_partido),
    UNIQUE KEY uq_partido_cancha_slot (cancha_slot),
    KEY idx_partido_torneo_fecha (id_torneo, numero_fecha),
    KEY idx_partido_local (id_equipo_local),
    KEY idx_partido_visitante (id_equipo_visitante),
    KEY idx_partido_turno (id_turno),
    KEY idx_partido_cancha (nombre_cancha, id_complejo),
    CONSTRAINT fk_partido_torneo FOREIGN KEY (id_torneo)
        REFERENCES torneo (id_torneo),
    CONSTRAINT fk_partido_local FOREIGN KEY (id_equipo_local, id_torneo)
        REFERENCES equipo (id_equipo, id_torneo),
    CONSTRAINT fk_partido_visitante FOREIGN KEY (id_equipo_visitante, id_torneo)
        REFERENCES equipo (id_equipo, id_torneo),
    CONSTRAINT fk_partido_turno FOREIGN KEY (id_turno)
        REFERENCES turno (id_turno),
    CONSTRAINT fk_partido_cancha FOREIGN KEY (nombre_cancha, id_complejo)
        REFERENCES cancha (nombre_cancha, id_complejo),
    CONSTRAINT chk_partido_distintos CHECK (id_equipo_local <> id_equipo_visitante),
    CONSTRAINT chk_partido_fecha CHECK (numero_fecha >= 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- planilla_partido: jugadores que participaron del partido
-- La FK compuesta asegura que el jugador pertenezca al plantel del
-- equipo indicado. Pendiente (trigger): que el equipo sea local o
-- visitante del partido y que el jugador no esté suspendido.
-- ---------------------------------------------------------------------
CREATE TABLE planilla_partido (
    id_partido INT        NOT NULL,
    ci_jugador VARCHAR(8) NOT NULL,
    id_equipo  INT        NOT NULL,
    PRIMARY KEY (id_partido, ci_jugador),
    KEY idx_planilla_jugador (ci_jugador),
    KEY idx_planilla_equipo (id_equipo),
    CONSTRAINT fk_planilla_partido FOREIGN KEY (id_partido)
        REFERENCES partido (id_partido),
    CONSTRAINT fk_planilla_plantel FOREIGN KEY (id_equipo, ci_jugador)
        REFERENCES equipo_jugador_torneo (id_equipo, ci_jugador)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- gol: solo jugadores que figuran en la planilla del partido.
-- autogol = TRUE suma el gol al rival del equipo del jugador.
-- ---------------------------------------------------------------------
CREATE TABLE gol (
    id_gol     INT        NOT NULL AUTO_INCREMENT,
    id_partido INT        NOT NULL,
    ci_jugador VARCHAR(8) NOT NULL,
    minuto     TINYINT UNSIGNED NOT NULL,
    autogol    BOOLEAN    NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_gol),
    KEY idx_gol_partido (id_partido),
    KEY idx_gol_jugador (ci_jugador),
    CONSTRAINT fk_gol_planilla FOREIGN KEY (id_partido, ci_jugador)
        REFERENCES planilla_partido (id_partido, ci_jugador),
    CONSTRAINT chk_gol_minuto CHECK (minuto BETWEEN 0 AND 120)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- tarjeta: solo jugadores que figuran en la planilla del partido
-- ---------------------------------------------------------------------
CREATE TABLE tarjeta (
    id_tarjeta INT        NOT NULL AUTO_INCREMENT,
    id_partido INT        NOT NULL,
    ci_jugador VARCHAR(8) NOT NULL,
    minuto     TINYINT UNSIGNED NOT NULL,
    color      ENUM('amarilla', 'roja') NOT NULL,
    PRIMARY KEY (id_tarjeta),
    KEY idx_tarjeta_partido (id_partido),
    KEY idx_tarjeta_jugador (ci_jugador),
    CONSTRAINT fk_tarjeta_planilla FOREIGN KEY (id_partido, ci_jugador)
        REFERENCES planilla_partido (id_partido, ci_jugador),
    CONSTRAINT chk_tarjeta_minuto CHECK (minuto BETWEEN 0 AND 120)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- sancion_jugador
-- La suspensión abarca las fechas [numero_fecha_inicio,
-- numero_fecha_inicio + cantidad_fechas - 1].
-- Las automáticas (roja / 3 amarillas) las genera un trigger con
-- cantidad_fechas = 1 y numero_fecha_inicio = fecha del partido + 1.
-- ---------------------------------------------------------------------
CREATE TABLE sancion_jugador (
    id_sancion          INT        NOT NULL AUTO_INCREMENT,
    ci_jugador          VARCHAR(8) NOT NULL,
    id_torneo           INT        NOT NULL,
    motivo              ENUM('roja', 'acumulacion_amarillas', 'disciplinaria') NOT NULL,
    numero_fecha_inicio TINYINT UNSIGNED NOT NULL,
    cantidad_fechas     TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (id_sancion),
    KEY idx_sancion_jugador_torneo (ci_jugador, id_torneo),
    KEY idx_sancion_torneo (id_torneo),
    CONSTRAINT fk_sancion_jugador FOREIGN KEY (ci_jugador)
        REFERENCES jugador (ci),
    CONSTRAINT fk_sancion_torneo FOREIGN KEY (id_torneo)
        REFERENCES torneo (id_torneo),
    CONSTRAINT chk_sancion_inicio CHECK (numero_fecha_inicio >= 1),
    CONSTRAINT chk_sancion_cantidad CHECK (cantidad_fechas >= 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Datos maestros: turnos de una hora entre 18:00 y 23:00
-- ---------------------------------------------------------------------
INSERT INTO turno (hora_inicio, hora_fin) VALUES
    ('18:00:00', '19:00:00'),
    ('19:00:00', '20:00:00'),
    ('20:00:00', '21:00:00'),
    ('21:00:00', '22:00:00'),
    ('22:00:00', '23:00:00');
