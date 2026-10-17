BEGIN;
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Add encrypted columns
ALTER TABLE Gold.dim_customer ADD COLUMN customer_name_enc BYTEA;
ALTER TABLE Gold.dim_client   ADD COLUMN client_name_enc BYTEA;

-- Create encryption trigger function
CREATE OR REPLACE FUNCTION Gold.fn_encrypt_pii()
RETURNS TRIGGER AS $$
BEGIN
    IF current_setting('app.enc_key', true) IS NULL THEN
        RAISE EXCEPTION 'app.enc_key not set';
    END IF;

    NEW.customer_name_enc := pgp_sym_encrypt(
        COALESCE(NEW.customer_name, ''),
        current_setting('app.enc_key'),
        'cipher-algo=aes256,compress-algo=none,key-derive-algo=pbkdf2'
    );
    NEW.client_name_enc := pgp_sym_encrypt(
        COALESCE(NEW.client_name, ''),
        current_setting('app.enc_key'),
        'cipher-algo=aes256,compress-algo=none,key-derive-algo=pbkdf2'
    );

    -- Never store plaintext
    NEW.customer_name := NULL;
    NEW.client_name   := NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers
CREATE TRIGGER trg_encrypt_dim_customer
    BEFORE INSERT OR UPDATE ON Gold.dim_customer
    FOR EACH ROW EXECUTE FUNCTION Gold.fn_encrypt_pii();

CREATE TRIGGER trg_encrypt_dim_client
    BEFORE INSERT OR UPDATE ON Gold.dim_client
    FOR EACH ROW EXECUTE FUNCTION Gold.fn_encrypt_pii();

-- Create decryption view
CREATE OR REPLACE VIEW Gold.v_dim_customer_decrypted AS
SELECT
    customer_key,
    customer_id,
    CASE
        WHEN current_setting('app.user_role', true) = 'admin'
            THEN pgp_sym_decrypt(customer_name_enc, current_setting('app.enc_key'))
        ELSE 'CUSTOMER-' || customer_id
    END AS customer_name,
    customer_type, industry, country, region
FROM Gold.dim_customer;

CREATE OR REPLACE VIEW Gold.v_dim_client_decrypted AS
SELECT
    client_key,
    client_id,
    CASE
        WHEN current_setting('app.user_role', true) = 'admin'
            THEN pgp_sym_decrypt(client_name_enc, current_setting('app.enc_key'))
        ELSE 'CLIENT-' || client_id
    END AS client_name,
    client_type, industry, country, region
FROM Gold.dim_client;

COMMIT;

SELECT 'ENCRYPTION' AS STATUS;



-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -- Add encrypted columns
-- ALTER TABLE Gold.dim_customer ADD COLUMN customer_name_enc BYTEA;
-- ALTER TABLE Gold.dim_client   ADD COLUMN client_name_enc BYTEA;

-- -- Encryption trigger function
-- CREATE OR REPLACE FUNCTION Gold.fn_encrypt_pii()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF current_setting('app.enc_key', true) IS NULL THEN
--         RAISE EXCEPTION 'app.enc_key not set';
--     END IF;

--     NEW.customer_name_enc := pgp_sym_encrypt(
--         COALESCE(NEW.customer_name, ''),
--         current_setting('app.enc_key'),
--         'cipher-algo=aes256,compress-algo=none,key-derive-algo=pbkdf2'
--     );
--     NEW.client_name_enc := pgp_sym_encrypt(
--         COALESCE(NEW.client_name, ''),
--         current_setting('app.enc_key'),
--         'cipher-algo=aes256,compress-algo=none,key-derive-algo=pbkdf2'
--     );

--     -- Never store plaintext
--     NEW.customer_name := NULL;
--     NEW.client_name   := NULL;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Attach triggers
-- CREATE TRIGGER trg_encrypt_dim_customer
--     BEFORE INSERT OR UPDATE ON Gold.dim_customer
--     FOR EACH ROW EXECUTE FUNCTION Gold.fn_encrypt_pii();

-- CREATE TRIGGER trg_encrypt_dim_client
--     BEFORE INSERT OR UPDATE ON Gold.dim_client
--     FOR EACH ROW EXECUTE FUNCTION Gold.fn_encrypt_pii();

-- -- Decryption views (admin-only)
-- CREATE OR REPLACE VIEW Gold.v_dim_customer_decrypted AS
-- SELECT
--     customer_key,
--     customer_id,
--     CASE
--         WHEN current_setting('app.user_role', true) = 'admin'
--             THEN pgp_sym_decrypt(customer_name_enc, current_setting('app.enc_key'))
--         ELSE 'CUSTOMER-' || customer_id
--     END AS customer_name,
--     customer_type, industry, country, region
-- FROM Gold.dim_customer;

-- CREATE OR REPLACE VIEW Gold.v_dim_client_decrypted AS
-- SELECT
--     client_key,
--     client_id,
--     CASE
--         WHEN current_setting('app.user_role', true) = 'admin'
--             THEN pgp_sym_decrypt(client_name_enc, current_setting('app.enc_key'))
--         ELSE 'CLIENT-' || client_id
--     END AS client_name,
--     client_type, industry, country, region
-- FROM Gold.dim_client;