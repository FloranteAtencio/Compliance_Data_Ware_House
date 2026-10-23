BEGIN;

-- Validate AR import
DROP FUNCTION IF EXISTS Compliance.validate_product_import( VARCHAR, VARCHAR, INT, DECIMAL, DECIMAL, DATE) CASCADE;
CREATE FUNCTION Compliance.validate_product_import(

    p_product_name VARCHAR,
    p_product_unit VARCHAR,
    p_quantity INT,
    p_cost DECIMAL,
    p_price DECIMAL,
    p_purchase_date DATE

)
RETURNS TABLE (empty_string_error TEXT, product_unit_error TEXT, quantity_error TEXT, cost_error TEXT, price_error TEXT, purchase_date_error TEXT) AS $$
DECLARE

    v_errors_empty_string TEXT;
    v_errors_product_unit TEXT;
    v_errors_quantity TEXT;
    v_errors_cost TEXT;
    v_errors_price TEXT;
    v_errors_purchase_date TEXT;    

BEGIN
    -- 1
    IF p_product_name IS NULL THEN
        v_errors_empty_string  := 'Product name must be not empty';
    END IF;
    -- 2
    IF lower(p_product_unit) NOT IN ('unit','piece','box') THEN
        v_errors_product_unit := 'Invalid Product Unit';
    END IF;
    -- 3
    IF p_quantity <= 0 THEN
        v_errors_quantity := 'AR amount must be positive';
    END IF;
    -- 4
    IF p_cost <= 0 THEN
        v_errors_cost := 'AR amount must be positive';
    END IF;
    -- 5
    IF p_price <= 0 THEN
        v_errors_price := 'AR amount must be positive';
    END IF;
    -- 6
    IF p_purchase_date IS NULL THEN
        v_errors_purchase_date := 'purchase date cannot be empty';
    END IF;
    
    RETURN QUERY SELECT
        v_errors_empty_string,
        v_errors_product_unit,
        v_errors_quantity,
        v_errors_cost,
        v_errors_price,
        v_errors_purchase_date;

-- -- Validate customer exists
    -- IF NOT EXISTS (SELECT 1 FROM Finance.customers z WHERE z.customer_id = p_customer_id) THEN
    --     v_errors_customer := 'Customer ID does not exist';
    -- END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = Bronze, Silver, Audit, Compliance, Staging, pg_catalog;


COMMIT;

SELECT '13 Product compliance' as  status;
