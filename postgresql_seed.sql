-- StockSafe - Datos iniciales PostgreSQL

BEGIN;

INSERT INTO restaurantes (
  restaurant_name,
  address,
  phone,
  email,
  password_hash,
  manager_name,
  manager_email
)
VALUES
  ('Restaurante A', 'Calle A 101', '5550001001', 'restaurante.a@stocksafe.com', '123456', 'Rosita', 'rosita@restaurantea.com'),
  ('Restaurante B', 'Avenida B 202', '5550002002', 'restaurante.b@stocksafe.com', '123456', 'Flor', 'flor@restauranteb.com')
ON CONFLICT (email) DO NOTHING;

INSERT INTO system_users (
  email,
  password_hash
)
VALUES
  ('admin@stocksafe.com', '123456')
ON CONFLICT (email) DO NOTHING;

INSERT INTO restaurant_users (
  restaurante_id,
  nombre_completo,
  usuario,
  password_hash,
  rol
)
SELECT r.id, u.nombre_completo, u.usuario, u.password_hash, u.rol
FROM restaurantes r
CROSS JOIN (
  VALUES
    ('Rosita', 'rosita', '123456', 'gerente'),
    ('Juan', 'juan', '123456', 'empleado')
) AS u(nombre_completo, usuario, password_hash, rol)
WHERE r.restaurant_name = 'Restaurante A'
ON CONFLICT (usuario) DO NOTHING;

INSERT INTO restaurant_users (
  restaurante_id,
  nombre_completo,
  usuario,
  password_hash,
  rol
)
SELECT r.id, u.nombre_completo, u.usuario, u.password_hash, u.rol
FROM restaurantes r
CROSS JOIN (
  VALUES
    ('Flor', 'flor', '123456', 'gerente'),
    ('Carmen', 'carmen', '123456', 'empleado')
) AS u(nombre_completo, usuario, password_hash, rol)
WHERE r.restaurant_name = 'Restaurante B'
ON CONFLICT (usuario) DO NOTHING;

INSERT INTO sections (restaurante_id, nombre)
SELECT r.id, s.nombre
FROM restaurantes r
JOIN (
  VALUES
    ('restaurante.a@stocksafe.com', 'Perfume'),
    ('restaurante.b@stocksafe.com', 'Carne')
) AS s(restaurant_email, nombre)
  ON s.restaurant_email = r.email
ON CONFLICT (restaurante_id, nombre) DO NOTHING;

INSERT INTO products (
  restaurante_id,
  section_id,
  nombre,
  cantidad,
  unidad,
  stock_minimo,
  stock_maximo
)
SELECT
  r.id,
  s.id,
  'Perfume de pina',
  10,
  'pz',
  2,
  20
FROM restaurantes r
JOIN sections s ON s.restaurante_id = r.id AND s.nombre = 'Perfume'
WHERE r.email = 'restaurante.a@stocksafe.com'
  AND NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.restaurante_id = r.id
      AND p.nombre = 'Perfume de pina'
  );

INSERT INTO products (
  restaurante_id,
  section_id,
  nombre,
  cantidad,
  unidad,
  stock_minimo,
  stock_maximo
)
SELECT
  r.id,
  s.id,
  'Bisteck',
  30,
  'kg',
  8,
  60
FROM restaurantes r
JOIN sections s ON s.restaurante_id = r.id AND s.nombre = 'Carne'
WHERE r.email = 'restaurante.b@stocksafe.com'
  AND NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.restaurante_id = r.id
      AND p.nombre = 'Bisteck'
  );

COMMIT;
