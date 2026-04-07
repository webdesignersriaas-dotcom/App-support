// Support Ticket System - Node.js Backend API
// Express + ERPNext/Frappe (middleware architecture)

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

require('dotenv').config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);

app.use(cors());
app.use(express.json());

const ERP_BASE_URL = normalizeBaseUrl(process.env.ERP_BASE_URL || '');
const ERP_API_KEY = (process.env.ERP_API_KEY || '').trim();
const ERP_API_SECRET = (process.env.ERP_API_SECRET || '').trim();
const ERP_BEARER_TOKEN = (process.env.ERP_BEARER_TOKEN || '').trim();

const ERP_TICKET_DOCTYPE = (process.env.ERP_TICKET_DOCTYPE || 'Support Ticket').trim();
const ERP_MESSAGE_DOCTYPE = (process.env.ERP_MESSAGE_DOCTYPE || 'Support Ticket Message').trim();
const ERP_MESSAGE_TICKET_FIELD = (process.env.ERP_MESSAGE_TICKET_FIELD || 'ticket').trim();

const MAX_LIST_LIMIT = 100;
const VALID_STATUSES = new Set(['open', 'in_progress', 'resolved', 'closed']);
const VALID_PRIORITIES = new Set(['low', 'medium', 'high', 'urgent']);

const envPath = path.join(__dirname, '.env');
console.log('📁 Current directory:', __dirname);
console.log('📄 .env file exists?', fs.existsSync(envPath) ? '✅ YES' : '❌ NO');
console.log('🌐 ERP base URL:', ERP_BASE_URL || '❌ NOT SET');
console.log('📦 Ticket DocType:', ERP_TICKET_DOCTYPE);
console.log('📦 Message DocType:', ERP_MESSAGE_DOCTYPE);
console.log('🔗 Message ticket field:', ERP_MESSAGE_TICKET_FIELD);

if (!ERP_BASE_URL) {
  console.warn('⚠️ ERP_BASE_URL is not configured. API requests will fail until set.');
}
if (!hasAuthConfigured()) {
  console.warn('⚠️ ERP auth is not configured. Set ERP_API_KEY+ERP_API_SECRET or ERP_BEARER_TOKEN.');
}

function hasAuthConfigured() {
  return Boolean((ERP_API_KEY && ERP_API_SECRET) || ERP_BEARER_TOKEN);
}

function normalizeBaseUrl(value) {
  let out = (value || '').trim();
  while (out.endsWith('/')) out = out.slice(0, -1);
  return out;
}

function authHeaders() {
  if (ERP_BEARER_TOKEN) {
    return { Authorization: `Bearer ${ERP_BEARER_TOKEN}` };
  }
  if (ERP_API_KEY && ERP_API_SECRET) {
    return { Authorization: `token ${ERP_API_KEY}:${ERP_API_SECRET}` };
  }
  return {};
}

function toIso(value, fallback = null) {
  if (!value) return fallback;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? fallback : d.toISOString();
}

function safeJsonParse(value, fallback) {
  if (value == null) return fallback;
  if (typeof value === 'object') return value;
  if (typeof value !== 'string') return fallback;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function mapTicketFromERP(doc) {
  return {
    id: doc.name,
    ticket_number: doc.ticket_number || doc.name,
    user_id: doc.user_id || null,
    user_name: doc.user_name || '',
    user_email: doc.user_email || '',
    user_phone: doc.user_phone || '',
    subject: doc.subject || '',
    description: doc.description || '',
    status: doc.status || 'open',
    priority: doc.priority || 'medium',
    category: doc.category || null,
    assigned_to: doc.assigned_to || null,
    assigned_to_name: doc.assigned_to_name || null,
    created_at: toIso(doc.creation, new Date().toISOString()),
    updated_at: toIso(doc.modified, new Date().toISOString()),
    resolved_at: toIso(doc.resolved_at, null),
    closed_at: toIso(doc.closed_at, null),
    metadata: safeJsonParse(doc.metadata, null),
    unread_message_count: typeof doc.unread_message_count === 'number' ? doc.unread_message_count : 0,
  };
}

function mapMessageFromERP(doc) {
  const attachments = safeJsonParse(doc.attachments, []);
  return {
    id: doc.name,
    ticket_id: doc[ERP_MESSAGE_TICKET_FIELD] || doc.ticket || doc.ticket_id || '',
    sender_type: doc.sender_type || 'user',
    sender_id: doc.sender_id || null,
    sender_name: doc.sender_name || '',
    message: doc.message || '',
    attachments: Array.isArray(attachments) ? attachments : [],
    is_read: Boolean(doc.is_read),
    read_at: toIso(doc.read_at, null),
    created_at: toIso(doc.creation, new Date().toISOString()),
    updated_at: toIso(doc.modified, new Date().toISOString()),
  };
}

async function erpFetch(pathname, { method = 'GET', body, query } = {}) {
  if (!ERP_BASE_URL) {
    throw new Error('ERP_BASE_URL is not configured');
  }

  const url = new URL(`${ERP_BASE_URL}${pathname}`);
  if (query && typeof query === 'object') {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null && v !== '') {
        url.searchParams.set(k, typeof v === 'string' ? v : JSON.stringify(v));
      }
    }
  }

  const response = await fetch(url.toString(), {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders(),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = { message: text };
  }

  if (!response.ok) {
    const message = parsed?.message || parsed?.exc || `ERPNext request failed: ${response.status}`;
    const err = new Error(message);
    err.status = response.status;
    err.payload = parsed;
    throw err;
  }

  return parsed;
}

