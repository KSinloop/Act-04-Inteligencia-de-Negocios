-- =====================================================================
-- PASO 1. PERFILADO  (base u4_etl)
-- Solo LEE las tablas raw_*; no modifica los datos de origen.
-- Los resultados se guardan en observaciones_perfilado.
-- Se puede ejecutar varias veces: la tabla de observaciones se vacía al inicio.
-- =====================================================================
USE u4_etl;

CREATE TABLE IF NOT EXISTS observaciones_perfilado (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  tabla          VARCHAR(40)  NOT NULL,
  revision       VARCHAR(100) NOT NULL,
  resultado      BIGINT       NOT NULL,
  nota           VARCHAR(255) NULL,
  fecha_revision DATETIME DEFAULT CURRENT_TIMESTAMP
);
TRUNCATE TABLE observaciones_perfilado;

-- ---------------------------------------------------------------------
-- 1.1 Columnas, claves y tipos de datos (solo consulta, para captura)
-- ---------------------------------------------------------------------
SELECT table_name AS tabla, column_name AS columna, column_type AS tipo,
       column_key AS clave, is_nullable AS acepta_null
FROM information_schema.columns
WHERE table_schema = 'u4_etl'
  AND table_name IN ('raw_clientes','raw_pedidos','catalogo_estados')
ORDER BY table_name, ordinal_position;

-- ---------------------------------------------------------------------
-- 1.2 Conteo de registros por tabla
-- ---------------------------------------------------------------------
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'filas totales', COUNT(*), 'Incluye repetidos' FROM raw_clientes;

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'filas totales', COUNT(*), 'Incluye repetidos' FROM raw_pedidos;

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'catalogo_estados', 'filas totales', COUNT(*), 'Alias unicos sin distinguir mayusculas/acentos' FROM catalogo_estados;

-- ---------------------------------------------------------------------
-- 1.3 Claves repetidas
-- ---------------------------------------------------------------------
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'id_cliente repetidos (ids distintos)', COUNT(*),
       'Ids que aparecen mas de una vez'
FROM (SELECT id_cliente FROM raw_clientes GROUP BY id_cliente HAVING COUNT(*) > 1) t;

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'filas sobrantes por id_cliente repetido', COALESCE(SUM(n - 1), 0),
       'Filas que se descartarian al dejar una por id'
FROM (SELECT COUNT(*) AS n FROM raw_clientes GROUP BY id_cliente HAVING COUNT(*) > 1) t;

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'id_pedido repetidos (ids distintos)', COUNT(*),
       'Ids que aparecen mas de una vez'
FROM (SELECT id_pedido FROM raw_pedidos GROUP BY id_pedido HAVING COUNT(*) > 1) t;

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'filas sobrantes por id_pedido repetido', COALESCE(SUM(n - 1), 0),
       'Filas que se descartarian al dejar una por id'
FROM (SELECT COUNT(*) AS n FROM raw_pedidos GROUP BY id_pedido HAVING COUNT(*) > 1) t;

-- ---------------------------------------------------------------------
-- 1.4 Estados no estandarizados (clientes)
-- ---------------------------------------------------------------------
-- Estado vacio o nulo
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'estado vacio o nulo', COUNT(*), 'Sin estado: no tiene equivalencia en el catalogo'
FROM raw_clientes
WHERE estado IS NULL OR TRIM(estado) = '';

-- Estado que no coincide con ningun alias del catalogo
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'estado sin equivalencia en catalogo', COUNT(*), 'Incluye los vacios'
FROM raw_clientes c
LEFT JOIN catalogo_estados e ON TRIM(c.estado) = e.alias
WHERE e.alias IS NULL;

-- Estado que existe en el catalogo pero no esta escrito como clave canonica
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'estado con alias distinto a la clave canonica', COUNT(*),
       'Necesitan normalizarse (ej. Guanajuato -> GTO)'
FROM raw_clientes c
JOIN catalogo_estados e ON TRIM(c.estado) = e.alias
WHERE c.estado COLLATE utf8mb4_bin <> e.estado_canonico COLLATE utf8mb4_bin;

-- Variantes de escritura encontradas (solo consulta, para captura)
SELECT estado COLLATE utf8mb4_bin AS variante_estado, COUNT(*) AS filas
FROM raw_clientes
GROUP BY variante_estado
ORDER BY filas DESC;

-- ---------------------------------------------------------------------
-- 1.5 Fechas vacias
-- ---------------------------------------------------------------------
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_clientes', 'fecha_registro vacia', COUNT(*), NULL
FROM raw_clientes
WHERE fecha_registro IS NULL OR TRIM(fecha_registro) = '';

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'fecha_pedido vacia', COUNT(*), 'Se rechazaran en el Paso 4'
FROM raw_pedidos
WHERE fecha_pedido IS NULL OR TRIM(fecha_pedido) = '';

-- Formatos de fecha en pedidos (ISO, DD/MM/AAAA u otro)
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'fecha_pedido en formato ISO (AAAA-MM-DD)', COUNT(*), NULL
FROM raw_pedidos
WHERE fecha_pedido REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'fecha_pedido en formato DD/MM/AAAA', COUNT(*), 'Hay que convertirlas con STR_TO_DATE'
FROM raw_pedidos
WHERE fecha_pedido REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'fecha_pedido con otro formato (sin contar vacias)', COUNT(*), NULL
FROM raw_pedidos
WHERE TRIM(fecha_pedido) <> ''
  AND fecha_pedido NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND fecha_pedido NOT REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

-- ---------------------------------------------------------------------
-- 1.6 Montos no positivos
-- ---------------------------------------------------------------------
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'importe nulo, cero o negativo', COUNT(*), 'Se rechazaran en el Paso 4'
FROM raw_pedidos
WHERE importe IS NULL OR importe <= 0;

-- ---------------------------------------------------------------------
-- 1.7 Extras utiles para el Paso 4
-- ---------------------------------------------------------------------
-- Pedidos cuyo cliente no existe en raw_clientes
INSERT INTO observaciones_perfilado (tabla, revision, resultado, nota)
SELECT 'raw_pedidos', 'pedidos sin cliente existente', COUNT(*), 'id_cliente no esta en raw_clientes'
FROM raw_pedidos p
LEFT JOIN (SELECT DISTINCT id_cliente FROM raw_clientes) c ON c.id_cliente = p.id_cliente
WHERE c.id_cliente IS NULL;

-- Variantes de escritura de estado_pedido (solo consulta, para captura)
SELECT estado_pedido COLLATE utf8mb4_bin AS variante_estado_pedido, COUNT(*) AS filas
FROM raw_pedidos
GROUP BY variante_estado_pedido
ORDER BY filas DESC;

-- ---------------------------------------------------------------------
-- RESULTADO FINAL: tabla de observaciones (esta es la captura a entregar)
-- ---------------------------------------------------------------------
SELECT id, tabla, revision, resultado, nota
FROM observaciones_perfilado
ORDER BY id;
