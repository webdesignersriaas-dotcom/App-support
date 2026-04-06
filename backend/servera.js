// Support Ticket System - Node.js Backend API
// Express + PostgreSQL

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Load .env file
require('dotenv').config();

// Debug: Check if .env file exists and is being loaded
const envPath = path.join(__dirname, '.env');
console.log('📁 Current directory:', __dirname);
console.log('📄 Looking for .env at:', envPath);
console.log('📄 .env file exists?', fs.existsSync(envPath) ? '✅ YES' : '❌ NO');

if (!fs.existsSync(envPath)) {
  console.error('❌ ERROR: .env file not found at:', envPath);
  console.error('💡 Please create .env file in the backend folder');
}

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// PostgreSQL Connection Pool
// Debug: Check if environment variables are loaded
console.log('🔍 Environment check:');
console.log('  DB_HOST:', process.env.DB_HOST || '13.202.148.229 (using default)');
console.log('  DB_USER:', process.env.DB_USER || 'dba (using default)');
console.log('  DB_NAME:', process.env.DB_NAME || 'support_tickets (using default)');
console.log('  DB_PASSWORD:', process.env.DB_PASSWORD ? '***SET FROM .ENV***' : '***USING HARDCODED***');

const pool = new Pool({
  host: process.env.DB_HOST || '13.202.148.229',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'support_tickets',
  user: process.env.DB_USER || 'dba',
  password: process.env.DB_PASSWORD || 'Siya_A830-lsuhjJF', // Using password directly for now
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection error:', err.message);
    console.error('💡 Check your .env file and PostgreSQL is running');
  } else {
    console.log('✅ Database connected successfully');
    console.log('📅 Database time:', res.rows[0].now);
  }
});

// ============================================
// API ROUTES
// ============================================

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Support Ticket API is running',
    timestamp: new Date().toISOString()
  });
});

