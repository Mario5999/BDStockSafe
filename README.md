# Base de datos PostgreSQL - StockSafe

Guia para despliegue con servidores separados:

- Servidor A: PostgreSQL
- Servidor B: Backend Node.js

## 1) Servidor A (Base de datos)

Ubicacion: carpeta Base de datos

1. Crear archivo .env a partir de .env.example

   Crea un archivo llamado .env y copia el contenido de .env.example.

2. Ajustar credenciales en .env

   POSTGRES_DB=stocksafe
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=una-clave-segura
   POSTGRES_PORT=5432

3. Levantar PostgreSQL

   docker compose -f docker-compose.db.yml up -d

Notas importantes:

- El esquema (postgresql_schema.sql) y el seed (postgresql_seed.sql) se aplican automaticamente solo en la inicializacion del volumen.
- Si necesitas reinicializar desde cero:

  docker compose -f docker-compose.db.yml down -v
  docker compose -f docker-compose.db.yml up -d

## 2) Servidor B (Backend)

Ubicacion: carpeta Backend

1. Instalar dependencias

   npm install

2. Crear archivo .env a partir de .env.example

   Crea un archivo llamado .env y copia el contenido de .env.example.

3. Configurar conexion al Servidor A (IP privada o DNS interno)

   DB_HOST=10.20.30.40
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=una-clave-segura
   DB_NAME=stocksafe
   DB_SSL=false

4. Verificar conexion desde backend

   npm run db:check

5. Levantar backend

   npm run start

## 3) Verificacion de salud

Con backend arriba, prueba:

GET /api/health/db

Si todo esta correcto responde:

- ok: true
- message: PostgreSQL disponible.

## 4) Seguridad recomendada en produccion

- Abrir el puerto 5432 solo para la IP del servidor backend.
- No exponer PostgreSQL a internet publica.
- Usar contrasenas robustas y distintas por ambiente.
- Activar SSL en la conexion (DB_SSL=true) cuando tengas TLS configurado.

## 5) Scripts utiles en Backend

Estos scripts son para entorno local o de mantenimiento:

- npm run db:up
- npm run db:down
- npm run db:reset
- npm run db:schema
- npm run db:seed
- npm run db:check
