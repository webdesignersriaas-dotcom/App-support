import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

typedef SupportTicketsResolveUser = SupportTicketsUser? Function(
    BuildContext context);

String formatSupportApiError(Object e) {
  final raw = e.toString().replaceFirst('Exception: ', '').trim();
  if (RegExp(r'<html|<!doctype', caseSensitive: false).hasMatch(raw)) {
    final title = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(raw)?.group(1);
    if (title != null) {
      final clean = title.split('//').first.trim();
      if (clean.toLowerCase().contains('brokenpipe')) {
        return 'ERP error: Support Ticket DocType crashes on Frappe. '
            'Ask ERP admin to fix the DocType or use engagement_items tickets.';
      }
      return clean;
    }
    return 'Server error. ERP may be unreachable or misconfigured.';
  }
  return raw.length > 280 ? '${raw.substring(0, 280)}…' : raw;
}

void showSupportApiErrorSnack(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(formatSupportApiError(e), maxLines: 4),
      duration: const Duration(seconds: 5),
    ),
  );
}

int _countFromJson(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

class SupportTicketsConfig {
  final String apiBaseUrl;
  final String defaultAvatarUrlOrAsset;
  final SupportTicketsResolveUser? resolveUser;
  final String? appId;
  final String? signingSecret;
  final String? erpToken;

  const SupportTicketsConfig({
    required this.apiBaseUrl,
    required this.defaultAvatarUrlOrAsset,
    this.resolveUser,
    this.appId,
    this.signingSecret,
    this.erpToken,
  });
}

class SupportTicketsUser {
  final String id;
  final String? name;
  final String? firstName;
  final String? email;
  final String? phone;
  final String? picture;
  final String? userUrl;

  const SupportTicketsUser({
    required this.id,
    this.name,
    this.firstName,
    this.email,
    this.phone,
    this.picture,
    this.userUrl,
  });
}

class SupportTicketsScope extends InheritedWidget {
  final SupportTicketsConfig config;

  const SupportTicketsScope({
    super.key,
    required this.config,
    required super.child,
  });

  static SupportTicketsScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SupportTicketsScope>();
  }

  @override
  bool updateShouldNotify(covariant SupportTicketsScope oldWidget) {
    return oldWidget.config != config;
  }
}

class SupportTicketsPreloader {
  static final Map<String, _SupportTicketCacheEntry> _cache =
      <String, _SupportTicketCacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 5);

  static Future<void> preload({
    required SupportTicketsConfig config,
    required SupportTicketsUser user,
  }) async {
    final key = _cacheKey(config, user);
    final existing = _cache[key];
    if (existing != null) {
      final age = DateTime.now().difference(existing.loadedAt);
      if (existing.inFlight != null) {
        await existing.inFlight;
        return;
      }
      if (age < _cacheTtl) return;
    }

    late final Future<void> inFlight;
    inFlight = _fetchAndCache(config: config, user: user, key: key);
    _cache[key] = _SupportTicketCacheEntry(
      tickets: existing?.tickets ?? <_Ticket>[],
      loadedAt: existing?.loadedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      inFlight: inFlight,
    );
    await inFlight;
  }

  static List<_Ticket>? _cachedTickets({
    required SupportTicketsConfig config,
    required SupportTicketsUser user,
  }) {
    final existing = _cache[_cacheKey(config, user)];
    if (existing == null || existing.tickets.isEmpty) return null;
    if (DateTime.now().difference(existing.loadedAt) > _cacheTtl) return null;
    return List<_Ticket>.of(existing.tickets);
  }

  static Future<void> _fetchAndCache({
    required SupportTicketsConfig config,
    required SupportTicketsUser user,
    required String key,
  }) async {
    final client = _SupportApiClient(
      config.apiBaseUrl,
      appId: config.appId,
      signingSecret: config.signingSecret,
      erpToken: config.erpToken,
    );
    final tickets = await client.fetchTickets(
      userId: user.id,
      userEmail: user.email,
      userPhone: user.phone,
    );
    _cache[key] = _SupportTicketCacheEntry(
      tickets: tickets,
      loadedAt: DateTime.now(),
    );
  }

  static void _storeTickets({
    required SupportTicketsConfig config,
    required SupportTicketsUser user,
    required List<_Ticket> tickets,
  }) {
    _cache[_cacheKey(config, user)] = _SupportTicketCacheEntry(
      tickets: List<_Ticket>.of(tickets),
      loadedAt: DateTime.now(),
    );
  }

  static String _cacheKey(
      SupportTicketsConfig config, SupportTicketsUser user) {
    return '${config.apiBaseUrl.trim()}|${config.appId?.trim() ?? ''}|${config.erpToken?.trim() ?? ''}|${user.id.trim()}';
  }
}

class _SupportTicketCacheEntry {
  final List<_Ticket> tickets;
  final DateTime loadedAt;
  final Future<void>? inFlight;

  const _SupportTicketCacheEntry({
    required this.tickets,
    required this.loadedAt,
    this.inFlight,
  });
}