// ============================================
// 1. CREATE TICKET
// POST /api/v1/support/tickets
// ============================================
app.post('/api/v1/support/tickets', async (req, res) => {
  try {
    const {
      user_name,
      user_email,
      user_phone,
      subject,
      description,
      user_id,
      category,
      priority = 'medium',
    } = req.body;

    // SECURITY: Require user_id (user must be logged in)
    if (!user_id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Please log in to create a ticket.',
      });
    }

    // Validate required fields
    if (!user_name || !user_email || !user_phone || !subject || !description) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: user_name, user_email, user_phone, subject, description',
      });
    }

    // Generate ticket number (format: TKT-YYYY-XXXXXX)
    const year = new Date().getFullYear();
    const result = await pool.query(
      `SELECT COALESCE(MAX(CAST(SUBSTRING(ticket_number FROM '\\d+$') AS INTEGER)), 0) + 1 as next_num
       FROM tickets
       WHERE ticket_number LIKE $1`,
      [`TKT-${year}-%`]
    );
    const nextNum = result.rows[0].next_num;
    const ticketNumber = `TKT-${year}-${String(nextNum).padStart(6, '0')}`;

    // Validate user_id - must be a valid UUID format
    // Shopify IDs like "gid://shopify/Customer/8971995087157" are not valid UUIDs
    let validUserId = null;
    if (user_id) {
      // Check if it's a valid UUID format (8-4-4-4-12 hex characters)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (uuidRegex.test(user_id)) {
        validUserId = user_id;
      } else {
        // Not a valid UUID - store in metadata instead
        console.log(`⚠️ user_id "${user_id}" is not a valid UUID, storing in metadata instead`);
      }
    }

    // Insert ticket into database
    const insertResult = await pool.query(
      `INSERT INTO tickets (
        ticket_number, user_id, user_name, user_email, user_phone,
        subject, description, status, priority, category, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *`,
      [
        ticketNumber,
        validUserId,
        user_name,
        user_email,
        user_phone,
        subject,
        description,
        'open',
        priority,
        category || null,
        user_id && !validUserId ? JSON.stringify({ original_user_id: user_id }) : null,
      ]
    );

    const ticket = insertResult.rows[0];

    // Format response
    res.status(201).json({
      success: true,
      data: {
        ticket: {
          id: ticket.id,
          ticket_number: ticket.ticket_number,
          user_id: ticket.user_id,
          user_name: ticket.user_name,
          user_email: ticket.user_email,
          user_phone: ticket.user_phone,
          subject: ticket.subject,
          description: ticket.description,
          status: ticket.status,
          priority: ticket.priority,
          category: ticket.category,
          assigned_to: ticket.assigned_to,
          assigned_to_name: ticket.assigned_to_name,
          created_at: ticket.created_at,
          updated_at: ticket.updated_at,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error creating ticket:', error);
    console.error('❌ Error details:', {
      message: error.message,
      code: error.code,
      detail: error.detail,
      hint: error.hint,
      stack: error.stack,
    });
    res.status(500).json({
      success: false,
      message: 'Failed to create ticket',
      error: error.message,
      detail: error.detail || null,
      hint: error.hint || null,
    });
  }
});

// ============================================
// 2. GET USER TICKETS
// GET /api/v1/support/tickets?user_id=xxx&status=open&page=1&limit=20
// ============================================
app.get('/api/v1/support/tickets', async (req, res) => {
  try {
    const { user_id, status, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    console.log('🔍 GET /api/v1/support/tickets - Query params:', { user_id, status, page, limit });

    // SECURITY: Require user_id (user must be logged in)
    if (!user_id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Please log in to view your tickets.',
      });
    }

    // CRITICAL SECURITY: Always filter by user_id - NEVER return all tickets
    let query = '';
    const params = [];
    let paramCount = 0;

    // Validate if user_id is a valid UUID
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (uuidRegex.test(user_id)) {
      // Valid UUID - filter by user_id column ONLY
      paramCount++;
      query = `SELECT * FROM tickets WHERE user_id = $${paramCount}`;
      params.push(user_id);
      console.log('✅ Filtering by UUID user_id:', user_id);
    } else {
      // Not a valid UUID (e.g., Shopify ID) - filter by metadata ONLY
      paramCount++;
      query = `SELECT * FROM tickets WHERE metadata IS NOT NULL AND metadata->>'original_user_id' = $${paramCount}`;
      params.push(user_id);
      console.log('✅ Filtering by metadata original_user_id:', user_id);
    }
    
    // CRITICAL: If no user_id match condition, return empty result
    if (query === '') {
      console.error('❌ SECURITY ERROR: No user_id filter condition! Returning empty result.');
      return res.status(200).json({
        success: true,
        data: {
          tickets: [],
          pagination: {
            total: 0,
            page: parseInt(page),
            limit: parseInt(limit),
            pages: 0,
          },
        },
      });
    }

    if (status) {
      paramCount++;
      query += ` AND status = $${paramCount}`;
      params.push(status);
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
    params.push(parseInt(limit), offset);

    console.log('📝 Executing query:', query);
    console.log('📝 Query params:', params);
    console.log('🔒 SECURITY: Filtering tickets for user_id:', user_id);
    
    const result = await pool.query(query, params);
    
    console.log(`✅ Found ${result.rows.length} tickets for user_id: ${user_id}`);
    
    // SECURITY CHECK: Verify all returned tickets belong to this user
    if (uuidRegex.test(user_id)) {
      const invalidTickets = result.rows.filter(t => t.user_id !== user_id);
      if (invalidTickets.length > 0) {
        console.error('❌ SECURITY ERROR: Found tickets not belonging to user!', invalidTickets);
        return res.status(500).json({
          success: false,
          message: 'Security error: Invalid ticket access detected',
        });
      }
    } else {
      const invalidTickets = result.rows.filter(t => {
        const metadataUserId = t.metadata?.original_user_id || t.metadata?.['original_user_id'];
        return metadataUserId !== user_id;
      });
      if (invalidTickets.length > 0) {
        console.error('❌ SECURITY ERROR: Found tickets not belonging to user!', invalidTickets);
        return res.status(500).json({
          success: false,
          message: 'Security error: Invalid ticket access detected',
        });
      }
    }

    // Get unread message count for each ticket
    const ticketsWithUnread = await Promise.all(
      result.rows.map(async (ticket) => {
        const unreadResult = await pool.query(
          `SELECT COUNT(*) as count
           FROM ticket_messages
           WHERE ticket_id = $1 AND is_read = FALSE AND sender_type = 'agent'`,
          [ticket.id]
        );
        return {
          ...ticket,
          unread_message_count: parseInt(unreadResult.rows[0].count),
        };
      })
    );

    res.json({
      success: true,
      data: {
        tickets: ticketsWithUnread,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: result.rowCount,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error fetching tickets:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch tickets',
      error: error.message,
    });
  }
});

// ============================================
// 3. GET TICKET DETAILS WITH MESSAGES
// GET /api/v1/support/tickets/:id
// ============================================
app.get('/api/v1/support/tickets/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Get ticket
    const ticketResult = await pool.query(
      'SELECT * FROM tickets WHERE id = $1',
      [id]
    );

    if (ticketResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    // Get messages for this ticket
    const messagesResult = await pool.query(
      `SELECT * FROM ticket_messages
       WHERE ticket_id = $1
       ORDER BY created_at ASC`,
      [id]
    );

    res.json({
      success: true,
      data: {
        ticket: ticketResult.rows[0],
        messages: messagesResult.rows,
      },
    });
  } catch (error) {
    console.error('❌ Error fetching ticket details:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch ticket details',
      error: error.message,
    });
  }
});

