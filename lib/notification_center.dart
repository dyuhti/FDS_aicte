import 'package:flutter/material.dart';

enum NotificationRecipientRole { institution, officer }

enum NotificationCategory {
  submission,
  verification,
  approval,
  correction,
  request,
  reminder,
  clarification,
  merger,
  announcement,
}

extension NotificationCategoryLabel on NotificationCategory {
  String get label => switch (this) {
    NotificationCategory.submission => 'Submissions',
    NotificationCategory.verification => 'FDR verification',
    NotificationCategory.approval => 'Approvals',
    NotificationCategory.correction => 'Returned for correction',
    NotificationCategory.request => 'Requests',
    NotificationCategory.reminder => 'Reminders',
    NotificationCategory.clarification => 'Clarifications',
    NotificationCategory.merger => 'Merger updates',
    NotificationCategory.announcement => 'Announcements',
  };

  IconData get icon => switch (this) {
    NotificationCategory.approval => Icons.check_circle_outline_rounded,
    NotificationCategory.correction => Icons.error_outline_rounded,
    NotificationCategory.verification => Icons.verified_outlined,
    NotificationCategory.request => Icons.account_balance_wallet_outlined,
    NotificationCategory.reminder => Icons.schedule_rounded,
    NotificationCategory.clarification => Icons.question_answer_outlined,
    NotificationCategory.merger => Icons.compare_arrows_rounded,
    NotificationCategory.announcement => Icons.campaign_outlined,
    NotificationCategory.submission => Icons.fact_check_outlined,
  };

  Color get color => switch (this) {
    NotificationCategory.approval => const Color(0xFF15803D),
    NotificationCategory.correction => const Color(0xFFB91C1C),
    NotificationCategory.verification => const Color(0xFFEA580C),
    _ => const Color(0xFFF97316),
  };
}

class PortalNotification {
  const PortalNotification({
    required this.id,
    required this.recipientRole,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.recipientId,
    this.relatedId,
    this.read = false,
  });

  final String id;
  final NotificationRecipientRole recipientRole;
  final String? recipientId;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime createdAt;
  final String? relatedId;
  final bool read;

  PortalNotification copyWith({bool? read}) => PortalNotification(
    id: id,
    recipientRole: recipientRole,
    recipientId: recipientId,
    title: title,
    message: message,
    category: category,
    createdAt: createdAt,
    relatedId: relatedId,
    read: read ?? this.read,
  );
}

