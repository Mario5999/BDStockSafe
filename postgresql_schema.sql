-- StockSafe - Esquema PostgreSQL v2
-- Ejecutar sobre una base de datos ya creada (ejemplo: stocksafe)

BEGIN;

-- ============================================================
-- RESTAURANTES
-- Datos de registro público del restaurante.
-- email + password_hash son las credenciales de acceso del restaurante.
-- manager_name / manager_email son datos de contacto del responsable
-- visibles para el administrador global.
-- ============================================================
CREATE TABLE IF NOT EXISTS restaurantes (
  id                      BIGSERIAL PRIMARY KEY,
  restaurant_name         VARCHAR(120) NOT NULL,
  address                 TEXT NOT NULL,
  phone                   VARCHAR(25) NOT NULL,
  email                   VARCHAR(150) NOT NULL UNIQUE,
  password_hash           TEXT NOT NULL,
  manager_name            VARCHAR(120) NOT NULL,
  manager_email           VARCHAR(150) NOT NULL UNIQUE,
  reset_token             VARCHAR(128),
  reset_token_expires_at  TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SYSTEM_USERS
-- Administrador global de la plataforma (solo un usuario).
-- Acceso por correo y contraseña.
-- Pueden ver todos los restaurantes registrados.
-- ============================================================
CREATE TABLE IF NOT EXISTS system_users (
  id                      BIGSERIAL PRIMARY KEY,
  email                   VARCHAR(150) NOT NULL UNIQUE,
  password_hash           TEXT NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- RESTAURANT_USERS - TABLA NUEVA
-- Usuarios internos de cada restaurante: gerente y empleado.
-- El gerente gestiona secciones y productos.
-- El empleado registra movimientos y verificaciones físicas.
-- Acceso por usuario (username), no por correo.
-- No incluye recuperación de contraseña para estos usuarios.
-- Un restaurante debe tener exactamente un gerente y un empleado.
-- ============================================================
CREATE TABLE IF NOT EXISTS restaurant_users (
  id                      BIGSERIAL PRIMARY KEY,
  restaurante_id          BIGINT NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  nombre_completo         VARCHAR(120) NOT NULL,
  usuario                 VARCHAR(80) NOT NULL UNIQUE,
  password_hash           TEXT NOT NULL,
  rol                     VARCHAR(20) NOT NULL CHECK (rol IN ('gerente', 'empleado')),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Garantiza que cada restaurante tenga un solo gerente y un solo empleado
  UNIQUE (restaurante_id, rol)
);

-- ============================================================
-- SECTIONS
-- Secciones del inventario creadas por el gerente de cada restaurante.
-- Ahora pertenecen a un restaurante específico.
-- El nombre puede repetirse entre restaurantes distintos,
-- pero no dentro del mismo restaurante.
-- ============================================================
CREATE TABLE IF NOT EXISTS sections (
  id                      BIGSERIAL PRIMARY KEY,
  restaurante_id          BIGINT NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  nombre                  VARCHAR(100) NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (restaurante_id, nombre),
  UNIQUE (restaurante_id, id)
);

-- ============================================================
-- PRODUCTS
-- Productos del inventario de cada restaurante.
-- La sección representa la categoría del producto.
-- La cantidad representa el stock inicial/cantidad actual.
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
  id                      BIGSERIAL PRIMARY KEY,
  restaurante_id          BIGINT NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  section_id              BIGINT NOT NULL REFERENCES sections(id) ON DELETE RESTRICT,
  nombre                  VARCHAR(140) NOT NULL,
  unidad                  VARCHAR(20) NOT NULL,
  cantidad                NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
  stock_minimo            NUMERIC(12,2) NOT NULL CHECK (stock_minimo >= 0),
  stock_maximo            NUMERIC(12,2) NOT NULL CHECK (stock_maximo >= stock_minimo),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INVENTORY_MOVEMENTS
-- Historial de movimientos de inventario (entrada, salida, ajuste).
-- Solo el empleado del restaurante realiza estos movimientos.
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_movements (
  id                      BIGSERIAL PRIMARY KEY,
  product_id              BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  restaurant_user_id      BIGINT NOT NULL REFERENCES restaurant_users(id) ON DELETE RESTRICT,
  movement_type           VARCHAR(20) NOT NULL CHECK (movement_type IN ('entry', 'exit', 'adjustment')),
  quantity                NUMERIC(12,2) NOT NULL CHECK (quantity > 0),
  previous_quantity       NUMERIC(12,2) NOT NULL CHECK (previous_quantity >= 0),
  new_quantity            NUMERIC(12,2) NOT NULL CHECK (new_quantity >= 0),
  note                    TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INVENTORY_CHECKS
-- Verificaciones físicas del inventario realizadas por el empleado.
-- Compara la cantidad en sistema vs el conteo real.
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_checks (
  id                      BIGSERIAL PRIMARY KEY,
  product_id              BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  restaurant_user_id      BIGINT NOT NULL REFERENCES restaurant_users(id) ON DELETE RESTRICT,
  cantidad_sistema        NUMERIC(12,2) NOT NULL CHECK (cantidad_sistema >= 0),
  cantidad_fisica         NUMERIC(12,2) NOT NULL CHECK (cantidad_fisica >= 0),
  diferencia              NUMERIC(12,2) NOT NULL,
  checked_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- REPORT_GENERATIONS
-- Cabecera de cada reporte PDF generado por restaurante.
-- ============================================================
CREATE TABLE IF NOT EXISTS report_generations (
  id                      BIGSERIAL PRIMARY KEY,
  restaurante_id          BIGINT NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- REPORT_GENERATION_ITEMS
-- Detalle por seccion/producto de cada reporte generado.
-- Guarda IDs y snapshot de datos para poder volver a ver el
-- reporte historico sin depender del estado actual del inventario.
-- ============================================================
CREATE TABLE IF NOT EXISTS report_generation_items (
  id                      BIGSERIAL PRIMARY KEY,
  report_generation_id    BIGINT NOT NULL REFERENCES report_generations(id) ON DELETE CASCADE,
  restaurante_id          BIGINT NOT NULL REFERENCES restaurantes(id) ON DELETE CASCADE,
  seccion_id              BIGINT NOT NULL REFERENCES sections(id) ON DELETE RESTRICT,
  producto_id             BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  seccion_nombre          VARCHAR(100) NOT NULL,
  producto_nombre         VARCHAR(140) NOT NULL,
  unidad                  VARCHAR(20) NOT NULL,
  entradas                NUMERIC(12,2) NOT NULL DEFAULT 0,
  salidas                 NUMERIC(12,2) NOT NULL DEFAULT 0,
  diferencia_verificacion NUMERIC(12,2) NOT NULL DEFAULT 0,
  generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (report_generation_id, producto_id)
);

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_restaurantes_email             ON restaurantes(email);
CREATE INDEX IF NOT EXISTS idx_restaurantes_manager_email     ON restaurantes(manager_email);
CREATE INDEX IF NOT EXISTS idx_system_users_email             ON system_users(email);
CREATE INDEX IF NOT EXISTS idx_restaurant_users_restaurante   ON restaurant_users(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_users_usuario       ON restaurant_users(usuario);
CREATE INDEX IF NOT EXISTS idx_sections_restaurante_id        ON sections(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_products_restaurante_id        ON products(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_products_section_id            ON products(section_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_user_id    ON inventory_movements(restaurant_user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_checks_product_id    ON inventory_checks(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_checks_user_id       ON inventory_checks(restaurant_user_id);
CREATE INDEX IF NOT EXISTS idx_report_generations_restaurante ON report_generations(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_report_generations_generated   ON report_generations(generated_at DESC);
CREATE INDEX IF NOT EXISTS idx_report_items_generation_id     ON report_generation_items(report_generation_id);
CREATE INDEX IF NOT EXISTS idx_report_items_restaurante_id    ON report_generation_items(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_report_items_seccion_id        ON report_generation_items(seccion_id);
CREATE INDEX IF NOT EXISTS idx_report_items_producto_id       ON report_generation_items(producto_id);

-- Fuerza un solo administrador global en system_users.
CREATE UNIQUE INDEX IF NOT EXISTS idx_system_users_singleton  ON system_users ((true));

-- ============================================================
-- FUNCIÓN updated_at
-- Reutilizable por todos los triggers de actualización.
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Valida que la sección asociada al producto pertenezca al mismo restaurante.
CREATE OR REPLACE FUNCTION validate_product_section_restaurant()
RETURNS TRIGGER AS $$
DECLARE
  section_restaurante_id BIGINT;
BEGIN
  IF NEW.section_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT s.restaurante_id
  INTO section_restaurante_id
  FROM sections s
  WHERE s.id = NEW.section_id;

  IF section_restaurante_id IS NULL THEN
    RAISE EXCEPTION 'La sección % no existe.', NEW.section_id;
  END IF;

  IF section_restaurante_id <> NEW.restaurante_id THEN
    RAISE EXCEPTION 'La sección % no pertenece al restaurante %.', NEW.section_id, NEW.restaurante_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Valida que el usuario que registra movimiento/verificación pertenezca al mismo restaurante del producto.
CREATE OR REPLACE FUNCTION validate_inventory_user_product_restaurant()
RETURNS TRIGGER AS $$
DECLARE
  product_restaurante_id BIGINT;
  user_restaurante_id BIGINT;
BEGIN
  SELECT p.restaurante_id
  INTO product_restaurante_id
  FROM products p
  WHERE p.id = NEW.product_id;

  IF product_restaurante_id IS NULL THEN
    RAISE EXCEPTION 'El producto % no existe.', NEW.product_id;
  END IF;

  SELECT ru.restaurante_id
  INTO user_restaurante_id
  FROM restaurant_users ru
  WHERE ru.id = NEW.restaurant_user_id;

  IF user_restaurante_id IS NULL THEN
    RAISE EXCEPTION 'El usuario de restaurante % no existe.', NEW.restaurant_user_id;
  END IF;

  IF product_restaurante_id <> user_restaurante_id THEN
    RAISE EXCEPTION 'El producto % y el usuario % no pertenecen al mismo restaurante.', NEW.product_id, NEW.restaurant_user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGERS updated_at
-- ============================================================
DROP TRIGGER IF EXISTS trg_restaurantes_updated_at ON restaurantes;
CREATE TRIGGER trg_restaurantes_updated_at
BEFORE UPDATE ON restaurantes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_system_users_updated_at ON system_users;
CREATE TRIGGER trg_system_users_updated_at
BEFORE UPDATE ON system_users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_restaurant_users_updated_at ON restaurant_users;
CREATE TRIGGER trg_restaurant_users_updated_at
BEFORE UPDATE ON restaurant_users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sections_updated_at ON sections;
CREATE TRIGGER trg_sections_updated_at
BEFORE UPDATE ON sections
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_validate_section_restaurante ON products;
CREATE TRIGGER trg_products_validate_section_restaurante
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION validate_product_section_restaurant();

DROP TRIGGER IF EXISTS trg_inventory_movements_validate_user_product_restaurante ON inventory_movements;
CREATE TRIGGER trg_inventory_movements_validate_user_product_restaurante
BEFORE INSERT OR UPDATE ON inventory_movements
FOR EACH ROW EXECUTE FUNCTION validate_inventory_user_product_restaurant();

DROP TRIGGER IF EXISTS trg_inventory_checks_validate_user_product_restaurante ON inventory_checks;
CREATE TRIGGER trg_inventory_checks_validate_user_product_restaurante
BEFORE INSERT OR UPDATE ON inventory_checks
FOR EACH ROW EXECUTE FUNCTION validate_inventory_user_product_restaurant();

-- ============================================================
-- VISTA vw_product_stock_status
-- Calcula el estado del stock por producto.
-- Ahora incluye restaurante_id para filtrar por restaurante.
-- ============================================================
CREATE OR REPLACE VIEW vw_product_stock_status AS
SELECT
  p.id,
  p.restaurante_id,
  p.nombre,
  s.nombre AS categoria,
  p.cantidad,
  p.unidad,
  p.stock_minimo,
  p.stock_maximo,
  CASE
    WHEN p.cantidad = 0                  THEN 'out'
    WHEN p.cantidad < p.stock_minimo     THEN 'low'
    WHEN p.cantidad > p.stock_maximo     THEN 'excess'
    ELSE                                      'ok'
  END AS status
FROM products p
JOIN sections s ON s.id = p.section_id;

-- ============================================================
-- VISTA vw_product_movements_summary - VISTA NUEVA
-- Calcula entradas y salidas totales por producto directamente
-- desde inventory_movements, reemplazando las columnas eliminadas.
-- Úsala cuando necesites los acumulados en reportes.
-- ============================================================
CREATE OR REPLACE VIEW vw_product_movements_summary AS
SELECT
  p.id                                                        AS product_id,
  p.restaurante_id,
  p.nombre,
  p.cantidad                                                  AS stock_actual,
  p.cantidad                                                  AS stock_inicial,
  COALESCE(SUM(CASE WHEN m.movement_type = 'entry'  THEN m.quantity ELSE 0 END), 0) AS total_entradas,
  COALESCE(SUM(CASE WHEN m.movement_type = 'exit'   THEN m.quantity ELSE 0 END), 0) AS total_salidas,
  COALESCE(SUM(CASE WHEN m.movement_type = 'adjustment' THEN m.quantity ELSE 0 END), 0) AS total_ajustes
FROM products p
LEFT JOIN inventory_movements m ON m.product_id = p.id
GROUP BY p.id, p.restaurante_id, p.nombre, p.cantidad;

COMMIT;