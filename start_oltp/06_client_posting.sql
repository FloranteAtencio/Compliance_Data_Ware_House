BEGIN;

CREATE OR REPLACE PROCEDURE Staging.post_client_import( 
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
        FROM Bronze.stg_client a
        LEFT JOIN Audit.import_workflows b ON a.id = b.staging_record_id 
        WHERE a.session_id = p_session_id
          AND validation_status = 'VALID'
          AND b.new_state = 'VALID'
    LOOP
        INSERT INTO Silver.stg_client (
            bronze_id
            ,session_id
            ,client_code
            ,client_name
            ,contact_info
            ,email
            ,address
            ,tax_id
            ,SSN
            --,idempotency_key
            )
        VALUES (
            r.id::BIGINT
            ,r.session_id::INT
            ,r.client_id::INT
            ,r.client_name::VARCHAR
            ,r.contact_info::VARCHAR
            ,r.email::VARCHAR
            ,r.address::TEXT
            ,r.tax_id::VARCHAR
            ,r.SSN::VARCHAR
            --,r.purchase_date::DATE            
            --,r.idempotency_key::TEXT
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
            'stg_client', 
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
                || 'stg_client'
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
        RAISE EXCEPTION 'Staging post_client_import failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '14 Staging Schema import data posting complete' as Status;
