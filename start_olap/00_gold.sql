BEGIN;

-- Schema
CREATE SCHEMA IF NOT EXISTS Gold;

-- ============================================================
-- DIMENSIONS
-- ============================================================

DROP TABLE IF EXISTS Gold.dim_account CASCADE;
CREATE TABLE Gold.dim_account (
    account_key    BIGINT PRIMARY KEY,
    account_id     INT NOT NULL,
    account_name   VARCHAR(100) NOT NULL,
    account_type   VARCHAR(50),
    account_role   VARCHAR(50),
    account_category VARCHAR(50),
    UNIQUE(account_id)
);

DROP TABLE IF EXISTS Gold.dim_date CASCADE;
CREATE TABLE Gold.dim_date (
    date_key      BIGINT PRIMARY KEY,
    date          DATE NOT NULL,
    day           VARCHAR(10),
    month         VARCHAR(10),
    month_name    VARCHAR(20),
    quarter       VARCHAR(10),
    year          VARCHAR(10),
    week          VARCHAR(10),
    day_of_week   VARCHAR(20),
    UNIQUE(date)
);

DROP TABLE IF EXISTS Gold.dim_client CASCADE;
CREATE TABLE Gold.dim_client (
    client_key    BIGINT PRIMARY KEY,
    client_id     INT NOT NULL,
    client_name   VARCHAR(100) NOT NULL,
    client_type   VARCHAR(50),
    industry      VARCHAR(100),
    country       VARCHAR(50),
    region        VARCHAR(100),
    UNIQUE(client_id)
);

DROP TABLE IF EXISTS Gold.dim_customer CASCADE;
CREATE TABLE Gold.dim_customer (
    customer_key    BIGINT PRIMARY KEY,
    customer_id     INT NOT NULL,
    customer_name   VARCHAR(100) NOT NULL,
    customer_type   VARCHAR(50),
    industry        VARCHAR(100),
    country         VARCHAR(50),
    region          VARCHAR(100),
    UNIQUE(customer_id)
);

DROP TABLE IF EXISTS Gold.dim_location CASCADE;
CREATE TABLE Gold.dim_location (
    location_key    BIGINT PRIMARY KEY,
    location_id     INT NOT NULL,
    country         VARCHAR(50),
    region          VARCHAR(100),
    province        VARCHAR(100),
    city            VARCHAR(100),
    municipality    VARCHAR(100),
    barangay        VARCHAR(100),
    UNIQUE(location_id)
);

DROP TABLE IF EXISTS Gold.dim_currency CASCADE;
CREATE TABLE Gold.dim_currency (
    currency_key    BIGINT PRIMARY KEY,
    currency_id     INT NOT NULL,
    currency_code   VARCHAR(10) NOT NULL,
    currency_name   VARCHAR(50),
    symbol          VARCHAR(10),
    UNIQUE(currency_id, currency_code)
);

DROP TABLE IF EXISTS Gold.product CASCADE;
CREATE TABLE Gold.product (
    product_key       BIGINT PRIMARY KEY,
    product_id        INT NOT NULL,
    product_name      VARCHAR(200) NOT NULL,
    product_line_name VARCHAR(100),
    product_effective DATE,
    product_expired   DATE,
    UNIQUE(product_id)
);

-- ============================================================
-- FACT TABLES
-- ============================================================

