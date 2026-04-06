import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/ticket_model.dart';
import '../support_ticket_service.dart';
import '../widgets/network_or_asset_image.dart';
import 'create_ticket_screen.dart';
import 'ticket_chat_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  SupportTicketService? _ticketService;
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  TicketStatus? _selectedFilter;
  bool _initialLoadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticketService = SupportTicketService(SupportTicketsScope.of(context));
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      _loadTickets();
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupportTicketsScope.of(context).resolveUser(context);

      if (user == null || user.id.isEmpty) {
        if (mounted) {
          setState(() {
            _tickets = [];
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint('🔒 Loading tickets for user_id: ${user.id}');

      final tickets = await _ticketService!.getUserTickets(
        userId: user.id,
        status: _selectedFilter,
      );

      final invalidTickets = tickets.where((t) {
        if (t.userId == user.id) return false;
        if (t.metadata != null && t.metadata!['original_user_id'] == user.id) {
          return false;
        }
        return true;
      }).toList();

      if (invalidTickets.isNotEmpty) {
        debugPrint(
            '❌ Found ${invalidTickets.length} tickets not belonging to user!');
        final validTickets =
            tickets.where((t) => !invalidTickets.contains(t)).toList();
        if (mounted) {
          setState(() {
            _tickets = validTickets;
            _isLoading = false;
          });
        }
        BotToast.showText(
            text: 'Security error: Some tickets were filtered out');
        return;
      }

      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final errorMessage = e.toString().contains('401') ||
                e.toString().contains('Authentication')
            ? 'Please log in to view your tickets'
            : 'Failed to load tickets: ${e.toString()}';
        BotToast.showText(text: errorMessage);
      }
    }
  }

  String _displayFirstName(SupportTicketsUser? user) {
    if (user == null) return 'there';
    final n = user.greetingName();
    if (n.isEmpty) return 'there';
    if (n.length > 1) {
      return '${n[0].toUpperCase()}${n.substring(1)}';
    }
    return n.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = SupportTicketsScope.of(context).resolveUser(context);
    final userName = _displayFirstName(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Support Tickets',
          style: TextStyle(
            color: Color(0xFF1A1F36),
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFF8F9FB),
        foregroundColor: const Color(0xFF1A1F36),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
        actions: [
          PopupMenuButton<TicketStatus?>(
            icon: const Icon(Icons.filter_list, color: Color(0xFF6B7280)),
            color: Colors.white,
            onSelected: (status) {
              setState(() {
                _selectedFilter = status;
              });
              _loadTickets();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Tickets'),
              ),
              ...TicketStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: status.getColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.getDisplayText()),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTickets,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildProfessionalHeader(userName),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTicketCard(_tickets[index]),
                              );
                            },
                            childCount: _tickets.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
              builder: (context) => const CreateTicketScreen(),
            ),
          )
              .then((_) {
            _loadTickets();
          });
        },
        backgroundColor: const Color(0xFF1A1F36),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New Ticket',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader(String userName) {
    final user = SupportTicketsScope.of(context).resolveUser(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final config = SupportTicketsScope.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF0DB),
            const Color(0xFFFFF0DB).withOpacity(0.95),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF0DB),
                const Color(0xFFFFF0DB).withOpacity(0.95),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              const Color(0xFFF0F2F5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: _UserAvatarWithTimeout(
                          imageUrl: user?.picture?.isNotEmpty == true
                              ? user!.picture!
                              : (user?.userUrl?.isNotEmpty == true
                                  ? user!.userUrl!
                                  : null),
                          placeholderUrl: config.defaultAvatarUrlOrAsset,
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName.isNotEmpty ? userName : 'there',
                            style: const TextStyle(
                              color: Color(0xFF1A1F36),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _tickets.isEmpty
                              ? 'Create a ticket to get support'
                              : '${_tickets.length} ${_tickets.length == 1 ? 'active ticket' : 'active tickets'}',
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final user = SupportTicketsScope.of(context).resolveUser(context);
    final userName = _displayFirstName(user);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildProfessionalHeader(userName),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.support_agent_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'No Support Tickets Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create your first ticket and we\'ll be\nglad to assist you',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 15,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a', 'en_US');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => TicketChatScreen(ticketId: ticket.id),
              ),
            )
                .then((_) {
              _loadTickets();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ticket.status.getColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ticket.status.getColor().withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ticket.status.getColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ticket.status.getDisplayText(),
                            style: TextStyle(
                              color: ticket.status.getColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ticket.priority.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ticket.priority.getColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ticket.priority.getDisplayText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: ticket.priority.getColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.tag_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ticket.ticketNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(ticket.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (ticket.assignedToName != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ticket.assignedToName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (ticket.unreadMessageCount != null &&
                        ticket.unreadMessageCount! > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red[400]!,
                              Colors.red[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${ticket.unreadMessageCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatarWithTimeout extends StatefulWidget {
  const _UserAvatarWithTimeout({
    required this.imageUrl,
    required this.placeholderUrl,
    required this.width,
    required this.height,
  });

  final String? imageUrl;
  final String placeholderUrl;
  final double width;
  final double height;

  @override
  State<_UserAvatarWithTimeout> createState() => _UserAvatarWithTimeoutState();
}

class _UserAvatarWithTimeoutState extends State<_UserAvatarWithTimeout> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      _timedOut = true;
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
        });
      }
    });
  }

  bool _isAssetPath(String url) => url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final hasUserImageUrl =
        widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final shouldShowUserImage = hasUserImageUrl && !_timedOut;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetworkOrAssetImage(
            url: widget.placeholderUrl,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
          ),
          if (shouldShowUserImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isAssetPath(widget.imageUrl!)
                  ? Image.asset(
                      widget.imageUrl!,
                      fit: BoxFit.cover,
                      width: widget.width,
                      height: widget.height,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : NetworkOrAssetImage(
                      url: widget.imageUrl!,
                      width: widget.width,
                      height: widget.height,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
            ),
        ],
      ),
    );
  }
}
