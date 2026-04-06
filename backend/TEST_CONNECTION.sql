-- ============================================
-- Test Connection Queries
-- Run these in pgAdmin Query Tool
-- ============================================

-- 1. Test basic connection
SELECT NOW() AS current_time, version() AS postgres_version;

-- 2. Check if database exists
SELECT datname FROM pg_database WHERE datname = 'support_tickets';

-- 3. Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('tickets', 'ticket_messages', 'ticket_attachments', 'ticket_activity_log')
ORDER BY table_name;

-- 4. Count records in each table (if they exist)
SELECT 
  'tickets' AS table_name, 
  COUNT(*) AS record_count 
FROM tickets
UNION ALL
SELECT 
  'ticket_messages' AS table_name, 
  COUNT(*) AS record_count 
FROM ticket_messages
UNION ALL
SELECT 
  'ticket_attachments' AS table_name, 
  COUNT(*) AS record_count 
FROM ticket_attachments
UNION ALL
SELECT 
  'ticket_activity_log' AS table_name, 
  COUNT(*) AS record_count 
FROM ticket_activity_log;

-- 5. Test insert (creates a test ticket)
INSERT INTO tickets (
    ticket_number,
    user_name,
    user_email,
    user_phone,
    subject,
    description,
    status,
    priority
) VALUES (
    'TKT-TEST-000001',
    'Test User',
    'test@test.com',
    '+1234567890',
    'Connection Test',
    'This is a test ticket to verify database connection',
    'open',
    'medium'
) RETURNING id, ticket_number, created_at;

-- 6. View the test ticket
SELECT * FROM tickets WHERE ticket_number = 'TKT-TEST-000001';

-- 7. Clean up test ticket (optional - delete after testing)
-- DELETE FROM tickets WHERE ticket_number = 'TKT-TEST-000001';

