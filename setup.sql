-- ============================================================
-- UNIVERSAL AI DATABASE AGENT — SETUP SQL
-- Run this on your MASTER CONTROL Postgres database
-- ============================================================

-- ============================================================
-- 1. MASTER CLIENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS master_clients (
    id              SERIAL PRIMARY KEY,
    user_phone      VARCHAR(50)  NOT NULL UNIQUE,  -- Telegram User ID (as string)
    user_email      VARCHAR(255),
    client_id       VARCHAR(50)  NOT NULL UNIQUE,  -- e.g. 'acme', 'beta', 'gamma'
    client_name     VARCHAR(255) NOT NULL,
    db_type         VARCHAR(30)  NOT NULL,          -- mysql | postgres | mssql | airtable | google-sheets | bigquery | supabase
    db_config       JSONB        NOT NULL DEFAULT '{}',  -- connection/config params
    api_key         TEXT,                            -- API token for non-SQL databases
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_db_type CHECK (db_type IN (
        'mysql', 'postgres', 'mssql', 'airtable', 'google-sheets', 'bigquery', 'supabase'
    ))
);

CREATE INDEX idx_master_clients_phone    ON master_clients (user_phone);
CREATE INDEX idx_master_clients_active   ON master_clients (is_active);
CREATE INDEX idx_master_clients_db_type  ON master_clients (db_type);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_master_clients_updated_at
    BEFORE UPDATE ON master_clients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 2. AUDIT LOG (optional but recommended)
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_audit_log (
    id              BIGSERIAL PRIMARY KEY,
    client_id       VARCHAR(50)  NOT NULL,
    user_phone      VARCHAR(50)  NOT NULL,
    db_type         VARCHAR(30)  NOT NULL,
    user_query      TEXT         NOT NULL,
    ai_query        TEXT,
    ai_operation    VARCHAR(20),
    record_count    INTEGER      DEFAULT 0,
    success         BOOLEAN      DEFAULT true,
    error_message   TEXT,
    execution_ms    INTEGER,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_client     ON agent_audit_log (client_id);
CREATE INDEX idx_audit_created    ON agent_audit_log (created_at);
CREATE INDEX idx_audit_user_phone ON agent_audit_log (user_phone);

-- ============================================================
-- 3. SAMPLE DATA — 7 clients across all supported DB types
-- ============================================================

-- CLIENT 1: MySQL — E-commerce orders system
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '123456789',                            -- Replace with actual Telegram user ID
    'user@acme.com',
    'acme',
    'Acme E-Commerce',
    'mysql',
    '{
        "host": "mysql.acme.com",
        "port": 3306,
        "database": "acme_orders",
        "db": "acme_orders",
        "schema": "acme_orders"
    }'::jsonb,
    NULL  -- SQL DB uses n8n credential, not API key
);

-- CLIENT 2: Postgres — SaaS subscription platform
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '987654321',
    'user@betasaas.com',
    'betasaas',
    'Beta SaaS Platform',
    'postgres',
    '{
        "host": "pg.betasaas.com",
        "port": 5432,
        "database": "betasaas_prod",
        "db": "betasaas_prod",
        "schema": "public"
    }'::jsonb,
    NULL
);

-- CLIENT 3: Airtable — Marketing agency CRM
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '555000111',
    'user@marketpro.com',
    'marketpro',
    'MarketPro Agency',
    'airtable',
    '{
        "baseId": "appXXXXXXXXXXXXXX",
        "table": "Campaigns",
        "view": "Grid view"
    }'::jsonb,
    'pat_XXXXXXXXXXXXXXXXXX'  -- Airtable Personal Access Token
);

-- CLIENT 4: Google Sheets — Freelance invoicing
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '444000222',
    'user@freelancer.com',
    'freelancer',
    'Freelancer Co',
    'google-sheets',
    '{
        "sheetId": "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms",
        "tab": "Invoices",
        "headers": ["invoice_id", "client_name", "amount", "status", "due_date", "paid_date"]
    }'::jsonb,
    'ya29.XXXXXXXXXXXXXXXXXX'  -- Google OAuth2 access token (refresh via Google OAuth2 credential)
);

-- CLIENT 5: BigQuery — Analytics company
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '333000333',
    'user@analytics.com',
    'analyticsco',
    'Analytics Co',
    'bigquery',
    '{
        "projectId": "analytics-project-123",
        "dataset": "sales_data",
        "location": "US"
    }'::jsonb,
    'ya29.XXXXXXXXXXXXXXXXXX'  -- Google service account access token
);

-- CLIENT 6: Supabase — Startup backend
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '222000444',
    'user@startup.io',
    'startup',
    'Startup App',
    'supabase',
    '{
        "url": "https://xyzcompany.supabase.co",
        "schema": "public"
    }'::jsonb,
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.XXXXXXXXX'  -- Supabase anon or service_role key
);

-- CLIENT 7: MSSQL — Enterprise logistics
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES (
    '111000555',
    'user@logistics.com',
    'logistics',
    'Enterprise Logistics',
    'mssql',
    '{
        "host": "mssql.logistics.com",
        "port": 1433,
        "database": "LogisticsDB",
        "db": "LogisticsDB",
        "schema": "dbo"
    }'::jsonb,
    NULL
);

-- ============================================================
-- 4. VERIFY SETUP
-- ============================================================
SELECT
    client_id,
    client_name,
    db_type,
    user_phone,
    CASE
        WHEN db_type IN ('mysql','postgres','mssql') THEN 'n8n credential: ' || client_id || '_' || db_type
        ELSE 'API key in api_key column'
    END AS credential_source,
    is_active
FROM master_clients
ORDER BY db_type, client_id;
