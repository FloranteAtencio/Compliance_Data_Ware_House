-- ============================================
-- ROLES (NOLOGIN groups; grant to users with GRANT <role> TO <user>)
-- ============================================
CREATE ROLE admin_role NOLOGIN;
CREATE ROLE app_role   NOLOGIN;
CREATE ROLE audit_role NOLOGIN;
CREATE ROLE ready_role NOLOGIN;

-- Hardening: never let these log in directly, and keep search_path sane
ALTER ROLE admin_role SET search_path = Bronze, Silver, Audit, Compliance, Staging;
ALTER ROLE app_role   SET search_path = Bronze, Silver, Audit, Compliance, Staging;
ALTER ROLE audit_role SET search_path = Bronze, Silver, Audit, Compliance, Staging;
ALTER ROLE ready_role SET search_path = Bronze, Silver, Audit, Compliance, Staging;

-- ============================================
-- ADMIN_ROLE  (full control everywhere)
-- ============================================
DO $$
DECLARE s TEXT;
BEGIN
  FOREACH s IN ARRAY ARRAY['bronze','silver','compliance','staging','audit']
--  FOREACH s IN ARRAY ARRAY[Bronze,Silver,Compliance,Staging,Audit,Staging]
  LOOP
    EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO admin_role', s);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO admin_role', s);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO admin_role', s);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA %I TO admin_role', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA %I GRANT ALL ON TABLES TO admin_role', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA %I GRANT ALL ON SEQUENCES TO admin_role', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA %I GRANT ALL ON FUNCTIONS TO admin_role', s);
  END LOOP;
END $$;

-- ============================================
-- APP_ROLE  (CRUD on business data; append-only on Audit/Compliance; INSERT-only staging)
-- ============================================
-- silver: full CRUD + sequences + functions
GRANT USAGE ON SCHEMA silver,bronze TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver,bronze TO app_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA silver,bronze TO app_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver,bronze TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA silver,bronze GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA silver,bronze GRANT ALL ON SEQUENCES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA silver,bronze GRANT EXECUTE ON FUNCTIONS TO app_role;

-- Audit: append-only (no UPDATE/DELETE — immutability)
GRANT USAGE ON SCHEMA Audit TO app_role;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA Audit TO app_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Audit TO app_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Audit TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Audit GRANT SELECT, INSERT ON TABLES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Audit GRANT ALL ON SEQUENCES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Audit GRANT EXECUTE ON FUNCTIONS TO app_role;

-- Compliance: append-only
GRANT USAGE ON SCHEMA Compliance TO app_role;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA Compliance TO app_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Compliance TO app_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Compliance TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Compliance GRANT SELECT, INSERT ON TABLES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Compliance GRANT ALL ON SEQUENCES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Compliance GRANT EXECUTE ON FUNCTIONS TO app_role;

-- Staging: write-only landing zone
GRANT USAGE ON SCHEMA Staging TO app_role;
GRANT INSERT ON ALL TABLES IN SCHEMA Staging TO app_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Staging TO app_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Staging TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Staging GRANT INSERT ON TABLES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Staging GRANT ALL ON SEQUENCES TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA Staging GRANT EXECUTE ON FUNCTIONS TO app_role;

-- ============================================
-- AUDIT_ROLE  (read-everything, write-nothing)
-- ============================================
DO $$
DECLARE s TEXT;
BEGIN
  FOREACH s IN ARRAY ARRAY['silver','audit','compliance','staging']
--  FOREACH s IN ARRAY ARRAY['silver','audit','compliance','staging','Management','admin_meta','governance_v2']

  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO audit_role', s);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO audit_role', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA %I GRANT SELECT ON TABLES TO audit_role', s);
  END LOOP;
END $$;

-- ============================================
-- READY_ROLE  (sign-off / release gate: read broadly, write only to an approvals table)
-- ============================================
-- Read access for reviewing what is being approved
DO $$
DECLARE s TEXT;
BEGIN
  FOREACH s IN ARRAY ARRAY['bronze','silver','compliance','staging','audit','staging']
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO ready_role', s);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO ready_role', s);
    EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA %I GRANT SELECT ON TABLES TO ready_role', s);
  END LOOP;
END $$;

-- The one thing it can mutate: its own sign-off table
CREATE SCHEMA IF NOT EXISTS governance_v2;
CREATE TABLE IF NOT EXISTS governance_v2.approvals (
    approval_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject      TEXT NOT NULL,          -- e.g. 'release:2026-10' or 'batch:staging->finance'
    decided_by   TEXT NOT NULL DEFAULT current_user,
    decision     TEXT NOT NULL CHECK (decision IN ('approved','rejected')),
    decided_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes        TEXT
);

GRANT USAGE ON SCHEMA governance_v2 TO ready_role;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA governance_v2 TO ready_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA governance_v2 TO ready_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA governance_v2 GRANT SELECT, INSERT ON TABLES TO ready_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA governance_v2 GRANT ALL ON SEQUENCES TO ready_role;

-- App must be able to read the sign-offs to honor them
GRANT USAGE ON SCHEMA governance_v2 TO app_role;
GRANT SELECT ON ALL TABLES IN SCHEMA governance_v2 TO app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE erp_admin IN SCHEMA governance_v2 GRANT SELECT ON TABLES TO app_role;

-- ============================================
-- MEMBERSHIP EXAMPLES
-- ============================================
-- CREATE ROLE alice LOGIN PASSWORD '...';
-- GRANT admin_role TO alice;
-- CREATE ROLE svc_app LOGIN PASSWORD '...';
-- GRANT app_role TO svc_app;
-- CREATE ROLE auditor_ext LOGIN PASSWORD '...';
-- GRANT audit_role TO auditor_ext;
-- CREATE ROLE release_mgr LOGIN PASSWORD '...';
-- GRANT ready_role TO release_mgr;

-- Verify
SELECT r.rolname AS group_role, m.rolname AS member
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
ORDER BY 1, 2;
