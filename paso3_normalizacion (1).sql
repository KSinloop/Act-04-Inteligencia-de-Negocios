-- =====================================================================
-- PASO 3. NORMALIZACION  (base u4_etl)
--
--
-- Transforma los datos que ya estan en stg_*. Lee raw_* y catalogo_estados
-- como referencia; NO modifica raw_*.
-- Se puede repetir sin problema: cada UPDATE vuelve a calcular el mismo valor.
-- =====================================================================
USE u4_etl;

-- Workbench activa por defecto el "modo seguro" y bloquea UPDATE multitabla.
SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------------------
-- 3A. Clientes: estado -> clave estatal uniforme con catalogo_estados
--     Sin equivalencia o vacio -> 'ND' (No identificado).
--     Tambien se limpia nombre (sin espacios sobrantes) y email (minusculas).
-- ---------------------------------------------------------------------
UPDATE stg_clientes s
JOIN (SELECT id_cliente, MIN(fila_id) AS fila_id
      FROM raw_clientes
      GROUP BY id_cliente) u ON u.id_cliente = s.id_cliente
JOIN raw_clientes c ON c.fila_id = u.fila_id
LEFT JOIN catalogo_estados e ON TRIM(c.estado) = e.alias
SET s.estado_canonico = COALESCE(e.estado_canonico, 'ND'),
    s.nombre = TRIM(s.nombre),
    s.email  = LOWER(TRIM(s.email));

-- ---------------------------------------------------------------------
-- 3B. Pedidos: fecha ISO (AAAA-MM-DD) y DD/MM/AAAA -> tipo DATE
--     Fecha vacia o con otro formato -> NULL.
--     estado_pedido en minusculas y sin espacios.
-- ---------------------------------------------------------------------
UPDATE stg_pedidos s
JOIN (SELECT id_pedido, MIN(fila_id) AS fila_id
      FROM raw_pedidos
      GROUP BY id_pedido) u ON u.id_pedido = s.id_pedido
JOIN raw_pedidos p ON p.fila_id = u.fila_id
SET s.fecha_pedido = CASE
      WHEN TRIM(p.fecha_pedido) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
           THEN STR_TO_DATE(TRIM(p.fecha_pedido), '%Y-%m-%d')
      WHEN TRIM(p.fecha_pedido) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
           THEN STR_TO_DATE(TRIM(p.fecha_pedido), '%d/%m/%Y')
      ELSE NULL
    END,
    s.estado_pedido = LOWER(TRIM(s.estado_pedido));

SET SQL_SAFE_UPDATES = 1;
-- ---------------------------------------------------------------------
-- COMPROBACIONES (capturas para el entregable)
-- ---------------------------------------------------------------------
-- Clientes por estado canonico (ND = sin equivalencia; nunca debe haber NULL)
SELECT estado_canonico, COUNT(*) AS clientes
FROM stg_clientes
GROUP BY estado_canonico
ORDER BY clientes DESC;

SELECT SUM(estado_canonico IS NULL) AS clientes_sin_normalizar,
       SUM(estado_canonico = 'ND')  AS clientes_nd
FROM stg_clientes;

-- Fechas: cuantas se convirtieron y cuantas quedaron NULL
SELECT SUM(fecha_pedido IS NOT NULL) AS fechas_convertidas,
       SUM(fecha_pedido IS NULL)     AS fechas_nulas,
       MIN(fecha_pedido)             AS fecha_minima,
       MAX(fecha_pedido)             AS fecha_maxima
FROM stg_pedidos;

-- Estados de pedido ya estandarizados
SELECT estado_pedido, COUNT(*) AS pedidos
FROM stg_pedidos
GROUP BY estado_pedido
ORDER BY pedidos DESC;

-- Muestra de conversion de fechas: original (raw) contra convertida (stg)
SELECT r.id_pedido, r.fecha_pedido AS fecha_original, s.fecha_pedido AS fecha_convertida
FROM raw_pedidos r
JOIN stg_pedidos s ON s.id_pedido = r.id_pedido
WHERE r.fecha_pedido LIKE '%/%'
LIMIT 10;
