BEGIN;

CREATE OR REPLACE PROCEDURE Staging.import_workflow_posting(
    IN p_session_id INT, IN p_import_type TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    new_session_id INT;
    table_related VARCHAR;
BEGIN
    
    SELECT session_id INTO new_session_id
    FROM Audit.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;
    
    SELECT Staging.table_verification(new_session_id) INTO table_related;

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'invalid Session ID : %', new_session_id;
    END IF;

    IF table_related IS NULL THEN   
        RAISE EXCEPTION 'Invalid table referecne : %',table_related;
    END IF;

    PERFORM 1 FROM Audit.import_sessions WHERE session_id = p_session_id;

    IF table_related = 'Bronze.stg_ar_imports' THEN
        CALL Staging.post_ar_import(new_session_id,p_import_type);
    END IF;

    IF table_related = 'Bronze.ar_line' THEN
        CALL Staging.post_ar_line_import(new_session_id,p_import_type);
    END IF;

    IF table_related = 'Bronze.product' THEN
        CALL Staging.post_product_import(new_session_id,p_import_type);
    END IF;

        IF table_related = 'Bronze.stg_client' THEN
        CALL Staging.post_client_import(new_session_id,p_import_type);
    END IF;
    
    IF table_related = 'Bronze.stg_customer' THEN
        CALL Staging.post_customer_import(new_session_id,p_import_type);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'import_workflow_posting failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '19 SUPPORT TRANSFER' AS STATUS