// ============================================
// 4. SEND MESSAGE TO TICKET
// POST /api/v1/support/tickets/:id/messages
// ============================================
app.post('/api/v1/support/tickets/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      message, 
      attachments = [], 
      user_id, 
      user_name,
      sender_id,
      sender_name,
      sender_type = 'user' // Default to 'user', can be 'agent'
    } = req.body;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message is required',
      });
    }

    // Verify ticket exists
    const ticketResult = await pool.query(
      'SELECT * FROM tickets WHERE id = $1',
      [id]
    );

    if (ticketResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    const ticket = ticketResult.rows[0];

    // Determine sender info based on sender_type
    let finalSenderType = sender_type === 'agent' ? 'agent' : 'user';
    let finalSenderName;
    let finalSenderId = null;
    
    if (finalSenderType === 'agent') {
      // Agent message - use sender_name and sender_id from request
      finalSenderName = sender_name || 'Support Agent';
      finalSenderId = sender_id || null;
    } else {
      // User message - use user_name and user_id from request or ticket
      finalSenderName = user_name || ticket.user_name;
      
      // Validate user_id - only use if it's a valid UUID
      if (user_id) {
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (uuidRegex.test(user_id)) {
          finalSenderId = user_id;
        }
      }
      if (!finalSenderId && ticket.user_id) {
        finalSenderId = ticket.user_id;
      }
    }

    // Insert message
    const insertResult = await pool.query(
      `INSERT INTO ticket_messages (
        ticket_id, sender_type, sender_id, sender_name, message, attachments
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
      [
        id,
        finalSenderType,
        finalSenderId,
        finalSenderName,
        message,
        JSON.stringify(attachments),
      ]
    );

    // Update ticket updated_at timestamp
    await pool.query(
      'UPDATE tickets SET updated_at = CURRENT_TIMESTAMP WHERE id = $1',
      [id]
    );

    res.status(201).json({
      success: true,
      data: {
        message: insertResult.rows[0],
      },
    });
  } catch (error) {
    console.error('❌ Error sending message:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send message',
      error: error.message,
    });
  }
});

// ============================================
// 5. GET TICKET MESSAGES (with pagination)
// GET /api/v1/support/tickets/:id/messages?page=1&limit=50
// ============================================
app.get('/api/v1/support/tickets/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    const result = await pool.query(
      `SELECT * FROM ticket_messages
       WHERE ticket_id = $1
       ORDER BY created_at ASC
       LIMIT $2 OFFSET $3`,
      [id, parseInt(limit), offset]
    );

    res.json({
      success: true,
      data: {
        messages: result.rows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: result.rowCount,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error fetching messages:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch messages',
      error: error.message,
    });
  }
});

// ============================================
// 6. UPDATE TICKET STATUS
// PATCH /api/v1/support/tickets/:id
// ============================================
app.patch('/api/v1/support/tickets/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, assigned_to, assigned_to_name, category, priority } = req.body;

    // Build dynamic update query
    const updateFields = [];
    const params = [];
    let paramCount = 0;

    // Update status
    if (status) {
      const validStatuses = ['open', 'in_progress', 'resolved', 'closed'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
        });
      }
      paramCount++;
      updateFields.push(`status = $${paramCount}`);
      params.push(status);

      // Set resolved_at or closed_at based on status
      if (status === 'resolved') {
        updateFields.push('resolved_at = CURRENT_TIMESTAMP');
      }
      if (status === 'closed') {
        updateFields.push('closed_at = CURRENT_TIMESTAMP');
      }
    }

    // Update assigned_to
    if (assigned_to !== undefined) {
      paramCount++;
      updateFields.push(`assigned_to = $${paramCount}`);
      params.push(assigned_to);
    }

    // Update assigned_to_name
    if (assigned_to_name !== undefined) {
      paramCount++;
      updateFields.push(`assigned_to_name = $${paramCount}`);
      params.push(assigned_to_name);
    }

    // Update category
    if (category !== undefined) {
      paramCount++;
      updateFields.push(`category = $${paramCount}`);
      params.push(category);
    }

    // Update priority
    if (priority) {
      const validPriorities = ['low', 'medium', 'high', 'urgent'];
      if (!validPriorities.includes(priority)) {
        return res.status(400).json({
          success: false,
          message: `Invalid priority. Must be one of: ${validPriorities.join(', ')}`,
        });
      }
      paramCount++;
      updateFields.push(`priority = $${paramCount}`);
      params.push(priority);
    }

    // Check if there are any fields to update
    if (updateFields.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No fields to update. Provide at least one: status, assigned_to, assigned_to_name, category, or priority',
      });
    }

    // Always update updated_at
    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    
    // Add ticket ID for WHERE clause
    paramCount++;
    params.push(id);

    const result = await pool.query(
      `UPDATE tickets
       SET ${updateFields.join(', ')}
       WHERE id = $${paramCount}
       RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    res.json({
      success: true,
      data: {
        ticket: result.rows[0],
      },
    });
  } catch (error) {
    console.error('❌ Error updating ticket:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update ticket',
      error: error.message,
    });
  }
});