async function erpGetList(doctype, { fields, filters, orderBy, limit = 20, offset = 0 } = {}) {
  const payload = await erpFetch(`/api/resource/${encodeURIComponent(doctype)}`, {
    query: {
      fields: fields || ['name'],
      filters: filters || [],
      order_by: orderBy || 'creation desc',
      limit_page_length: Math.min(Math.max(parseInt(limit, 10) || 20, 1), MAX_LIST_LIMIT),
      limit_start: Math.max(parseInt(offset, 10) || 0, 0),
    },
  });
  return Array.isArray(payload?.data) ? payload.data : [];
}

async function erpCreateDoc(doctype, doc) {
  const payload = await erpFetch(`/api/resource/${encodeURIComponent(doctype)}`, {
    method: 'POST',
    body: doc,
  });
  return payload?.data || null;
}

async function erpGetDoc(doctype, name) {
  const payload = await erpFetch(`/api/resource/${encodeURIComponent(doctype)}/${encodeURIComponent(name)}`);
  return payload?.data || null;
}

async function erpUpdateDoc(doctype, name, data) {
  const payload = await erpFetch(`/api/resource/${encodeURIComponent(doctype)}/${encodeURIComponent(name)}`, {
    method: 'PUT',
    body: data,
  });
  return payload?.data || null;
}

async function resolveTicketDoc(idOrTicketNumber) {
  try {
    const byName = await erpGetDoc(ERP_TICKET_DOCTYPE, idOrTicketNumber);
    if (byName) return byName;
  } catch (_) {
    // fallback to ticket_number lookup
  }

  const list = await erpGetList(ERP_TICKET_DOCTYPE, {
    fields: ['name', 'ticket_number', 'user_id', 'user_name', 'user_email', 'user_phone', 'subject', 'description', 'status', 'priority', 'category', 'assigned_to', 'assigned_to_name', 'metadata', 'creation', 'modified', 'resolved_at', 'closed_at'],
    filters: [['ticket_number', '=', idOrTicketNumber]],
    limit: 1,
    orderBy: 'creation desc',
  });
  return list[0] || null;
}

async function nextTicketNumber() {
  const year = new Date().getFullYear();
  const prefix = `TKT-${year}-`;

  const rows = await erpGetList(ERP_TICKET_DOCTYPE, {
    fields: ['ticket_number'],
    filters: [['ticket_number', 'like', `${prefix}%`]],
    limit: MAX_LIST_LIMIT,
    orderBy: 'creation desc',
  });

  let max = 0;
  for (const r of rows) {
    const value = (r.ticket_number || '').trim();
    const match = value.match(/(\d+)$/);
    if (match) {
      const n = parseInt(match[1], 10);
      if (!Number.isNaN(n) && n > max) max = n;
    }
  }
  const next = max + 1;
  return `${prefix}${String(next).padStart(6, '0')}`;
}

async function countUnreadAgentMessages(ticketId) {
  const rows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
    fields: ['name'],
    filters: [
      [ERP_MESSAGE_TICKET_FIELD, '=', ticketId],
      ['sender_type', '=', 'agent'],
      ['is_read', '=', 0],
    ],
    limit: MAX_LIST_LIMIT,
    orderBy: 'creation desc',
  });
  return rows.length;
}

