-- =====================================================================
-- PASO 2. STAGING  (base u4_etl)
--
-- raw_*  = zona de aterrizaje INMUTABLE.
-- stg_*  = zona de trabajo donde si se transforman los datos.
--
-- Este paso SOLO LEE raw_* y ESCRIBE en stg_*. Aqui se copian los datos
-- a staging con UNA fila por clave (id_cliente / id_pedido). Las columnas
-- que necesitan transformacion (estado_canonico, fecha_pedido) quedan NULL
-- y se llenan en el Paso 3.
-- Se puede repetir: stg_* se vacia y se vuelve a llenar. Si lo repites,
-- ejecuta despues otra vez el Paso 3.
-- =====================================================================
USE u4_etl;


TRUNCATE TABLE stg_clientes;
TRUNCATE TABLE stg_pedidos;

-- Clientes: una fila por id_cliente (se conserva la primera por fila_id;
-- en estos datos las filas repetidas son identicas).
INSERT INTO stg_clientes (id_cliente, nombre, email, estado_canonico)
SELECT c.id_cliente, c.nombre, c.email, NULL
FROM raw_clientes c
JOIN (SELECT id_cliente, MIN(fila_id) AS fila_id
      FROM raw_clientes
      GROUP BY id_cliente) u ON u.fila_id = c.fila_id;

-- Pedidos: una fila por id_pedido (se conserva la primera por fila_id).
-- fecha_pedido queda NULL: en raw es texto y aqui es DATE (Paso 3).
INSERT INTO stg_pedidos (id_pedido, id_cliente, fecha_pedido, estado_pedido, importe)
SELECT p.id_pedido, p.id_cliente, NULL, p.estado_pedido, p.importe
FROM raw_pedidos p
JOIN (SELECT id_pedido, MIN(fila_id) AS fila_id
      FROM raw_pedidos
      GROUP BY id_pedido) u ON u.fila_id = p.fila_id;

-- ---------------------------------------------------------------------
-- COMPROBACIONES (capturas para el entregable)
-- ---------------------------------------------------------------------
-- Conteos: raw contra staging (raw debe seguir intacto: 510 y 2012)
SELECT 'raw_clientes' AS tabla, COUNT(*) AS filas FROM raw_clientes
UNION ALL SELECT 'stg_clientes', COUNT(*) FROM stg_clientes
UNION ALL SELECT 'raw_pedidos',  COUNT(*) FROM raw_pedidos
UNION ALL SELECT 'stg_pedidos',  COUNT(*) FROM stg_pedidos;

-- Filas de origen que no pasaron a staging por ser repetidas
SELECT (SELECT COUNT(*) FROM raw_clientes) - (SELECT COUNT(*) FROM stg_clientes) AS clientes_repetidos_omitidos,
       (SELECT COUNT(*) FROM raw_pedidos)  - (SELECT COUNT(*) FROM stg_pedidos)  AS pedidos_repetidos_omitidos;

-- Claves unicas en staging (ambas deben dar 0 repetidos)
SELECT (SELECT COUNT(*) - COUNT(DISTINCT id_cliente) FROM stg_clientes) AS repetidos_stg_clientes,
       (SELECT COUNT(*) - COUNT(DISTINCT id_pedido)  FROM stg_pedidos)  AS repetidos_stg_pedidos;
