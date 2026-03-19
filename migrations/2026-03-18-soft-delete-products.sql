-- StockSafe production migration: soft delete for products
-- Safe to run multiple times.

BEGIN;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_products_restaurante_active
  ON products (restaurante_id, is_active);

UPDATE products
SET is_active = TRUE
WHERE is_active IS NULL;

COMMIT;
