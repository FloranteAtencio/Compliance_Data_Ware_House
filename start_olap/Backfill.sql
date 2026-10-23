
BEGIN ;
-- Run with app.enc_key set
SET app.enc_key = 'your-secret-key-here';

UPDATE Gold.dim_customer
SET customer_name_enc = pgp_sym_encrypt(customer_name, current_setting('app.enc_key'), 'cipher-algo=aes256'),
    customer_name = NULL
WHERE customer_name_enc IS NULL AND customer_name IS NOT NULL;

UPDATE Gold.dim_client
SET client_name_enc = pgp_sym_encrypt(client_name, current_setting('app.enc_key'), 'cipher-algo=aes256'),
    client_name = NULL
WHERE client_name_enc IS NULL AND client_name IS NOT NULL;

COMMIT;

SELECT 'BACK FILL ' AS STATUS;