DROP TABLE IF EXISTS Gold.fact_gl CASCADE;
CREATE TABLE Gold.fact_gl (
    general_ledger_id  BIGINT PRIMARY KEY
    ,transaction        TEXT
    ,account_key        BIGINT NOT NULL --REFERENCES Gold.dim_account(account_key)
    ,client_key         BIGINT NOT NULL --REFERENCES Gold.dim_client(client_key)
    ,journal_date_key   BIGINT NOT NULL --REFERENCES Gold.dim_date(date_key)
    ,debit_amount       DECIMAL(18,2) DEFAULT 0
    ,credit_amount      DECIMAL(18,2) DEFAULT 0
    ,source_system      VARCHAR(50)
    ,created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS Gold.fact_ar CASCADE;
CREATE TABLE Gold.fact_ar (
    invoice_key        BIGINT PRIMARY KEY
    ,invoice_id         TEXT NOT NULL
    ,client_key         BIGINT NOT NULL --REFERENCES Gold.dim_client(client_key)
    ,customer_key       BIGINT NOT NULL --REFERENCES Gold.dim_customer(customer_key)
    ,currency_key       BIGINT NOT NULL --REFERENCES Gold.dim_currency(currency_key)
    ,invoice_date_key   BIGINT NOT NULL --REFERENCES Gold.dim_date(date_key)
    ,due_date_key       BIGINT --REFERENCES Gold.dim_date(date_key)
    ,sub_total          DECIMAL(18,2) DEFAULT 0
    ,discount           DECIMAL(18,2) DEFAULT 0
    ,net_sales          DECIMAL(18,2) DEFAULT 0
    ,tax_amount         DECIMAL(18,2) DEFAULT 0
    ,total_amount       DECIMAL(18,2) DEFAULT 0
    ,gross_amount       DECIMAL(18,2) DEFAULT 0
    ,net_cash_flow      DECIMAL(18,2) DEFAULT 0
    ,source_system      VARCHAR(50)
    ,created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ,UNIQUE(invoice_id)
);

DROP TABLE IF EXISTS Gold.fact_invoice_line CASCADE;
CREATE TABLE Gold.fact_invoice_line (
    invoice_line_key   BIGINT PRIMARY KEY
    ,invoice_key        BIGINT NOT NULL --REFERENCES Gold.fact_ar(invoice_key)
    ,client_key         BIGINT NOT NULL --REFERENCES Gold.dim_client(client_key)
    ,customer_key       BIGINT NOT NULL --REFERENCES Gold.dim_customer(customer_key)
    ,location_key       BIGINT --REFERENCES Gold.dim_location(location_key)
    ,product_key        BIGINT --REFERENCES Gold.product(product_key)
    ,invoice_date_key   BIGINT NOT NULL --REFERENCES Gold.dim_date(date_key)
    ,quantity           DECIMAL(18,4) DEFAULT 0
    ,unit_price         DECIMAL(18,2) DEFAULT 0
    ,unit_cost          DECIMAL(18,2) DEFAULT 0
    ,sub_total          DECIMAL(18,2) DEFAULT 0
    ,discount           DECIMAL(18,2) DEFAULT 0
    ,net_sales          DECIMAL(18,2) DEFAULT 0
    ,tax_amount         DECIMAL(18,2) DEFAULT 0
    ,total_amount       DECIMAL(18,2) DEFAULT 0
    ,gross_amount       DECIMAL(18,2) DEFAULT 0
    ,net_cash_flow      DECIMAL(18,2) DEFAULT 0
    ,source_system      VARCHAR(50)
    ,created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMIT;

SELECT '00 GOLD LAYER SQL' AS STATUS
-- BEGIN;

-- CREATE SCHEMA Gold;

-- DROP TABLE IF EXISTS Gold.dim_account;
-- CREATE TABLE IF NOT EXISTS Gold.dim_account(

--     account_key BIGINT,
--     account_id INT,
--     account_name VARCHAR(50),
--     account_type VARCHAR(50),
--     account_role VARCHAR(50),
--     account_category VARCHAR(50),
--     UNIQUE(account_key, account_id)

-- );

-- DROP TABLE IF EXISTS Gold.dim_date;
-- CREATE TABLE IF NOT EXISTS Gold.dim_date(

--     date_key BIGINT,
--     date DATE,
--     day VARCHAR(50),
--     month VARCHAR(50),
--     month_name VARCHAR(50),
--     quarter VARCHAR(50),
--     year VARCHAR(50),
--     week VARCHAR(50),
--     day_of_week VARCHAR(50),
--     UNIQUE(date_key,date)

-- );


-- -- Client information
-- DROP TABLE IF EXISTS Gold.dim_client;
-- CREATE TABLE IF NOT EXISTS Gold.dim_client(

--     client_key BIGINT,
--     client_id INT,
--     client_name TEXT,
--     client_type VARCHAR(50),
--     industry TEXT,
--     country VARCHAR(50),
--     region TEXT,
--     UNIQUE(client_key,client_id)

-- );

-- -- Client information
-- DROP TABLE IF EXISTS Gold.dim_customer;
-- CREATE TABLE IF NOT EXISTS Gold.dim_customer(

--     customer_key BIGINT,
--     customer_id INT,
--     customer_name VARCHAR(50),
--     customer_type VARCHAR(50),
--     industry TEXT,
--     country VARCHAR(50),
--     region TEXT,
--     UNIQUE(customer_key,customer_id)

-- );

-- -- Location information
-- DROP TABLE IF EXISTS Gold.dim_location;
-- CREATE TABLE IF NOT EXISTS Gold.dim_location(

--     location_key BIGINT,
--     location_id INT,
--     country TEXT,
--     region TEXT,
--     province TEXT,
--     city TEXT,
--     municipality TEXT,
--     barangay TEXT,
--     UNIQUE(location_key,location_id)

-- );

-- DROP TABLE IF EXISTS Gold.dim_currency;
-- CREATE TABLE IF NOT EXISTS Gold.dim_currency(

--     currency_key BIGINT,
--     currency_id INT,
--     currency_code TEXT,
--     currency_name TEXT,
--     symbol TEXT,
--     UNIQUE(currency_key,currency_id)

-- );


-- -- DROP TABLE IF EXISTS Gold.invoice_date;
-- -- CREATE TABLE IF NOT EXISTS Gold.invoice_date(

-- -- invoice_date_key VARCHAR(50),
-- -- invoice_date_id INT,
-- -- invoice_date DATE,
-- -- UNIQUE(invoice_date_key,invoice_date_id)

-- -- );


-- -- DROP TABLE IF EXISTS Gold.due_date;
-- -- CREATE TABLE IF NOT EXISTS Gold.due_date(
-- --     due_date_key VARCHAR(50),
-- --     due_date_id INT,  -- Note: second field should probably be due_date_id
-- --     due_date DATE,
-- --     UNIQUE(due_date_key,due_date_id)
-- -- );

-- DROP TABLE IF EXISTS Gold.product;
-- CREATE TABLE IF NOT EXISTS Gold.product(
--     product_key BIGINT,
--     product_id INT,
--     product_name VARCHAR(50),
--     product_line_name VARCHAR(50),
--     product_effective Date,
--     product_expired date,
--     UNIQUE(product_key,product_id)
-- );

-- COMMIT;
-- BEGIN;

-- CREATE TABLE Gold.fact_gl (

--     general_ledger_id INT,
-- --    journal_id INT,

--     transaction TEXT,
--     account_key VARCHAR(50),
--     client_key VARCHAR(50),
--     journal_date_key VARCHAR(50),

--     debit_amount DECIMAL(18,2),
--     credit_amount DECIMAL(18,2),

--     source_system TEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );


-- CREATE TABLE Gold.fact_ar (
--     invoice_key VARCHAR(50),
--     invoice_id TEXT,

--     client_key VARCHAR(50),
--     customer_key VARCHAR(50),
--     currency_key VARCHAR(50),

--     invoice_date_key VARCHAR(50),
--     due_date_key VARCHAR(50),

--     sub_total DECIMAL(18,2),
--     discount DECIMAL(18,2),
--     net_sales DECIMAL(18,2),
--     tax_amount DECIMAL(18,2),
--     total_amount DECIMAL(18,2),
--     gross_amount DECIMAL(18,2),
--     net_cash_flow DECIMAL(18,2),

--     source_system TEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

--     UNIQUE(invoice_key, invoice_id)
-- );

-- CREATE TABLE Gold.fact_invoice_line (

--     invoice_line_key VARCHAR(50),
--     invoice_key TEXT,

--     client_key VARCHAR(50),
--     customer_key VARCHAR(50),
--     location_key VARCHAR(50),
--     product_key VARCHAR(50),

--     invoice_date_key VARCHAR(50),

--     quantity DECIMAL(18,2),
--     unit_price DECIMAL(18,2),

--     sub_total DECIMAL(18,2),
--     discount DECIMAL(18,2),
--     net_sales DECIMAL(18,2),
--     tax_amount DECIMAL(18,2),
--     total_amount DECIMAL(18,2),
--     gross_amount DECIMAL(18,2),
--     net_cash_flow DECIMAL(18,2),

--     source_system TEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

--     UNIQUE(invoice_key, invoice_line_key)
-- );

-- COMMIT;
