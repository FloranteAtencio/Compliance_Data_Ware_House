SELECT 'Optimized Bronze Schema Start!' AS Status;

BEGIN;

CREATE SCHEMA IF NOT EXISTS Bronze;

-- ============================================================
-- 1. STAGING TABLE (AR Imports)
-- ============================================================
DROP TABLE IF EXISTS Bronze.stg_ar_imports;
CREATE TABLE IF NOT EXISTS Bronze.stg_ar_imports (
    id                  BIGSERIAL PRIMARY KEY, -- Scale-safe ID
    session_id          INT,
    invoice_code        TEXT,
    customer_code       TEXT,
    client_code         TEXT,
    amount              TEXT,                  -- Keep as TEXT for Silver validation
    invoice_date        TEXT,
    due_date            TEXT,
    status              TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL,
    UNIQUE(idempotency_key)
) PARTITION BY RANGE (imported_at); -- <--- CRITICAL for performance

-- Create initial partition (e.g., for 2024-2025)
CREATE TABLE Bronze.stg_ar_imports_y2024 PARTITION OF Bronze.stg_ar_imports
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- ============================================================
-- 2. DIMENSION TABLES (Staging)
-- ============================================================

DROP TABLE IF EXISTS Bronze.stg_account;
CREATE TABLE IF NOT EXISTS Bronze.stg_account (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    account_key         TEXT,
    account_id          TEXT,
    account_name        TEXT,
    account_type        TEXT,
    account_role        TEXT,
    account_category    TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_key, account_id)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.stg_date;
CREATE TABLE IF NOT EXISTS Bronze.stg_date (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    date_key            TEXT,
    date                TEXT,
    day                 TEXT,
    month               TEXT,
    month_name          TEXT,
    quarter             TEXT,
    year                TEXT,
    week                TEXT,
    day_of_week         TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(date_key, date)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.stg_client;
CREATE TABLE IF NOT EXISTS Bronze.stg_client (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    client_key          TEXT,
    client_id           TEXT,
    client_name         TEXT,
    client_type         TEXT,
    industry            TEXT,
    country             TEXT,
    region              TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_key, client_id)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.stg_customer;
CREATE TABLE IF NOT EXISTS Bronze.stg_customer (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    customer_key        TEXT,
    customer_id         TEXT,
    customer_name       TEXT,
    customer_type       TEXT,
    industry            TEXT,
    country             TEXT,
    region              TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(customer_key, customer_id)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.stg_location;
CREATE TABLE IF NOT EXISTS Bronze.stg_location (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    location_key        TEXT,
    location_id         TEXT,
    country             TEXT,
    region              TEXT,
    province            TEXT,
    city                TEXT,
    municipality        TEXT,
    barangay            TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(location_key, location_id)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.stg_currency;
CREATE TABLE IF NOT EXISTS Bronze.stg_currency (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    currency_key        TEXT,
    currency_id         TEXT,
    currency_code       TEXT,
    currency_name       TEXT,
    symbol              TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(currency_key, currency_id)
) PARTITION BY RANGE (imported_at);

-- ============================================================
-- 3. PRODUCT & LINES
-- ============================================================

DROP TABLE IF EXISTS Bronze.product;
CREATE TABLE IF NOT EXISTS Bronze.product (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    product_code        TEXT,
    product_name        TEXT,
    description         TEXT,
    product_unit        TEXT,
    quantity            TEXT,
    cost                TEXT,
    price               TEXT,
    purchase_date       TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_name, product_code)
) PARTITION BY RANGE (imported_at);

DROP TABLE IF EXISTS Bronze.ar_line;
CREATE TABLE IF NOT EXISTS Bronze.ar_line (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          INT,
    client_code         TEXT,
    invoice_code        TEXT,
    product_code        TEXT,
    quantity            TEXT,
    discount            TEXT,
    validation_status   TEXT DEFAULT NULL,
    validation_errors   TEXT DEFAULT NULL,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL, -- <--- Added NOT NULL
    UNIQUE(idempotency_key)
) PARTITION BY RANGE (imported_at);

COMMIT;

SELECT 'Optimized Bronze Schema Complete!' AS Status;