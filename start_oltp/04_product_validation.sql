BEGIN;

CREATE OR REPLACE PROCEDURE Staging.product_import_workflow_validation(
    IN p_session_id INT
)
LANGUAGE plpgsql as $$
DECLARE
    new_session_id INT;
    r RECORD;
    z RECORD; -- This will hold the 4 error columns
BEGIN
    -- 1. Validate Session
    SELECT session_id INTO new_session_id
    FROM Audit.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'Invalid Session ID: %', p_session_id; -- Fixed: use p_session_id, not new_session_id (which is NULL)
    END IF;

    -- 2. Loop through records
    FOR r IN
        SELECT 
            a.*,  
            c.table_name
        FROM Bronze.product a
        LEFT JOIN Audit.import_workflows b ON a.id = b.staging_record_id 
        LEFT JOIN Audit.import_detail_logs c ON a.id = c.created_record_id
        WHERE a.session_id = p_session_id AND b.new_state = 'PENDING' -- Fixed: Handle case where workflow row might not exist yet
    
    LOOP

        -- Call the validation function
        SELECT *
        INTO z
        FROM Compliance.validate_product_import(
            r.product_name::VARCHAR,
            r.product_unit::VARCHAR,
            r.quantity::INT,
            r.cost::DECIMAL,
            r.price::DECIMAL,
            r.purchase_date::DATE
        );

        -- ========================================================
        -- Amount Check 1
        -- ========================================================
        -- FIX: Use z.amount_error instead of z.v_errors_amount
        IF z.empty_string_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.empty_string_error, r.product_name, FALSE, 'ERROR'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 7::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'VALID: NOT Empty String Value!', r.product_name, FALSE, 'ERROR'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 7::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;

        -- ========================================================
        -- Invoice Date Check 2
        -- ========================================================
        -- FIX: Use z.Invoice_error instead of z.v_errors_invoice
        IF z.product_unit_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.empty_string_error, r.product_unit, FALSE, 'ERROR'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 4::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'VALID: Product Unit!', r.product_unit, TRUE, 'INFO'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 4::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;

        --========================================================
        --Customer Check 3
        --========================================================
        --FIX: Use z.customer_error instead of z.v_errors_customer
        IF z.quantity_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.quantity_error, r.quantity, FALSE, 'ERROR'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'VALID: Quantity!', r.quantity, TRUE, 'INFO'
            );
            PERFORM Compliance.log_compliance_check(
                r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;

        -- ========================================================
        -- Status Check 4
        -- ========================================================
        -- FIX: Use z.status_error instead of z.v_errors_status
        IF z.cost_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.cost_error, r.cost, FALSE, 'ERROR'
            );
            -- Log status fail if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'Valid: Cost!', r.cost, TRUE, 'INFO'
            );
            -- Log status pass if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;
        -- ========================================================
        -- Status Check 4
        -- ========================================================
        -- FIX: Use z.status_error instead of z.v_errors_status
        IF z.price_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.price_error, r.price, FALSE, 'ERROR'
            );
            -- Log status fail if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'Valid: Price!', r.price, TRUE, 'INFO'
            );
            -- Log status pass if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 1::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;
        -- ========================================================
        -- Status Check 4
        -- ========================================================
        -- FIX: Use z.status_error instead of z.v_errors_status
        IF z.purchase_date_error IS NOT NULL THEN
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                z.purchase_date_error, r.purchase_date, FALSE, 'ERROR'
            );
            -- Log status fail if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 2::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'FAIL'
                , 'UNRESOLVED'
                , NULL
            );
        ELSE
            PERFORM Audit.import_validation(
                r.session_id, r.id, r.table_name, 
                'Valid: Purchase Date!', r.purchase_date, TRUE, 'INFO'
            );
            -- Log status pass if needed
            PERFORM Compliance.log_compliance_check(
               r.client_code::INT
                , 2::INT
                , r.session_id::INT
                , r.id::INT
                , NULL
                , r.table_name
                , 'PASS'
                , 'RESOLVED'
                , NULL
            );
        END IF;

        -- ========================================================
        -- Update Workflow Status (Only if ALL checks passed)
        -- ========================================================
        -- Logic: If ANY error was found, we should NOT update to 'VALID'.
        -- We only update if ALL four are NULL.
        IF z.empty_string_error IS NULL 
            AND z.product_unit_error IS NULL 
            AND z.quantity_error IS NULL 
            AND z.cost_error IS NULL
            AND z.price_error IS NULL 
            AND z.purchase_date_error IS NULL THEN
            
            UPDATE Audit.import_workflows 
            SET 
                new_state = 'VALID',
                previous_state = 'PENDING',
                notes = 'PENDING FOR POSTING'
            WHERE Audit.import_workflows.session_id = r.session_id
              AND Audit.import_workflows.staging_record_id = r.id;
        END IF;
    
    END LOOP;    

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Procedure Product_import_workflow_validation failed: %', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;

COMMIT;

SELECT '12 ar line validation' as status;