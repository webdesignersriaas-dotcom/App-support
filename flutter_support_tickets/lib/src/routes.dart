import 'package:flutter/material.dart';

import 'screens/create_ticket_screen.dart';
import 'screens/ticket_list_screen.dart';

/// Route names aligned with typical GoRouter / Navigator usage.
class SupportTicketsPaths {
  SupportTicketsPaths._();

  static const String list = 'support-tickets';
  static const String create = 'create-ticket';
}

/// Register with your app: `routes: { ...supportTicketsRouteMap(), ... }`
Map<String, WidgetBuilder> supportTicketsRouteMap() {
  return {
    SupportTicketsPaths.list: (_) => const TicketListScreen(),
    SupportTicketsPaths.create: (_) => const CreateTicketScreen(),
  };
}
