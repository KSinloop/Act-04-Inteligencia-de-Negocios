-- =====================================================================
-- PASO 7. INDICADORES  (base u4_etl)
-- Ventas netas y pedidos entregados por estado canonico y fecha.
-- Supuesto del laboratorio: ventas netas = suma de pedidos entregados.
-- No hay descuentos, impuestos ni devoluciones modelados.
-- Solo LEE; no modifica ninguna tabla.
-- =====================================================================
USE u4_etl;

-- 7.1 Indicadores por estado y fecha
SELECT
  c.estado_canonico,
  p.fecha_pedido,
  COUNT(*)       AS pedidos_entregados,
  SUM(p.importe) AS ventas_netas
FROM stg_pedidos p
JOIN stg_clientes c ON c.id_cliente = p.id_cliente
WHERE p.estado_pedido = 'entregado'
  AND p.fecha_pedido IS NOT NULL
  AND p.importe > 0
GROUP BY c.estado_canonico, p.fecha_pedido
ORDER BY p.fecha_pedido, c.estado_canonico;

-- 7.2 Resumen por estado (captura mas legible)
SELECT
  c.estado_canonico,
  COUNT(*)       AS pedidos_entregados,
  SUM(p.importe) AS ventas_netas
FROM stg_pedidos p
JOIN stg_clientes c ON c.id_cliente = p.id_cliente
WHERE p.estado_pedido = 'entregado'
  AND p.fecha_pedido IS NOT NULL
  AND p.importe > 0
GROUP BY c.estado_canonico
ORDER BY ventas_netas DESC;

-- 7.3 Control: el total de 7.2 debe coincidir con este
SELECT COUNT(*)       AS pedidos_entregados,
       SUM(p.importe) AS ventas_netas
FROM stg_pedidos p
JOIN stg_clientes c ON c.id_cliente = p.id_cliente
WHERE p.estado_pedido = 'entregado'
  AND p.fecha_pedido IS NOT NULL
  AND p.importe > 0;