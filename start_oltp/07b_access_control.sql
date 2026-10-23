BEGIN;

CREATE SCHEMA IF NOT EXISTS rbac;

-- Roles (the four you named + extensible)
CREATE TABLE rbac.role (
    role_id     SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name   TEXT NOT NULL UNIQUE,
    description TEXT,
    CONSTRAINT role_name_lower CHECK (role_name = lower(role_name))
);

-- Permissions: resource + action pairs
CREATE TABLE rbac.permission (
    perm_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    resource   TEXT NOT NULL,   -- e.g. 'user', 'log', 'deployment'
    action     TEXT NOT NULL,   -- e.g. 'read', 'write', 'approve'
    UNIQUE (resource, action)
);

-- Role -> permission
CREATE TABLE rbac.role_permission (
    role_id SMALLINT NOT NULL REFERENCES rbac.role(role_id) ON DELETE CASCADE,
    perm_id SMALLINT NOT NULL REFERENCES rbac.permission(perm_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, perm_id)
);

-- App users (FK to your real user table if you have one)
CREATE TABLE rbac.app_user (
    user_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username   TEXT NOT NULL UNIQUE,
    is_active  BOOLEAN NOT NULL DEFAULT true
);

-- User -> role (many-to-many)
CREATE TABLE rbac.user_role (
    user_id BIGINT   NOT NULL REFERENCES rbac.app_user(user_id) ON DELETE CASCADE,
    role_id SMALLINT NOT NULL REFERENCES rbac.role(role_id)     ON DELETE CASCADE,
    granted_by  BIGINT,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ,          -- optional time-boxed grants
    PRIMARY KEY (user_id, role_id)
);

-- Audit trail of every grant/revoke
CREATE TABLE rbac.grant_audit (
    audit_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor      TEXT NOT NULL DEFAULT current_user,
    action     TEXT NOT NULL CHECK (action IN ('GRANT','REVOKE')),
    user_id    BIGINT,
    role_name  TEXT
);

CREATE INDEX idx_user_role_user ON rbac.user_role(user_id);

INSERT INTO rbac.permission (resource, action) VALUES
  ('user','manage'), ('role','manage'), ('config','write'),
  ('resource','read'), ('resource','write'),
  ('log','read'), ('report','read'),
  ('deployment','approve');

INSERT INTO rbac.role (role_name, description) VALUES
  ('admin_role', 'Full control: users, roles, config'),
  ('app_role',   'Day-to-day application usage'),
  ('audit_role', 'Read-only plus log/report access'),
  ('ready_role', 'Approval / sign-off gate');

