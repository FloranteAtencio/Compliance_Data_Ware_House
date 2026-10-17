-- -- Enable RLS on fact tables (dims are usually small, skip RLS there)
-- ALTER TABLE Gold.fact_gl         ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE Gold.fact_ar         ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE Gold.fact_invoice_line ENABLE ROW LEVEL SECURITY;

-- -- Force RLS even for table owners (optional but recommended)
-- ALTER TABLE Gold.fact_gl         FORCE ROW LEVEL SECURITY;
-- ALTER TABLE Gold.fact_ar         FORCE ROW LEVEL SECURITY;
-- ALTER TABLE Gold.fact_invoice_line FORCE ROW LEVEL SECURITY;

-- -- Policy: analysts see only their region
-- CREATE POLICY p_analyst_region ON Gold.fact_ar
--     FOR SELECT TO gold_analyst
--     USING (
--         current_setting('app.user_role', true) = 'admin'
--         OR region = current_setting('app.region', true)
--     );

-- -- Policy: finance sees all (but masked via views)
-- CREATE POLICY p_finance_all ON Gold.fact_ar
--     FOR SELECT TO gold_finance
--     USING (true);

-- -- Policy: admin sees all
-- CREATE POLICY p_admin_all ON Gold.fact_ar
--     FOR SELECT TO gold_admin
--     USING (true);

-- ============ Version 2 ===================

BEGIN;

    -- Enable RLS on fact tables
ALTER TABLE Gold.fact_gl         ENABLE ROW LEVEL SECURITY;
ALTER TABLE Gold.fact_ar         ENABLE ROW LEVEL SECURITY;
ALTER TABLE Gold.fact_invoice_line ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners
ALTER TABLE Gold.fact_gl         FORCE ROW LEVEL SECURITY;
ALTER TABLE Gold.fact_ar         FORCE ROW LEVEL SECURITY;
ALTER TABLE Gold.fact_invoice_line FORCE ROW LEVEL SECURITY;

-- Policies (adjust conditions to your actual data model)
-- CREATE POLICY p_analyst_region ON Gold.fact_ar
--     FOR SELECT TO gold_analyst
--     USING (
--         current_setting('app.user_role', true) = 'admin'
--         OR region = current_setting('app.region', true)
--     );

CREATE POLICY p_finance_all ON Gold.fact_ar
    FOR SELECT TO gold_finance
    USING (true);

CREATE POLICY p_admin_all ON Gold.fact_ar
    FOR SELECT TO gold_admin
    USING (true);

-- Same pattern for fact_gl and fact_invoice_line as needed
-- CREATE POLICY p_analyst_region_gl ON Gold.fact_gl
--     FOR SELECT TO gold_analyst
--     USING (
--         current_setting('app.user_role', true) = 'admin'
--         OR region = current_setting('app.region', true)
--     );

CREATE POLICY p_finance_all_gl ON Gold.fact_gl
    FOR SELECT TO gold_finance
    USING (true);

CREATE POLICY p_admin_all_gl ON Gold.fact_gl
    FOR SELECT TO gold_admin
    USING (true);

COMMIT;

SELECT '02 ROW LEVEL SECURITY' AS STATUS;