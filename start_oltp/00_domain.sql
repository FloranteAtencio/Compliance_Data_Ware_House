SELECT 'Finance Schema Domain Start!' as  Status;

BEGIN;

CREATE SCHEMA Staging;
-- CREATE SCHEMA Audit;
CREATE SCHEMA Compliance;

CREATE SCHEMA Domains;

-- Email Domains
DROP DOMAIN IF EXISTS Domains.email_type CASCADE;
CREATE DOMAIN Domains.email_type AS VARCHAR(255)
    NOT NULL
    CONSTRAINT valid_email CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');   

-- -- Phone Domains
-- DROP DOMAIN IF EXISTS phone_type CASCADE;
-- CREATE DOMAIN phone_type AS VARCHAR(20)
--     CONSTRAINT valid_phone CHECK (VALUE ~ '^\+?1?\d{9,15}$' OR VALUE = '');

-- -- Amount Domains (non-negative)
-- DROP DOMAIN IF EXISTS amount_type CASCADE;
-- CREATE DOMAIN amount_type AS DECIMAL(15,2)
--     CONSTRAINT positive_amount CHECK (VALUE >= 0);

-- -- Quantity Domains (positive integer)
-- DROP DOMAIN IF EXISTS quantity_type CASCADE;
-- CREATE DOMAIN quantity_type AS BIGINT
--     CONSTRAINT positive_quantity CHECK (VALUE > 0);

-- Account code Domains
DROP DOMAIN IF EXISTS Domains.account_code_type CASCADE;
CREATE DOMAIN Domains.account_code_type AS BIGINT
    CONSTRAINT valid_account_code CHECK (VALUE > 0);

DROP DOMAIN IF EXISTS Domains.bigint_account_code_type CASCADE;
CREATE DOMAIN Domains.bigint_account_code_type AS BIGINT
    CONSTRAINT bigint_valid_account_code CHECK (VALUE > 0);


DROP DOMAIN IF EXISTS Domains.charts_type CASCADE;
CREATE DOMAIN Domains.charts_type AS VARCHAR(50)
    CONSTRAINT valid_charts_type CHECK ( VALUE IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE','CONTRA REVENUE','CONTRA ASSET','CONTRA LIABILITY','CONTRA EQUITY','CONTRA EXPENSE'));

DROP DOMAIN IF EXISTS Domains.action_type  CASCADE;
CREATE DOMAIN Domains.action_type as  VARCHAR(50)
    CONSTRAINT valid_action_type CHECK (VALUE IN ('PURCHASE', 'SALE', 'SARE RETURN', 'PURCHASE RETURN', 'TRANSFER'));

DROP DOMAIN IF EXISTS Domains.status_type CASCADE;
CREATE DOMAIN Domains.status_type as VARCHAR(50)
    CONSTRAINT valid_status_type CHECK (VALUE IN ('PENDING', 'PAID', 'OVERDUE','RETURNED','PARTIALLY RETURNED','PARTIALLY PAID', 'VOID', 'CANCELLED','DRAFT'));

DROP DOMAIN IF EXISTS Domains.audit_log_type CASCADE;
CREATE DOMAIN Domains.audit_log_type as VARCHAR(50)
    CONSTRAINT valid_audit_log_type CHECK (VALUE IN ('INSERT', 'UPDATE', 'DELETE'));

DROP DOMAIN IF EXISTS Domains.phone_type CASCADE;
CREATE DOMAIN Domains.phone_type AS VARCHAR(20)
    CONSTRAINT valid_phone CHECK (
        VALUE = '' OR
        VALUE ~ '^\+63\d{9}$' OR      -- +63xxxxxxxxx
        VALUE ~ '^0\d{9}$'            -- 0xxxxxxxxx local format
    );

-- Who did it
CREATE DOMAIN Domains.actor_type AS VARCHAR(100)
    CONSTRAINT valid_actor CHECK (VALUE <> '');

-- What changed (JSONB diff)
CREATE TABLE Audit.data_changes (
    audit_id      BIGSERIAL PRIMARY KEY,
    table_name    TEXT NOT NULL,
    record_id     TEXT,
    action        Domains.audit_log_type NOT NULL,
    old_values    JSONB,
    new_values    JSONB,
    changed_by    TEXT DEFAULT current_user,
    changed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_addr   INET DEFAULT inet_client_addr()
);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION Audit.fn_audit_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Audit.data_changes(table_name, record_id, action, old_values, new_values)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id::TEXT, OLD.id::TEXT),
        TG_OP::Domains.audit_log_type,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

COMMIT;

SELECT '01 Finance Schema Domain Complete!' as  Status;
