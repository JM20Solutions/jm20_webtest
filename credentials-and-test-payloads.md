# Universal AI Database Agent — Credentials & Test Guide

## CREDENTIAL NAMING CONVENTION

### Rule: `{client_id}_{db_type}`

| client_id | db_type | n8n Credential Name | Type in n8n |
|-----------|---------|---------------------|-------------|
| `acme` | `mysql` | `acme_mysql` | MySQL |
| `betasaas` | `postgres` | `betasaas_postgres` | PostgreSQL |
| `logistics` | `mssql` | `logistics_mssql` | Microsoft SQL |
| `marketpro` | `airtable` | *(no n8n cred — API key in db)* | HTTP Header |
| `freelancer` | `google-sheets` | *(no n8n cred — OAuth token in db)* | HTTP Header |
| `analyticsco` | `bigquery` | *(no n8n cred — service token in db)* | HTTP Header |
| `startup` | `supabase` | *(no n8n cred — JWT key in db)* | HTTP Header |

### Required n8n Credentials to Create

**1. Master Control DB** (one, shared):
- Type: `PostgreSQL`
- Name: `Master Control DB`
- Points to: Your control server with `master_clients` table

**2. Telegram Bot** (one, shared):
- Type: `Telegram API`
- Name: `Telegram Bot API`
- Token: Your BotFather token

**3. Anthropic API** (one, shared):
- Type: `HTTP Header Auth`
- Name: `Anthropic API Key`
- Header Name: `x-api-key`
- Header Value: `sk-ant-api03-...`

**4. Per SQL Client** (one per SQL client):
- `acme_mysql` → MySQL → host: mysql.acme.com, db: acme_orders
- `betasaas_postgres` → PostgreSQL → host: pg.betasaas.com, db: betasaas_prod
- `logistics_mssql` → Microsoft SQL → host: mssql.logistics.com, db: LogisticsDB

**API clients** (Airtable, Sheets, BigQuery, Supabase) use tokens stored in `master_clients.api_key` — **no n8n credential needed**.

---

## ADDING A NEW CLIENT

1. Insert one row into `master_clients`:
```sql
INSERT INTO master_clients (user_phone, user_email, client_id, client_name, db_type, db_config, api_key)
VALUES ('TELEGRAM_ID', 'email@company.com', 'newclient', 'New Client', 'mysql',
        '{"host":"db.newclient.com","database":"newclient_db"}'::jsonb, NULL);
```

2. If SQL database: Create n8n credential named `newclient_mysql`

3. Done. The workflow auto-detects everything else.

---

## TEST PAYLOADS

### Test 1: MySQL Client (acme — "cancel my order")

**Telegram message simulation** (what the trigger receives):
```json
{
  "message": {
    "message_id": 1001,
    "from": {
      "id": 123456789,
      "first_name": "John",
      "last_name": "Smith",
      "username": "johnsmith"
    },
    "chat": { "id": 123456789 },
    "text": "cancel my most recent order",
    "date": 1742256000
  }
}
```

**Expected AI query output** (Claude generates this):
```json
{
  "query": "UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE customer_id = (SELECT id FROM customers WHERE telegram_id = '123456789') ORDER BY created_at DESC LIMIT 1",
  "params": [],
  "response_template": "✅ Your order #{{order_id}} has been cancelled. Refund of ${{total_amount}} will process in 3-5 days.",
  "explanation": "Cancels the most recent order for this customer",
  "safe": true,
  "operation": "UPDATE"
}
```

**Final Telegram reply**:
> ✅ Your order #ORD-8842 has been cancelled. Refund of $124.99 will process in 3-5 days.

---

### Test 2: Airtable Client (marketpro — "show active campaigns")

**Telegram message simulation**:
```json
{
  "message": {
    "message_id": 2001,
    "from": {
      "id": 555000111,
      "first_name": "Sarah",
      "last_name": "Jones"
    },
    "chat": { "id": 555000111 },
    "text": "show me all active campaigns this month",
    "date": 1742256000
  }
}
```

**Expected AI query output**:
```json
{
  "query": "?filterByFormula=AND({Status}='Active',IS_SAME(DATETIME_PARSE({Start Date},'YYYY-MM-DD'),TODAY(),'month'))&sort[0][field]=Budget&sort[0][direction]=desc&maxRecords=20",
  "params": [],
  "response_template": "Found {{count}} active campaigns this month. Top: {{Campaign Name}} — Budget: ${{Budget}}",
  "explanation": "Fetches all active campaigns starting this month, sorted by budget descending",
  "safe": true,
  "operation": "API_READ"
}
```

**Final Telegram reply**:
> ✅ Found 4 active campaigns this month.
> **1.** Campaign Name: `Summer Sale 2026` | Status: `Active` | Budget: `50000`
> **2.** Campaign Name: `Product Launch Q1` | Status: `Active` | Budget: `35000`
> ...

---

### Test 3: Google Sheets Client (freelancer — "check unpaid invoices")

**Telegram message simulation**:
```json
{
  "message": {
    "message_id": 3001,
    "from": {
      "id": 444000222,
      "first_name": "Alex",
      "last_name": "Chen"
    },
    "chat": { "id": 444000222 },
    "text": "which invoices are still unpaid?",
    "date": 1742256000
  }
}
```

**db_config for this client**:
```json
{
  "sheetId": "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms",
  "tab": "Invoices",
  "headers": ["invoice_id","client_name","amount","status","due_date","paid_date"]
}
```

**Expected AI query output**:
```json
{
  "query": "A1:F1000",
  "params": [],
  "response_template": "You have {{unpaid_count}} unpaid invoices totalling ${{total_unpaid}}. Oldest due: {{oldest_invoice}} from {{oldest_client}}.",
  "explanation": "Fetches all invoice rows; Format Response node filters for status != Paid",
  "safe": true,
  "operation": "API_READ"
}
```

**Final Telegram reply**:
> ✅ Found 12 row(s)
> **1.** invoice_id: `INV-2024-089` | client_name: `TechCorp` | amount: `3500` | status: `Unpaid`
> **2.** invoice_id: `INV-2024-091` | client_name: `StartupXYZ` | amount: `1200` | status: `Overdue`
> ...and 10 more

---

## WORKFLOW IMPORT CHECKLIST

- [ ] Import `universal-db-agent.json` into n8n (Settings → Import Workflow)
- [ ] Run `setup.sql` on your master Postgres database
- [ ] Create credential: `Master Control DB` (Postgres → your control server)
- [ ] Create credential: `Telegram Bot API` (Telegram → your bot token)
- [ ] Create credential: `Anthropic API Key` (HTTP Header Auth → your sk-ant key)
- [ ] For each SQL client: create credential named `{client_id}_{db_type}`
- [ ] Update `master_clients` with real Telegram user IDs and connection params
- [ ] Activate the workflow
- [ ] Send a test message from a registered Telegram account

## SCHEMA AUTO-DETECTION

The workflow fetches LIVE schema on every request — no schema caching. This means:
- Add a new column to any client DB → Claude knows about it immediately
- Rename a table → AI adapts on next query
- New table added → Available for querying without any workflow changes

## PORTABILITY SUMMARY

| Action | What to do |
|--------|------------|
| Add new client (SQL) | 1 row in `master_clients` + 1 n8n credential |
| Add new client (API) | 1 row in `master_clients` only |
| Add new DB type | Add 1 branch to each Switch node + execute node |
| User changes DB schema | Nothing — auto-detected live |
| User asks anything | AI translates to correct DB syntax automatically |
