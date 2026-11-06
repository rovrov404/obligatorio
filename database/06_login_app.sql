USE torneo_f5;

INSERT INTO login (correo, contrasena, rol) VALUES
('admin@torneo.ucu', '$2b$12$e/4wlGSn1Xux1FQLgIr03.b/wbBhlMY4o0bZjy3AUq8N1.Lt8eNo2', 'administrador'),
('planillero@torneo.ucu', '$2b$12$G3an2L0gaq6CT3iaO4LkROZJX9RqmEQxAxWkcFBhbKkj6mecSgia2', 'planillero')
ON DUPLICATE KEY UPDATE contrasena=VALUES(contrasena), rol=VALUES(rol);