-- admin_role: everything
INSERT INTO rbac.role_permission (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM rbac.role r CROSS JOIN rbac.permission p
WHERE r.role_name = 'admin_role';

-- app_role: read + write resources
INSERT INTO rbac.role_permission (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM rbac.role r JOIN rbac.permission p
  ON (p.resource, p.action) IN (('resource','read'), ('resource','write'))
WHERE r.role_name = 'app_role';

-- audit_role: read-only, incl. logs/reports. NO writes.
INSERT INTO rbac.role_permission (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM rbac.role r JOIN rbac.permission p
  ON (p.resource, p.action) IN
     (('resource','read'), ('log','read'), ('report','read'))
WHERE r.role_name = 'audit_role';

-- ready_role: reads + approve
INSERT INTO rbac.role_permission (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM rbac.role r JOIN rbac.permission p
  ON (p.resource, p.action) IN
     (('resource','read'), ('log','read'), ('deployment','approve'))
WHERE r.role_name = 'ready_role';

CREATE OR REPLACE FUNCTION rbac.has_permission(
    p_username TEXT,
    p_resource TEXT,
    p_action   TEXT
) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM rbac.user_role ur
    JOIN rbac.app_user u   ON u.user_id  = ur.user_id
    JOIN rbac.role     r   ON r.role_id  = ur.role_id
    JOIN rbac.role_permission rp ON rp.role_id = r.role_id
    JOIN rbac.permission p  ON p.perm_id = rp.perm_id
    WHERE u.username   = p_username
      AND u.is_active
      AND p.resource   = p_resource
      AND p.action     = p_action
      AND (ur.expires_at IS NULL OR ur.expires_at > now())
  );
$$;

-- Example: enforce at the DB level for a deployments table
-- ALTER TABLE app.deployment ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY deployment_approve ON app.deployment
--   FOR UPDATE USING (rbac.has_permission(current_setting('app.user', true), 'deployment', 'approve'));

CREATE OR REPLACE FUNCTION rbac.audit_grants() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO rbac.grant_audit(action, user_id, role_name)
    VALUES ('GRANT', NEW.user_id, (SELECT role_name FROM rbac.role WHERE role_id = NEW.role_id));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO rbac.grant_audit(action, user_id, role_name)
    VALUES ('REVOKE', OLD.user_id, (SELECT role_name FROM rbac.role WHERE role_id = OLD.role_id));
    RETURN OLD;
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER trg_grant_audit
AFTER INSERT OR DELETE ON rbac.user_role
FOR EACH ROW EXECUTE FUNCTION rbac.audit_grants();

-- Give alice the ready_role
INSERT INTO rbac.user_role (user_id, role_id, granted_by)
SELECT u.user_id, r.role_id, NULL
FROM rbac.app_user u, rbac.role r
WHERE u.username = 'alice' AND r.role_name = 'ready_role'
ON CONFLICT DO NOTHING;

-- Who can approve deployments?
SELECT u.username
FROM rbac.user_role ur
JOIN rbac.app_user u ON u.user_id = ur.user_id
JOIN rbac.role r     ON r.role_id = ur.role_id
JOIN rbac.role_permission rp ON rp.role_id = r.role_id
JOIN rbac.permission p ON p.perm_id = rp.perm_id
WHERE p.resource = 'deployment' AND p.action = 'approve';

-- Check a single call
SELECT rbac.has_permission('alice', 'deployment', 'approve');  -- t
SELECT rbac.has_permission('alice', 'resource', 'write');      -- f (ready_role can't write)

-- ================================================================================================
-- ================================================================================================
-- ================================================================================================

-- SELECT 'Silver Encryption Start!' AS Status;

-- BEGIN;

-- ============================================
-- 1. EXTENSION + KEY VALIDATION FUNCTION
-- -- ============================================
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -- Helper: fails loudly if app.enc_key is missing or empty
-- CREATE OR REPLACE FUNCTION Silver.fn_require_enc_key()
-- RETURNS TEXT AS $$
-- DECLARE k TEXT := current_setting('app.enc_key', true);
-- BEGIN
--     IF k IS NULL OR k = '' THEN
--         RAISE EXCEPTION 'app.enc_key not set - refusing to write unencrypted PII'
--             USING HINT = 'SET app.enc_key = ''<key-from-secrets-manager>''';
--     END IF;
--     RETURN k;
-- END;
-- $$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 2. ADD CIPHERTEXT COLUMNS
-- ============================================
-- ALTER TABLE Silver.stg_customer ADD COLUMN IF NOT EXISTS customer_name_enc BYTEA;
-- ALTER TABLE Silver.stg_client   ADD COLUMN IF NOT EXISTS client_name_enc   BYTEA;

-- ============================================
-- 3. ENCRYPTION TRIGGER FUNCTION
-- ============================================
-- CREATE OR REPLACE FUNCTION Silver.fn_encrypt_pii()
-- RETURNS TRIGGER AS $$
-- DECLARE k TEXT := Silver.fn_require_enc_key();
-- BEGIN
--     -- Only encrypt when plaintext is present (skip already-encrypted rows)
--     IF TG_TABLE_NAME = 'stg_customer' AND NEW.customer_name IS NOT NULL THEN
--         NEW.customer_name_enc := pgp_sym_encrypt(
--             NEW.customer_name, k, 'cipher-algo=aes256');
--         NEW.customer_name := NULL;
--     END  IF;
--        -- never persist plaintext
--     IF TG_TABLE_NAME = 'stg_client' AND NEW.client_name IS NOT NULL THEN
--         NEW.client_name_enc := pgp_sym_encrypt(
--             NEW.client_name, k, 'cipher-algo=aes256');
--         NEW.client_name := NULL;
--     END IF;
    
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_silver_encrypt_customer
--     BEFORE INSERT OR UPDATE ON Silver.stg_customer
--     FOR EACH ROW EXECUTE FUNCTION Silver.fn_encrypt_pii();

-- CREATE TRIGGER trg_silver_encrypt_client
--     BEFORE INSERT OR UPDATE ON Silver.stg_client
--     FOR EACH ROW EXECUTE FUNCTION Silver.fn_encrypt_pii();

-- ============================================
-- 4. ROLE-AWARE DECRYPT VIEWS
-- ============================================
-- Masked view for app_role / ready_role (surrogate names only)
-- CREATE OR REPLACE VIEW Silver.v_stg_customer_masked AS
-- SELECT
--     --customer_key, 
--     customer_id,
--     'CUSTOMER-' || customer_id AS customer_name,
--     --customer_type, 
--     --industry, 
--     --country, 
--     --region,
--     --validation_status, 
--     --validation_errors, 
--     imported_at
-- FROM Silver.stg_customer;

-- CREATE OR REPLACE VIEW Silver.v_stg_client_masked AS
-- SELECT
--     --client_key, 
--     client_id,
--     'CLIENT-' || client_id AS client_name,
--     --client_type, 
--     --industry, 
--     --country, 
--     --region,
--     --validation_status, 
--     --validation_errors, 
--     imported_at
-- FROM Silver.stg_client;

-- -- Decrypted view for admin_role / audit_role (forensic review)
-- CREATE OR REPLACE VIEW Silver.v_stg_customer_decrypted AS
-- SELECT
--     --customer_key, 
--     customer_id,
--     CASE WHEN customer_name_enc IS NOT NULL
--          THEN pgp_sym_decrypt(customer_name_enc, Silver.fn_require_enc_key())
--     END AS customer_name,
--     --customer_type, industry, country, region,
--     --validation_status, validation_errors, 
--     imported_at
-- FROM Silver.stg_customer;

-- CREATE OR REPLACE VIEW Silver.v_stg_client_decrypted AS
-- SELECT
--     --client_key, 
--     client_id,
--     CASE WHEN client_name_enc IS NOT NULL
--          THEN pgp_sym_decrypt(client_name_enc, Silver.fn_require_enc_key())
--     END AS client_name,
--     --client_type, industry, country, region,
--     --validation_status, validation_errors, 
--     imported_at
-- FROM Silver.stg_client;

-- -- ============================================
-- -- 5. GRANTS (CLS alignment with your roles)
-- -- ============================================
-- REVOKE ALL ON Silver.v_stg_customer_masked, Silver.v_stg_client_masked FROM PUBLIC;
-- REVOKE ALL ON Silver.v_stg_customer_decrypted, Silver.v_stg_client_decrypted FROM PUBLIC;

-- GRANT SELECT ON Silver.v_stg_customer_masked, Silver.v_stg_client_masked
--     TO app_role, ready_role;
-- GRANT SELECT ON Silver.v_stg_customer_decrypted, Silver.v_stg_client_decrypted
--     TO admin_role, audit_role;

-- -- Base tables keep their existing grants from your RBAC script;
-- -- views are what BI/analyst tooling should query going forward.

COMMIT;

SELECT 'Silver Encryption Complete!' AS Status;