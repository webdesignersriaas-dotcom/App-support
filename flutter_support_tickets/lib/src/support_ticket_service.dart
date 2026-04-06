import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'config.dart';
import 'models/ticket_message_model.dart';
import 'models/ticket_model.dart';

/// HTTP client for the support ticket REST API.
class SupportTicketService {
  SupportTicketService(this._config) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _config.normalizedBaseUrl,
        connectTimeout: _config.connectTimeout,
        receiveTimeout: _config.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );
  }

  final SupportTicketsConfig _config;
  late final Dio _dio;

  Future<SupportTicket> createTicket({
    required String userName,
    required String userEmail,
    required String userPhone,
    required String subject,
    required String description,
    String? userId,
    String? category,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/support/tickets',
        data: {
          'user_name': userName,
          'user_email': userEmail,
          'user_phone': userPhone,
          'subject': subject,
          'description': description,
          'user_id': userId,
          'category': category,
          'priority': priority.value,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final ticket = SupportTicket.fromJson(data['data']['ticket']);

          final webhook = _config.ticketCreatedWebhookUrl;
          if (webhook != null && webhook.isNotEmpty) {
            Future.delayed(const Duration(seconds: 3), () {
              _sendWebhook(webhook, ticket.ticketNumber, ticket.category);
            });
          }

          return ticket;
        }
        throw Exception('Failed to create ticket: ${data['message'] ?? 'Unknown error'}');
      }
      throw Exception('Failed to create ticket: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      rethrow;
    }
  }

  Future<List<SupportTicket>> getUserTickets({
    String? userId,
    TicketStatus? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (userId != null) {
        queryParams['user_id'] = userId;
      }
      if (status != null) {
        queryParams['status'] = status.value;
      }

      final response = await _dio.get(
        '/api/v1/support/tickets',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final tickets = data['data']['tickets'] as List;
          return tickets.map((t) => SupportTicket.fromJson(t)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getTicketDetails(String ticketId) async {
    try {
      final response = await _dio.get('/api/v1/support/tickets/$ticketId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return {
            'ticket': SupportTicket.fromJson(data['data']['ticket']),
            'messages': (data['data']['messages'] as List)
                .map((m) => TicketMessage.fromJson(m))
                .toList(),
          };
        }
      }
      throw Exception('Failed to fetch ticket details');
    } catch (e) {
      debugPrint('Error fetching ticket details: $e');
      rethrow;
    }
  }

  Future<TicketMessage> sendMessage({
    required String ticketId,
    required String message,
    List<String>? attachmentUrls,
    String? userId,
    String? userName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/support/tickets/$ticketId/messages',
        data: {
          'message': message,
          'attachments': attachmentUrls ?? [],
          'user_id': userId,
          'user_name': userName,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return TicketMessage.fromJson(data['data']['message']);
        }
        throw Exception('Failed to send message: ${data['message'] ?? 'Unknown error'}');
      }
      throw Exception('Failed to send message: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<List<TicketMessage>> getTicketMessages({
    required String ticketId,
    int page = 1,
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }

      final response = await _dio.get(
        '/api/v1/support/tickets/$ticketId/messages',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final messages = data['data']['messages'] as List;
          return messages.map((m) => TicketMessage.fromJson(m)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  Future<SupportTicket> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/v1/support/tickets/$ticketId',
        data: {
          'status': status.value,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return SupportTicket.fromJson(data['data']['ticket']);
        }
        throw Exception('Failed to update ticket: ${data['message'] ?? 'Unknown error'}');
      }
      throw Exception('Failed to update ticket: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error updating ticket: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead({
    required String ticketId,
    List<String>? messageIds,
  }) async {
    try {
      await _dio.post(
        '/api/v1/support/tickets/$ticketId/messages/read',
        data: {
          'message_ids': messageIds,
        },
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendWebhook(
    String webhookUrl,
    String ticketNumber,
    String? category,
  ) async {
    try {
      final webhookDio = Dio();
      await webhookDio.post(
        webhookUrl,
        data: {
          'ticket_number': ticketNumber,
          'category': category ?? '',
        },
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      debugPrint('✅ Webhook triggered for ticket: $ticketNumber');
    } catch (e) {
      debugPrint('⚠️ Webhook error for ticket $ticketNumber: $e');
    }
  }
}
