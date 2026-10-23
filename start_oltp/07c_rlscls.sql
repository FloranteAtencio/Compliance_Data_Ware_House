-- ============================================
-- BRONZE LAYER ACCESS CONTROL (RLS + CLS)
-- ============================================

-- 1. LOCK DOWN BRONZA SCHEMA (CLS Foundation)
-- Revoke public access to ensure only defined roles can enter
REVOKE ALL ON SCHEMA Bronze FROM PUBLIC;
GRANT USAGE ON SCHEMA Bronze TO admin_role, app_role, audit_role, ready_role;

-- Grant SELECT to roles that need to read Bronze
-- admin: ALL (already granted in previous script)
-- app: INSERT only (they write raw data)
-- audit/ready: SELECT only (they review raw data)
REVOKE ALL ON ALL TABLES IN SCHEMA Bronze FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA Bronze TO audit_role, ready_role;
-- Note: app_role already has INSERT via Staging/finance logic, but if they write directly to Bronze:
-- GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA Bronze TO app_role; 

-- 2. ENABLE ROW-LEVEL SECURITY (RLS)
-- We will use 'session_id' to isolate data by batch/load

-- Helper: Ensure the session ID setting exists
-- (Your Python app should do: SET app.current_session_id = <id>)

-- --- stg_ar_imports ---
ALTER TABLE Bronze.stg_ar_imports ENABLE ROW LEVEL SECURITY;

-- Policy: app_role can only see/modify their own session
CREATE POLICY p_bronze_ar_app_scope ON Bronze.stg_ar_imports
    FOR ALL
    TO app_role
    USING (
        session_id = current_setting('app.current_session_id', true)::INT
    )
    WITH CHECK (
        session_id = current_setting('app.current_session_id', true)::INT
    );

-- Policy: audit/ready/admin can see everything (no restriction needed if they have SELECT)
-- But if you want to enforce scope even for admins in some contexts, you can add policies here.
-- Usually, Admins bypass RLS, but we can force it:
ALTER TABLE Bronze.stg_ar_imports FORCE ROW LEVEL SECURITY;

-- --- stg_account ---
ALTER TABLE Bronze.stg_account ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_account_app_scope ON Bronze.stg_account
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.stg_account FORCE ROW LEVEL SECURITY;

-- --- stg_customer ---
ALTER TABLE Bronze.stg_customer ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_customer_app_scope ON Bronze.stg_customer
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.stg_customer FORCE ROW LEVEL SECURITY;

-- --- stg_client ---
ALTER TABLE Bronze.stg_client ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_client_app_scope ON Bronze.stg_client
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.stg_client FORCE ROW LEVEL SECURITY;

-- -- --- stg_date ---
-- ALTER TABLE Bronze.stg_date ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY p_bronze_date_app_scope ON Bronze.stg_date
--     FOR ALL
--     TO app_role
--     USING (session_id = current_setting('app.current_session_id', true)::INT)
--     WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
-- ALTER TABLE Bronze.stg_date FORCE ROW LEVEL SECURITY;

-- --- stg_location ---
ALTER TABLE Bronze.stg_location ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_location_app_scope ON Bronze.stg_location
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.stg_location FORCE ROW LEVEL SECURITY;

-- --- stg_currency ---
ALTER TABLE Bronze.stg_currency ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_currency_app_scope ON Bronze.stg_currency
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.stg_currency FORCE ROW LEVEL SECURITY;

-- --- product ---
ALTER TABLE Bronze.product ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_product_app_scope ON Bronze.product
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.product FORCE ROW LEVEL SECURITY;

-- --- ar_line ---
ALTER TABLE Bronze.ar_line ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_bronze_ar_line_app_scope ON Bronze.ar_line
    FOR ALL
    TO app_role
    USING (session_id = current_setting('app.current_session_id', true)::INT)
    WITH CHECK (session_id = current_setting('app.current_session_id', true)::INT);
ALTER TABLE Bronze.ar_line FORCE ROW LEVEL SECURITY;

-- ============================================
-- VERIFICATION
-- ============================================

-- Check RLS status
SELECT schemaname, tablename, policyname, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'Bronze';