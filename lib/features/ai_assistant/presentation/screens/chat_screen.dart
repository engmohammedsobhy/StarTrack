import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import 'package:itiproject/features/home/data/models/entity_model.dart';
import '../providers/chat_provider.dart';

class PromptSuggestion {
  final String icon;
  final String persona;
  final String title;
  final String query;

  const PromptSuggestion({
    required this.icon,
    required this.persona,
    required this.title,
    required this.query,
  });
}

const List<PromptSuggestion> _kDefaultSuggestions = [
  PromptSuggestion(
    icon: '⚽',
    persona: 'Lionel Messi',
    title: '@Lionel Messi',
    query: '@Lionel Messi tell me about his greatest World Cup triumphs and career records',
  ),
  PromptSuggestion(
    icon: '🔬',
    persona: 'Marie Curie',
    title: '@Marie Curie',
    query: '@Marie Curie what breakthrough discoveries won her two Nobel Prizes?',
  ),
  PromptSuggestion(
    icon: '🎬',
    persona: 'Christian Bale',
    title: '@Christian Bale',
    query: '@Christian Bale what method acting transformations define his legendary career?',
  ),
  PromptSuggestion(
    icon: '⚡',
    persona: 'Nikola Tesla',
    title: '@Nikola Tesla',
    query: '@Nikola Tesla what inventions and visions changed modern electricity?',
  ),
];

