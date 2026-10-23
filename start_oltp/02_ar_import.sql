BEGIN;

DROP FUNCTION IF EXISTS Staging.ar_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.ar_import_data(
    p_session_id        INT,
    p_invoice_id        TEXT,
    p_client_id         TEXT,
    p_customer_id       TEXT,
    p_invoice_date      TEXT,
    p_due_date          TEXT,
    p_amount            TEXT,
    p_status            TEXT,
    p_import_status     TEXT,
    p_idempotency_key   TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.stg_ar_imports( 
        session_id, invoice_code, client_code, customer_code,
        invoice_date, due_date, amount, status,
        validation_status, validation_errors, imported_at, idempotency_key
    ) VALUES ( 
        p_session_id, p_invoice_id, p_client_id, p_customer_id,
        p_invoice_date, p_due_date, p_amount, p_status,
        'DRAFT', NULL, NOW(), p_idempotency_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    IF new_ar_staging_id IS NULL THEN
        SELECT id INTO new_ar_staging_id 
        FROM Bronze.stg_ar_imports 
        WHERE idempotency_key = p_idempotency_key;
        
        RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
            p_idempotency_key, new_ar_staging_id;
    END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'ar_import_data',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'stg_ar_import', 
            new_ar_staging_id, 
            p_client_id::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_ar_import'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END; 
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Audit, Compliance, Staging, pg_catalog;


DROP FUNCTION IF EXISTS Staging.ar_line_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.ar_line_import_data(
    p_session_id        INT,
    p_client_id         TEXT,
    p_invoice_id        TEXT,
    p_product_code      TEXT,
    p_quantity          TEXT,
    p_discount          TEXT,
    p_import_status     TEXT,
    p_idempotency_key   TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.ar_line( 
        session_id,  client_code, invoice_code, product_code, quantity,
        discount, validation_status, validation_errors,
        imported_at, idempotency_key
    ) VALUES ( 
        p_session_id, p_client_id, p_invoice_id, p_product_code, p_quantity,
        p_discount,'DRAFT', NULL, 
        NOW(), p_idempotency_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    IF new_ar_staging_id IS NULL THEN
        SELECT id INTO new_ar_staging_id 
        FROM Bronze.ar_line  
        WHERE idempotency_key = p_idempotency_key;
        
        RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
            p_idempotency_key, new_ar_staging_id;
    END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'ar_Line_import_data',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'ar_line', 
            new_ar_staging_id, 
            p_client_id::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'ar_line'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

DROP FUNCTION IF EXISTS Staging.product_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.product_import_data(
    p_session_id        INT,
    p_client_code       TEXT,
    p_product_code      TEXT,
    p_product_name      TEXT,
    p_description       TEXT,
    p_product_unit      TEXT,
    p_quantity          TEXT,
    p_cost              TEXT,
    p_price             TEXT,
    p_purchase_date     TEXT,
    p_import_status     TEXT,
    p_idempotency_key   TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.product( 
        session_id, client_code, product_code, product_name, description,
        product_unit, quantity, cost, price, purchase_date,
        validation_status, validation_errors, imported_at,
        idempotency_key
    ) VALUES ( 
        p_session_id, p_client_code, p_product_code, p_product_name,
        p_description, p_product_unit, p_quantity, p_cost, p_price,
        p_purchase_date,
        'DRAFT', NULL, NOW(), p_idempotency_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    IF new_ar_staging_id IS NULL THEN
        SELECT id INTO new_ar_staging_id 
        FROM Bronze.product  
        WHERE idempotency_key = p_idempotency_key;
        
        RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
            p_idempotency_key, new_ar_staging_id;
    END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'product',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'product', 
            new_ar_staging_id, 
            p_client_code::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'product'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

DROP FUNCTION IF EXISTS Staging.client_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.client_import_data(
    p_session_id        INT,
    p_client_code       TEXT,
    p_client_name       TEXT,
    p_contact_info      TEXT,
    p_email             TEXT,
    p_address           TEXT,
    p_tax_id            TEXT,
    p_ssn               TEXT,
    p_import_status     TEXT
--    p_idempotency_key   TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.stg_client( 
        session_id, client_id, client_name, contact_info,
        email, address, tax_id, SSN, 
        validation_status, validation_errors, imported_at
    ) VALUES ( 
        p_session_id, p_client_code, p_client_name,
        p_contact_info, p_email, p_address, p_tax_id, p_ssn,
        'DRAFT', NULL, NOW()
    )
    -- ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    -- IF new_ar_staging_id IS NULL THEN
    --     SELECT id INTO new_ar_staging_id 
    --     FROM Bronze.stg_client  
    --     WHERE idempotency_key = p_idempotency_key;
        
    --     RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
    --         p_idempotency_key, new_ar_staging_id;
    -- END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'stg_client',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'stg_client', 
            new_ar_staging_id, 
            p_client_code::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_client'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

DROP FUNCTION IF EXISTS Staging.customer_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.customer_import_data(
    p_session_id        INT,
    p_client_code       TEXT,
    p_customer_code     TEXT,
    p_customer_name     TEXT,
    p_contact_info      TEXT,
    p_email             TEXT,
    p_address           TEXT,
    p_import_status     TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.stg_customer( 
        session_id, client_id, customer_id, customer_name, contact_info,
        email, address, 
        validation_status, validation_errors, imported_at
    ) VALUES ( 
        p_session_id, p_client_code, p_customer_code, p_customer_name,
        p_contact_info, p_email, p_address,
        'DRAFT', NULL, NOW()
    )
    -- ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    -- IF new_ar_staging_id IS NULL THEN
    --     SELECT id INTO new_ar_staging_id 
    --     FROM Bronze.stg_customer  
    --     WHERE idempotency_key = p_idempotency_key;
        
    --     RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
    --         p_idempotency_key, new_ar_staging_id;
    -- END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'stg_customer',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'stg_customer', 
            new_ar_staging_id, 
            p_client_code::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_customer'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

DROP FUNCTION IF EXISTS Staging.location_import_data(INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) CASCADE;
CREATE FUNCTION Staging.location_import_data(
    p_session_id    INT,
    p_client_code   TEXT,
    p_location_id   TEXT,
    p_country       TEXT,
    p_region        TEXT,
    p_province      TEXT,
    p_city          TEXT,
    p_municipality  TEXT,
    p_import_status TEXT
)
RETURNS INT AS $$
DECLARE
    new_previous_hash TEXT;
    new_ar_staging_id INT;
BEGIN

    SELECT row_hash
    INTO new_previous_hash
    FROM Audit.record_lineage
    ORDER BY lineage_id DESC
    LIMIT 1
    FOR UPDATE;

    -- Attempt insert
    INSERT INTO Bronze.stg_location( 
        session_id, client_code, location_id, country, region,
        province, city, municipality, 
        validation_status, validation_errors, imported_at
    ) VALUES ( 
        p_session_id, p_client_code, p_location_id, p_country,
        p_region, p_province, p_city, p_municipality,
        'DRAFT', NULL, NOW()
    )
    -- ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO new_ar_staging_id;

    -- Handle duplicate case
    -- IF new_ar_staging_id IS NULL THEN
    --     SELECT id INTO new_ar_staging_id 
    --     FROM Bronze.stg_customer  
    --     WHERE idempotency_key = p_idempotency_key;
        
    --     RAISE NOTICE 'Duplicate skipped for key %. Reusing existing id %.', 
    --         p_idempotency_key, new_ar_staging_id;
    -- END IF;

    INSERT INTO Audit.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, changed_by)
    VALUES(p_session_id, new_ar_staging_id, 'stg_location',NULL, 'DRAFT',current_user);

    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'stg_location', 
            new_ar_staging_id, 
            p_client_code::INT, 
            p_import_status,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_location'
                || p_import_status
                || new_ar_staging_id
                || current_user
            )
    );
    -- END IF;

    RETURN new_ar_staging_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '06 AR imports' AS Status;
