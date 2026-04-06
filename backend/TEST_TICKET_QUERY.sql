-- Test query to check if tickets with Shopify IDs are stored correctly
-- Run this in pgAdmin to verify the data

-- 1. Check all tickets and their metadata
SELECT 
  ticket_number,
  user_id,
  user_name,
  metadata,
  metadata->>'original_user_id' as original_user_id_from_metadata
FROM tickets
ORDER BY created_at DESC
LIMIT 10;

-- 2. Test the query that the backend uses (replace with your Shopify ID)
-- Replace 'gid://shopify/Customer/8971995087157' with your actual user ID
SELECT 
  ticket_number,
  user_name,
  metadata->>'original_user_id' as original_user_id
FROM tickets
WHERE metadata IS NOT NULL 
  AND metadata->>'original_user_id' = 'gid://shopify/Customer/8971995087157'
ORDER BY created_at DESC;

-- 3. Check if metadata column exists and has data
SELECT 
  COUNT(*) as total_tickets,
  COUNT(metadata) as tickets_with_metadata,
  COUNT(user_id) as tickets_with_user_id
FROM tickets;

