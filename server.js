// Support Ticket System - Node.js Backend API
// Express + ERPNext/Frappe (middleware architecture)

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

require('dotenv').config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);

const CORS_ALLOWED_ORIGINS = (process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((v) => v.trim())
  .filter(Boolean);
const REQUESTS_PER_WINDOW = Math.max(parseInt(process.env.REQUESTS_PER_WINDOW || '120', 10) || 120, 1);
const REQUEST_WINDOW_MS = Math.max(parseInt(process.env.REQUEST_WINDOW_MS || '60000', 10) || 60000, 1000);

const ipRateBucket = new Map();

function corsOriginValidator(origin, callback) {
  // Allow server-to-server and native/mobile requests with no browser origin.
  if (!origin) return callback(null, true);
  if (CORS_ALLOWED_ORIGINS.length === 0) return callback(null, true);
  if (CORS_ALLOWED_ORIGINS.includes(origin)) return callback(null, true);
  return callback(new Error('Origin not allowed by CORS'));
}

app.use(
  cors({
    origin: corsOriginValidator,
  }),
);

const ERP_BASE_URL = normalizeBaseUrl(process.env.ERP_BASE_URL || '');
const ERP_API_KEY = (process.env.ERP_API_KEY || '').trim();
const ERP_API_SECRET = (process.env.ERP_API_SECRET || '').trim();
const ERP_BEARER_TOKEN = (process.env.ERP_BEARER_TOKEN || '').trim();

const ERP_TICKET_DOCTYPE = (process.env.ERP_TICKET_DOCTYPE || 'Support Ticket').trim();
const ERP_MESSAGE_DOCTYPE = (process.env.ERP_MESSAGE_DOCTYPE || 'Support Ticket Message').trim();
const ERP_MESSAGE_TICKET_FIELD = (process.env.ERP_MESSAGE_TICKET_FIELD || 'ticket').trim();
const SUPPORT_APP_ID = (process.env.SUPPORT_APP_ID || '').trim();
const SUPPORT_SIGNING_SECRET = (process.env.SUPPORT_SIGNING_SECRET || '').trim();
const SUPPORT_ENFORCE_REQUEST_SIGNING = (process.env.SUPPORT_ENFORCE_REQUEST_SIGNING || 'true').trim().toLowerCase() !== 'false';
const REQUEST_SIGNATURE_MAX_SKEW_MS = Math.max(parseInt(process.env.REQUEST_SIGNATURE_MAX_SKEW_MS || '300000', 10) || 300000, 1000);
const SUPPORT_SERVER_API_KEY = (process.env.SUPPORT_SERVER_API_KEY || '').trim();

const MAX_LIST_LIMIT = 100;
const VALID_STATUSES = new Set(['open', 'in_progress', 'resolved', 'closed', 'waiting_for_customer']);
const VALID_PRIORITIES = new Set(['low', 'medium', 'high', 'urgent']);

function emptyTicketListResponse(page, limit, warning) {
  return {
    success: true,
    data: {
      tickets: [],
      pagination: {
        page,
        limit,
        total: 0,
      },
      ...(warning ? { warning } : {}),
    },
  };
}

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
console.log(
  `🛡️ Rate limit: ${REQUESTS_PER_WINDOW} req / ${REQUEST_WINDOW_MS}ms per IP`,
);
if (CORS_ALLOWED_ORIGINS.length > 0) {
  console.log(`🌐 CORS allowlist enabled: ${CORS_ALLOWED_ORIGINS.join(', ')}`);
} else {
  console.warn('⚠️ CORS allowlist is empty; all origins are allowed.');
}
if (SUPPORT_ENFORCE_REQUEST_SIGNING) {
  if (!SUPPORT_APP_ID || !SUPPORT_SIGNING_SECRET) {
    console.warn('⚠️ Request signing is enabled but SUPPORT_APP_ID/SUPPORT_SIGNING_SECRET is missing.');
  } else {
    console.log('🔐 Support API request signing: ENABLED');
  }
} else {
  console.warn('⚠️ Support API request signing is DISABLED. This is unsafe for production.');
}
if (SUPPORT_SERVER_API_KEY) {
  console.log('🔑 Server API key auth: ENABLED');
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

function erpRequestHeaders() {
  return {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    'User-Agent': 'sriaas-support-api/1.0',
    // Harmless for normal hosts; required when ERP is exposed through ngrok/free tunnels.
    'ngrok-skip-browser-warning': 'true',
    ...authHeaders(),
  };
}

function isHtmlErrorBody(text) {
  const t = String(text || '');
  return /<html|<!doctype|BrokenPipeError|Werkzeug Debugger/i.test(t);
}

function rawBodySaver(req, res, buf) {
  req.rawBody = buf ? buf.toString('utf8') : '';
}

app.use(express.json({ verify: rawBodySaver }));

function toIso(value, fallback = null) {
  if (!value) return fallback;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? fallback : d.toISOString();
}

function toERPDatetime(value = new Date()) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 19).replace('T', ' ');
}

