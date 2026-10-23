-- =====================================
-- add more procedure for sanitation for each staging table
-- =====================================

BEGIN;

CREATE OR REPLACE PROCEDURE Staging.data_customer_reference(
    IN p_session_id INT
)
LANGUAGE plpgsql as $$
DECLARE
    collect_errors TEXT[] := ARRAY[]::TEXT[];
    r RECORD;
BEGIN

    FOR r IN    
        SELECT *
        FROM Bronze.stg_customer a
        WHERE a.session_id = p_session_id
    LOOP

        -- IF NOT EXISTS ( SELECT 1 FROM Finance.customers z WHERE z.customer_id = r.customer_code::INT ) THEN 
        --     collect_errors := array_append(collect_errors, 'Customer not found');
        -- END IF;

        -- IF NOT EXISTS ( SELECT 1 FROM Finance.clients z WHERE z.client_id = r.client_code::INT )  THEN 
        --     collect_errors := array_append(collect_errors, 'Client not found');
        
        -- END IF;

        -- IF r.customer_code !~ '^\.?\d+(\.\d+)?$' THEN 
        --     collect_errors := array_append(collect_errors,'Invalid cost format');
        -- END IF;

        -- IF r.emai !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN 
        --     collect_errors := array_append(collect_errors,'Invalid amount format');
        -- END IF;
        
        -- IF r.contact_info !~ '^\+?[\d\s\-()._]{7,32}$'  THEN 
        --     collect_errors := array_append(collect_errors,'Invalid Date');  
        -- END IF;
        
        UPDATE Bronze.stg_customer s
        SET 
            validation_status = 
                CASE 
                WHEN
                    array_length(collect_errors,1) IS NULL THEN 
                        'VALID' 
                ELSE 
                        'INVALID' 
                END ,
            validation_errors = 
                CASE 
                WHEN
                    array_length(collect_errors,1) IS NULL THEN 
                        NULL  
                    ELSE 
                        array_to_string(collect_errors, '; ')
                END
        WHERE s.session_id = p_session_id
        AND s.validation_status = 'DRAFT'
        AND s.id = r.id;
        
        collect_errors := ARRAY[]::TEXT[];

    END LOOP;

    UPDATE Audit.import_workflows a
    SET
        new_state = 'VALID',
        previous_state = 'DRAFT',
        notes = 'PENDING FOR POSTING'
    FROM Bronze.stg_customer b
    WHERE a.staging_record_id = b.id 
    AND a.session_id = b.session_id
    AND b.validation_status = 'VALID'
    AND a.session_id = p_session_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Customer Sanitation Failed: %', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '09 ar sanitation ' as Status