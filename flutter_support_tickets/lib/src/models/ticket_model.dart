import 'package:flutter/material.dart';

class SupportTicket {
  final String id;
  final String ticketNumber;
  final String? userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String subject;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final Map<String, dynamic>? metadata;
  final int? unreadMessageCount;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedToName,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    this.metadata,
    this.unreadMessageCount,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? '',
      ticketNumber: json['ticket_number'] ?? json['ticketNumber'] ?? '',
      userId: json['user_id'] ?? json['userId'],
      userName: json['user_name'] ?? json['userName'] ?? '',
      userEmail: json['user_email'] ?? json['userEmail'] ?? '',
      userPhone: json['user_phone'] ?? json['userPhone'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: TicketStatus.fromString(json['status'] ?? 'open'),
      priority: TicketPriority.fromString(json['priority'] ?? 'medium'),
      assignedTo: json['assigned_to'] ?? json['assignedTo'],
      assignedToName: json['assigned_to_name'] ?? json['assignedToName'],
      category: json['category'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt']).toLocal()
              : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt']).toLocal()
              : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at']).toLocal()
          : json['resolvedAt'] != null
              ? DateTime.parse(json['resolvedAt']).toLocal()
              : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at']).toLocal()
          : json['closedAt'] != null
              ? DateTime.parse(json['closedAt']).toLocal()
              : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      unreadMessageCount: json['unread_message_count'] ?? json['unreadMessageCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_phone': userPhone,
      'subject': subject,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? ticketNumber,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? subject,
    String? description,
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    String? assignedToName,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    Map<String, dynamic>? metadata,
    int? unreadMessageCount,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
      metadata: metadata ?? this.metadata,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
    );
  }
}

enum TicketStatus {
  open('open'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed');

  final String value;
  const TicketStatus(this.value);

  static TicketStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in-progress':
        return TicketStatus.inProgress;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }

  Color getColor() {
    switch (this) {
      case TicketStatus.open:
        return Colors.blue;
      case TicketStatus.inProgress:
        return Colors.orange;
      case TicketStatus.resolved:
        return Colors.green;
      case TicketStatus.closed:
        return Colors.grey;
    }
  }

  String getDisplayText() {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }
}

enum TicketPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  final String value;
  const TicketPriority(this.value);

  static TicketPriority fromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return TicketPriority.urgent;
      case 'high':
        return TicketPriority.high;
      case 'low':
        return TicketPriority.low;
      default:
        return TicketPriority.medium;
    }
  }

  Color getColor() {
    switch (this) {
      case TicketPriority.low:
        return Colors.grey;
      case TicketPriority.medium:
        return Colors.blue;
      case TicketPriority.high:
        return Colors.orange;
      case TicketPriority.urgent:
        return Colors.red;
    }
  }

  String getDisplayText() {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.urgent:
        return 'Urgent';
    }
  }
}