function safeEqualText(a, b) {
  const aBuf = Buffer.from(String(a || ''), 'utf8');
  const bBuf = Buffer.from(String(b || ''), 'utf8');
  if (aBuf.length !== bBuf.length) return false;
  return crypto.timingSafeEqual(aBuf, bBuf);
}

function computeRequestSignature({ method, pathOnly, timestamp, body }) {
  const payload = `${method.toUpperCase()}\n${pathOnly}\n${timestamp}\n${body || ''}`;
  return crypto
      .createHmac('sha256', SUPPORT_SIGNING_SECRET)
      .update(payload, 'utf8')
      .digest('hex');
}

function verifySignedRequest(req, res, next) {
  // Allow trusted server-to-server clients (ERP automations, backend jobs) with a static key.
  const serverApiKey = (req.get('x-server-api-key') || '').trim();
  if (SUPPORT_SERVER_API_KEY && safeEqualText(serverApiKey, SUPPORT_SERVER_API_KEY)) {
    return next();
  }

  if (!SUPPORT_ENFORCE_REQUEST_SIGNING) return next();
  if (!SUPPORT_APP_ID || !SUPPORT_SIGNING_SECRET) {
    return res.status(503).json({
      success: false,
      message: 'API security misconfigured on server',
    });
  }

  const clientAppId = (req.get('x-app-id') || '').trim();
  const timestamp = (req.get('x-timestamp') || '').trim();
  const signature = (req.get('x-signature') || '').trim().toLowerCase();

  if (!clientAppId || !timestamp || !signature) {
    return res.status(401).json({
      success: false,
      message: 'Missing authentication headers',
    });
  }

  if (!safeEqualText(clientAppId, SUPPORT_APP_ID)) {
    return res.status(401).json({
      success: false,
      message: 'Invalid app identity',
    });
  }

  const requestTs = parseInt(timestamp, 10);
  if (Number.isNaN(requestTs)) {
    return res.status(401).json({
      success: false,
      message: 'Invalid timestamp',
    });
  }

  const skew = Math.abs(Date.now() - requestTs);
  if (skew > REQUEST_SIGNATURE_MAX_SKEW_MS) {
    return res.status(401).json({
      success: false,
      message: 'Request expired',
    });
  }

  const pathOnly = (req.originalUrl || req.path || '').split('?')[0];
  const body = req.rawBody || '';
  const expected = computeRequestSignature({
    method: req.method,
    pathOnly,
    timestamp,
    body,
  });
  if (!safeEqualText(signature, expected)) {
    return res.status(401).json({
      success: false,
      message: 'Invalid request signature',
    });
  }

  return next();
}