// ============================================
// API ROUTES
// ============================================

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Support Ticket API middleware is running',
    storage: 'erpnext',
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

    if (!VALID_PRIORITIES.has(priority)) {
      return res.status(400).json({
        success: false,
        message: `Invalid priority. Must be one of: ${Array.from(VALID_PRIORITIES).join(', ')}`,
      });
    }

    const ticketNumber = await nextTicketNumber();
    const created = await erpCreateDoc(ERP_TICKET_DOCTYPE, {
      ticket_number: ticketNumber,
      // Some ERP setups keep customer_* fields mandatory alongside user_* fields.
      customer_name: user_name,
      user_id,
      user_name,
      user_email,
      user_phone,
      subject,
      description,
      status: 'open',
      priority,
      category: category || null,
      metadata: JSON.stringify({ source: 'mobile_app' }),
    });

    const ticket = mapTicketFromERP(created || {});

    // Format response
    return res.status(201).json({
      success: true,
      data: {
        ticket,
      },
    });
  } catch (error) {
    console.error('❌ Error creating ticket:', error);
    return res.status(error.status || 500).json({
      success: false,
      message: 'Failed to create ticket',
      error: error.message,
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
    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 20, 1), MAX_LIST_LIMIT);
    const offset = (pageNum - 1) * limitNum;

    // SECURITY: Require user_id (user must be logged in)
    if (!user_id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Please log in to view your tickets.',
      });
    }

    const filters = [['user_id', '=', user_id]];
    if (status) {
      filters.push(['status', '=', status]);
    }

    const rows = await erpGetList(ERP_TICKET_DOCTYPE, {
      fields: ['name', 'ticket_number', 'user_id', 'user_name', 'user_email', 'user_phone', 'subject', 'description', 'status', 'priority', 'category', 'assigned_to', 'assigned_to_name', 'metadata', 'creation', 'modified', 'resolved_at', 'closed_at'],
      filters,
      orderBy: 'creation desc',
      limit: limitNum,
      offset,
    });

    const ticketsWithUnread = await Promise.all(rows.map(async (row) => {
      const ticket = mapTicketFromERP(row);
      ticket.unread_message_count = await countUnreadAgentMessages(ticket.id);
      return ticket;
    }));

    res.json({
      success: true,
      data: {
        tickets: ticketsWithUnread,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: ticketsWithUnread.length,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error fetching tickets:', error);
    res.status(error.status || 500).json({
      success: false,
      message: 'Failed to fetch tickets',
      error: error.message,
    });
  }
});

// ============================================
// 3. GET TICKET DETAILS WITH MESSAGES
// GET /api/v1/support/tickets/:id
// Supports both UUID (ticket ID) and ticket_number (e.g., TKT-2026-000001)
// ============================================
app.get('/api/v1/support/tickets/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const ticketDoc = await resolveTicketDoc(id);
    if (!ticketDoc) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }
    const ticket = mapTicketFromERP(ticketDoc);
    const messageRows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
      fields: ['name', ERP_MESSAGE_TICKET_FIELD, 'sender_type', 'sender_id', 'sender_name', 'message', 'attachments', 'is_read', 'read_at', 'creation', 'modified'],
      filters: [[ERP_MESSAGE_TICKET_FIELD, '=', ticket.id]],
      orderBy: 'creation asc',
      limit: MAX_LIST_LIMIT,
      offset: 0,
    });
    const messages = messageRows.map(mapMessageFromERP);

    res.json({
      success: true,
      data: {
        ticket,
        messages,
      },
    });
  } catch (error) {
    console.error('❌ Error fetching ticket details:', error);
    res.status(error.status || 500).json({
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

    const ticketDoc = await resolveTicketDoc(id);
    if (!ticketDoc) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }
    const ticket = mapTicketFromERP(ticketDoc);
    const ticketId = ticket.id;

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
      if (user_id) finalSenderId = user_id;
      if (!finalSenderId && ticket.user_id) {
        finalSenderId = ticket.user_id;
      }
    }

    const created = await erpCreateDoc(ERP_MESSAGE_DOCTYPE, {
      [ERP_MESSAGE_TICKET_FIELD]: ticketId,
      sender_type: finalSenderType,
      sender_id: finalSenderId,
      sender_name: finalSenderName,
      message,
      attachments: JSON.stringify(Array.isArray(attachments) ? attachments : []),
      is_read: 0,
    });

    res.status(201).json({
      success: true,
      data: {
        message: mapMessageFromERP(created || {}),
      },
    });
  } catch (error) {
    console.error('❌ Error sending message:', error);
    res.status(error.status || 500).json({
      success: false,
      message: 'Failed to send message',
      error: error.message,
    });
  }
});

