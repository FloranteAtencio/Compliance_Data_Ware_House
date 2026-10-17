BEGIN;

-- Create roles (assign to users via GRANT in your app provisioning)
CREATE ROLE gold_analyst NOLOGIN;
CREATE ROLE gold_finance NOLOGIN;
CREATE ROLE gold_admin NOLOGIN;

-- Lock down schema access
REVOKE ALL ON SCHEMA Gold FROM PUBLIC;
GRANT USAGE ON SCHEMA Gold TO gold_analyst, gold_finance, gold_admin;

-- Base tables: only admin can select; analysts/finance use views
REVOKE ALL ON ALL TABLES IN SCHEMA Gold FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA Gold TO gold_admin;

-- Views: analysts and finance get SELECT
CREATE OR REPLACE VIEW Gold.v_dim_customer AS
SELECT
    customer_key,
    customer_id,
    'CUSTOMER-' || customer_id AS customer_name,  -- masked
    customer_type, industry, country, region
FROM Gold.dim_customer;

CREATE OR REPLACE VIEW Gold.v_dim_client AS
SELECT
    client_key,
    client_id,
    'CLIENT-' || client_id AS client_name,         -- masked
    client_type, industry, country, region
FROM Gold.dim_client;

CREATE OR REPLACE VIEW Gold.v_fact_ar AS
SELECT
    invoice_key, invoice_id, client_key, customer_key, currency_key,
    invoice_date_key, due_date_key,
    sub_total, discount, net_sales, tax_amount,
    total_amount, gross_amount, net_cash_flow,
    source_system, created_at
FROM Gold.fact_ar;

-- Views
GRANT SELECT ON Gold.v_dim_customer, Gold.v_dim_client TO gold_analyst, gold_finance;
GRANT SELECT ON Gold.v_fact_ar TO gold_finance;
GRANT SELECT ON Gold.v_fact_ar TO gold_analyst;
--GRANT SELECT ON Gold.v_dim_customer_decrypted, Gold.v_dim_client_decrypted TO gold_admin;

COMMIT;

SELECT '01 ACCESS CONTROL' AS STATUS;