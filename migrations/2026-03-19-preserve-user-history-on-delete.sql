-- StockSafe production migration: preserve inventory history when deleting internal users.
-- Safe to run multiple times.

BEGIN;

ALTER TABLE inventory_movements
  ALTER COLUMN restaurant_user_id DROP NOT NULL;

ALTER TABLE inventory_checks
  ALTER COLUMN restaurant_user_id DROP NOT NULL;

ALTER TABLE inventory_movements
  DROP CONSTRAINT IF EXISTS inventory_movements_restaurant_user_id_fkey;

ALTER TABLE inventory_checks
  DROP CONSTRAINT IF EXISTS inventory_checks_restaurant_user_id_fkey;

ALTER TABLE inventory_movements
  ADD CONSTRAINT inventory_movements_restaurant_user_id_fkey
  FOREIGN KEY (restaurant_user_id)
  REFERENCES restaurant_users(id)
  ON DELETE SET NULL
  ON UPDATE RESTRICT;

ALTER TABLE inventory_checks
  ADD CONSTRAINT inventory_checks_restaurant_user_id_fkey
  FOREIGN KEY (restaurant_user_id)
  REFERENCES restaurant_users(id)
  ON DELETE SET NULL
  ON UPDATE RESTRICT;

CREATE OR REPLACE FUNCTION validate_inventory_user_product_restaurant()
RETURNS TRIGGER AS $$
DECLARE
  product_restaurante_id BIGINT;
  user_restaurante_id BIGINT;
BEGIN
  IF NEW.restaurant_user_id IS NULL THEN
    RETURN NEW;
  END IF;

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

COMMIT;
