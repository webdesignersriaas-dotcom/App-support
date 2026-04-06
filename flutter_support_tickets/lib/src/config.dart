import 'package:flutter/material.dart';

/// End-user identity for ticket APIs. Map this from your auth layer.
class SupportTicketsUser {
  const SupportTicketsUser({
    required this.id,
    this.name,
    this.firstName,
    this.email,
    this.phone,
    this.picture,
    this.userUrl,
  });

  final String id;
  final String? name;
  final String? firstName;
  final String? email;
  final String? phone;
  final String? picture;
  final String? userUrl;

  String greetingName() {
    if (firstName != null && firstName!.trim().isNotEmpty) {
      return firstName!.trim();
    }
    if (name != null && name!.trim().isNotEmpty) {
      final parts = name!.trim().split(RegExp(r'\s+'));
      return parts.first;
    }
    return 'there';
  }
}

/// API and UX configuration for the support ticket module.
class SupportTicketsConfig {
  const SupportTicketsConfig({
    required this.apiBaseUrl,
    required this.defaultAvatarUrlOrAsset,
    required this.resolveUser,
    this.ticketCreatedWebhookUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  /// Base URL only (e.g. `https://api.example.com`). No trailing slash required.
  final String apiBaseUrl;

  /// Shown when the user has no profile image. Can be `https://...` or `assets/...`.
  final String defaultAvatarUrlOrAsset;

  /// Return the logged-in user, or `null` if not signed in.
  final SupportTicketsUser? Function(BuildContext context) resolveUser;

  /// Optional: POST JSON `{ ticket_number, category }` after a ticket is created.
  final String? ticketCreatedWebhookUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  String get normalizedBaseUrl {
    var u = apiBaseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

/// Place [SupportTicketsScope] above [MaterialApp] (or around the subtree that
/// navigates to ticket screens) so screens can resolve [SupportTicketsConfig].
class SupportTicketsScope extends InheritedWidget {
  const SupportTicketsScope({
    super.key,
    required this.config,
    required super.child,
  });

  final SupportTicketsConfig config;

  static SupportTicketsConfig of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SupportTicketsScope>();
    assert(scope != null, 'SupportTicketsScope not found in widget tree');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(SupportTicketsScope oldWidget) {
    return !identical(oldWidget.config, config);
  }
}