// ============================================
// 7. MARK MESSAGES AS READ
// POST /api/v1/support/tickets/:id/messages/read
// ============================================
app.post('/api/v1/support/tickets/:id/messages/read', async (req, res) => {
  try {
    const { id } = req.params;
    const { message_ids } = req.body;

    if (message_ids && message_ids.length > 0) {
      // Mark specific messages as read
      await pool.query(
        `UPDATE ticket_messages
         SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
         WHERE ticket_id = $1 AND id = ANY($2)`,
        [id, message_ids]
      );
    } else {
      // Mark all agent messages as read
      await pool.query(
        `UPDATE ticket_messages
         SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
         WHERE ticket_id = $1 AND sender_type = 'agent'`,
        [id]
      );
    }

    res.json({
      success: true,
      message: 'Messages marked as read',
    });
  } catch (error) {
    console.error('❌ Error marking messages as read:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to mark messages as read',
      error: error.message,
    });
  }
});

// ============================================
// ERROR HANDLING MIDDLEWARE
// ============================================
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: err.message,
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    path: req.path,
  });
});

// ============================================
// START SERVER
// ============================================
app.listen(PORT, () => {
  console.log('');
  console.log('🚀 ========================================');
  console.log('   Support Ticket API Server');
  console.log('🚀 ========================================');
  console.log(`📡 Server running on: http://localhost:${PORT}`);
  console.log(`💚 Health check: http://localhost:${PORT}/api/health`);
  console.log(`📝 API Base: http://localhost:${PORT}/api/v1/support`);
  console.log('🚀 ========================================');
  console.log('');
});

