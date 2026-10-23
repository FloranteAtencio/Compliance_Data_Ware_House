BEGIN;

CREATE OR REPLACE PROCEDURE Staging.post_customer_import( 
    IN p_session_id INT, p_import_type TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    new_previous_state VARCHAR(50);
    new_previous_hash VARCHAR(50);
BEGIN    

    SET LOCAL app.allow_direct_insert = 'true';
    
    FOR r IN
        SELECT DISTINCT a.*
        FROM Bronze.stg_customer a
        LEFT JOIN Audit.import_workflows b ON a.id = b.staging_record_id 
        WHERE a.session_id = p_session_id
          AND validation_status = 'VALID'
          AND b.new_state = 'VALID'
    LOOP
        INSERT INTO Silver.stg_customer (
            bronze_id
            ,session_id
            ,client_code
            ,customer_id
            ,customer_name
            ,contact_info
            ,email
            ,address
            )
        VALUES (
            r.id::BIGINT
            ,r.session_id::INT
            ,r.client_id::INT
            ,r.customer_id::INT
            ,r.customer_name::VARCHAR
            ,r.contact_info::VARCHAR
            ,r.email::VARCHAR
            ,r.address::TEXT
            );        
        
        SELECT row_hash
        INTO new_previous_hash
        FROM Audit.record_lineage
        ORDER BY lineage_id DESC
        LIMIT 1
        FOR UPDATE;
        
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
            r.id, 
            r.client_id::INT, 
            p_import_type,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_customer'
                || p_import_type
                || r.id
                || current_user
            )
        );

    END LOOP;
        
    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN


    UPDATE Audit.import_workflows
    SET new_state = 'POSTED',
        previous_state = 'VALID'
    WHERE session_id = p_session_id AND new_state = 'VALID';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging post_Product_import failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '14 Staging Schema import data posting complete' as Status;
