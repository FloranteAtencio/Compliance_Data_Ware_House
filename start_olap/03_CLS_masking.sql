BEGIN;

-- Masked views for analysts (no PII visible)
CREATE OR REPLACE VIEW Gold.v_dim_customer AS
SELECT
    customer_key,
    customer_id,
    'CUSTOMER-' || customer_id AS customer_name,
    customer_type, industry, country, region
FROM Gold.dim_customer;

CREATE OR REPLACE VIEW Gold.v_dim_client AS
SELECT
    client_key,
    client_id,
    'CLIENT-' || client_id AS client_name,
    client_type, industry, country, region
FROM Gold.dim_client;

-- Finance view: full amounts, masked names
CREATE OR REPLACE VIEW Gold.v_fact_ar AS
SELECT
    invoice_key, invoice_id, client_key, customer_key, currency_key,
    invoice_date_key, due_date_key,
    sub_total, discount, net_sales, tax_amount,
    total_amount, gross_amount, net_cash_flow,
    source_system, created_at
FROM Gold.fact_ar;

CREATE OR REPLACE VIEW Gold.v_fact_invoice_line AS
SELECT
    invoice_line_key, invoice_key, client_key, customer_key,
    location_key, product_key, invoice_date_key,
    quantity, unit_price, sub_total, discount, net_sales,
    tax_amount, total_amount, gross_amount, net_cash_flow,
    source_system, created_at
FROM Gold.fact_invoice_line;

CREATE OR REPLACE VIEW Gold.v_fact_gl AS
SELECT
    general_ledger_id, transaction, account_key, client_key,
    journal_date_key, debit_amount, credit_amount,
    source_system
FROM Gold.fact_gl;

COMMIT;

SELECT '03 COLUMN LEVEL SECURITY MASKING' AS STATUS;