class ChatScreen extends ConsumerStatefulWidget {
  final KnowledgeEntity? entity;
  const ChatScreen({super.key, this.entity});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isMentionActive = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    if (widget.entity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatState = ref.read(chatProvider);
        if (chatState.valueOrNull == null || chatState.valueOrNull!.isEmpty) {
          ref.read(chatProvider.notifier).sendMessage(
                "@${widget.entity!.title}",
                entityName: widget.entity!.title,
                entityTitle: widget.entity!.title,
              );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;

    if (cursor > 0 && cursor <= text.length) {
      final textBeforeCursor = text.substring(0, cursor);
      final atIndex = textBeforeCursor.lastIndexOf('@');

      if (atIndex != -1) {
        final queryAfterAt = textBeforeCursor.substring(atIndex + 1);
        // Only trigger if no newline and reasonable length
        if (!queryAfterAt.contains('\n') && queryAfterAt.length < 25) {
          if (!_isMentionActive || _mentionQuery != queryAfterAt) {
            setState(() {
              _isMentionActive = true;
              _mentionQuery = queryAfterAt;
              _mentionStartIndex = atIndex;
            });
          }
          return;
        }
      }
    }

    if (_isMentionActive) {
      setState(() {
        _isMentionActive = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }
  }

  void _insertMention(String personaTitle) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;

    if (_mentionStartIndex != -1 && _mentionStartIndex < text.length) {
      final beforeAt = text.substring(0, _mentionStartIndex);
      final afterCursor = cursor <= text.length ? text.substring(cursor) : '';
      final replacement = '@$personaTitle ';

      _controller.text = '$beforeAt$replacement$afterCursor';
      _controller.selection = TextSelection.collapsed(
        offset: beforeAt.length + replacement.length,
      );
    } else {
      _controller.text = '@$personaTitle ';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }

    setState(() {
      _isMentionActive = false;
      _mentionQuery = '';
      _mentionStartIndex = -1;
    });

    _focusNode.requestFocus();
  }

  void _insertAtSymbol() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final safeCursor = cursor >= 0 ? cursor : text.length;

    final before = text.substring(0, safeCursor);
    final after = text.substring(safeCursor);

    _controller.text = '$before@$after';
    _controller.selection = TextSelection.collapsed(offset: safeCursor + 1);
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _sendText(text);
      _controller.clear();
      setState(() {
        _isMentionActive = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }
  }

  void _sendText(String text) {
    ref.read(chatProvider.notifier).sendMessage(
          text,
          entityName: widget.entity?.title,
          entityTitle: widget.entity?.title,
        );
    _scrollToBottom();
  }

  void _handleRegenerate(List<ChatMessage> messages, int aiIndex) {
    for (int i = aiIndex - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        _sendText(messages[i].text);
        break;
      }
    }
  }

  String _formatSessionTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes.clamp(1, 60)}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),
      drawer: _buildGeminiDrawer(notifier),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Chat History',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.entity != null ? widget.entity!.title : 'Persona AI',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          // New Chat Button
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 24),
            onPressed: () {
              ref.read(chatProvider.notifier).startNewChat();
            },
            tooltip: 'New Chat',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: Colors.white70, size: 20),
            onPressed: () => context.push('/favorites'),
            tooltip: 'Saved Personas',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: chatState.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return _buildEmptyState();
                      }
                      _scrollToBottom();
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _ChatBubble(
                            message: message,
                            onRegenerate: !message.isUser
                                ? () => _handleRegenerate(messages, index)
                                : null,
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (err, stack) => _buildErrorState(err),
                  ),
                ),
                if (chatState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _PulsingAiLoader(),
                    ),
                  ),
                // Floating Input Bar
                _buildInputBar(),
              ],
            ),
            // Floating WhatsApp-style @ Mention Suggestions Overlay
            if (_isMentionActive)
              Positioned(
                left: 16,
                right: 16,
                bottom: 76,
                child: _buildMentionSuggestionsOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiDrawer(ChatNotifier notifier) {
    final sessions = notifier.sessions;
    final activeId = notifier.activeSessionId;

    return Drawer(
      backgroundColor: const Color(0xFF181818),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Top Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Persona AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // + New Chat Pill Button (Gemini style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  notifier.startNewChat();
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'New Chat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF262626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'RECENT CHATS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // History List
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No chat history yet.\nStart a conversation to see it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSelected = session.id == activeId;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF282828)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            leading: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: isSelected ? Colors.redAccent : Colors.white54,
                            ),
                            title: Text(
                              session.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatSessionTime(session.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white38,
                              ),
                              onPressed: () {
                                notifier.deleteSession(session.id);
                                setState(() {});
                              },
                              tooltip: 'Delete Chat',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              notifier.loadSession(session.id);
                            },
                          ),
                        );
                      },
                    ),
            ),

            if (sessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton.icon(
                  onPressed: () {
                    notifier.clearAllHistory();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white38, size: 18),
                  label: const Text(
                    'Clear All History',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Gemini-style Welcome
          const Text(
            'Hello',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask anything about any iconic persona, or type @ to mention someone.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Quick @ Mention Helper Banner
          InkWell(
            onTap: _insertAtSymbol,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '@',
                      style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Type @ to mention any persona (e.g. @Lionel Messi)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.touch_app_rounded, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Suggested Prompts Pinterest-like Cards
          const Text(
            'EXPLORE PERSONAS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: _kDefaultSuggestions.map((s) {
              return InkWell(
                onTap: () => _sendText(s.query),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.icon, style: const TextStyle(fontSize: 22)),
                      Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestionsOverlay() {
    final suggestionsAsync = ref.watch(
      personaMentionSuggestionsProvider(_mentionQuery),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 230),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded, color: Colors.cyanAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _mentionQuery.isEmpty
                        ? 'Mention a Persona'
                        : 'Matching "$_mentionQuery"',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            // Suggestions
            Flexible(
              child: suggestionsAsync.when(
                data: (entities) {
                  if (entities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No matching personas found. Type any name to ask.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: entities.length,
                    itemBuilder: (context, index) {
                      final item = entities[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white12,
                          backgroundImage: item.thumbnailUrl != null
                              ? CachedNetworkImageProvider(item.thumbnailUrl!)
                              : null,
                          child: item.thumbnailUrl == null
                              ? Text(
                                  item.title.isNotEmpty ? item.title[0] : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: item.description != null && item.description!.isNotEmpty
                            ? Text(
                                item.description!,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _insertMention(item.title),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // @ Quick Mention Shortcut
          InkWell(
            onTap: _insertAtSymbol,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isMentionActive
                    ? const Color(0xFFE53935).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Text(
                '@',
                style: TextStyle(
                  color: _isMentionActive ? Colors.redAccent : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text Field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              decoration: const InputDecoration(
                hintText: 'Ask anything or type @ to mention...',
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),

          // Send Arrow Circle Button
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE53935),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Connection Issue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => ref.refresh(chatProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onRegenerate;

  const _ChatBubble({
    required this.message,
    this.onRegenerate,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _isCopied = false;

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    setState(() {
      _isCopied = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF262626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  void _shareText() {
    // ignore: deprecated_member_use
    Share.share(widget.message.text);
  }

  Widget _buildUserMessageContent(String text) {
    // Detect @mentions to highlight them nicely
    final mentionMatch = RegExp(r'@([A-Za-z0-9\s\.\-]+)').firstMatch(text);
    if (mentionMatch != null) {
      final mention = mentionMatch.group(0)!;
      final parts = text.split(mention);

      return RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          children: [
            if (parts.isNotEmpty) TextSpan(text: parts[0]),
            TextSpan(
              text: mention,
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (parts.length > 1) TextSpan(text: parts.sublist(1).join(mention)),
          ],
        ),
      );
    }

    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                // AI Sparkle Avatar Badge
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE53935),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(6),
                      bottomRight: isUser
                          ? const Radius.circular(6)
                          : const Radius.circular(20),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: isUser
                      ? _buildUserMessageContent(widget.message.text)
                      : MarkdownBody(
                          data: widget.message.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.5,
                            ),
                            h1: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            strong: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            em: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                            listBullet: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 15,
                            ),
                            code: const TextStyle(
                              backgroundColor: Color(0xFF262626),
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
              ),
              if (isUser) const SizedBox(width: 4),
            ],
          ),
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Row(
                children: [
                  _ActionButton(
                    icon: _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                    label: _isCopied ? 'Copied' : 'Copy',
                    color: _isCopied ? const Color(0xFFE53935) : Colors.white38,
                    onTap: _copyText,
                  ),
                  const SizedBox(width: 8),
                  if (widget.onRegenerate != null) ...[
                    _ActionButton(
                      icon: Icons.refresh_rounded,
                      label: 'Regenerate',
                      color: Colors.white38,
                      onTap: widget.onRegenerate!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: Colors.white38,
                    onTap: _shareText,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingAiLoader extends StatefulWidget {
  const _PulsingAiLoader();

  @override
  State<_PulsingAiLoader> createState() => _PulsingAiLoaderState();
}

class _PulsingAiLoaderState extends State<_PulsingAiLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE53935).withValues(
                  alpha: _glowAnimation.value,
                ),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE53935),
                  highlightColor: Colors.white,
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Shimmer.fromColors(
                  baseColor: Colors.white,
                  highlightColor: const Color(0xFFE53935),
                  child: const Text(
                    "Persona AI is thinking...",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
