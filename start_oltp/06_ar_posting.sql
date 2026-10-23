BEGIN;

CREATE OR REPLACE PROCEDURE Staging.post_ar_import( 
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
        FROM Bronze.stg_ar_imports a
        LEFT JOIN Audit.import_workflows b ON a.id = b.staging_record_id 
        WHERE a.session_id = p_session_id
          AND validation_status = 'VALID'
          AND b.new_state = 'VALID'
    LOOP
        INSERT INTO Silver.stg_ar_imports (
            session_id
            ,bronze_id
            ,invoice_code
            ,client_code
            ,customer_code
            ,due_date
            ,invoice_date
            ,amount
            ,status
            ,idempotency_key)
        VALUES (
            r.session_id::INT,
            r.id::BIGINT,
            UPPER(TRIM(r.invoice_code::TEXT)),
            r.client_code::BIGINT,
            r.customer_code::BIGINT,
            r.due_date::DATE,
            r.invoice_date::DATE,
            r.amount::DECIMAL,
            UPPER(TRIM(r.status::VARCHAR)),
            r.idempotency_key::TEXT
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
            'ar_line', 
            r.id, 
            r.client_code::INT, 
            p_import_type,
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'ar_line'
                || p_import_type
                || r.id
                || current_user
            )
        );

    END LOOP;
        
    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
    INSERT INTO Silver.stg_date (
        bronze_id,
        session_id,
        date,
        day,
        month,
        month_name,
        quarter,
        year,
        week,
        day_of_week,
        date_type,
        imported_at,
        idempotency_key
    )
    SELECT 
        id
        ,p_session_id
        ,CAST(date_val AS DATE)
        ,EXTRACT(DAY FROM CAST(date_val AS DATE))::VARCHAR
        ,EXTRACT(MONTH FROM CAST(date_val AS DATE))::VARCHAR
        ,TO_CHAR(CAST(date_val AS DATE), 'Month')
        ,'Q' || EXTRACT(QUARTER FROM CAST(date_val AS DATE))::VARCHAR
        ,EXTRACT(YEAR FROM CAST(date_val AS DATE))::VARCHAR
        ,EXTRACT(WEEK FROM CAST(date_val AS DATE))::VARCHAR
        ,TO_CHAR(CAST(date_val AS DATE), 'Day')
        ,date_types
        ,CURRENT_TIMESTAMP
        ,'date-' || TO_CHAR(CAST(date_val AS DATE), 'YYYY-MM-DD') || id
    FROM (
        SELECT id, invoice_date AS date_val, 'invoice_date' as date_types FROM Silver.stg_ar_imports WHERE invoice_date IS NOT NULL AND session_id = p_session_id
        UNION ALL
        SELECT id, due_date AS date_val, 'due_date' as date_types FROM Silver.stg_ar_imports WHERE due_date IS NOT NULL AND  session_id = p_session_id
    ) combined;

    UPDATE Audit.import_workflows
    SET new_state = 'POSTED',
        previous_state = 'VALID'
    WHERE session_id = p_session_id AND new_state = 'VALID';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging post_ar_import failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '14 Staging Schema import data posting complete' as Status;
