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

COMMIT;