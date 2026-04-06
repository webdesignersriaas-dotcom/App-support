class TicketMessage {
  final String id;
  final String ticketId;
  final MessageSenderType senderType;
  final String? senderId;
  final String senderName;
  final String message;
  final List<TicketAttachment> attachments;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    this.senderId,
    required this.senderName,
    required this.message,
    this.attachments = const [],
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    List<TicketAttachment> attachmentsList = [];
    if (json['attachments'] != null) {
      if (json['attachments'] is List) {
        attachmentsList = (json['attachments'] as List)
            .map((item) => TicketAttachment.fromJson(item))
            .toList();
      }
    }

    return TicketMessage(
      id: json['id'] ?? '',
      ticketId: json['ticket_id'] ?? json['ticketId'] ?? '',
      senderType: MessageSenderType.fromString(
          json['sender_type'] ?? json['senderType'] ?? 'user'),
      senderId: json['sender_id'] ?? json['senderId'],
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      message: json['message'] ?? '',
      attachments: attachmentsList,
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at']).toLocal()
          : json['readAt'] != null
              ? DateTime.parse(json['readAt']).toLocal()
              : null,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'sender_type': senderType.value,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TicketMessage copyWith({
    String? id,
    String? ticketId,
    MessageSenderType? senderType,
    String? senderId,
    String? senderName,
    String? message,
    List<TicketAttachment>? attachments,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketMessage(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum MessageSenderType {
  user('user'),
  agent('agent');

  final String value;
  const MessageSenderType(this.value);

  static MessageSenderType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'agent':
        return MessageSenderType.agent;
      default:
        return MessageSenderType.user;
    }
  }
}

class TicketAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;

  TicketAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
  });

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      id: json['id'] ?? '',
      fileName: json['file_name'] ?? json['fileName'] ?? '',
      fileUrl: json['file_url'] ?? json['fileUrl'] ?? '',
      fileType: json['file_type'] ?? json['fileType'],
      fileSize: json['file_size'] ?? json['fileSize'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
    };
  }
}