class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();

  static final instance = NotificationCenter._();
  final List<PortalNotification> _notifications = <PortalNotification>[];
  final Map<String, bool> _preferences = <String, bool>{
    'inApp': true,
    'workflow': true,
    'reminders': true,
  };
  int _sequence = 0;

  List<PortalNotification> forRecipient(
    NotificationRecipientRole role, {
    String? recipientId,
    NotificationCategory? category,
    bool unreadOnly = false,
  }) {
    final result = _notifications.where((notification) {
      final recipientMatches = notification.recipientRole == role &&
          (role == NotificationRecipientRole.officer ||
              notification.recipientId == recipientId);
      return recipientMatches &&
          (!unreadOnly || !notification.read) &&
          (category == null || notification.category == category);
    }).toList()..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List.unmodifiable(result);
  }

  int unreadCount(NotificationRecipientRole role, {String? recipientId}) =>
      forRecipient(role, recipientId: recipientId, unreadOnly: true).length;

  bool preference(String key) => _preferences[key] ?? true;

  void setPreference(String key, bool value) {
    _preferences[key] = value;
    notifyListeners();
  }

  void add({
    required NotificationRecipientRole recipientRole,
    required String title,
    required String message,
    required NotificationCategory category,
    String? recipientId,
    String? relatedId,
    required String eventKey,
  }) {
    if (!preference('inApp') ||
        (category == NotificationCategory.reminder && !preference('reminders')) ||
        (category != NotificationCategory.reminder && !preference('workflow'))) {
      return;
    }
    final duplicate = _notifications.any((item) => item.id == eventKey);
    if (duplicate) return;
    _notifications.add(
      PortalNotification(
        id: eventKey,
        recipientRole: recipientRole,
        recipientId: recipientId,
        title: title,
        message: message,
        category: category,
        createdAt: DateTime.now(),
        relatedId: relatedId,
      ),
    );
    notifyListeners();
  }

  void markRead(String id) {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].read) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    notifyListeners();
  }

  void markAllRead(NotificationRecipientRole role, {String? recipientId}) {
    var changed = false;
    for (var index = 0; index < _notifications.length; index++) {
      final item = _notifications[index];
      if (item.recipientRole == role &&
          (role == NotificationRecipientRole.officer ||
              item.recipientId == recipientId) &&
          !item.read) {
        _notifications[index] = item.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void seedDemoNotifications() {
    if (_notifications.isNotEmpty) return;
    add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'New FDR Submission',
      message: 'Example Institute of Technology submitted an FDR for verification.',
      category: NotificationCategory.submission,
      relatedId: 'FDR-2026-00124',
      eventKey: 'seed-officer-fdr-00124',
    );
    add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: 'INST-DEMO-0042',
      title: 'FDR Verification Update',
      message: 'Your FDR submission is awaiting verification review.',
      category: NotificationCategory.verification,
      relatedId: 'FDR-2026-00124',
      eventKey: 'seed-institution-fdr-00124',
    );
  }

  void reset() {
    _notifications.clear();
    _preferences
      ..clear()
      ..addAll({'inApp': true, 'workflow': true, 'reminders': true});
    _sequence = 0;
    seedDemoNotifications();
    notifyListeners();
  }

  String nextEventKey(String prefix) => '$prefix-${_sequence++}';
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.role,
    this.recipientId,
    this.onOpenRelated,
  });

  final NotificationRecipientRole role;
  final String? recipientId;
  final ValueChanged<PortalNotification>? onOpenRelated;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationCategory? _category;
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: NotificationCenter.instance,
    builder: (context, _) {
      final notifications = NotificationCenter.instance.forRecipient(
        widget.role,
        recipientId: widget.recipientId,
        category: _category,
        unreadOnly: _unreadOnly,
      );
      final unread = NotificationCenter.instance.unreadCount(
        widget.role,
        recipientId: widget.recipientId,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (unread > 0)
              TextButton(
                onPressed: () => NotificationCenter.instance.markAllRead(
                  widget.role,
                  recipientId: widget.recipientId,
                ),
                child: const Text('Mark all as read'),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text('$unread unread', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip('All', null),
                  _filterChip('Unread', null, unread: true),
                  _filterChip('Approvals', NotificationCategory.approval),
                  _filterChip('Submissions', NotificationCategory.submission),
                  _filterChip('Requests', NotificationCategory.request),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFFF97316)),
                            SizedBox(height: 12),
                            Text('You are all caught up', style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 5),
                            Text('New portal updates will appear here.', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _NotificationCard(
                          notification: notification,
                          onTap: () {
                            NotificationCenter.instance.markRead(notification.id);
                            widget.onOpenRelated?.call(notification);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _filterChip(String label, NotificationCategory? category, {bool unread = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: unread ? _unreadOnly : _category == category && !_unreadOnly,
          onSelected: (_) => setState(() {
            _unreadOnly = unread;
            _category = unread ? null : category;
          }),
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final PortalNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: notification.read ? Colors.white : const Color(0xFFFFF7ED),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAE6E1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notification.category.icon, color: notification.category.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(notification.message),
                  const SizedBox(height: 7),
                  Text(_relativeTime(notification.createdAt), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
            ),
            if (!notification.read)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 3),
                child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFF97316)),
              ),
          ],
        ),
      ),
    ),
  );
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
  if (difference.inHours < 24) return '${difference.inHours} hours ago';
  return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
}
