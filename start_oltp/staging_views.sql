    --Procuct Line
DROP VIEW IF EXISTS silver.product_line;
CREATE VIEW silver.product_line AS
SELECT
    sai.invoice_code,
    sai.customer_code,
    al.product_code,
    sai.client_code,
    sai.invoice_date,
    p.price                                          AS product_price,
    p.cost                                           AS product_cost,
    al.quantity                                      AS sold_quantity,
    ROUND(p.price * al.quantity, 2)                  AS sub_total,
    ROUND(p.price * al.discount * al.quantity, 2)    AS discount,
    ROUND(p.price * (1 - al.discount) * al.quantity, 2)                    AS net_sales,
    ROUND(p.price * (1 - al.discount) * al.quantity * 0.10, 2)             AS tax_amount,
    ROUND(p.price * (1 - al.discount) * al.quantity * 1.10, 2)             AS total_amount,
    ROUND((p.price * (1 - al.discount) - p.cost) * al.quantity, 2)         AS net_profit_or_gross_amount,
    -- Verify intent here; currently equals net_profit_or_gross_amount
    ROUND((p.price * (1 - al.discount) - p.cost) * al.quantity, 2)         AS net_cash_flow,
    'CSV_Import'                                     AS source
FROM silver.stg_ar_imports sai
LEFT JOIN silver.ar_line al USING (invoice_code)
LEFT JOIN silver.product p  USING (product_code);

-- DROP VIEW IF EXISTS Silver.product_line;
-- CREATE VIEW Silver.product_line as 
--     SELECT 