// ============================================
// 5. GET TICKET MESSAGES (with pagination)
// GET /api/v1/support/tickets/:id/messages?page=1&limit=50
// Supports both UUID (ticket ID) and ticket_number
// ============================================
app.get('/api/v1/support/tickets/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 50, since } = req.query;
    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 50, 1), MAX_LIST_LIMIT);
    const offset = (pageNum - 1) * limitNum;

    const ticketDoc = await resolveTicketDoc(id);
    if (!ticketDoc) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    const filters = [[ERP_MESSAGE_TICKET_FIELD, '=', ticketDoc.name]];
    if (since) {
      const s = toIso(since, null);
      if (s) filters.push(['creation', '>', s]);
    }

    const rows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
      fields: ['name', ERP_MESSAGE_TICKET_FIELD, 'sender_type', 'sender_id', 'sender_name', 'message', 'attachments', 'is_read', 'read_at', 'creation', 'modified'],
      filters,
      orderBy: 'creation asc',
      limit: limitNum,
      offset,
    });
    const messages = rows.map(mapMessageFromERP);

    res.json({
      success: true,
      data: {
        messages,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: messages.length,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error fetching messages:', error);
    res.status(error.status || 500).json({
      success: false,
      message: 'Failed to fetch messages',
      error: error.message,
    });
  }
});

// ============================================
// 6. UPDATE TICKET STATUS
// PATCH /api/v1/support/tickets/:id
// Supports both UUID (ticket ID) and ticket_number
// ============================================
app.patch('/api/v1/support/tickets/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, assigned_to, assigned_to_name, category, priority } = req.body;
    const ticketDoc = await resolveTicketDoc(id);
    if (!ticketDoc) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    const updateData = {};
    if (status !== undefined) {
      if (!VALID_STATUSES.has(status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status. Must be one of: ${Array.from(VALID_STATUSES).join(', ')}`,
        });
      }
      updateData.status = status;
      if (status === 'resolved') updateData.resolved_at = new Date().toISOString();
      if (status === 'closed') updateData.closed_at = new Date().toISOString();
    }
    if (assigned_to !== undefined) updateData.assigned_to = assigned_to;
    if (assigned_to_name !== undefined) updateData.assigned_to_name = assigned_to_name;
    if (category !== undefined) updateData.category = category;
    if (priority !== undefined) {
      if (!VALID_PRIORITIES.has(priority)) {
        return res.status(400).json({
          success: false,
          message: `Invalid priority. Must be one of: ${Array.from(VALID_PRIORITIES).join(', ')}`,
        });
      }
      updateData.priority = priority;
    }

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No fields to update. Provide at least one: status, assigned_to, assigned_to_name, category, or priority',
      });
    }
    const updated = await erpUpdateDoc(ERP_TICKET_DOCTYPE, ticketDoc.name, updateData);

    res.json({
      success: true,
      data: {
        ticket: mapTicketFromERP(updated || {}),
      },
    });
  } catch (error) {
    console.error('❌ Error updating ticket:', error);
    res.status(error.status || 500).json({
      success: false,
      message: 'Failed to update ticket',
      error: error.message,
    });
  }
});

// ============================================
// 7. MARK MESSAGES AS READ
// POST /api/v1/support/tickets/:id/messages/read
// Supports both UUID (ticket ID) and ticket_number
// ============================================
app.post('/api/v1/support/tickets/:id/messages/read', async (req, res) => {
  try {
    const { id } = req.params;
    const { message_ids } = req.body;
    const ticketDoc = await resolveTicketDoc(id);
    if (!ticketDoc) {
      return res.status(404).json({
        success: false,
        message: 'Ticket not found',
      });
    }

    let targets = [];
    if (Array.isArray(message_ids) && message_ids.length > 0) {
      const rows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
        fields: ['name'],
        filters: [['name', 'in', message_ids], [ERP_MESSAGE_TICKET_FIELD, '=', ticketDoc.name]],
        limit: MAX_LIST_LIMIT,
      });
      targets = rows.map((r) => r.name);
    } else {
      const rows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
        fields: ['name'],
        filters: [[ERP_MESSAGE_TICKET_FIELD, '=', ticketDoc.name], ['sender_type', '=', 'agent']],
        limit: MAX_LIST_LIMIT,
      });
      targets = rows.map((r) => r.name);
    }

    await Promise.all(targets.map((name) =>
      erpUpdateDoc(ERP_MESSAGE_DOCTYPE, name, {
        is_read: 1,
        read_at: new Date().toISOString(),
      })
    ));

    res.json({
      success: true,
      message: 'Messages marked as read',
    });
  } catch (error) {
    console.error('❌ Error marking messages as read:', error);
    res.status(error.status || 500).json({
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

