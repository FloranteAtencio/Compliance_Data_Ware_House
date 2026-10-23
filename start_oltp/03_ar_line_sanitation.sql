-- =====================================
-- add more procedure for sanitation for each staging table
-- =====================================

BEGIN;

CREATE OR REPLACE PROCEDURE Staging.ar_line_sanitation(
    IN p_session_id INT
)
LANGUAGE plpgsql as $$
DECLARE
    collect_errors TEXT[] := ARRAY[]::TEXT[];
    r RECORD;
BEGIN

    FOR r IN    
        SELECT *
        FROM Bronze.ar_line a
        WHERE a.session_id = p_session_id
    LOOP

        -- IF NOT EXISTS ( SELECT 1 FROM Finance.customers z WHERE z.customer_id = r.customer_code::INT ) THEN 
        --     collect_errors := array_append(collect_errors, 'Customer not found');
        -- END IF;

        -- IF NOT EXISTS ( SELECT 1 FROM Finance.clients z WHERE z.client_id = r.product_code::INT )  THEN 
        --     collect_errors := array_append(collect_errors, 'Client not found');
        
        -- END IF;

        IF r.quantity !~ '^\.?\d+(\.\d+)?$' THEN 
            collect_errors := array_append(collect_errors,'Invalid amount format');
        END IF;

        IF r.discount !~ '^\.?\d+(\.\d+)?$' THEN 
            collect_errors := array_append(collect_errors,'Invalid amount format');
        END IF;

        UPDATE Bronze.ar_line s
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
        new_state = 'PENDING',
        previous_state = 'DRAFT',
        notes = 'PENDING FOR VALIDATION'
    FROM Bronze.ar_line b
    WHERE a.staging_record_id = b.id 
    AND a.session_id = b.session_id
    AND b.validation_status = 'VALID'
    AND a.session_id = p_session_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Account Receivables Sanitations Failed: %', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;


COMMIT;

SELECT '08 ar line sanitation' as status
