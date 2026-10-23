SELECT 'Silver table schema start!' as  Status;

BEGIN;

-- ============================================================
-- Silver table or Silver stage 
-- On this layer data are already sanitated and validated 
-- this time record linage only
-- ============================================================
CREATE SCHEMA Silver;
-- 1. STAGING TABLE
CREATE TABLE IF NOT EXISTS Silver.stg_ar_imports(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    invoice_code        TEXT,
    customer_code       Domains.bigint_account_code_type,
    client_code         Domains.bigint_account_code_type,
    amount              DECIMAL(15,2),--Domains.amount_type,
    invoice_date        DATE,
    due_date            DATE,
    status              Domains.status_type,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL UNIQUE

);

DROP TABLE IF EXISTS Silver.stg_account;
CREATE TABLE IF NOT EXISTS Silver.stg_account(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    account_id          INT,
    account_name        VARCHAR(50),
    account_type        VARCHAR(50),
    account_role        VARCHAR(50),
    account_category    VARCHAR(50),
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP    
--    idempotency_key TEXT NOT NULL UNIQUE,
--    UNIQUE(idempotency_key)

);

-- Client information
DROP TABLE IF EXISTS Silver.stg_client;
CREATE TABLE IF NOT EXISTS Silver.stg_client(
    id                  BIGSERIAL PRIMARY KEY
    ,bronze_id          BIGINT          -- FK to Bronze.ar_line.id
    ,session_id         INT
    ,client_code          INT
    ,client_name        VARCHAR(250)
    ,contact_info       VARCHAR(25)--client_type         VARCHAR(50),
    ,email              VARCHAR(100)
    ,address            TEXT
    ,tax_id             VARCHAR(20)
    ,SSN                VARCHAR(20)
    ,imported_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
--    ,idempotency_key    TEXT NOT NULL UNIQUE
--    ,UNIQUE(client_key,client_id)

);

-- Client information
DROP TABLE IF EXISTS Silver.stg_customer;
CREATE TABLE IF NOT EXISTS Silver.stg_customer(
    id              BIGSERIAL PRIMARY KEY,
    bronze_id       BIGINT,          -- FK to Bronze.ar_line.id
    session_id      INT,
    client_code     INT,
    customer_id     INT,
    customer_name   VARCHAR(50),
    contact_info    VARCHAR(20),--client_type         VARCHAR(50),
    email           VARCHAR(100),
    address         TEXT,
    imported_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
--    idempotency_key TEXT NOT NULL UNIQUE,
--    UNIQUE(customer_key,customer_id)

);

DROP TABLE IF EXISTS Silver.stg_currency;
CREATE TABLE IF NOT EXISTS Silver.stg_currency(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    currency_id         INT,
    currency_code       TEXT,
    currency_name       TEXT,
    symbol              TEXT,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
--    idempotency_key     TEXT NOT NULL UNIQUE,
--    UNIQUE(currency_key,currency_id)

);

DROP TABLE IF EXISTS Silver.product;
CREATE TABLE IF NOT EXISTS Silver.product(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,
    client_code         INT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    product_code        INT,
    product_name        VARCHAR(50),
    description         TEXT,
    product_unit        VARCHAR(50),
    quantity            INT,
    cost                DECIMAL(10,2),
    price               DECIMAL(10,2),
    purchase_date       date,   
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL UNIQUE
--    UNIQUE(product_name,product_code)

);


-- Lineage + idempotency pattern for all Silver tables
CREATE TABLE IF NOT EXISTS Silver.ar_line (
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    client_code         BIGINT,
    invoice_code        TEXT,
    product_code        INT,            -- match Bronze type
    quantity            DECIMAL(18,4),
    discount            DECIMAL(18,2),
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL UNIQUE

);

-- Location information
DROP TABLE IF EXISTS Silver.stg_location;
CREATE TABLE IF NOT EXISTS Silver.stg_location(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    location_id         INT,
    client_code         INT,
    country             TEXT,
    region              TEXT,
    province            TEXT,
    city                TEXT,
    municipality        TEXT,
    barangay            TEXT,
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

DROP TABLE IF EXISTS Silver.stg_date;
CREATE TABLE IF NOT EXISTS Silver.stg_date(
    id                  BIGSERIAL PRIMARY KEY,
    bronze_id           BIGINT,          -- FK to Bronze.ar_line.id
    session_id          INT,
    date                DATE,
    day                 VARCHAR(50),
    month               VARCHAR(50),
    month_name          VARCHAR(50),
    quarter             VARCHAR(50),
    year                VARCHAR(50),
    week                VARCHAR(50),
    day_of_week         VARCHAR(50),
    date_type           VARCHAR(50),
    imported_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    idempotency_key     TEXT NOT NULL UNIQUE

);

COMMIT;

SELECT 'Silver table schema complete!' as  Status;
-- INSERT INTO Silver.stg_date (
--     bronze_id,
--     session_id,
--     date,
--     day,
--     month,
--     month_name,
--     quarter,
--     year,
--     week,
--     day_of_week,
--     imported_at,
--     idempotency_key
-- )
-- SELECT 
--     NULL,                              -- bronze_id if you don't have one
--     NULL,                              -- session_id if you don't have one
--     CAST(invoice_date AS DATE)         AS date,
--     EXTRACT(DAY FROM CAST(invoice_date AS DATE))::VARCHAR AS day,
--     EXTRACT(MONTH FROM CAST(invoice_date AS DATE))::VARCHAR AS month,
--     TO_CHAR(CAST(invoice_date AS DATE), 'Month') AS month_name,
--     'Q' || EXTRACT(QUARTER FROM CAST(invoice_date AS DATE))::VARCHAR AS quarter,
--     EXTRACT(YEAR FROM CAST(invoice_date AS DATE))::VARCHAR AS year,
--     EXTRACT(WEEK FROM CAST(invoice_date AS DATE))::VARCHAR AS week,
--     TO_CHAR(CAST(invoice_date AS DATE), 'Day') AS day_of_week,
--     CURRENT_TIMESTAMP                  AS imported_at,
--     'date-' || TO_CHAR(CAST(invoice_date AS DATE), 'YYYY-MM-DD') AS idempotency_key
-- FROM your_source_table
-- WHERE invoice_date IS NOT NULL;

-- INSERT INTO Silver.stg_date (...)
-- SELECT 
--     NULL, NULL,
--     CAST(date_val AS DATE),
--     EXTRACT(DAY FROM CAST(date_val AS DATE))::VARCHAR,
--     EXTRACT(MONTH FROM CAST(date_val AS DATE))::VARCHAR,
--     TO_CHAR(CAST(date_val AS DATE), 'Month'),
--     'Q' || EXTRACT(QUARTER FROM CAST(date_val AS DATE))::VARCHAR,
--     EXTRACT(YEAR FROM CAST(date_val AS DATE))::VARCHAR,
--     EXTRACT(WEEK FROM CAST(date_val AS DATE))::VARCHAR,
--     TO_CHAR(CAST(date_val AS DATE), 'Day'),
--     CURRENT_TIMESTAMP,
--     'date-' || TO_CHAR(CAST(date_val AS DATE), 'YYYY-MM-DD')
-- FROM (
--     SELECT invoice_date AS date_val FROM source WHERE invoice_date IS NOT NULL
--     UNION ALL
--     SELECT due_date AS date_val FROM source WHERE due_date IS NOT NULL
-- ) combined;