class _Ticket {
  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final String userId;
  final String? category;
  final int unreadMessageCount;
  final int agentMessageCount;
  final DateTime? createdAt;

  _Ticket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.userId,
    required this.category,
    required this.unreadMessageCount,
    required this.agentMessageCount,
    required this.createdAt,
  });

  factory _Ticket.fromJson(Map<String, dynamic> j) {
    return _Ticket(
      id: (j['id'] ?? '').toString(),
      ticketNumber: (j['ticket_number'] ?? j['id'] ?? '').toString(),
      subject: (j['subject'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      status: (j['status'] ?? 'open').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      userId: (j['user_id'] ?? j['patient_id'] ?? j['external_id'] ?? '')
          .toString(),
      category: j['category']?.toString(),
      unreadMessageCount: _countFromJson(j['unread_message_count']),
      agentMessageCount: _countFromJson(j['agent_message_count']),
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
    );
  }
}

class _TicketMessage {
  final String id;
  final String ticketId;
  final String senderType;
  final String senderName;
  final String message;
  final DateTime? createdAt;

  _TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory _TicketMessage.fromJson(Map<String, dynamic> j) {
    return _TicketMessage(
      id: (j['id'] ?? '').toString(),
      ticketId: (j['ticket_id'] ?? '').toString(),
      senderType: (j['sender_type'] ?? 'user').toString(),
      senderName: (j['sender_name'] ?? '').toString(),
      message: (j['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
    );
  }
}

class _SupportApiClient {
  final String baseUrl;
  final String appId;
  final String signingSecret;
  final String erpToken;

  _SupportApiClient(
    this.baseUrl, {
    String? appId,
    String? signingSecret,
    String? erpToken,
  })  : appId = (appId ?? '').trim(),
        signingSecret = (signingSecret ?? '').trim(),
        erpToken = (erpToken ?? '').trim();

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Map<String, String> _signedHeaders({
    required String method,
    required String path,
    required String body,
    bool includeContentType = false,
  }) {
    final headers = <String, String>{};
    if (includeContentType) headers['Content-Type'] = 'application/json';
    if (erpToken.isNotEmpty) headers['X-ERP-Token'] = erpToken;
    if (appId.isEmpty || signingSecret.isEmpty) return headers;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = '${method.toUpperCase()}\n$path\n$timestamp\n$body';
    final signature = Hmac(sha256, utf8.encode(signingSecret))
        .convert(utf8.encode(payload))
        .toString();
    headers['x-app-id'] = appId;
    headers['x-timestamp'] = timestamp;
    headers['x-signature'] = signature;
    return headers;
  }

  Future<Map<String, dynamic>> _parse(http.Response r) async {
    final body = r.body.trim();
    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(_sanitizeErrorText(body, statusCode: r.statusCode));
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    final message = (data['message'] ?? '').toString();
    final details = (data['error'] ?? '').toString();
    final msg = _bestErrorMessage(message, details);
    throw Exception(msg);
  }

  String _sanitizeErrorText(String raw, {int? statusCode}) {
    final text = raw.trim();
    if (text.isEmpty) {
      return statusCode != null
          ? 'Request failed (HTTP $statusCode)'
          : 'Request failed';
    }
    if (RegExp(r'<html|<!doctype', caseSensitive: false).hasMatch(text)) {
      final title = RegExp(
        r'<title[^>]*>([^<]+)</title>',
        caseSensitive: false,
      ).firstMatch(text)?.group(1);
      if (title != null) {
        final clean = title.split('//').first.trim();
        if (clean.toLowerCase().contains('brokenpipe')) {
          return 'ERP error: Support Ticket DocType crashes on Frappe. '
              'Ask ERP admin to fix the DocType or use engagement_items tickets.';
        }
        return clean;
      }
      return 'Server error. ERP may be unreachable or misconfigured.';
    }
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }

  String _bestErrorMessage(String message, String details) {
    final safeDetails = _sanitizeErrorText(details);
    final safeMessage = _sanitizeErrorText(message);
    if (safeDetails.isNotEmpty && safeDetails != 'Request failed') {
      final mandatory = RegExp(r'MandatoryError:.*?:\s*([a-zA-Z0-9_]+)')
          .firstMatch(safeDetails)
          ?.group(1);
      if (mandatory != null && mandatory.isNotEmpty) {
        return 'Missing required field in ERP: $mandatory';
      }
      if (safeMessage.isEmpty ||
          safeMessage.toLowerCase().startsWith('failed') ||
          safeMessage.toLowerCase().contains('request failed')) {
        return safeDetails;
      }
    }
    if (safeMessage.isNotEmpty && safeMessage != 'Request failed') {
      return safeMessage;
    }
    return safeDetails.isNotEmpty ? safeDetails : 'Request failed';
  }

  Future<List<_Ticket>> fetchTickets({
    required String userId,
    String? userEmail,
    String? userPhone,
    String? status,
  }) async {
    final q = <String, String>{
      'page': '1',
      'limit': '50',
      if (userId.trim().isNotEmpty) 'user_id': userId,
      if (userId.trim().isNotEmpty) 'patient_id': userId,
      if ((userEmail ?? '').trim().isNotEmpty) 'user_email': userEmail!.trim(),
      if ((userPhone ?? '').trim().isNotEmpty) 'user_phone': userPhone!.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    const path = '/api/v1/support/tickets';
    final r = await http.get(
      _uri(path, q),
      headers: _signedHeaders(method: 'GET', path: path, body: ''),
    );
    final data = await _parse(r);
    final list = (data['data']?['tickets'] as List<dynamic>? ?? <dynamic>[]);
    return list
        .map((e) => _Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<_Ticket> createTicket({
    required SupportTicketsUser user,
    required String subject,
    required String description,
    String priority = 'medium',
    String? category,
  }) async {
    final resolvedName = (user.name ?? user.firstName ?? '').trim();
    final resolvedEmail = (user.email ?? '').trim();
    final resolvedPhone = (user.phone ?? '').trim();

    final body = <String, dynamic>{
      'user_id': user.id,
      // Backend requires non-empty user fields.
      'user_name': resolvedName.isNotEmpty ? resolvedName : 'User',
      'user_email':
          resolvedEmail.isNotEmpty ? resolvedEmail : '${user.id}@app.local',
      'user_phone': resolvedPhone.isNotEmpty ? resolvedPhone : 'NA',
      'subject': subject,
      'description': description,
      'priority': priority,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
    };
    const path = '/api/v1/support/tickets';
    final rawBody = jsonEncode(body);
    final r = await http.post(
      _uri(path),
      headers: _signedHeaders(
        method: 'POST',
        path: path,
        body: rawBody,
        includeContentType: true,
      ),
      body: rawBody,
    );
    final data = await _parse(r);
    return _Ticket.fromJson(
        Map<String, dynamic>.from(data['data']['ticket'] as Map));
  }

  Future<List<_TicketMessage>> fetchMessages(
      {required String ticketIdOrNumber}) async {
    final path = '/api/v1/support/tickets/$ticketIdOrNumber/messages';
    final r = await http.get(
      _uri(path, <String, String>{
        'page': '1',
        'limit': '100',
      }),
      headers: _signedHeaders(method: 'GET', path: path, body: ''),
    );
    final data = await _parse(r);
    final list = (data['data']?['messages'] as List<dynamic>? ?? <dynamic>[]);
    return list
        .map(
            (e) => _TicketMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<_TicketMessage> sendUserMessage({
    required String ticketIdOrNumber,
    required SupportTicketsUser user,
    required String message,
  }) async {
    final path = '/api/v1/support/tickets/$ticketIdOrNumber/messages';
    final rawBody = jsonEncode(<String, dynamic>{
      'message': message,
      'user_id': user.id,
      'user_name': user.name ?? user.firstName ?? 'User',
      'attachments': <dynamic>[],
    });
    final r = await http.post(
      _uri(path),
      headers: _signedHeaders(
        method: 'POST',
        path: path,
        body: rawBody,
        includeContentType: true,
      ),
      body: rawBody,
    );
    final data = await _parse(r);
    return _TicketMessage.fromJson(
        Map<String, dynamic>.from(data['data']['message'] as Map));
  }

  Future<void> markMessagesRead({
    required String ticketIdOrNumber,
    List<String>? messageIds,
  }) async {
    final path = '/api/v1/support/tickets/$ticketIdOrNumber/messages/read';
    final rawBody = jsonEncode(<String, dynamic>{
      if (messageIds != null && messageIds.isNotEmpty)
        'message_ids': messageIds,
    });
    final r = await http.post(
      _uri(path),
      headers: _signedHeaders(
        method: 'POST',
        path: path,
        body: rawBody,
        includeContentType: true,
      ),
      body: rawBody,
    );
    await _parse(r);
  }
}

class TicketListScreen extends StatefulWidget {
  final SupportTicketsUser? userOverride;

  const TicketListScreen({super.key, this.userOverride});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

enum _SupportView { dashboard, create, details }

class _TicketListScreenState extends State<TicketListScreen> {
  _SupportApiClient? _api;
  SupportTicketsUser? _user;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<_Ticket> _allTickets = <_Ticket>[];
  List<_Ticket> _tickets = <_Ticket>[];
  List<_TicketMessage> _messages = <_TicketMessage>[];
  _SupportView _currentView = _SupportView.dashboard;
  _Ticket? _selectedTicket;
  String _selectedFilter = 'All';
  String _newCategory = 'General';
  String _newPriority = 'Normal priority';
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _refreshTimer;
  Timer? _ticketListRefreshTimer;
  bool _ticketListRefreshInFlight = false;
  bool _ticketUnreadRefreshInFlight = false;
  final Map<String, int> _ticketUnreadCounts = <String, int>{};
  final Map<String, List<_TicketMessage>> _ticketMessageCache =
      <String, List<_TicketMessage>>{};
  final Map<String, DateTime> _ticketLastSeenAgentAt = <String, DateTime>{};
  SupportTicketsConfig? _config;

  static const List<String> _filters = <String>[
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed',
  ];
  static const List<String> _categories = <String>[
    'General',
    'Technical',
    'Appointment',
    'Payment',
    'Other',
  ];
  static const List<String> _priorities = <String>[
    'Low priority',
    'Normal priority',
    'High priority',
  ];

  final Color healthGreen = const Color(0xFF10B981);
  final Color royalNavy = const Color(0xFF254063);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SupportTicketsScope.of(context);
    if (_api == null) {
      final config = scope?.config;
      _config = config;
      _api = _SupportApiClient(
        config?.apiBaseUrl ?? '',
        appId: config?.appId,
        signingSecret: config?.signingSecret,
        erpToken: config?.erpToken,
      );
      _user = widget.userOverride ?? config?.resolveUser?.call(context);
      final cachedTickets = config == null || _user == null
          ? null
          : SupportTicketsPreloader._cachedTickets(
              config: config,
              user: _user!,
            );
      if (cachedTickets != null) {
        _allTickets = cachedTickets;
        _tickets = _filteredTicketsForCurrentStatus();
        _ticketUnreadCounts
          ..clear()
          ..addEntries(cachedTickets.map(
            (ticket) => MapEntry(_ticketKey(ticket), ticket.unreadMessageCount),
          ));
        _loading = false;
        unawaited(_refreshTicketUnreadCounts(_tickets));
        unawaited(_loadTickets(silent: true));
      } else {
        _loadTickets();
      }
      _startTicketListPolling();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ticketListRefreshTimer?.cancel();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    _messageCtrl.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _startTicketListPolling() {
    _ticketListRefreshTimer?.cancel();
    _ticketListRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _currentView != _SupportView.dashboard) return;
      _loadTickets(silent: true);
    });
  }

  String _ticketKey(_Ticket t) =>
      t.ticketNumber.trim().isNotEmpty ? t.ticketNumber.trim() : t.id.trim();

  void _markTicketSeen(_Ticket ticket, List<_TicketMessage> messages) {
    final key = _ticketKey(ticket);
    DateTime? latestAgentAt = _ticketLastSeenAgentAt[key];
    for (final message in messages) {
      if (message.senderType != 'agent' || message.createdAt == null) continue;
      if (latestAgentAt == null || message.createdAt!.isAfter(latestAgentAt)) {
        latestAgentAt = message.createdAt;
      }
    }
    if (latestAgentAt != null) {
      _ticketLastSeenAgentAt[key] = latestAgentAt;
    }
    _ticketUnreadCounts[key] = 0;
  }

  Future<void> _refreshTicketUnreadCounts(List<_Ticket> tickets) async {
    if (_ticketUnreadRefreshInFlight ||
        _currentView != _SupportView.dashboard) {
      return;
    }
    final client = _api;
    if (client == null || tickets.isEmpty) return;

    _ticketUnreadRefreshInFlight = true;
    final nextCounts = <String, int>{};
    try {
      final counts = await Future.wait(tickets.map((ticket) async {
        final key = _ticketKey(ticket);
        final statusUi = _statusToUi(ticket.status);
        if (_isClosedTicketStatus(ticket.status) ||
            _isClosedTicketStatus(statusUi)) {
          return MapEntry<String, int>(key, 0);
        }
        final messages =
            await client.fetchMessages(ticketIdOrNumber: ticket.ticketNumber);
        _ticketMessageCache[key] = messages;
        DateTime? latestUserReplyAt;
        for (final message in messages) {
          if (message.senderType == 'agent' || message.createdAt == null) {
            continue;
          }
          if (latestUserReplyAt == null ||
              message.createdAt!.isAfter(latestUserReplyAt)) {
            latestUserReplyAt = message.createdAt;
          }
        }
        final lastSeenAgentAt = _ticketLastSeenAgentAt[key];
        DateTime? unreadAfter = latestUserReplyAt;
        if (lastSeenAgentAt != null &&
            (unreadAfter == null || lastSeenAgentAt.isAfter(unreadAfter))) {
          unreadAfter = lastSeenAgentAt;
        }
        var unseenAgentCount = 0;
        for (final message in messages) {
          if (message.senderType != 'agent') continue;
          final createdAt = message.createdAt;
          if (unreadAfter == null ||
              (createdAt != null && createdAt.isAfter(unreadAfter))) {
            unseenAgentCount += 1;
          }
        }
        final backendCount = ticket.unreadMessageCount;
        return MapEntry<String, int>(
          key,
          unseenAgentCount > backendCount ? unseenAgentCount : backendCount,
        );
      }));
      nextCounts.addEntries(counts);
      if (!mounted || nextCounts.isEmpty) return;
      setState(() => _ticketUnreadCounts.addAll(nextCounts));
    } catch (e) {
      debugPrint('Support ticket unread refresh unavailable: $e');
    } finally {
      _ticketUnreadRefreshInFlight = false;
    }
  }

  String _statusToUi(String api) {
    switch (api.toLowerCase().trim()) {
      case 'open':
        return 'Open';
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return api;
    }
  }

  bool _ticketMatchesFilter(_Ticket ticket) {
    final currentUserId = (_user?.id ?? '').trim();
    final ticketUserId = ticket.userId.trim();
    if (currentUserId.isNotEmpty &&
        ticketUserId.isNotEmpty &&
        ticketUserId != currentUserId) {
      return false;
    }
    if (_selectedFilter == 'All') return true;
    return _statusToUi(ticket.status) == _selectedFilter;
  }

  List<_Ticket> _filteredTicketsForCurrentStatus() {
    return _allTickets.where(_ticketMatchesFilter).toList();
  }

  bool _isClosedTicketStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'closed' || normalized == 'resolved';
  }

  String _priorityToApi(String ui) {
    switch (ui) {
      case 'Low priority':
        return 'low';
      case 'High priority':
        return 'high';
      default:
        return 'medium';
    }
  }

  String _priorityToUi(String api) {
    switch (api.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'high':
        return 'High';
      default:
        return 'Normal';
    }
  }

  String _monthShort(int month) {
    const names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  ({Color bg, Color text}) _priorityTagStyle(String priorityUi) {
    switch (priorityUi) {
      case 'High':
        return (bg: const Color(0xFFFEE2E2), text: const Color(0xFFDC2626));
      case 'Low':
        return (bg: const Color(0xFF79F694), text: const Color(0xFF333333));
      default:
        return (bg: const Color(0xFFEDB678), text: const Color(0xFF333333));
    }
  }

  Color _priorityTextColor(String priorityUi) {
    if (priorityUi == 'High') return const Color(0xFFDC2626);
    return const Color(0xFF333333);
  }

  ({Color bg, Color text}) _statusTagStyle(String statusUi) {
    switch (statusUi) {
      case 'Resolved':
        return (bg: const Color(0xFFDCFCE7), text: const Color(0xFF166534));
      case 'Closed':
        return (bg: const Color(0xFFE53935), text: Colors.white);
      case 'In Progress':
        return (bg: const Color(0xFFEDB678), text: const Color(0xFF333333));
      case 'Open':
        return (bg: const Color(0xFF79F694), text: const Color(0xFF333333));
      default:
        return (bg: const Color(0xFFE5E7EB), text: const Color(0xFFFF9800));
    }
  }

  Future<void> _loadTickets({bool silent = false}) async {
    if (_ticketListRefreshInFlight) return;
    final u = _user;
    final hasId = (u?.id ?? '').trim().isNotEmpty;
    if (u == null || !hasId) {
      setState(() {
        _loading = false;
        _error = 'Please login first to use support tickets.';
      });
      return;
    }
    try {
      _ticketListRefreshInFlight = true;
      if (!silent && _tickets.isEmpty) {
        setState(() => _loading = true);
      }
      final client = _api;
      if (client == null) return;
      final tickets = await client.fetchTickets(
        userId: u.id,
        userEmail: u.email,
        userPhone: u.phone,
      );
      if (!mounted) return;
      _allTickets = tickets;
      final filteredTickets = _filteredTicketsForCurrentStatus();
      _ticketUnreadCounts
        ..clear()
        ..addEntries(tickets.map(
          (ticket) => MapEntry(_ticketKey(ticket), ticket.unreadMessageCount),
        ));
      setState(() {
        _tickets = filteredTickets;
        _loading = false;
        _error = null;
      });
      final config = _config;
      if (config != null) {
        SupportTicketsPreloader._storeTickets(
          config: config,
          user: u,
          tickets: tickets,
        );
      }
      unawaited(_refreshTicketUnreadCounts(filteredTickets));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _allTickets = <_Ticket>[];
          _tickets = <_Ticket>[];
        }
        _loading = false;
        _error = null;
      });
      if (!silent) debugPrint('Support ticket list unavailable: $e');
    } finally {
      _ticketListRefreshInFlight = false;
    }
  }

  Future<void> _submitTicket() async {
    if (_user == null) return;
    final subject = _subjectCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill subject and description')),
      );
      return;
    }
    try {
      final client = _api;
      if (client == null) return;
      final t = await client.createTicket(
        user: _user!,
        subject: subject,
        description: description,
        category: _newCategory,
        priority: _priorityToApi(_newPriority),
      );
      if (!mounted) return;
      _subjectCtrl.clear();
      _descriptionCtrl.clear();
      setState(() {
        _allTickets = <_Ticket>[t, ..._allTickets];
        _tickets = _filteredTicketsForCurrentStatus();
        _currentView = _SupportView.dashboard;
      });
      _startTicketListPolling();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(e);
    }
  }

  void _showErrorSnack(Object e) => showSupportApiErrorSnack(context, e);

  Future<void> _openDetails(_Ticket t) async {
    _refreshTimer?.cancel();
    _ticketListRefreshTimer?.cancel();
    final cachedMessages = _ticketMessageCache[_ticketKey(t)];
    setState(() {
      _selectedTicket = t;
      _currentView = _SupportView.details;
      _loading = cachedMessages == null;
      _messages = cachedMessages ?? <_TicketMessage>[];
      _ticketUnreadCounts[_ticketKey(t)] = 0;
    });
    if (cachedMessages != null) {
      _markTicketSeen(t, cachedMessages);
      _scrollMessagesToBottom();
      unawaited(
        _loadMessages(markRead: true, silent: true, scrollToBottom: true),
      );
    } else {
      await _loadMessages(markRead: true, scrollToBottom: true);
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages(
      {bool markRead = false,
      bool silent = false,
      bool scrollToBottom = false}) async {
    final t = _selectedTicket;
    if (t == null) return;
    if (!silent) setState(() => _loading = true);
    try {
      final client = _api;
      if (client == null) return;
      final out = await client.fetchMessages(ticketIdOrNumber: t.ticketNumber);
      _ticketMessageCache[_ticketKey(t)] = out;
      if (markRead) {
        _markTicketSeen(t, out);
        final ids = out
            .where((m) => m.senderType == 'agent')
            .map((m) => m.id)
            .where((id) => id.isNotEmpty)
            .toList();
        if (ids.isNotEmpty) {
          try {
            await client.markMessagesRead(
                ticketIdOrNumber: t.ticketNumber, messageIds: ids);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _messages = out;
        _loading = false;
      });
      if (scrollToBottom) {
        _scrollMessagesToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) _showErrorSnack(e);
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _sendMessage() async {
    final t = _selectedTicket;
    if (t == null || _user == null) return;
    if (_isClosedTicketStatus(t.status)) return;
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = _api;
      if (client == null) return;
      final msg = await client.sendUserMessage(
        ticketIdOrNumber: t.ticketNumber,
        user: _user!,
        message: text,
      );
      if (!mounted) return;
      _messageCtrl.clear();
      setState(() {
        _messages = <_TicketMessage>[..._messages, msg];
        _ticketMessageCache[_ticketKey(t)] = _messages;
        _sending = false;
      });
      _scrollMessagesToBottom();
      await _loadMessages(markRead: true, silent: true);
      await _loadTickets();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showErrorSnack(e);
    }
  }

  PreferredSizeWidget _buildAppBar() {
    String title = 'Support Tickets';
    if (_currentView == _SupportView.create) title = 'Raise a Ticket';
    if (_currentView == _SupportView.details) {
      title = _selectedTicket?.subject ?? 'Ticket';
    }

    if (_currentView == _SupportView.details) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF254063),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () async {
                    _refreshTimer?.cancel();
                    setState(() {
                      _currentView = _SupportView.dashboard;
                      _selectedTicket = null;
                    });
                    await _loadTickets();
                    _startTicketListPolling();
                  },
                ),
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support Agent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: Color(0xFF34D399),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Online',
                            style: TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(98),
      child: Container(
        padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF254063),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () async {
                  if (_currentView == _SupportView.dashboard) {
                    Navigator.of(context).pop();
                    return;
                  }
                  _refreshTimer?.cancel();
                  setState(() {
                    _currentView = _SupportView.dashboard;
                    _selectedTicket = null;
                  });
                  await _loadTickets();
                  _startTicketListPolling();
                },
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              if (_selectedFilter == filter) return;
              setState(() {
                _selectedFilter = filter;
                _tickets = _filteredTicketsForCurrentStatus();
              });
              unawaited(_refreshTicketUnreadCounts(_tickets));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? healthGreen : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: <Widget>[
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTickets,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: <Widget>[
                const SizedBox(height: 6),
                if (_loading && _tickets.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_tickets.isEmpty)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Text(
                      _error ?? 'No tickets found',
                      textAlign: TextAlign.center,
                    ),
                  ))
                else
                  ..._tickets.map((t) {
                    final statusUi = _statusToUi(t.status);
                    final statusTag = _statusTagStyle(statusUi);
                    final notificationsDisabled =
                        _isClosedTicketStatus(t.status) ||
                            _isClosedTicketStatus(statusUi);
                    final unreadCount = notificationsDisabled
                        ? 0
                        : _ticketUnreadCounts[_ticketKey(t)] ?? 0;
                    final hasUnread = unreadCount > 0;
                    final badgeText =
                        unreadCount > 99 ? '99+' : unreadCount.toString();
                    final dateText = t.createdAt == null
                        ? ''
                        : '${_monthShort(t.createdAt!.month)} ${t.createdAt!.day.toString().padLeft(2, '0')}, ${t.createdAt!.year}';
                    return GestureDetector(
                      onTap: () => _openDetails(t),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusTag.bg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusUi.toUpperCase(),
                                        style: TextStyle(
                                          color: statusTag.text,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      dateText,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(t.subject,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 31 / 2,
                                        color: Color(0xFF1E293B))),
                                const SizedBox(height: 4),
                                Text(t.category ?? 'General',
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const Divider(
                                    height: 24, color: Color(0xFFE2E8F0)),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 14,
                                      color: _priorityTextColor(
                                          _priorityToUi(t.priority)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_priorityToUi(t.priority)} Priority',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _priorityTextColor(
                                            _priorityToUi(t.priority)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'View Discussion',
                                      style: TextStyle(
                                        color: healthGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: healthGreen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (hasUnread)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: healthGreen,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            healthGreen.withValues(alpha: 0.35),
                                        offset: const Offset(0, 3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Support Category',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final sel = _newCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _newCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? healthGreen : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  sel ? healthGreen : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF64748B))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _subjectCtrl,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Subject',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _descriptionCtrl,
                    minLines: 4,
                    maxLines: 6,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Description',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: _priorities.map((p) {
                    final sel = _newPriority == p;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _newPriority = p),
                        child: Container(
                          margin: EdgeInsets.only(right: p == 'Urgent' ? 0 : 8),
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel
                                ? healthGreen.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sel
                                    ? healthGreen
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(p),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitTicket,
              style: ElevatedButton.styleFrom(backgroundColor: healthGreen),
              child: const Text('Submit Ticket',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    final t = _selectedTicket;
    if (t == null) return const SizedBox.shrink();
    final statusUi = _statusToUi(t.status);
    final priorityUi = _priorityToUi(t.priority);
    final repliesDisabled =
        _isClosedTicketStatus(t.status) || _isClosedTicketStatus(statusUi);
    final categoryText = (t.category == null || t.category!.trim().isEmpty)
        ? 'General'
        : t.category!;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                bottom:
                    BorderSide(color: Colors.black.withValues(alpha: 0.05))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoryText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.62,
                        child: Text(
                          t.subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priorityUi.toUpperCase() == 'LOW'
                          ? 'OPEN'
                          : statusUi.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t.description.isEmpty ? '-' : t.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadMessages(),
                  child: ListView.builder(
                    controller: _messagesScrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isUser = m.senderType != 'agent';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    healthGreen.withValues(alpha: 0.1),
                                child: const Icon(Icons.support_agent,
                                    color: Color(0xFF10B981), size: 16),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.75),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? const Color(0xFF0F172A)
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft:
                                            Radius.circular(isUser ? 20 : 0),
                                        bottomRight:
                                            Radius.circular(isUser ? 0 : 20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      m.message,
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTime(m.createdAt),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUser) const SizedBox(width: 12),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: _messageCtrl,
                    enabled: !repliesDisabled,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: repliesDisabled
                          ? 'Ticket is closed'
                          : 'Type your message...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: repliesDisabled ? null : (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: repliesDisabled || _sending ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        repliesDisabled ? const Color(0xFFCBD5E1) : healthGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (repliesDisabled
                                ? const Color(0xFF94A3B8)
                                : healthGreen)
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_currentView) {
      _SupportView.dashboard => _buildDashboard(),
      _SupportView.create => _buildCreateForm(),
      _SupportView.details => _buildDetails(),
    };
    return PopScope(
      canPop: _currentView == _SupportView.dashboard,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _currentView == _SupportView.dashboard) return;
        _refreshTimer?.cancel();
        setState(() {
          _currentView = _SupportView.dashboard;
          _selectedTicket = null;
        });
        await _loadTickets();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: body,
        floatingActionButton: _currentView == _SupportView.dashboard
            ? FloatingActionButton.extended(
                onPressed: () =>
                    setState(() => _currentView = _SupportView.create),
                backgroundColor: healthGreen,
                icon:
                    const Icon(Icons.add_comment_rounded, color: Colors.white),
                label: const Text('New Ticket',
                    style: TextStyle(color: Colors.white)),
              )
            : null,
      ),
    );
  }
}

class _TicketChatScreen extends StatefulWidget {
  final _SupportApiClient api;
  final SupportTicketsUser user;
  final _Ticket ticket;

  const _TicketChatScreen({
    required this.api,
    required this.user,
    required this.ticket,
  });

  @override
  State<_TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<_TicketChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  List<_TicketMessage> _messages = <_TicketMessage>[];
  Timer? _refreshTimer;
  static const Duration _refreshEvery = Duration(seconds: 5);
  static const Color healthGreen = Color(0xFF10B981);

  String _statusToUi(String api) {
    final s = api.toLowerCase().trim();
    if (s == 'open') return 'In Progress';
    if (s == 'closed') return 'Resolved';
    if (s == 'pending') return 'Waiting';
    return api.isEmpty ? 'Unknown' : api;
  }

  bool _isClosedTicketStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'closed' || normalized == 'resolved';
  }

  ({Color bg, Color text}) _statusTagStyle(String statusUi) {
    switch (statusUi.toLowerCase()) {
      case 'resolved':
        return (bg: const Color(0xFFDCFCE7), text: const Color(0xFF166534));
      case 'waiting':
        return (bg: const Color(0xFFFFEDD5), text: const Color(0xFF9A3412));
      case 'in progress':
        return (bg: const Color(0xFFDBEAFE), text: const Color(0xFF1E40AF));
      default:
        return (bg: const Color(0xFFE2E8F0), text: const Color(0xFF334155));
    }
  }

  String _monthShort(int month) {
    const names = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (month < 1 || month > 12) return '---';
    return names[month];
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h24 = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m $ampm';
  }

  String _priorityToUi(String api) {
    final s = api.toLowerCase().trim();
    if (s == 'low') return 'Low';
    if (s == 'medium') return 'Medium';
    if (s == 'high') return 'High';
    if (s == 'urgent') return 'Urgent';
    return api.isEmpty ? 'Normal' : api;
  }

  ({Color bg, Color text}) _priorityTagStyle(String priorityUi) {
    switch (priorityUi.toLowerCase()) {
      case 'low':
        return (bg: const Color(0xFFDCFCE7), text: const Color(0xFF166534));
      case 'medium':
        return (bg: const Color(0xFFFEF3C7), text: const Color(0xFF92400E));
      case 'high':
        return (bg: const Color(0xFFFEE2E2), text: const Color(0xFF991B1B));
      case 'urgent':
        return (bg: const Color(0xFFFFE4E6), text: const Color(0xFFBE123C));
      default:
        return (bg: const Color(0xFFE2E8F0), text: const Color(0xFF334155));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages(scrollToBottom: true);
    _refreshTimer = Timer.periodic(_refreshEvery, (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markReadForAgentMessages(List<_TicketMessage> messages) async {
    final ids = messages
        .where((m) => m.senderType == 'agent')
        .map((m) => m.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;
    try {
      await widget.api.markMessagesRead(
        ticketIdOrNumber: widget.ticket.ticketNumber,
        messageIds: ids,
      );
    } catch (_) {
      // Best-effort: read state sync should never block chat rendering.
    }
  }

  Future<void> _loadMessages(
      {bool markRead = false,
      bool silent = false,
      bool scrollToBottom = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final out = await widget.api
          .fetchMessages(ticketIdOrNumber: widget.ticket.ticketNumber);
      if (markRead) {
        await _markReadForAgentMessages(out);
      }
      if (!mounted) return;
      setState(() {
        _messages = out;
        _loading = false;
      });
      if (scrollToBottom) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) showSupportApiErrorSnack(context, e);
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    if (_isClosedTicketStatus(widget.ticket.status)) return;
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await widget.api.sendUserMessage(
        ticketIdOrNumber: widget.ticket.ticketNumber,
        user: widget.user,
        message: text,
      );
      if (!mounted) return;
      _messageCtrl.clear();
      setState(() {
        _messages = <_TicketMessage>[..._messages, m];
        _sending = false;
      });
      _scrollToBottom(animated: true);
      await _loadMessages(markRead: true, silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSupportApiErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusUi = _statusToUi(widget.ticket.status);
    final priorityUi = _priorityToUi(widget.ticket.priority);
    final repliesDisabled = _isClosedTicketStatus(widget.ticket.status) ||
        _isClosedTicketStatus(statusUi);
    final dateText = widget.ticket.createdAt == null
        ? '-'
        : '${_monthShort(widget.ticket.createdAt!.month)} ${widget.ticket.createdAt!.day.toString().padLeft(2, '0')}, ${widget.ticket.createdAt!.year}';
    final categoryText = (widget.ticket.category == null ||
            widget.ticket.category!.trim().isEmpty)
        ? 'General'
        : widget.ticket.category!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: healthGreen.withValues(alpha: 0.1),
              child: const Icon(Icons.support_agent_rounded,
                  color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support Agent',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom:
                      BorderSide(color: Colors.black.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TICKET ${widget.ticket.ticketNumber.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryText,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.62,
                          child: Text(
                            widget.ticket.subject.isEmpty
                                ? 'Ticket Details'
                                : widget.ticket.subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusUi.toUpperCase() == 'IN PROGRESS'
                            ? 'OPEN'
                            : statusUi.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.ticket.description.isEmpty
                      ? '-'
                      : widget.ticket.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadMessages(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        final isUser = m.senderType != 'agent';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isUser) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      healthGreen.withValues(alpha: 0.1),
                                  child: const Icon(Icons.support_agent,
                                      color: Color(0xFF10B981), size: 16),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft:
                                              Radius.circular(isUser ? 20 : 0),
                                          bottomRight:
                                              Radius.circular(isUser ? 0 : 20),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        m.message,
                                        style: TextStyle(
                                          color: isUser
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(m.createdAt),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isUser) const SizedBox(width: 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _messageCtrl,
                        enabled: !repliesDisabled,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: repliesDisabled
                              ? 'Ticket is closed'
                              : 'Type your message...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                        onSubmitted: repliesDisabled ? null : (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: repliesDisabled || _sending ? null : _send,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: repliesDisabled
                            ? const Color(0xFFCBD5E1)
                            : healthGreen,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (repliesDisabled
                                    ? const Color(0xFF94A3B8)
                                    : healthGreen)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
