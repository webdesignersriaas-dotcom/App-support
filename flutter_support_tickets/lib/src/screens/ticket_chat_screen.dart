import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/ticket_message_model.dart';
import '../models/ticket_model.dart';
import '../support_ticket_service.dart';
import '../widgets/network_or_asset_image.dart';

class TicketChatScreen extends StatefulWidget {
  const TicketChatScreen({
    super.key,
    required this.ticketId,
  });

  final String ticketId;

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen>
    with WidgetsBindingObserver {
  SupportTicketService? _ticketService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  SupportTicket? _ticket;
  List<TicketMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _currentPage = 1;
  bool _hasMoreMessages = true;
  Timer? _pollingTimer;
  DateTime? _lastMessageTime;
  bool _showTypingIndicator = false;

  Duration _pollingInterval = const Duration(seconds: 3);
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _maxInterval = Duration(seconds: 30);
  int _consecutiveEmptyPolls = 0;
  bool _isAppInForeground = true;
  bool _initialLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticketService = SupportTicketService(SupportTicketsScope.of(context));
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      _loadTicketData();
      _startPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isAppInForeground = state == AppLifecycleState.resumed;
    });

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      _resumePolling();
      _checkForNewMessages();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (mounted && !_isLoading && !_isSending && _isAppInForeground) {
        _checkForNewMessages();
      }
    });
  }

  void _pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _resumePolling() {
    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _startPolling();
    }
  }

  void _adjustPollingInterval(bool hasNewMessages) {
    if (hasNewMessages) {
      _consecutiveEmptyPolls = 0;
      _pollingInterval = _minInterval;
    } else {
      _consecutiveEmptyPolls++;

      if (_consecutiveEmptyPolls <= 1) {
        _pollingInterval = const Duration(seconds: 3);
      } else if (_consecutiveEmptyPolls <= 2) {
        _pollingInterval = const Duration(seconds: 5);
      } else if (_consecutiveEmptyPolls <= 3) {
        _pollingInterval = const Duration(seconds: 8);
      } else if (_consecutiveEmptyPolls <= 4) {
        _pollingInterval = const Duration(seconds: 12);
      } else if (_consecutiveEmptyPolls <= 5) {
        _pollingInterval = const Duration(seconds: 18);
      } else {
        _pollingInterval = _maxInterval;
      }
    }

    _startPolling();
  }

  Future<void> _checkForNewMessages() async {
    if (!mounted || !_isAppInForeground) return;

    try {
      final messages = await _ticketService!.getTicketMessages(
        ticketId: widget.ticketId,
        page: 1,
        limit: 50,
        since: _lastMessageTime,
      );

      if (!mounted) return;

      bool hasNewMessages = false;

      if (messages.isNotEmpty) {
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final existingIds = _messages.map((m) => m.id).toSet();
        final uniqueNewMessages =
            messages.where((m) => !existingIds.contains(m.id)).toList();

        if (uniqueNewMessages.isNotEmpty) {
          hasNewMessages = true;

          _lastMessageTime = uniqueNewMessages.last.createdAt;

          setState(() {
            _messages.addAll(uniqueNewMessages);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _showTypingIndicator = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              final currentScroll = _scrollController.position.pixels;
              if (maxScroll - currentScroll < 200) {
                _scrollController.animateTo(
                  maxScroll,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            }
          });
        }
      }

      _adjustPollingInterval(hasNewMessages);
    } catch (e) {
      debugPrint('Error checking for new messages: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadTicketData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _ticketService!.getTicketDetails(widget.ticketId);

      if (mounted) {
        final messages = (data['messages'] as List<TicketMessage>);
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        setState(() {
          _ticket = data['ticket'] as SupportTicket;
          _messages = messages;
          _isLoading = false;
          _currentPage = 1;
          _hasMoreMessages = true;

          if (messages.isNotEmpty) {
            _lastMessageTime = messages.last.createdAt;
            _consecutiveEmptyPolls = 0;
            _pollingInterval = _minInterval;
            _startPolling();
          }
        });

        _ticketService!.markMessagesAsRead(ticketId: widget.ticketId);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (!isRefresh) {
          BotToast.showText(text: 'Failed to load ticket: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _currentPage++;
      final messages = await _ticketService!.getTicketMessages(
        ticketId: widget.ticketId,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          if (messages.isEmpty) {
            _hasMoreMessages = false;
          } else {
            messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _messages.insertAll(0, messages);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final ticket = _ticket!;
      final newMessage = await _ticketService!.sendMessage(
        ticketId: widget.ticketId,
        message: message,
        userId: ticket.userId,
        userName: ticket.userName,
      );

      if (mounted) {
        setState(() {
          _messages.add(newMessage);
          _messageController.clear();
          _lastMessageTime = newMessage.createdAt;
          _consecutiveEmptyPolls = 0;
          _pollingInterval = _minInterval;
          _startPolling();
          _showTypingIndicator = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        Timer(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() {
              _showTypingIndicator = false;
            });
          }
        });
      }
    } catch (e) {
      BotToast.showText(text: 'Failed to send message: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket Not Found')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ticket!.ticketNumber,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              _ticket!.subject,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _ticket!.status.getColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _ticket!.status.getColor(),
                    width: 1,
                  ),
                ),
                child: Text(
                  _ticket!.status.getDisplayText(),
                  style: TextStyle(
                    color: _ticket!.status.getColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${_ticket!.status.getDisplayText()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_ticket!.assignedToName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Assigned to: ${_ticket!.assignedToName}'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _ticket!.description,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTicketData(isRefresh: true),
              child: _messages.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start the conversation',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length +
                          (_hasMoreMessages && _isLoading ? 1 : 0) +
                          (_showTypingIndicator ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 && _hasMoreMessages && _isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        int messageIndex =
                            _hasMoreMessages && _isLoading ? index - 1 : index;

                        if (_showTypingIndicator &&
                            messageIndex == _messages.length) {
                          return _buildTypingIndicator();
                        }

                        if (messageIndex < 0 ||
                            messageIndex >= _messages.length) {
                          return const SizedBox.shrink();
                        }

                        return _buildMessageBubble(_messages[messageIndex]);
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final config = SupportTicketsScope.of(context);
    final user = config.resolveUser(context);
    final imageUrl = user?.picture?.isNotEmpty == true
        ? user!.picture!
        : (user?.userUrl?.isNotEmpty == true ? user!.userUrl! : null);

    bool isAssetPath(String url) => url.startsWith('assets/');

    Widget buildImageWidget(String url, double size) {
      if (isAssetPath(url)) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size),
          child: Image.asset(
            url,
            fit: BoxFit.cover,
            width: size * 2,
            height: size * 2,
            errorBuilder: (context, error, stackTrace) {
              return CircleAvatar(
                radius: size,
                backgroundColor: Colors.grey[400],
                child: Icon(
                  Icons.person,
                  size: size,
                  color: Colors.white,
                ),
              );
            },
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size),
          child: NetworkOrAssetImage(
            url: url,
            width: size * 2,
            height: size * 2,
            fit: BoxFit.cover,
            errorWidget: CircleAvatar(
              radius: size,
              backgroundColor: Colors.grey[400],
              child: Icon(
                Icons.person,
                size: size,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return buildImageWidget(imageUrl, 18);
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[400],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: NetworkOrAssetImage(
          url: config.defaultAvatarUrlOrAsset,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorWidget: const Icon(
            Icons.person,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(TicketMessage message) {
    final isUser = message.senderType == MessageSenderType.user;
    final timeFormat = DateFormat('hh:mm a', 'en_US');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[400],
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isUser ? 0 : 4,
                    right: isUser ? 4 : 0,
                  ),
                  child: Text(
                    timeFormat.format(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue[400],
            child: const Text(
              'A',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_animation.value * 0.7),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
