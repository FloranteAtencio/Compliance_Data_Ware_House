    --Procuct Line
    DROP VIEW IF EXISTS Silver.product_line;
    CREATE VIEW Silver.product_line as 
    SELECT 

        sai.invoice_code
        ,sai.customer_code
        ,al.product_code
        ,sai.client_code
        ,sai.invoice_date
        ,p.price as  product_price
        ,p.cost as product_cost
        ,al.quantity as sold_quantity
        ,round((p.price * al.quantity),2) as sub_total
        ,round(((p.price * al.discount) * al.quantity ),2) as discount
        ,round(((p.price - (p.price * al.discount)) * al.quantity ),2) as net_sales
        ,round((((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ),2) as tax_amount
        ,round((((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ),2) as total_amount
        ,round(((p.price - (p.price * al.discount) - p.cost) * al.quantity ),2) as net_profit_or_gross_amount
        ,round((((p.price - (p.price * al.discount) + ( p.price - (p.price * al.discount) * 0.10))  - p.cost - ( p.price - (p.price * al.discount) * 0.10) ) * al.quantity ) ,2)as net_cash_flow
        ,'CSV_Import' as souurce
    FROM Silver.stg_ar_imports sai
    LEFT JOIN Silver.ar_line al USING(invoice_code)
    LEFT JOIN Silver.product p USING(product_code);

    SELECT * FROM Silver.product_line;
    -- AR
    DROP VIEW  IF EXISTS Silver.account_receivables_fact;
    CREATE VIEW  Silver.account_receivables_fact as
    SELECT 

        sai.invoice_code,
        sai.client_code,
        sai.customer_code,
        sai.invoice_date,
        sai.due_date,
        (SELECT round(sum( (p.price * al.quantity) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as sub_total,
        (SELECT round(sum( ((p.price * al.discount) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as discount,
        (SELECT round(sum( ((p.price - (p.price * al.discount)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_sales,    
        (SELECT round(sum( (((p.price - (p.price * al.discount)) * al.quantity) * 0.10 ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as tax_amount,
        (SELECT round(sum( (((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as total_amount,
        (SELECT round(sum( ((p.price - (p.price * al.discount) - p.cost) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_profit_or_gross_amount,
        (SELECT round(sum( (((p.price - (p.price * al.discount) + ( p.price - (p.price * al.discount) * 0.10))  - p.cost - ( p.price - (p.price * al.discount) * 0.10) ) * al.quantity ) ),2) FROM Staging.ar_line al LEFT JOIN Staging.product p USING(product_code) WHERE al.invoice_code = sai.invoice_code ) as net_cash_flow,
        'CSV_import' as  source
    FROM silver.stg_ar_imports sai;
SELECT * FROM Silver.account_receivables_fact;

DROP VIEW IF EXISTS Silver.general_ledger_view;
CREATE VIEW Silver.general_ledger_view AS
WITH -- 1. Calculate Invoice-Level Totals from Silver
invoice_totals AS (
    SELECT 
        sai.invoice_code,
        sai.client_code,
        sai.customer_code,
        sai.invoice_date,
        sai.due_date,
        sai.status,
        sai.amount, -- Cash received
        -- Calculate totals from lines
        COALESCE(SUM(p.price * al.quantity), 0) AS sub_total,
        COALESCE(SUM((p.price * al.discount) * al.quantity), 0) AS total_discount,
        COALESCE(SUM((p.price - (p.price * al.discount)) * al.quantity), 0) AS net_sales,
        COALESCE(SUM(((p.price - (p.price * al.discount)) * al.quantity) * 0.10), 0) AS tax_amount,
        COALESCE(SUM(((p.price - (p.price * al.discount)) + ((p.price - (p.price * al.discount)) * 0.10)) * al.quantity), 0) AS gross_total,
        COALESCE(SUM(p.cost * al.quantity), 0) AS cogs
    FROM Staging.stg_ar_imports sai
    LEFT JOIN Staging.ar_line al ON sai.invoice_code = al.invoice_code
    LEFT JOIN Staging.product p ON al.product_code = p.product_code
    GROUP BY 
        sai.invoice_code, sai.client_code, sai.customer_code, 
        sai.invoice_date, sai.due_date, sai.status, sai.amount
),

-- SELECT * FROM Gold.general_ledger_view;

-- 2. Generate GL Lines for Normal Invoices (Not Returned)
normal_invoices AS (
    SELECT 
        format('Invoice - %s', invoice_code) AS transaction,
        client_code,
        invoice_date AS journal_date_key,
        'CSV_Import' AS source,
        status
    FROM invoice_totals
    WHERE status NOT IN ('returned', 'void', 'cancelled')
),

-- 3. Generate GL Lines for Returned Invoices
returned_invoices AS (
    SELECT 
        format('Return - %s', invoice_code) AS transaction,
        client_code,
        invoice_date AS journal_date_key,
        'CSV_Import' AS source,
        status
    FROM invoice_totals
    WHERE status IN ('returned', 'cancelled')
),

-- 4. Union All the GL Entries
gl_normal AS (
    -- A. Revenue & Tax (Credit AR)
    SELECT 
        n.transaction,
        'Account Receivables' AS account_key,
        n.client_code AS client_key,
        n.journal_date_key,
        n.gross_total AS debit_amount,
        0.00 AS credit_amount,
        n.source
    FROM normal_invoices n

    UNION ALL

    -- B. Sales Revenue (Credit Revenue)
    SELECT 
        n.transaction,
        'Sales Revenue' AS account_key,
        n.client_code AS client_key,
        n.journal_date_key,
        0.00 AS debit_amount,
        n.net_sales AS credit_amount,
        n.source

    UNION ALL

    -- C. Tax Payable (Credit Tax)
    SELECT 
        n.transaction,
        'Tax Payable' AS account_key,
        n.client_code AS client_key,
        n.journal_date_key,
        0.00 AS debit_amount,
        n.tax_amount AS credit_amount,
        n.source

    UNION ALL

    -- D. Cost of Goods Sold (Debit COGS, Credit Inventory)
    -- We split this into two rows to keep the GL balanced per line item if needed, 
    -- or combined. Here is combined per invoice:
    SELECT 
        n.transaction || ' (COGS)',
        'Cost Of Goods Sold' AS account_key,
        n.client_code AS client_key,
        n.journal_date_key,
        n.cogs AS debit_amount,
        0.00 AS credit_amount,
        n.source

    UNION ALL

    SELECT 
        n.transaction || ' (Inv)',
        'Inventory' AS account_key,
        n.client_code AS client_key,
        n.journal_date_key,
        0.00 AS debit_amount,
        n.cogs AS credit_amount,
        n.source
),

gl_returned AS (
    -- A. Reverse Revenue (Debit Sales Returns)
    SELECT 
        r.transaction,
        'Sales Returns and Allowances' AS account_key,
        r.client_code AS client_key,
        r.journal_date_key,
        r.net_sales AS debit_amount,
        0.00 AS credit_amount,
        r.source

    UNION ALL

    -- B. Reverse Tax (Debit Tax Payable)
    SELECT 
        r.transaction,
        'Tax Payable' AS account_key,
        r.client_code AS client_key,
        r.journal_date_key,
        r.tax_amount AS debit_amount,
        0.00 AS credit_amount,
        r.source

    UNION ALL

    -- C. Reverse AR (Credit AR)
    SELECT 
        r.transaction,
        'Account Receivables' AS account_key,
        r.client_key AS client_key,
        r.journal_date_key,
        0.00 AS debit_amount,
        r.gross_total AS credit_amount,
        r.source

    UNION ALL

    -- D. Reverse Inventory (Debit Inventory, Credit COGS)
    SELECT 
        r.transaction || ' (Inv)',
        'Inventory' AS account_key,
        r.client_code AS client_key,
        r.journal_date_key,
        r.cogs AS debit_amount,
        0.00 AS credit_amount,
        r.source

    UNION ALL

    SELECT 
        r.transaction || ' (COGS)',
        'Cost Of Goods Sold' AS account_key,
        r.client_code AS client_key,
        r.journal_date_key,
        0.00 AS debit_amount,
        r.cogs AS credit_amount,
        r.source
),

-- 5. Add Payment/Cash Entries
cash_entries AS (
    -- A. Debit Cash/Bank
    SELECT 
        format('Payment - %s', invoice_code) AS transaction,
        'Cash/Bank' AS account_key,
        client_code AS client_key,
        invoice_date AS journal_date_key,
        amount AS debit_amount,
        0.00 AS credit_amount,
        'CSV_Import' AS source
    FROM invoice_totals
    WHERE amount > 0

    UNION ALL

    -- B. Credit AR
    SELECT 
        format('Payment - %s', invoice_code) AS transaction,
        'Account Receivables' AS account_key,
        client_code AS client_key,
        invoice_date AS journal_date_key,
        0.00 AS debit_amount,
        amount AS credit_amount,
        'CSV_Import' AS source
    FROM invoice_totals
    WHERE amount > 0
)

-- FINAL UNION
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