function applyRateLimit(req, res, next) {
  const key = (req.ip || req.socket?.remoteAddress || 'unknown').toString();
  const now = Date.now();
  const current = ipRateBucket.get(key);

  if (!current || now > current.resetAt) {
    ipRateBucket.set(key, {
      count: 1,
      resetAt: now + REQUEST_WINDOW_MS,
    });
    return next();
  }

  current.count += 1;
  if (current.count > REQUESTS_PER_WINDOW) {
    const retryAfterSec = Math.max(
      Math.ceil((current.resetAt - now) / 1000),
      1,
    );
    res.setHeader('Retry-After', retryAfterSec.toString());
    return res.status(429).json({
      success: false,
      message: 'Too many requests. Please try again shortly.',
    });
  }
  return next();
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

function sanitizeErpErrorMessage(raw) {
  let text = String(raw || '').trim();
  if (!text) return 'ERP request failed';

  const isHtml = /<html|<!doctype/i.test(text);
  if (isHtml || text.length > 600) {
    const titleMatch = text.match(/<title[^>]*>([^<]+)<\/title>/i);
    if (titleMatch) {
      const title = titleMatch[1]
        .replace(/\s*\/\/\s*Werkzeug Debugger/i, '')
        .trim();
      if (title) {
        if (/BrokenPipeError/i.test(title)) {
          return (
            'ERP server error (BrokenPipe) when using Support Ticket DocType. ' +
            'Frappe is crashing on site1.local — fix or recreate that DocType, or store tickets via ' +
            'Mobile App User engagement_items (record_type Support Ticket) instead.'
          );
        }
        return title;
      }
    }
    return (
      'ERP returned an HTML error page. Verify ERP_BASE_URL, API key permissions, ' +
      'and that Support Ticket / Support Ticket Message DocTypes exist.'
    );
  }

  if (text.length > 280) text = `${text.slice(0, 280)}…`;
  return text;
}

function extractFrappeError(payload) {
  if (!payload || typeof payload !== 'object') return null;

  if (typeof payload.exc === 'string' && payload.exc.trim()) {
    const lines = payload.exc.split('\n').map((l) => l.trim()).filter(Boolean);
    const last = lines[lines.length - 1] || payload.exc;
    return last.replace(/^frappe\.exceptions\.[A-Za-z]+:\s*/i, '');
  }

  if (payload._server_messages) {
    try {
      const raw = typeof payload._server_messages === 'string'
        ? JSON.parse(payload._server_messages)
        : payload._server_messages;
      if (Array.isArray(raw) && raw.length > 0) {
        const last = raw[raw.length - 1];
        if (typeof last === 'string') {
          const parsed = JSON.parse(last);
          return parsed?.message || last;
        }
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  if (typeof payload.message === 'string' && payload.message.trim()) {
    return payload.message;
  }

  return null;
}

function mapTicketFromERP(doc) {
  const statusRaw = (doc.status || '').toString().trim();
  const statusNorm = statusRaw.toLowerCase().replace(/\s+/g, '_');
  const priorityRaw = (doc.priority || '').toString().trim();
  const priorityNorm = priorityRaw.toLowerCase();
  return {
    id: doc.name,
    ticket_number: doc.ticket_number || doc.name,
    user_id: doc.user_id || doc.patient_id || doc.external_id || doc.email || doc.raised_by || null,
    user_name: doc.user_name || doc.customer_name || doc.requester_name || '',
    user_email: doc.user_email || doc.email || doc.raised_by || doc.email_id || '',
    user_phone: doc.user_phone || doc.phone || '',
    subject: doc.subject || '',
    description: doc.description || '',
    status: statusNorm || 'open',
    priority: priorityNorm || 'medium',
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
  const singleAttachment = doc.attachment ? [doc.attachment] : [];
  const senderTypeRaw = (doc.sender_type || '').toString().trim().toLowerCase();
  return {
    id: doc.name,
    ticket_id: doc[ERP_MESSAGE_TICKET_FIELD] || doc.ticket || doc.ticket_id || '',
    sender_type: senderTypeRaw === 'agent' ? 'agent' : 'user',
    sender_id: doc.sender_id || null,
    sender_name: doc.sender_name || '',
    message: doc.message || '',
    attachments: Array.isArray(attachments) && attachments.length > 0 ? attachments : singleAttachment,
    is_read: Boolean(doc.is_read),
    read_at: toIso(doc.read_at, null),
    created_at: toIso(doc.timestamp || doc.creation, new Date().toISOString()),
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
    headers: erpRequestHeaders(),
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();

  if (isHtmlErrorBody(text)) {
    const err = new Error(sanitizeErpErrorMessage(text));
    err.status = 502;
    err.payload = { message: text };
    throw err;
  }

  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = { message: text };
  }

  if (!response.ok) {
    const message = sanitizeErpErrorMessage(
      extractFrappeError(parsed) ||
        parsed?.message ||
        `ERPNext request failed: ${response.status}`,
    );
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

const BASE_TICKET_FIELDS = [
  'name',
  'subject',
  'description',
  'status',
  'priority',
  'creation',
  'modified',
];

const CUSTOM_TICKET_FIELDS = [
  'name',
  'ticket_number',
  'customer_name',
  'phone',
  'email',
  'user_id',
  'user_name',
  'user_email',
  'user_phone',
  'subject',
  'description',
  'status',
  'priority',
  'category',
  'assigned_to',
  'assigned_to_name',
  'metadata',
  'creation',
  'modified',
  'resolved_at',
  'closed_at',
];

function ticketListFilters(field, value, status) {
  const filters = [[field, '=', value]];
  if (status) filters.push(['status', '=', toERPStatus(status)]);
  return filters;
}

function addTicketListQueries(queries, fieldsToTry, value, status) {
  const normalized = (value || '').toString().trim();
  if (!normalized) return;
  for (const field of fieldsToTry) {
    queries.push(
      {
        fields: CUSTOM_TICKET_FIELDS,
        filters: ticketListFilters(field, normalized, status),
      },
      {
        fields: BASE_TICKET_FIELDS,
        filters: ticketListFilters(field, normalized, status),
      },
    );
  }
}

function ticketListQueryCandidates({ userId, userEmail, userPhone, status }) {
  const queries = [];
  addTicketListQueries(queries, ['user_id', 'patient_id', 'external_id'], userId, status);
  addTicketListQueries(queries, ['user_email', 'email', 'raised_by', 'email_id'], userEmail, status);
  addTicketListQueries(queries, ['user_phone', 'phone', 'mobile_no', 'contact'], userPhone, status);
  return queries;
}

async function getTicketRowsForUser({ userId, userEmail, userPhone, status, limit, offset }) {
  const queries = ticketListQueryCandidates({
    userId,
    userEmail,
    userPhone,
    status,
  });
  let firstError = null;
  let successCount = 0;
  const rowsByName = new Map();

  for (const query of queries) {
    try {
      const rows = await erpGetList(ERP_TICKET_DOCTYPE, {
        ...query,
        orderBy: 'creation desc',
        // Different ERP ticket versions may store the same user's records
        // under different requester fields. Merge before route pagination.
        limit: Math.min(limit + offset, MAX_LIST_LIMIT),
        offset: 0,
      });
      successCount += 1;
      for (const row of rows) {
        const name = (row?.name || '').toString().trim();
        if (!name) continue;
        const previous = rowsByName.get(name) || {};
        rowsByName.set(name, { ...previous, ...row });
      }
    } catch (error) {
      firstError = firstError || error;
      console.warn(
        `Ticket query fallback after ${error.status || 500}: ${sanitizeErpErrorMessage(error.message)}`,
      );
    }
  }

  if (successCount > 0) {
    return Array.from(rowsByName.values())
      .sort((a, b) => {
        const aTime = new Date(a.creation || a.modified || 0).getTime() || 0;
        const bTime = new Date(b.creation || b.modified || 0).getTime() || 0;
        return bTime - aTime;
      })
      .slice(offset, offset + limit);
  }

  throw firstError || new Error('No ticket lookup strategy is configured');
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

  let rows = [];
  try {
    rows = await erpGetList(ERP_TICKET_DOCTYPE, {
      fields: ['ticket_number'],
      filters: [['ticket_number', 'like', `${prefix}%`]],
      limit: MAX_LIST_LIMIT,
      orderBy: 'creation desc',
    });
  } catch (error) {
    // Standard ERPNext Support Ticket names itself and has no ticket_number field.
    console.warn(
      `Using ERP ticket naming after ticket_number lookup failed: ${sanitizeErpErrorMessage(error.message)}`,
    );
    return null;
  }

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

function toERPStatus(value) {
  const v = (value || '').toString().trim().toLowerCase();
  if (v === 'in_progress') return 'In Progress';
  if (v === 'waiting_for_customer') return 'Waiting for Customer';
  if (v === 'resolved') return 'Resolved';
  if (v === 'closed') return 'Closed';
  return 'Open';
}

function toERPPriority(value) {
  const v = (value || '').toString().trim().toLowerCase();
  if (v === 'low') return 'Low';
  if (v === 'high') return 'High';
  if (v === 'urgent') return 'Urgent';
  return 'Medium';
}

async function countUnreadAgentMessages(ticket) {
  const ticketIds = [
    ticket?.id,
    ticket?.ticket_number,
  ]
    .map((v) => (v || '').toString().trim())
    .filter(Boolean);
  const uniqueTicketIds = Array.from(new Set(ticketIds));

  for (const ticketId of uniqueTicketIds) {
    try {
      const rows = await erpGetList(ERP_MESSAGE_DOCTYPE, {
        fields: ['name', 'sender_type', 'is_read'],
        filters: [[ERP_MESSAGE_TICKET_FIELD, '=', ticketId]],
        limit: MAX_LIST_LIMIT,
        orderBy: 'creation desc',
      });
      return rows.filter((row) => {
        const senderType = (row.sender_type || '').toString().trim().toLowerCase();
        const isRead = row.is_read === 1 || row.is_read === true || row.is_read === '1';
        return senderType === 'agent' && !isRead;
      }).length;
    } catch (error) {
      console.warn(
        `Unread message count fallback after ${ticketId}: ${sanitizeErpErrorMessage(error.message)}`,
      );
    }
  }

  return 0;
}

// ============================================
// API ROUTES
// ============================================

app.use('/api/v1/support', applyRateLimit, verifySignedRequest);

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
      patient_id,
      category,
      priority = 'medium',
    } = req.body;
    const ticketUserId = (user_id || patient_id || '').toString().trim();

    // SECURITY: Require some user identifier
    if (!ticketUserId && !user_email) {
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
    const customTicketDoc = {
      ...(ticketNumber ? { ticket_number: ticketNumber } : {}),
      // Some ERP setups keep customer_* fields mandatory alongside user_* fields.
      customer_name: user_name,
      phone: user_phone,
      email: user_email,
      user_id: ticketUserId,
      user_name,
      user_email,
      user_phone,
      subject,
      description,
      status: toERPStatus('open'),
      priority: toERPPriority(priority),
      category: category || null,
      metadata: JSON.stringify({ source: 'mobile_app' }),
    };
    const patientTicketDoc = {
      customer_name: user_name,
      phone: user_phone,
      email: user_email,
      user_id: ticketUserId,
      user_name,
      user_email,
      user_phone,
      subject,
      description,
      status: toERPStatus('open'),
      priority: toERPPriority(priority),
    };
    let created;
    try {
      created = await erpCreateDoc(ERP_TICKET_DOCTYPE, customTicketDoc);
    } catch (error) {
      console.warn(
        `Custom ticket create failed, retrying exact patient ticket shape: ${sanitizeErpErrorMessage(error.message)}`,
      );
      created = await erpCreateDoc(ERP_TICKET_DOCTYPE, patientTicketDoc);
    }

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
      error: sanitizeErpErrorMessage(error.message),
    });
  }
});

// ============================================
// 2. GET USER TICKETS
// GET /api/v1/support/tickets?user_id=xxx&status=open&page=1&limit=20
// Also accepts patient_id as an alias for user_id.
// ============================================
app.get('/api/v1/support/tickets', async (req, res) => {
  try {
    const { user_id, patient_id, user_email, user_phone, status, page = 1, limit = 20 } = req.query;
    const ticketUserId = (user_id || patient_id || '').toString().trim();
    const ticketUserEmail = (user_email || '').toString().trim();
    const ticketUserPhone = (user_phone || '').toString().trim();
    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit, 10) || 20, 1), MAX_LIST_LIMIT);
    const offset = (pageNum - 1) * limitNum;

    // Patient ticket history is scoped only by the stable app patient UUID.
    if (!ticketUserId && !ticketUserEmail && !ticketUserPhone) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Provide user_id, patient_id, user_email, or user_phone.',
      });
    }

    const rows = await getTicketRowsForUser({
      userId: ticketUserId,
      userEmail: ticketUserEmail,
      userPhone: ticketUserPhone,
      status,
      limit: limitNum,
      offset,
    });

    const ticketsWithUnread = await Promise.all(rows.map(async (row) => {
      const ticket = mapTicketFromERP(row);
      ticket.unread_message_count = await countUnreadAgentMessages(ticket);
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
    const safeMessage = sanitizeErpErrorMessage(error.message);
    if (/html error page|browser warning|BrokenPipe/i.test(safeMessage)) {
      return res.json(emptyTicketListResponse(
        Math.max(parseInt(req.query.page, 10) || 1, 1),
        Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), MAX_LIST_LIMIT),
        safeMessage,
      ));
    }
    res.status(error.status || 500).json({
      success: false,
      message: 'Failed to fetch tickets',
      error: safeMessage,
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
      fields: ['name', ERP_MESSAGE_TICKET_FIELD, 'sender_type', 'sender_id', 'sender_name', 'message', 'attachment', 'attachments', 'timestamp', 'is_read', 'read_at', 'creation', 'modified'],
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
    let finalSenderType = sender_type === 'agent' ? 'Agent' : 'User';
    let finalSenderName;
    let finalSenderId = null;
    
    if (finalSenderType === 'Agent') {
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
      attachment: Array.isArray(attachments) && attachments.length > 0 ? attachments[0] : '',
      attachments: JSON.stringify(Array.isArray(attachments) ? attachments : []),
      timestamp: toERPDatetime(),
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
      fields: ['name', ERP_MESSAGE_TICKET_FIELD, 'sender_type', 'sender_id', 'sender_name', 'message', 'attachment', 'attachments', 'timestamp', 'is_read', 'read_at', 'creation', 'modified'],
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
      updateData.status = toERPStatus(status);
      if (status === 'resolved') updateData.resolved_at = toERPDatetime();
      if (status === 'closed') updateData.closed_at = toERPDatetime();
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
      updateData.priority = toERPPriority(priority);
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
        fields: ['name', 'sender_type'],
        filters: [[ERP_MESSAGE_TICKET_FIELD, '=', ticketDoc.name]],
        limit: MAX_LIST_LIMIT,
      });
      targets = rows
        .filter((r) => (r.sender_type || '').toString().trim().toLowerCase() === 'agent')
        .map((r) => r.name);
    }

    await Promise.all(targets.map((name) =>
      erpUpdateDoc(ERP_MESSAGE_DOCTYPE, name, {
        is_read: 1,
        read_at: toERPDatetime(),
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

