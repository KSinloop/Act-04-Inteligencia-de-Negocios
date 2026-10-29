TRUNCATE TABLE rechazos_pedidos;

INSERT INTO rechazos_pedidos (id_pedido, motivo)
SELECT id_pedido, 'Importe no positivo'
FROM raw_pedidos
WHERE importe <= 0;

INSERT INTO rechazos_pedidos (id_pedido, motivo)
SELECT id_pedido, 'Fecha no válida'
FROM raw_pedidos
WHERE fecha_pedido IS NULL OR TRIM(fecha_pedido) = '';

INSERT INTO rechazos_pedidos (id_pedido, motivo)
SELECT id_pedido, 'Cliente inexistente'
FROM raw_pedidos
WHERE id_cliente NOT IN (
    SELECT id_cliente 
    FROM raw_clientes
);

INSERT INTO rechazos_pedidos (id_pedido, motivo)
SELECT id_pedido, 'Estado no reconocido'
FROM raw_pedidos
WHERE id_cliente IN (
    SELECT id_cliente 
    FROM raw_clientes
    WHERE estado NOT IN (SELECT estado_canonico FROM catalogo_estados)
      AND estado NOT IN (SELECT nombre_oficial FROM catalogo_estados)
      AND estado NOT IN (SELECT alias FROM catalogo_estados)
);

INSERT INTO rechazos_pedidos (id_pedido, motivo)
SELECT DISTINCT id_pedido, 'Pedido duplicado'
FROM raw_pedidos
WHERE id_pedido IN (
    SELECT id_pedido
    FROM raw_pedidos
    GROUP BY id_pedido
    HAVING COUNT(*) > 1
);

SELECT motivo, COUNT(*) AS cantidad
FROM rechazos_pedidos
GROUP BY motivo;


TRUNCATE TABLE stg_clientes;

INSERT INTO stg_clientes (id_cliente, nombre, email, estado_canonico)
SELECT 
    c.id_cliente,
    c.nombre,
    c.email,
    MAX(cat.estado_canonico) AS estado_canonico
FROM raw_clientes c
JOIN catalogo_estados cat 
  ON c.estado = cat.estado_canonico 
  OR c.estado = cat.nombre_oficial 
  OR c.estado = cat.alias
GROUP BY c.id_cliente, c.nombre, c.email;


TRUNCATE TABLE stg_pedidos;

INSERT INTO stg_pedidos (id_pedido, id_cliente, fecha_pedido, estado_pedido, importe)
SELECT 
    id_pedido, 
    id_cliente, 
    CASE 
        WHEN fecha_pedido LIKE '%/%' THEN STR_TO_DATE(fecha_pedido, '%d/%m/%Y')
        ELSE fecha_pedido 
    END AS fecha_pedido, 
    estado_pedido, 
    importe
FROM raw_pedidos
WHERE id_pedido NOT IN (
    SELECT id_pedido 
    FROM rechazos_pedidos
);

SELECT COUNT(*) AS total_clientes_limpios FROM stg_clientes;
SELECT COUNT(*) AS total_pedidos_limpios FROM stg_pedidos;