--         sai.invoice_code
--         ,sai.customer_code
--         ,al.product_code
--         ,sai.client_code
--         ,sai.invoice_date
--         ,p.price as  product_price
--         ,p.cost as product_cost
--         ,al.quantity as sold_quantity
--         ,round((p.price * al.quantity),2) as sub_total
--         ,round(((p.price * al.discount) * al.quantity ),2) as discount
--         ,round(((p.price - (p.price * al.discount)) * al.quantity ),2) as net_sales
--         ,round((((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ),2) as tax_amount
--         ,round((((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ),2) as total_amount
--         ,round(((p.price - (p.price * al.discount) - p.cost) * al.quantity ),2) as net_profit_or_gross_amount
--         ,round((((p.price - (p.price * al.discount) + ( p.price - (p.price * al.discount) * 0.10))  - p.cost - ( p.price - (p.price * al.discount) * 0.10) ) * al.quantity ) ,2)as net_cash_flow
--         ,'CSV_Import' as souurce
--     FROM Silver.stg_ar_imports sai
--     LEFT JOIN Silver.ar_line al USING(invoice_code)
--     LEFT JOIN Silver.product p USING(product_code);


DROP VIEW IF EXISTS silver.account_receivables_fact;
CREATE VIEW silver.account_receivables_fact AS
SELECT
    sai.invoice_code,
    sai.client_code,
    sai.customer_code,
    sai.invoice_date,
    sai.due_date,
    COALESCE(agg.sub_total, 0)                  AS sub_total,
    COALESCE(agg.discount, 0)                   AS discount,
    COALESCE(agg.net_sales, 0)                  AS net_sales,
    COALESCE(agg.tax_amount, 0)                 AS tax_amount,
    COALESCE(agg.total_amount, 0)               AS total_amount,
    COALESCE(agg.net_profit_or_gross_amount, 0) AS net_profit_or_gross_amount,
    COALESCE(agg.net_cash_flow, 0)              AS net_cash_flow,
    'CSV_import'                                AS source
FROM silver.stg_ar_imports sai
LEFT JOIN (
    SELECT
        al.invoice_code,
        ROUND(SUM(p.price * al.quantity), 2)                                  AS sub_total,
        ROUND(SUM(p.price * al.discount * al.quantity), 2)                    AS discount,
        ROUND(SUM(p.price * (1 - al.discount) * al.quantity), 2)              AS net_sales,
        ROUND(SUM(p.price * (1 - al.discount) * al.quantity * 0.10), 2)       AS tax_amount,
        ROUND(SUM(p.price * (1 - al.discount) * al.quantity * 1.10), 2)       AS total_amount,
        ROUND(SUM((p.price * (1 - al.discount) - p.cost) * al.quantity), 2)   AS net_profit_or_gross_amount,
        -- Verify intent: this currently equals net_profit_or_gross_amount
        ROUND(SUM((p.price * (1 - al.discount) - p.cost) * al.quantity), 2)   AS net_cash_flow
    FROM silver.ar_line al
    LEFT JOIN silver.product p USING (product_code)
    GROUP BY al.invoice_code
) agg ON agg.invoice_code = sai.invoice_code;

--     SELECT * FROM Silver.product_line;
--     -- AR
--     DROP VIEW  IF EXISTS Silver.account_receivables_fact;
--     CREATE VIEW  Silver.account_receivables_fact as
--     SELECT 

--         sai.invoice_code,
--         sai.client_code,
--         sai.customer_code,
--         sai.invoice_date,
--         sai.due_date,
--         (SELECT round(sum( (p.price * al.quantity) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as sub_total,
--         (SELECT round(sum( ((p.price * al.discount) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as discount,
--         (SELECT round(sum( ((p.price - (p.price * al.discount)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_sales,    
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as tax_amount,
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as total_amount,
--         (SELECT round(sum( ((p.price - (p.price * al.discount) - p.cost) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_profit_or_gross_amount,
--         (SELECT round(sum( (((p.price - (p.price * al.discount) + ( p.price - (p.price * al.discount) * 0.10))  - p.cost - ( p.price - (p.price * al.discount) * 0.10) ) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_cash_flow,
--         'CSV_import' as  source
--     FROM silver.stg_ar_imports sai;
-- SELECT * FROM Silver.account_receivables_fact;

DROP VIEW IF EXISTS silver.general_ledger_view;

CREATE VIEW silver.general_ledger_view AS
WITH invoice_totals AS (
    SELECT 
        sai.invoice_code,
        sai.client_code,
        sai.customer_code,
        sai.invoice_date,
        sai.due_date,
        sai.status,
        COALESCE(sai.amount, 0) AS cash_received,
        COALESCE(SUM(p.price * al.quantity), 0) AS sub_total,
        COALESCE(SUM(p.price * al.discount * al.quantity), 0) AS total_discount,
        COALESCE(SUM(p.price * (1 - al.discount) * al.quantity), 0) AS net_sales,
        COALESCE(SUM(p.price * (1 - al.discount) * al.quantity * 0.10), 0) AS tax_amount,
        COALESCE(SUM(p.price * (1 - al.discount) * al.quantity * 1.10), 0) AS gross_total,
        COALESCE(SUM(p.cost * al.quantity), 0) AS cogs
    FROM silver.stg_ar_imports sai
    LEFT JOIN silver.ar_line al ON sai.invoice_code = al.invoice_code
    LEFT JOIN silver.product p ON al.product_code = p.product_code
    GROUP BY 
        sai.invoice_code, sai.client_code, sai.customer_code, 
        sai.invoice_date, sai.due_date, sai.status, sai.amount
),

normal_invoices AS (
    SELECT 
        format('Invoice - %s', invoice_code) AS transaction,
        client_code,
        invoice_date AS journal_date_key,
        'CSV_Import' AS source,
        status,
        gross_total,
        net_sales,
        tax_amount,
        cogs
    FROM invoice_totals
    WHERE status NOT IN ('RETURNED', 'VOID', 'CANCELLED')
),

returned_invoices AS (
    SELECT 
        format('Return - %s', invoice_code) AS transaction,
        client_code,
        invoice_date AS journal_date_key,
        'CSV_Import' AS source,
        status,
        gross_total,
        net_sales,
        tax_amount,
        cogs
    FROM invoice_totals
    WHERE status IN ('RETURNED', 'CANCELLED')
),

gl_normal AS (
    SELECT transaction, 'Account Receivables' AS account_key, client_code AS client_key, journal_date_key, gross_total AS debit_amount, 0.00 AS credit_amount, source FROM normal_invoices
    UNION ALL
    SELECT transaction, 'Sales Revenue' AS account_key, client_code AS client_key, journal_date_key, 0.00 AS debit_amount, net_sales AS credit_amount, source FROM normal_invoices
    UNION ALL
    SELECT transaction, 'Tax Payable' AS account_key, client_code AS client_key, journal_date_key, 0.00 AS debit_amount, tax_amount AS credit_amount, source FROM normal_invoices
    UNION ALL
    SELECT transaction || ' (COGS)', 'Cost Of Goods Sold' AS account_key, client_code AS client_key, journal_date_key, cogs AS debit_amount, 0.00 AS credit_amount, source FROM normal_invoices
    UNION ALL
    SELECT transaction || ' (Inv)', 'Inventory' AS account_key, client_code AS client_key, journal_date_key, 0.00 AS debit_amount, cogs AS credit_amount, source FROM normal_invoices
),

gl_returned AS (
    SELECT transaction, 'Sales Returns and Allowances' AS account_key, client_code AS client_key, journal_date_key, net_sales AS debit_amount, 0.00 AS credit_amount, source FROM returned_invoices
    UNION ALL
    SELECT transaction, 'Tax Payable' AS account_key, client_code AS client_key, journal_date_key, tax_amount AS debit_amount, 0.00 AS credit_amount, source FROM returned_invoices
    UNION ALL
    SELECT transaction, 'Account Receivables' AS account_key, client_code AS client_key, journal_date_key, 0.00 AS debit_amount, gross_total AS credit_amount, source FROM returned_invoices
    UNION ALL
    SELECT transaction || ' (Inv)', 'Inventory' AS account_key, client_code AS client_key, journal_date_key, cogs AS debit_amount, 0.00 AS credit_amount, source FROM returned_invoices
    UNION ALL
    SELECT transaction || ' (COGS)', 'Cost Of Goods Sold' AS account_key, client_code AS client_key, journal_date_key, 0.00 AS debit_amount, cogs AS credit_amount, source FROM returned_invoices
),

cash_entries AS (
    SELECT 
        format('Payment - %s', invoice_code) AS transaction,
        'Cash/Bank' AS account_key,
        client_code AS client_key,
        invoice_date AS journal_date_key,
        cash_received AS debit_amount,
        0.00 AS credit_amount,
        'CSV_Import' AS source
    FROM invoice_totals
    WHERE cash_received > 0
    UNION ALL
    SELECT 
        format('Payment - %s', invoice_code) AS transaction,
        'Account Receivables' AS account_key,
        client_code AS client_key,
        invoice_date AS journal_date_key,
        0.00 AS debit_amount,
        cash_received AS credit_amount,
        'CSV_Import' AS source
    FROM invoice_totals
    WHERE cash_received > 0
)

SELECT * FROM gl_normal
UNION ALL
SELECT * FROM gl_returned
UNION ALL
SELECT * FROM cash_entries;

-- CREATE VIEW general_ledger_view AS 
--     ---account receivables
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Account Receivables' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     UNION ALL
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Sales Revenue' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         round((((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ),2) as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.Staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     UNION ALL
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Tax Payable' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     --WHERE sai.status IN ('pending','paid','partially paid');
--     UNION ALL
--     --- =====================================================
--     -- Account Receivables
--     -- discount
--     --- =====================================================
--     -- ar discount
--     SELECT 

--         format('Invoice - %s (%s) ',sai.invoice_code, p.product_name) as transaction,
--         'Account Receivables' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         round(((p.price * al.discount) * al.quantity ),2) as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     WHERE al.discount > 0
--     UNION ALL
--     -- Sales Discount
--     SELECT 

--         format('Invoice - %s (%s) ',sai.invoice_code, p.product_name) as transaction,
--         'Sales Discount' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         round(((p.price * al.discount) * al.quantity ),2) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     WHERE al.discount > 0
--     UNION ALL
--     --- =====================================================
--     -- account receivable
--     -- cash/bank
--     --- =====================================================
--     -- Payment AR
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Account Receivables' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         sai.amount as credit_amount,
--     --    round(((p.price * al.discount) * al.quantity ),2) as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     -- LEFT JOIN staging.ar_line al USING(invoice_code)
--     -- LEFT JOIN staging.product p USING(product_code)
--     WHERE sai.amount > 0
--     UNION ALL
--     --sai.status IN ('pending','paid','partially paid') and 
--     -- PAYMENT CASH
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Cash/Bank' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         sai.amount as debit_amount,
--     --    round(((p.price * al.discount) * al.quantity ),2) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     -- LEFT JOIN staging.ar_line al USING(invoice_code)
--     -- LEFT JOIN staging.product p USING(product_code)
--     WHERE sai.amount > 0
--     UNION ALL
--     --- =====================================================
--     -- COST OF GOOD SOLE 
--     -- INVENTORY
--     --- ====================================================
--     SELECT 
--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Cost Of Good Sold' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         (SELECT round(sum(  p.cost * al.quantity),2 )FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as debit_amount,    
--     --    (SELECT round(sum( (((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     UNION ALL
--     -- WHERE sai.status IN ('pending','paid','partially paid');
--     SELECT 
--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Inventory' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         (SELECT round( sum(  p.cost * al.quantity  ),2 )FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as credit_amount,    
--     --    (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     -- WHERE sai.status IN ('pending','paid','partially paid');
--     UNION ALL
--     --- ========================================================
--     --- RETURNS
--     --- ========================================================
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Account Receivables' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     WHERE sai.status IN ('returned')
--     UNION ALL
--     --WHERE sai.status IN ('pending','paid','partially paid');
--     --sales revenue
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Sales Returns and Allowances' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         round((((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ),2) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     WHERE sai.status IN ('returned')
--     UNION ALL
--     --WHERE sai.status IN ('pending','paid','partially paid');
--     --Tax Payable
--     SELECT 

--         format('Invoice - %s ',sai.invoice_code) as transaction,
--         'Tax Payable' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--     --    0.00 as debit_amount,
--         (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as debit_amount,
--         0.00 as credit_amount,  
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     WHERE sai.status IN ('returned')
--     UNION ALL
--     --- =====================================================
--     -- account receivable
--     -- cash/bank
--     --- =====================================================
--     -- Payment AR
--     SELECT 

--         format('Invoice - %s',sai.invoice_code) as transaction,
--         'Account Payable (Customer Refund)' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         sai.amount as debit_amount,
--         0.00 as cred_amount,
--     --    round(((p.price * al.discount) * al.quantity ),2) as credit_amount,
--         'CSV_Import' as source
--     FROM Staging.stg_ar_imports sai
--     -- LEFT JOIN staging.ar_line al USING(invoice_code)
--     -- LEFT JOIN staging.product p USING(product_code)
--     WHERE sai.amount > 0 and sai.status IN ('returned')
--     UNION ALL
--     --sai.status IN ('pending','paid','partially paid') and 
--     -- PAYMENT CASH
--     SELECT 

--         format('Invoice - %s',sai.invoice_code ) as transaction,
--         'Cash/Bank' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         0.00 as debit_amount,
--         sai.amount as credit_amount,
--     --    round(((p.price * al.discount) * al.quantity ),2) as debit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     -- LEFT JOIN staging.ar_line al USING(invoice_code)
--     -- LEFT JOIN staging.product p USING(product_code)
--     WHERE sai.amount > 0 and sai.status IN ('returned')
--     UNION ALL
--     -- ar discount
--     SELECT 

--         format('Invoice - %s (%s) ',sai.invoice_code, p.product_name) as transaction,
--         'Account Receivables' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         round(((p.price * al.discount) * al.quantity ),2) as debit_amount,
--         0.00 as credit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     WHERE al.discount > 0 and sai.status IN ('returned')
--     -- Sales Discoun
--     UNION ALL
--     SELECT 

--         format('Invoice - %s (%s) ',sai.invoice_code, p.product_name) as transaction,
--         'Sales Discount' as account_key,
--         sai.client_code as  client_key,
--         sai.invoice_date as journal_date_key,
--         round(((p.price * al.discount) * al.quantity ),2) as credit_amount,
--         0.00 as debit_amount,
--         'CSV_Import' as source

--     FROM Staging.stg_ar_imports sai
--     LEFT JOIN staging.ar_line al USING(invoice_code)
--     LEFT JOIN staging.product p USING(product_code)
--     WHERE al.discount > 0 and sai.status IN ('returned');

--     --sai.status IN ('pending','paid','partially paid') and sai.amount > 0;

--         -- (SELECT round(sum( ((p.price - (p.price * al.discount) - p.cost) * al.quantity ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_profit_or_gross_amount,
--         -- (SELECT round(sum( (((p.price - (p.price * al.discount) + ( p.price - (p.price * al.discount) * 0.10))  - p.cost - ( p.price - (p.price * al.discount) * 0.10) ) * al.quantity ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_cash_flow
--         -- (SELECT round(sum( (p.price * al.quantity) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as sub_total,
--         -- (SELECT round(sum( ((p.price * al.discount) * al.quantity ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as discount,
--         -- (SELECT round(sum( ((p.price - (p.price * al.discount)) * al.quantity ) ),2) FROM ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_sales,    
--         -- (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM ar_line al LEFT JOIN product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as tax_amount,

-- drop VIEW general_ledger_view;
-- select * from general_ledger_view;
