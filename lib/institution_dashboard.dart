import 'package:flutter/material.dart';

import 'notification_center.dart';
import 'officer_dashboard.dart';
import 'portal_foundations.dart';

final ValueNotifier<int> _institutionSelectedTab = ValueNotifier<int>(0);

enum InstitutionSubmissionStatus {
  pending,
  verified,
  approved,
  rejected,
  actionRequired,
}

class InstitutionHistoryEvent {
  const InstitutionHistoryEvent({
    required this.title,
    required this.actor,
    required this.time,
    required this.remark,
  });

  final String title;
  final String actor;
  final String time;
  final String remark;
}

class InstitutionSubmission {
  const InstitutionSubmission({
    required this.id,
    required this.fdrNumber,
    required this.bankName,
    required this.amount,
    required this.submittedOn,
    required this.status,
    required this.institutionId,
    required this.caseType,
    this.caseId,
    this.requestedAmount,
    this.retainedBalance,
    this.reason,
    this.issues = const [],
    this.rejectionReason,
    this.correctionHistory = const [],
  });

  final String id;
  final String fdrNumber;
  final String bankName;
  final int amount;
  final DateTime submittedOn;
  final InstitutionSubmissionStatus status;
  final String institutionId;
  final String caseType;
  final String? caseId;
  final int? requestedAmount;
  final int? retainedBalance;
  final String? reason;
  final List<String> issues;
  final String? rejectionReason;
  final List<String> correctionHistory;
}

class InstitutionReleaseRequest {
  const InstitutionReleaseRequest({
    required this.id,
    required this.fdrNumber,
    required this.requestType,
    required this.amount,
    required this.reason,
    required this.submittedOn,
    required this.caseType,
    required this.status,
  });

  final String id;
  final String fdrNumber;
  final String requestType;
  final int amount;
  final String reason;
  final DateTime submittedOn;
  final String caseType;
  final String status;
}

class InstitutionDemoStore extends ChangeNotifier {
  InstitutionDemoStore._() {
    DemoFdrPortalStore.instance.addListener(notifyListeners);
  }

  static final instance = InstitutionDemoStore._();

  DemoFdrPortalStore get _store => DemoFdrPortalStore.instance;

  List<InstitutionSubmission> get submissions =>
      _store.dashboardSubmissions
          .where((record) => record.institutionId == _institutionId)
          .map(_fromOfficerSubmission)
          .toList(growable: false)
        ..sort((left, right) => right.submittedOn.compareTo(left.submittedOn));

  List<InstitutionSubmission> get fdrSubmissions => submissions
      .where((record) => record.caseType == 'FDR Submission')
      .toList(growable: false);

  List<InstitutionReleaseRequest> get releaseRequests => _store
      .dashboardSubmissions
      .where(
        (record) =>
            record.institutionId == _institutionId &&
            record.caseType != 'FDR Submission',
      )
      .map((record) {
        final caseRecord = record.caseId == null
            ? null
            : _store.releaseCases
                  .where((item) => item.caseId == record.caseId)
                  .firstOrNull;
        return InstitutionReleaseRequest(
          id: record.caseId ?? record.submissionId,
          fdrNumber: record.reference,
          requestType: record.caseType,
          amount: record.requestedAmount ?? 0,
          reason: record.requestReason ?? '',
          submittedOn: _parseSubmissionDate(record.submittedOn),
          caseType: record.caseType,
          status: caseRecord?.status ?? record.status.label,
        );
      })
      .toList(growable: false);

  void resetDemoData() {
    _store.resetDemoData();
    NotificationCenter.instance.reset();
  }

  InstitutionSubmission? submissionById(String id) {
    final submission = _store.submissionById(id);
    if (submission == null || submission.institutionId != _institutionId) {
      return null;
    }
    return _fromOfficerSubmission(submission);
  }

  InstitutionSubmission? submissionForCaseId(String caseId) {
    final submissionId = _store.releaseCases
        .where((record) => record.caseId == caseId)
        .firstOrNull
        ?.submissionId;
    return submissionId == null ? null : submissionById(submissionId);
  }

  ReleaseCase? releaseCaseForSubmission(String submissionId) {
    for (final record in _store.releaseCases) {
      if (record.submissionId == submissionId &&
          record.originalInstitutionId == _institutionId) {
        return record;
      }
    }
    return null;
  }

  List<InstitutionHistoryEvent> caseHistoryForInstitution(
    String institutionId,
  ) {
    final events = <InstitutionHistoryEvent>[];
    for (final record in _store.releaseCases) {
      if (record.originalInstitutionId != institutionId) continue;
      for (final event in record.history) {
        events.add(
          InstitutionHistoryEvent(
            title: event.action,
            actor: event.actor,
            time: event.at.toLocal().toString(),
            remark: event.remark,
          ),
        );
      }
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    return events;
  }

  InstitutionSubmission addSubmission({
    required String fdrNumber,
    required String bankName,
    required int amount,
    int? receiptAmount,
    String? issueDate,
    String? maturityDate,
    int declaredTenureMonths = 36,
    int enteredTenureMonths = 36,
    String lienInformation = 'No lien',
    List<DemoDocument> documents = const [],
  }) {
    final submission = _store.submitInstitutionFdr(
      institution: _institutionName,
      institutionId: _institutionId,
      bank: bankName,
      fdrNumber: fdrNumber,
      amount: amount,
      receiptAmount: receiptAmount ?? amount,
      issueDate: issueDate ?? _defaultIssueDate(),
      maturityDate: maturityDate ?? _defaultMaturityDate(),
      declaredTenureMonths: declaredTenureMonths,
      enteredTenureMonths: enteredTenureMonths,
      lienInformation: lienInformation,
      documents: documents,
    );
    return _fromOfficerSubmission(submission);
  }

  String _defaultIssueDate() => _formatDate(DateTime.now());

  String _defaultMaturityDate() => _formatDate(
    DateTime(DateTime.now().year + 3, DateTime.now().month, DateTime.now().day),
  );

  void addReleaseRequest({
    required String fdrNumber,
    required String requestType,
    required int amount,
    required String reason,
    required String caseType,
    String successorInstitution = '',
    String mergerReference = '',
    String effectiveDate = '',
  }) {
    final fdr = submissions.firstWhere(
      (record) => record.fdrNumber == fdrNumber,
    );
    _store.submitInstitutionReleaseCase(
      institution: _institutionName,
      institutionId: _institutionId,
      bank: fdr.bankName,
      fdrNumber: fdrNumber,
      originalAmount: fdr.amount,
      caseType: caseType,
      requestedAmount: amount,
      reason: reason.isEmpty ? requestType : reason,
      successorInstitution: successorInstitution,
      mergerReference: mergerReference,
      effectiveDate: effectiveDate,
    );
  }

  InstitutionSubmission _fromOfficerSubmission(FdrSubmission record) =>
      InstitutionSubmission(
        id: record.submissionId,
        fdrNumber: record.reference,
        bankName: record.bankName,
        amount: _currencyAmount(record.amount),
        submittedOn: _parseSubmissionDate(record.submittedOn),
        status: switch (record.status) {
          SubmissionStatus.pendingReview =>
            record.verificationPassed
                ? InstitutionSubmissionStatus.verified
                : InstitutionSubmissionStatus.pending,
          SubmissionStatus.blocked =>
            InstitutionSubmissionStatus.actionRequired,
          SubmissionStatus.approved => InstitutionSubmissionStatus.approved,
          SubmissionStatus.rejected || SubmissionStatus.correctionRequested =>
            InstitutionSubmissionStatus.rejected,
        },
        institutionId: record.institutionId,
        caseType: record.caseType,
        caseId: record.caseId,
        requestedAmount: record.requestedAmount,
        retainedBalance: record.retainedBalance,
        reason: record.requestReason,
        issues: record.issues,
        rejectionReason: record.rejectionReason,
        correctionHistory: record.correctionHistory,
      );
}

class InstitutionDashboardScreen extends StatefulWidget {
  const InstitutionDashboardScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<InstitutionDashboardScreen> createState() =>
      _InstitutionDashboardScreenState();
}

class _InstitutionDashboardScreenState
    extends State<InstitutionDashboardScreen> {
  int _selectedTab = 0;
  InstitutionSubmissionStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _institutionSelectedTab.value = 0;
    _institutionSelectedTab.addListener(_syncSelectedTab);
  }

  @override
  void dispose() {
    _institutionSelectedTab.removeListener(_syncSelectedTab);
    super.dispose();
  }

  void _syncSelectedTab() {
    if (_selectedTab != _institutionSelectedTab.value && mounted) {
      setState(() => _selectedTab = _institutionSelectedTab.value);
    }
  }

  void _openSubmissions([InstitutionSubmissionStatus? status]) {
    setState(() {
      _selectedTab = 1;
      _statusFilter = status;
    });
    _institutionSelectedTab.value = 1;
  }

  void _openSubmission(InstitutionSubmission submission) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            InstitutionSubmissionDetailPage(submissionId: submission.id),
      ),
    );
  }

  Future<void> _openNewSubmission() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const InstitutionNewSubmissionPage(),
      ),
    );
    if (created == true && mounted) _openSubmissions();
  }

  Future<void> _openReleaseRequest() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const InstitutionReleaseRequestPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: InstitutionDemoStore.instance,
    builder: (context, _) => ScreenScaffold(
      backgroundColor: _paper,
      appBar: _buildAppBar(context),
      body: switch (_selectedTab) {
        0 => _InstitutionHome(
          onOpenSubmissions: _openSubmissions,
          onOpenSubmission: _openSubmission,
          onNewSubmission: _openNewSubmission,
          onReleaseRequest: _openReleaseRequest,
        ),
        1 => _InstitutionSubmissionList(
          statusFilter: _statusFilter,
          onFilterChanged: (status) => setState(() => _statusFilter = status),
          onOpenSubmission: _openSubmission,
        ),
        2 => _InstitutionReleaseList(onCreateRequest: _openReleaseRequest),
        _ => _InstitutionProfile(onSignOut: widget.onSignOut),
      },
      bottomNavigationBar: NavigationBar(
        height: 88,
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
            if (index != 1) _statusFilter = null;
          });
          _institutionSelectedTab.value = index;
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE8D5),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'My Submissions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Release / Refund',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: _paper,
    surfaceTintColor: Colors.transparent,
    titleSpacing: 16,
    title: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E4),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: _orange,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _institutionName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _institutionId.replaceFirst('INST-DEMO-', 'INST-'),
                style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Case History',
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const _InstitutionCaseHistoryPage(),
          ),
        ),
        icon: const Icon(Icons.history_rounded, color: _ink),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => NotificationsPage(
              role: NotificationRecipientRole.institution,
              recipientId: _institutionId,
              onSelectTab: (index) {
                _institutionSelectedTab.value = index;
                if (mounted) setState(() => _selectedTab = index);
              },
              onOpenRelated: (notification) {
                Navigator.of(context).pop();
                final id = notification.relatedId;
                if (id == null) return;
                final store = InstitutionDemoStore.instance;
                final record =
                    store.submissionById(id) ?? store.submissionForCaseId(id);
                if (record != null) {
                  _openSubmissionFromNotification(context, record.id);
                }
              },
            ),
          ),
        ),
        icon: AnimatedBuilder(
          animation: NotificationCenter.instance,
          builder: (context, _) => Badge(
            isLabelVisible:
                NotificationCenter.instance.unreadCount(
                  NotificationRecipientRole.institution,
                  recipientId: _institutionId,
                ) >
                0,
            label: Text(
              '${NotificationCenter.instance.unreadCount(NotificationRecipientRole.institution, recipientId: _institutionId)}',
            ),
            child: const Icon(Icons.notifications_none_rounded, color: _ink),
          ),
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Institution administrator profile',
        onSelected: (value) {
          if (value == 'profile') {
            setState(() => _selectedTab = 3);
            _institutionSelectedTab.value = 3;
          }
          if (value == 'signout') widget.onSignOut();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'profile', child: Text('Profile')),
          PopupMenuItem(value: 'signout', child: Text('Sign out')),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFFE8D5),
            child: Text(
              'IA',
              style: TextStyle(
                color: _deepOrange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _openSubmissionFromNotification(BuildContext context, String id) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InstitutionSubmissionDetailPage(submissionId: id),
      ),
    );
  }
}

class _InstitutionHome extends StatelessWidget {
  const _InstitutionHome({
    required this.onOpenSubmissions,
    required this.onOpenSubmission,
    required this.onNewSubmission,
    required this.onReleaseRequest,
  });

  final ValueChanged<InstitutionSubmissionStatus?> onOpenSubmissions;
  final ValueChanged<InstitutionSubmission> onOpenSubmission;
  final VoidCallback onNewSubmission;
  final VoidCallback onReleaseRequest;

  @override
  Widget build(BuildContext context) {
    final store = InstitutionDemoStore.instance;
    final records = store.submissions;
    final pending = records
        .where((record) => record.status == InstitutionSubmissionStatus.pending)
        .length;
    final verified = records
        .where(
          (record) =>
              record.status == InstitutionSubmissionStatus.verified ||
              record.status == InstitutionSubmissionStatus.approved,
        )
        .length;
    final needsAction = records
        .where(
          (record) =>
              record.status == InstitutionSubmissionStatus.rejected ||
              record.status == InstitutionSubmissionStatus.actionRequired,
        )
        .length;
    final attention = records
        .where((record) => record.issues.isNotEmpty)
        .toList();
    final clarificationCount = DemoFdrPortalStore.instance
        .clarificationsForInstitution(_institutionId)
        .where(
          (clarification) => !attention.any(
            (record) =>
                record.id == clarification.submissionId &&
                record.issues.any(
                  (issue) => issue.contains(clarification.remark),
                ),
          ),
        )
        .length;
    final recent = records.take(4).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 18),
          Text(
            'Welcome back, Administrator',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _institutionName,
            style: TextStyle(
              color: _deepOrange,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Manage your security deposits and FDR submissions.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: _muted,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(DateTime.now()),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeading(title: 'Overview'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _OverviewCard(
                    label: 'Total FDRs',
                    count: records.length,
                    icon: Icons.receipt_long_outlined,
                    color: _orange,
                    width: cardWidth,
                    onTap: () => onOpenSubmissions(null),
                  ),
                  _OverviewCard(
                    label: 'Pending Verification',
                    count: pending,
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFB45309),
                    width: cardWidth,
                    onTap: () =>
                        onOpenSubmissions(InstitutionSubmissionStatus.pending),
                  ),
                  _OverviewCard(
                    label: 'Verified FDRs',
                    count: verified,
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF15803D),
                    width: cardWidth,
                    onTap: () =>
                        onOpenSubmissions(InstitutionSubmissionStatus.verified),
                  ),
                  _OverviewCard(
                    label: 'Rejected / Action Required',
                    count: needsAction,
                    icon: Icons.assignment_late_outlined,
                    color: const Color(0xFFB42318),
                    width: cardWidth,
                    onTap: () =>
                        onOpenSubmissions(InstitutionSubmissionStatus.rejected),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Quick Actions'),
          const SizedBox(height: 10),
          _QuickAction(
            label: 'Submit New FDR',
            subtitle: 'Add a deposit receipt',
            icon: Icons.add_circle_outline_rounded,
            onTap: onNewSubmission,
          ),
          const SizedBox(height: 8),
          _QuickAction(
            label: 'My Submissions',
            subtitle: 'Track verification progress',
            icon: Icons.fact_check_outlined,
            onTap: () => onOpenSubmissions(null),
          ),
          const SizedBox(height: 8),
          _QuickAction(
            label: 'Request Release / Refund',
            subtitle: 'Create a release request',
            icon: Icons.account_balance_wallet_outlined,
            onTap: onReleaseRequest,
          ),
          const SizedBox(height: 22),
          SummaryTile(
            icon: Icons.timer_rounded,
            title: 'Deadline Command Center',
            count: DemoFdrPortalStore.instance.deadlineItems
                .where(
                  (item) => item.submission.institutionId == _institutionId,
                )
                .length,
            subtitle: '4 FDRs · 1 needs review date',
            accentColor: const Color(0xFFEA580C),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const _InstitutionDeadlineCenterPage(),
              ),
            ),
          ),
          if (attention.isNotEmpty || clarificationCount > 0) ...[
            const SizedBox(height: 14),
            SummaryTile(
              icon: Icons.warning_amber_rounded,
              title: 'Items Requiring Attention',
              count:
                  attention.fold<int>(
                    0,
                    (sum, record) => sum + record.issues.length,
                  ) +
                  clarificationCount,
              subtitle: 'Open clarification and correction requests',
              accentColor: const Color(0xFFB91C1C),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const _InstitutionAttentionPage(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _SectionHeading(
            title: 'Recent FDR Submissions',
            actionLabel: 'View all',
            onAction: () => onOpenSubmissions(null),
          ),
          const SizedBox(height: 9),
          if (recent.isEmpty)
            const _EmptyState(
              title: 'No FDR submissions yet',
              message: 'Submit a new FDR to see it listed here.',
            )
          else
            for (final record in recent.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _InstitutionSubmissionTile(
                  record: record,
                  onTap: () => onOpenSubmission(record),
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> _showInstitutionRenewalDialog(
  BuildContext context,
  String submissionId,
) async {
  final store = DemoFdrPortalStore.instance;
  final record = store.fdrRecordForSubmission(submissionId);
  if (record == null) return;
  final number = TextEditingController();
  final amount = TextEditingController(text: '${record.declaredDepositAmount}');
  final tenure = TextEditingController(text: '${record.declaredTenureMonths}');
  final issue = TextEditingController(text: record.maturityDate);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Renew FDR'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: number,
            decoration: const InputDecoration(labelText: 'New FDR number'),
          ),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          TextField(
            controller: issue,
            decoration: const InputDecoration(labelText: 'Issue date'),
          ),
          TextField(
            controller: tenure,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tenure months'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            try {
              store.createRenewal(
                parentFdrReference: record.fdrNumber,
                newFdrNumber: number.text.trim(),
                bank: record.bank,
                amount: int.parse(amount.text.trim()),
                issueDate: issue.text.trim(),
                tenureMonths: int.parse(tenure.text.trim()),
              );
              Navigator.pop(dialogContext);
            } on Object catch (error) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
          child: const Text('Create renewal'),
        ),
      ],
    ),
  );
  number.dispose();
  amount.dispose();
  tenure.dispose();
  issue.dispose();
}

class _InstitutionDeadlineCenterPage extends StatelessWidget {
  const _InstitutionDeadlineCenterPage();

  @override
  Widget build(BuildContext context) {
    final deadlines = calculateFdrDeadlines(
      DemoFdrPortalStore.instance.dashboardSubmissions.where(
        (submission) => submission.institutionId == _institutionId,
      ),
    );

    return _InstitutionDeadlineCenterContent(deadlines: deadlines);
  }
}

class _InstitutionDeadlineCenterContent extends StatefulWidget {
  const _InstitutionDeadlineCenterContent({required this.deadlines});

  final List<FdrDeadlineInfo> deadlines;

  @override
  State<_InstitutionDeadlineCenterContent> createState() =>
      _InstitutionDeadlineCenterContentState();
}

class _InstitutionDeadlineCenterContentState
    extends State<_InstitutionDeadlineCenterContent> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filters = <String, MaturityStatus?>{
      'All': null,
      'Critical': MaturityStatus.critical,
      'Expiring Soon': MaturityStatus.expiringSoon,
      'Matured': MaturityStatus.matured,
      'Active': MaturityStatus.active,
      'Review Date': MaturityStatus.invalid,
    };
    final visible = widget.deadlines
        .where(
          (item) => filters[_filter] == null || item.status == filters[_filter],
        )
        .toList(growable: false);
    return _InstitutionSubpage(
      title: 'Deadline Command Center',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in filters.entries)
                ChoiceChip(
                  label: Text(
                    '${entry.key} (${entry.value == null ? widget.deadlines.length : widget.deadlines.where((item) => item.status == entry.value).length})',
                  ),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const _EmptyState(
              title: 'No FDRs in this bucket',
              message: 'There are no deadlines matching the selected status.',
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.submission.reference,
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.submission.bankName,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Maturity: ${item.maturityDate == null ? 'Not available' : _formatDate(item.maturityDate!)} · ${item.daysRemaining == null
                              ? 'Review date'
                              : item.daysRemaining! < 0
                              ? '${item.daysRemaining!.abs()} days overdue'
                              : '${item.daysRemaining} days remaining'}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.nextAction,
                          style: const TextStyle(color: _ink, fontSize: 12),
                        ),
                        if (item.status != MaturityStatus.active &&
                            !item.isRenewed) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showInstitutionRenewalDialog(
                                context,
                                item.submission.submissionId,
                              ),
                              icon: const Icon(Icons.autorenew_rounded),
                              label: const Text('Renew'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

enum _AttentionSeverity { blocking, warning, info }

class _InstitutionAttentionPage extends StatelessWidget {
  const _InstitutionAttentionPage();

  @override
  Widget build(BuildContext context) {
    final records = InstitutionDemoStore.instance.submissions
        .where((record) => record.institutionId == _institutionId)
        .where((record) => record.issues.isNotEmpty)
        .toList();

    final entries = [
      for (final record in records)
        for (final issue in record.issues)
          (record: record, issue: issue, severity: _attentionSeverity(issue)),
      for (final clarification
          in DemoFdrPortalStore.instance.clarificationsForInstitution(
            _institutionId,
          ))
        if (InstitutionDemoStore.instance.submissionById(
              clarification.submissionId,
            ) !=
            null)
          if (!records
              .where((record) => record.id == clarification.submissionId)
              .expand((record) => record.issues)
              .any((issue) => issue.contains(clarification.remark)))
            (
              record: InstitutionDemoStore.instance.submissionById(
                clarification.submissionId,
              )!,
              issue:
                  '${clarification.reviewSection}: ${clarification.remark}'
                  '${clarification.requiredDocument == null ? '' : ' · Document: ${clarification.requiredDocument}'}',
              severity: _AttentionSeverity.blocking,
            ),
    ];
    final groups =
        <
          _AttentionSeverity,
          List<
            ({
              InstitutionSubmission record,
              String issue,
              _AttentionSeverity severity,
            })
          >
        >{
          for (final severity in _AttentionSeverity.values)
            severity: entries
                .where((entry) => entry.severity == severity)
                .toList(),
        };
    final blockingCount = groups[_AttentionSeverity.blocking]!.length;
    final warningCount = groups[_AttentionSeverity.warning]!.length;
    final infoCount = groups[_AttentionSeverity.info]!.length;
    return _InstitutionSubpage(
      title: 'Items Requiring Attention',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: _deepOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${entries.length} items need action',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final severity in _AttentionSeverity.values)
            if (groups[severity]!.isNotEmpty) ...[
              _SectionHeading(
                title:
                    '${_severityLabel(severity)} (${groups[severity]!.length})',
              ),
              const SizedBox(height: 8),
              for (final entry in groups[severity]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AttentionItemCard(
                    record: entry.record,
                    issue: entry.issue,
                    severity: severity,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => InstitutionSubmissionDetailPage(
                          submissionId: entry.record.id,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          if (entries.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _line),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('No items need your attention.')),
                  ],
                ),
              ),
            ),
          if (entries.isNotEmpty)
            Semantics(
              label:
                  'Severity summary: $blockingCount blocking, $warningCount warnings, $infoCount info',
              child: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

_AttentionSeverity _attentionSeverity(String issue) {
  final normalized = issue.toLowerCase();
  if (normalized.contains('lien') ||
      normalized.contains('review') ||
      normalized.contains('warning') ||
      normalized.contains('missing') ||
      normalized.contains('required') ||
      normalized.contains('incomplete')) {
    return _AttentionSeverity.warning;
  }
  if (normalized.contains('info') || normalized.contains('note')) {
    return _AttentionSeverity.info;
  }
  return _AttentionSeverity.blocking;
}

String _severityLabel(_AttentionSeverity severity) => switch (severity) {
  _AttentionSeverity.blocking => 'Blocking',
  _AttentionSeverity.warning => 'Warnings',
  _AttentionSeverity.info => 'Info',
};

class _AttentionItemCard extends StatelessWidget {
  const _AttentionItemCard({
    required this.record,
    required this.issue,
    required this.severity,
    required this.onTap,
  });

  final InstitutionSubmission record;
  final String issue;
  final _AttentionSeverity severity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tint) = switch (severity) {
      _AttentionSeverity.blocking => (
        Icons.error_outline_rounded,
        const Color(0xFFB91C1C),
        const Color(0xFFFEE2E2),
      ),
      _AttentionSeverity.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFB45309),
        const Color(0xFFFFEDD5),
      ),
      _AttentionSeverity.info => (
        Icons.info_outline_rounded,
        const Color(0xFF475569),
        const Color(0xFFE2E8F0),
      ),
    };
    final isLong = issue.length > 95;
    final title = isLong && issue.toLowerCase().contains('duplicate')
        ? 'Duplicate FDR reference'
        : issue;
    return Semantics(
      button: true,
      label:
          '${_severityLabel(severity)} issue: $title. FDR ${record.fdrNumber}. Status ${record.status.displayLabel}.',
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _line),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if (isLong) ...[
                        const SizedBox(height: 5),
                        Text(
                          issue,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        'FDR ${record.fdrNumber}',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      _StatusPill(status: record.status),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.chevron_right_rounded, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstitutionCaseHistoryPage extends StatelessWidget {
  const _InstitutionCaseHistoryPage();

  @override
  Widget build(BuildContext context) {
    final store = InstitutionDemoStore.instance;
    final events = store.caseHistoryForInstitution(_institutionId);

    return _InstitutionSubpage(
      title: 'Case History',
      child: events.isEmpty
          ? const Center(child: Text('No history for this institution yet.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              children: [
                for (final event in events)
                  ListTile(
                    leading: const Icon(Icons.event_note_rounded),
                    title: Text(event.title),
                    subtitle: Text('${event.actor} · ${event.time}'),
                  ),
              ],
            ),
    );
  }
}

class _InstitutionSubmissionList extends StatelessWidget {
  const _InstitutionSubmissionList({
    required this.statusFilter,
    required this.onFilterChanged,
    required this.onOpenSubmission,
  });

  final InstitutionSubmissionStatus? statusFilter;
  final ValueChanged<InstitutionSubmissionStatus?> onFilterChanged;
  final ValueChanged<InstitutionSubmission> onOpenSubmission;

  @override
  Widget build(BuildContext context) {
    final records = InstitutionDemoStore.instance.fdrSubmissions;
    final visible = statusFilter == null
        ? records
        : records.where((record) {
            if (statusFilter == InstitutionSubmissionStatus.rejected) {
              return record.status == InstitutionSubmissionStatus.rejected ||
                  record.status == InstitutionSubmissionStatus.actionRequired;
            }
            if (statusFilter == InstitutionSubmissionStatus.verified) {
              return record.status == InstitutionSubmissionStatus.verified ||
                  record.status == InstitutionSubmissionStatus.approved;
            }
            return record.status == statusFilter;
          }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: _DemoNotice(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Text(
            'My Submissions',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: SegmentedButton<InstitutionSubmissionStatus?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(
                value: InstitutionSubmissionStatus.pending,
                label: Text('Pending'),
              ),
              ButtonSegment(
                value: InstitutionSubmissionStatus.verified,
                label: Text('Verified'),
              ),
              ButtonSegment(
                value: InstitutionSubmissionStatus.approved,
                label: Text('Approved'),
              ),
              ButtonSegment(
                value: InstitutionSubmissionStatus.rejected,
                label: Text('Needs action'),
              ),
            ],
            selected: {statusFilter},
            onSelectionChanged: (selected) => onFilterChanged(selected.single),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: const Color(0xFFFFE8D5),
              selectedForegroundColor: _deepOrange,
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _EmptyState(
                  title: 'No matching submissions',
                  message: 'Try another status filter or submit a new FDR.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _InstitutionSubmissionTile(
                    record: visible[index],
                    onTap: () => onOpenSubmission(visible[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class InstitutionSubmissionDetailPage extends StatelessWidget {
  const InstitutionSubmissionDetailPage({
    super.key,
    required this.submissionId,
  });

  final String submissionId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: InstitutionDemoStore.instance,
    builder: (context, _) {
      final store = InstitutionDemoStore.instance;
      final record = store.submissionById(submissionId);
      final fdrRecord = record == null
          ? null
          : DemoFdrPortalStore.instance.fdrRecordForSubmission(record.id);
      final releaseCase = record == null
          ? null
          : store.releaseCaseForSubmission(record.id);
      final clarification = record == null
          ? null
          : DemoFdrPortalStore.instance.clarificationForSubmission(record.id);
      return _InstitutionSubpage(
        title: 'Submission Details',
        selectedTab: 1,
        child: record == null
            ? const _EmptyState(
                title: 'Submission not found',
                message: 'This record may no longer be available.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  const _DemoNotice(),
                  const SizedBox(height: 14),
                  _InstitutionSubmissionTile(record: record, onTap: () {}),
                  const SizedBox(height: 12),
                  _InfoPanel(
                    title: 'FDR information',
                    rows: {
                      'FDR number': record.fdrNumber,
                      'Bank': record.bankName,
                      'Deposit amount': _money(record.amount),
                      'Submitted': _formatDate(record.submittedOn),
                      'Submission ID': record.id,
                      'Institution': _institutionName,
                      'Institution ID': record.institutionId,
                      'Case type': record.caseType,
                      if (fdrRecord != null)
                        'Maturity date': fdrRecord.maturityDate,
                      if (fdrRecord?.parentFdrReference != null)
                        'Renewed from': fdrRecord!.parentFdrReference!,
                      if (record.requestedAmount != null)
                        'Requested amount': _money(record.requestedAmount!),
                      if (record.retainedBalance != null)
                        'Retained balance': _money(record.retainedBalance!),
                      if (record.reason != null)
                        'Request reason': record.reason!,
                    },
                  ),
                  if (record.rejectionReason != null) ...[
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Previous rejection reason',
                      rows: {'Reason': record.rejectionReason!},
                    ),
                  ],
                  if (record.correctionHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Correction history',
                      rows: {
                        for (
                          var index = 0;
                          index < record.correctionHistory.length;
                          index++
                        )
                          'Correction ${index + 1}':
                              record.correctionHistory[index],
                      },
                    ),
                  ],
                  if (record.issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Current verification issues',
                      rows: {
                        for (
                          var index = 0;
                          index < record.issues.length;
                          index++
                        )
                          'Issue ${index + 1}': record.issues[index],
                      },
                    ),
                  ],
                  if (clarification != null) ...[
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Officer clarification',
                      rows: {
                        'Status': clarification.status,
                        'Review section': clarification.reviewSection,
                        'Officer':
                            '${clarification.officerName} (${clarification.officerId})',
                        'Remark': clarification.remark,
                        if (clarification.requiredDocument != null)
                          'Required document': clarification.requiredDocument!,
                        if (clarification.response != null)
                          'Response': clarification.response!,
                        if (clarification.documentStatus != null)
                          'Document status': clarification.documentStatus!,
                      },
                    ),
                    if (clarification.status == 'Clarification Requested')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _showFdrClarificationResponse(
                            context,
                            clarification: clarification,
                          ),
                          icon: const Icon(Icons.reply_outlined),
                          label: const Text('Respond to clarification'),
                        ),
                      ),
                  ],
                  if (releaseCase != null) ...[
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Required documents',
                      rows: {
                        for (final document in releaseCase.checklist)
                          document.name: document.status,
                      },
                    ),
                    for (final document in releaseCase.checklist)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final checksum = await DemoFdrPortalStore.instance
                                  .pickAndReplaceRequiredDocument(
                                    caseId: releaseCase.caseId,
                                    fileName: document.fileName,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    checksum == null
                                        ? 'Document selection cancelled.'
                                        : '${document.name} uploaded. SHA-256: $checksum',
                                  ),
                                ),
                              );
                            } on ArgumentError catch (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error.message.toString()),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text('Replace ${document.name}'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _InfoPanel(
                      title: 'Officer Remarks & Clarifications',
                      rows: {
                        'Case status': releaseCase.status,
                        for (final clearance in releaseCase.clearances)
                          clearance.name: _clearanceSummary(clearance),
                      },
                    ),
                    if (releaseCase.history.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoPanel(
                        title: 'Case history',
                        rows: {
                          for (
                            var index = 0;
                            index < releaseCase.history.length;
                            index++
                          )
                            '${releaseCase.history[index].action} · ${releaseCase.history[index].at.toLocal()}':
                                '${releaseCase.history[index].actor}: ${releaseCase.history[index].remark}',
                        },
                      ),
                    ],
                    for (final clearance in releaseCase.clearances)
                      for (final remark in clearance.remarkHistory)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _InfoPanel(
                            title: '${clearance.name} · ${remark.timestamp}',
                            rows: {
                              'Officer': remark.officerId,
                              'Remark': remark.text,
                              'Status': clearance.status,
                            },
                          ),
                        ),
                    for (final clearance in releaseCase.clearances)
                      if (clearance.status == 'Clarification Requested')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _showClarificationResponse(
                              context,
                              submissionId: record.id,
                              clearance: clearance,
                            ),
                            icon: const Icon(Icons.reply_outlined),
                            label: Text('Respond to ${clearance.name}'),
                          ),
                        ),
                    for (final clearance in releaseCase.clearances)
                      if (clearance.response != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _InfoPanel(
                            title: '${clearance.name} response',
                            rows: {
                              'Response': clearance.response!,
                              if (clearance.responseTimestamp != null)
                                'Submitted': clearance.responseTimestamp!,
                              'Status': clearance.status,
                            },
                          ),
                        ),
                  ],
                  if (record.status == InstitutionSubmissionStatus.rejected &&
                      record.caseType == 'FDR Submission') ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => InstitutionCorrectionPage(
                            submissionId: record.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Correct and Resubmit'),
                      style: FilledButton.styleFrom(backgroundColor: _orange),
                    ),
                  ],
                  if (record.status == InstitutionSubmissionStatus.pending)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Corrected submission is awaiting officer review.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
      );
    },
  );

  Future<void> _showFdrClarificationResponse(
    BuildContext context, {
    required OfficerClarification clarification,
  }) async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to clarification'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Response',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Submit response'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (response == null) return;
    DemoFdrPortalStore.instance.respondToFdrClarification(
      submissionId: clarification.submissionId,
      response: response,
    );
  }

  Future<void> _showClarificationResponse(
    BuildContext context, {
    required String submissionId,
    required ClearanceState clearance,
  }) async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to ${clearance.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Response',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Submit response'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (response == null) return;
    DemoFdrPortalStore.instance.respondToClarification(
      submissionId: submissionId,
      clearanceName: clearance.name,
      response: response,
    );
  }
}

String _clearanceSummary(ClearanceState clearance) {
  final updated = clearance.lastUpdated == null
      ? ''
      : ' · ${clearance.lastUpdated}';
  return '${clearance.status}$updated\n${clearance.remark}';
}

class InstitutionCorrectionPage extends StatefulWidget {
  const InstitutionCorrectionPage({super.key, required this.submissionId});

  final String submissionId;

  @override
  State<InstitutionCorrectionPage> createState() =>
      _InstitutionCorrectionPageState();
}

class _InstitutionCorrectionPageState extends State<InstitutionCorrectionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankController;
  late final TextEditingController _fdrController;
  late final TextEditingController _declaredAmountController;
  late final TextEditingController _receiptAmountController;
  VerificationSummary? _verification;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final record = DemoFdrPortalStore.instance.fdrRecordForSubmission(
      widget.submissionId,
    );
    _bankController = TextEditingController(text: record?.bank ?? '');
    _fdrController = TextEditingController(text: record?.fdrNumber ?? '');
    _declaredAmountController = TextEditingController(
      text: record?.declaredDepositAmount.toString() ?? '',
    );
    _receiptAmountController = TextEditingController(
      text: record?.receiptAmount.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _bankController.dispose();
    _fdrController.dispose();
    _declaredAmountController.dispose();
    _receiptAmountController.dispose();
    super.dispose();
  }

  void _saveCorrection() {
    if (!_formKey.currentState!.validate()) return;
    final summary = DemoFdrPortalStore.instance.saveInstitutionCorrection(
      submissionId: widget.submissionId,
      institutionId: _institutionId,
      bank: _bankController.text.trim(),
      fdrNumber: _fdrController.text.trim(),
      declaredAmount: int.parse(_declaredAmountController.text.trim()),
      receiptAmount: int.parse(_receiptAmountController.text.trim()),
    );
    setState(() {
      _verification = summary;
      _saved = true;
    });
  }

  void _resubmit() {
    final store = DemoFdrPortalStore.instance;
    final resubmitted = store.resubmitCorrectedSubmission(
      widget.submissionId,
      _institutionId,
    );
    if (resubmitted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _verification = store.lastVerification);
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _positiveAmount(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    if (amount == null || amount <= 0) {
      return 'Enter an amount greater than zero.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => _InstitutionSubpage(
    title: 'Correct FDR Submission',
    selectedTab: 1,
    child: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const SizedBox(height: 14),
          TextFormField(
            controller: _bankController,
            decoration: const InputDecoration(
              labelText: 'Bank name',
              border: OutlineInputBorder(),
            ),
            validator: _requiredText,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _fdrController,
            decoration: const InputDecoration(
              labelText: 'FDR number',
              border: OutlineInputBorder(),
            ),
            validator: _requiredText,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _declaredAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Declared amount (₹)',
              border: OutlineInputBorder(),
            ),
            validator: _positiveAmount,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _receiptAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Receipt amount (₹)',
              border: OutlineInputBorder(),
            ),
            validator: _positiveAmount,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saveCorrection,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Corrected Details'),
            style: FilledButton.styleFrom(backgroundColor: _orange),
          ),
          if (_saved && _verification != null) ...[
            const SizedBox(height: 14),
            _InfoPanel(
              title: _verification!.blocking == 0
                  ? 'Verification passed'
                  : 'Blocking issues remain',
              rows: _verification!.issues.isEmpty
                  ? const {'Result': 'No blocking discrepancies remain.'}
                  : {
                      for (
                        var index = 0;
                        index < _verification!.issues.length;
                        index++
                      )
                        'Issue ${index + 1}':
                            _verification!.issues[index].message,
                    },
            ),
            const SizedBox(height: 10),
            if (_verification!.blocking == 0)
              FilledButton.icon(
                onPressed: _resubmit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Resubmit for Officer Review'),
                style: FilledButton.styleFrom(backgroundColor: _deepOrange),
              )
            else
              const Text(
                'Resolve every blocking issue before resubmitting.',
                style: TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
          ],
        ],
      ),
    ),
  );
}

class InstitutionNewSubmissionPage extends StatefulWidget {
  const InstitutionNewSubmissionPage({super.key});

  @override
  State<InstitutionNewSubmissionPage> createState() =>
      _InstitutionNewSubmissionPageState();
}

class _InstitutionNewSubmissionPageState
    extends State<InstitutionNewSubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _fdrController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptAmountController = TextEditingController(text: '500000');
  final _issueDateController = TextEditingController();
  final _maturityDateController = TextEditingController();
  final _declaredTenureController = TextEditingController(text: '36');
  final _enteredTenureController = TextEditingController(text: '36');
  final _lienController = TextEditingController(text: 'No lien');

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final issueDate = _formatDate(today);
    final maturityDate = _formatDate(
      DateTime(today.year + 3, today.month, today.day),
    );
    _issueDateController.text = issueDate;
    _maturityDateController.text = maturityDate;
  }

  @override
  void dispose() {
    _bankController.dispose();
    _fdrController.dispose();
    _amountController.dispose();
    _receiptAmountController.dispose();
    _issueDateController.dispose();
    _maturityDateController.dispose();
    _declaredTenureController.dispose();
    _enteredTenureController.dispose();
    _lienController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final submission = InstitutionDemoStore.instance.addSubmission(
      fdrNumber: _fdrController.text.trim(),
      bankName: _bankController.text.trim(),
      amount: int.parse(_amountController.text.trim()),
      receiptAmount: int.parse(_receiptAmountController.text.trim()),
      issueDate: _issueDateController.text.trim(),
      maturityDate: _maturityDateController.text.trim(),
      declaredTenureMonths: int.parse(_declaredTenureController.text.trim()),
      enteredTenureMonths: int.parse(_enteredTenureController.text.trim()),
      lienInformation: _lienController.text.trim(),
      documents: const [
        DemoDocument(
          name: 'FDR receipt',
          fileName: 'fdr_receipt.pdf',
          status: 'Attached — Demo',
        ),
        DemoDocument(
          name: 'Institution request letter',
          fileName: 'request_letter.pdf',
          status: 'Attached — Demo',
        ),
        DemoDocument(
          name: 'Bank confirmation letter',
          fileName: 'bank_confirmation.pdf',
          status: 'Attached — Demo',
        ),
      ],
    );
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${submission.fdrNumber} added to submissions.')),
    );
  }

  String? _positiveAmount(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    return amount == null || amount <= 0
        ? 'Enter an amount greater than zero'
        : null;
  }

  @override
  Widget build(BuildContext context) => _InstitutionSubpage(
    title: 'Submit New FDR',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _DemoNotice(),
        const SizedBox(height: 14),
        const Text(
          'FDR submission',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Enter receipt details. The record is saved locally as Pending Verification.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InputLabel(label: 'Bank name'),
              TextFormField(
                controller: _bankController,
                decoration: _fieldDecoration('Enter bank name'),
                textCapitalization: TextCapitalization.words,
                validator: _required,
              ),
              const SizedBox(height: 14),
              _InputLabel(label: 'FDR number'),
              TextFormField(
                controller: _fdrController,
                decoration: _fieldDecoration('Enter FDR reference'),
                textCapitalization: TextCapitalization.characters,
                validator: _required,
              ),
              const SizedBox(height: 14),
              _InputLabel(label: 'Deposit amount (INR)'),
              TextFormField(
                controller: _amountController,
                decoration: _fieldDecoration('e.g. 500000'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Additional verification details'),
                subtitle: const Text('Dates, tenure, lien, and documents'),
                children: [
                  _InputLabel(label: 'Receipt amount (INR)'),
                  TextFormField(
                    controller: _receiptAmountController,
                    decoration: _fieldDecoration('Amount shown on the receipt'),
                    keyboardType: TextInputType.number,
                    validator: _positiveAmount,
                  ),
                  const SizedBox(height: 14),
                  _InputLabel(label: 'Issue date'),
                  TextFormField(
                    controller: _issueDateController,
                    decoration: _fieldDecoration('e.g. 26 Oct 2026'),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  _InputLabel(label: 'Maturity date'),
                  TextFormField(
                    controller: _maturityDateController,
                    decoration: _fieldDecoration('e.g. 26 Oct 2029'),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  _InputLabel(label: 'Declared tenure (months)'),
                  TextFormField(
                    controller: _declaredTenureController,
                    decoration: _fieldDecoration('e.g. 36'),
                    keyboardType: TextInputType.number,
                    validator: _positiveAmount,
                  ),
                  const SizedBox(height: 14),
                  _InputLabel(label: 'Entered tenure (months)'),
                  TextFormField(
                    controller: _enteredTenureController,
                    decoration: _fieldDecoration('e.g. 36'),
                    keyboardType: TextInputType.number,
                    validator: _positiveAmount,
                  ),
                  const SizedBox(height: 14),
                  _InputLabel(label: 'Lien information'),
                  TextFormField(
                    controller: _lienController,
                    decoration: _fieldDecoration(
                      'Enter lien or security details',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 18),
                  const _InputLabel(label: 'Supporting documents'),
                  const SizedBox(height: 6),
                  _DummyDocumentAttachment(
                    fileName: 'fdr_receipt.pdf',
                    description: 'Fixed Deposit Receipt',
                  ),
                  const SizedBox(height: 8),
                  _DummyDocumentAttachment(
                    fileName: 'request_letter.pdf',
                    description: 'Institution request letter',
                  ),
                  const SizedBox(height: 8),
                  _DummyDocumentAttachment(
                    fileName: 'bank_confirmation.pdf',
                    description: 'Bank confirmation letter',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Save Submission'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class InstitutionReleaseRequestPage extends StatefulWidget {
  const InstitutionReleaseRequestPage({super.key});

  @override
  State<InstitutionReleaseRequestPage> createState() =>
      _InstitutionReleaseRequestPageState();
}

class _DummyDocumentAttachment extends StatelessWidget {
  const _DummyDocumentAttachment({
    required this.fileName,
    required this.description,
  });

  final String fileName;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        const Icon(Icons.picture_as_pdf_outlined, color: _deepOrange, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fileName,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const Text(
          'Attached — Demo',
          style: TextStyle(
            color: Color(0xFF15803D),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _InstitutionReleaseRequestPageState
    extends State<InstitutionReleaseRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _successorController = TextEditingController();
  final _mergerReferenceController = TextEditingController();
  final _effectiveDateController = TextEditingController();
  String? _fdrNumber;
  String _caseType = 'Normal Release';

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _successorController.dispose();
    _mergerReferenceController.dispose();
    _effectiveDateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    InstitutionDemoStore.instance.addReleaseRequest(
      fdrNumber: _fdrNumber!,
      requestType: _caseType,
      amount: int.tryParse(_amountController.text.trim()) ?? 0,
      reason: _reasonController.text.trim(),
      caseType: _caseType,
      successorInstitution: _successorController.text.trim(),
      mergerReference: _mergerReferenceController.text.trim(),
      effectiveDate: _effectiveDateController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fdrs = InstitutionDemoStore.instance.fdrSubmissions
        .map((record) => record.fdrNumber)
        .toSet()
        .toList();
    return _InstitutionSubpage(
      title: 'Request Release / Refund',
      selectedTab: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 12),
          const _InfoBanner(
            text: 'Requests are saved locally until they are reviewed.',
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _InputLabel(label: 'FDR reference'),
                DropdownButtonFormField<String>(
                  initialValue: _fdrNumber,
                  isExpanded: true,
                  decoration: _fieldDecoration('Select an FDR'),
                  items: [
                    for (final fdr in fdrs)
                      DropdownMenuItem(value: fdr, child: Text(fdr)),
                  ],
                  onChanged: (value) => setState(() => _fdrNumber = value),
                  validator: (value) =>
                      value == null ? 'Select an FDR reference' : null,
                ),
                const SizedBox(height: 14),
                const _InputLabel(label: 'Request type'),
                DropdownButtonFormField<String>(
                  initialValue: _caseType,
                  isExpanded: true,
                  decoration: _fieldDecoration('Select request type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Normal Release',
                      child: Text('Normal Release'),
                    ),
                    DropdownMenuItem(
                      value: 'Progressive Closure',
                      child: Text('Progressive Closure'),
                    ),
                    DropdownMenuItem(value: 'Merger', child: Text('Merger')),
                  ],
                  onChanged: (value) =>
                      setState(() => _caseType = value ?? 'Normal Release'),
                ),
                const SizedBox(height: 14),
                _InputLabel(
                  label: _caseType == 'Merger'
                      ? 'Requested amount (INR), if applicable'
                      : 'Requested amount (INR)',
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: _fieldDecoration('Enter amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_caseType != 'Progressive Closure' &&
                        (value == null || value.trim().isEmpty)) {
                      return null;
                    }
                    final amount = int.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    final selectedFdr = InstitutionDemoStore
                        .instance
                        .fdrSubmissions
                        .where((record) => record.fdrNumber == _fdrNumber)
                        .firstOrNull;
                    if (_caseType == 'Progressive Closure' &&
                        selectedFdr != null &&
                        amount > selectedFdr.amount) {
                      return 'Amount cannot exceed the FDR deposit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const _InputLabel(label: 'Reason'),
                TextFormField(
                  controller: _reasonController,
                  decoration: _fieldDecoration('Describe the request'),
                  minLines: 3,
                  maxLines: 5,
                  validator: _required,
                ),
                if (_caseType == 'Merger') ...[
                  const SizedBox(height: 14),
                  const _InputLabel(label: 'Successor institution'),
                  TextFormField(
                    controller: _successorController,
                    decoration: _fieldDecoration('Enter successor institution'),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  const _InputLabel(label: 'Merger reference'),
                  TextFormField(
                    controller: _mergerReferenceController,
                    decoration: _fieldDecoration('Enter merger reference'),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  const _InputLabel(label: 'Effective date'),
                  TextFormField(
                    controller: _effectiveDateController,
                    decoration: _fieldDecoration('e.g. 01 Nov 2026'),
                    validator: _required,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Save Request'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionReleaseList extends StatelessWidget {
  const _InstitutionReleaseList({required this.onCreateRequest});

  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final requests = InstitutionDemoStore.instance.releaseRequests;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _DemoNotice(),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Release / Refund',
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'New release or refund request',
              onPressed: onCreateRequest,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const _InfoBanner(
          text: 'Requests remain saved locally until an officer reviews them.',
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          const _EmptyState(
            title: 'No release requests',
            message: 'Create a release or refund request draft to begin.',
          )
        else
          for (final request in requests)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoPanel(
                  title: '${request.requestType} request · ${request.id}',
                  rows: {
                    'FDR': request.fdrNumber,
                    'Amount': _money(request.amount),
                    'Submitted': _formatDate(request.submittedOn),
                    'Status': request.status,
                    'Reason': request.reason,
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => InstitutionSubmissionDetailPage(
                          submissionId: request.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('View history'),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _InstitutionProfile extends StatelessWidget {
  const _InstitutionProfile({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
    children: [
      const _DemoNotice(),
      const SizedBox(height: 20),
      const Center(
        child: CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFFFE8D5),
          child: Text(
            'IA',
            style: TextStyle(
              color: _deepOrange,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          'Institution Administrator',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 18),
      _InfoPanel(
        title: 'Institution profile',
        rows: {
          'Institution': _institutionName,
          'Institution ID': _institutionId,
          'Access role': 'Institution user',
        },
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: onSignOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class _InstitutionSubpage extends StatelessWidget {
  const _InstitutionSubpage({
    required this.title,
    required this.child,
    this.selectedTab = 0,
  });

  final String title;
  final Widget child;
  final int selectedTab;

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: _paper,
      surfaceTintColor: Colors.transparent,
    ),
    body: child,
    bottomNavigationBar: NavigationBar(
      height: 88,
      selectedIndex: selectedTab,
      onDestinationSelected: (index) {
        _institutionSelectedTab.value = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFE8D5),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'My Submissions',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Release / Refund',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class _InstitutionSubmissionTile extends StatelessWidget {
  const _InstitutionSubmissionTile({required this.record, required this.onTap});

  final InstitutionSubmission record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    record.fdrNumber,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: record.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.bankName,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                Text(
                  _money(record.amount),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDate(record.submittedOn),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (record.requestedAmount != null)
                  Text(
                    'Request ${_money(record.requestedAmount!)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    color: _deepOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 15, color: _deepOrange),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.width,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 104,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('institution-metric:$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const Spacer(),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _deepOrange, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final Object status;

  @override
  Widget build(BuildContext context) {
    final enumStatus = status is Enum ? status as Enum : null;
    final label = enumStatus?.displayLabel ?? status.toString();
    final foreground = enumStatus?.displayColor ?? _deepOrange;
    final background = foreground.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: _deepOrange,
          ),
          child: Text(actionLabel!),
        ),
    ],
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: _deepOrange),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF9A3412),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, color: _muted, size: 34),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _orange, width: 1.5),
  ),
);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

String _money(int amount) {
  final digits = amount.toString();
  if (digits.length <= 3) return '₹$digits';
  final prefix = digits.substring(0, digits.length - 3);
  final groupedPrefix = StringBuffer();
  for (var index = 0; index < prefix.length; index++) {
    if (index > 0 && (prefix.length - index) % 2 == 0) {
      groupedPrefix.write(',');
    }
    groupedPrefix.write(prefix[index]);
  }
  return '₹$groupedPrefix,${digits.substring(digits.length - 3)}';
}

int _currencyAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

DateTime _parseSubmissionDate(String value) {
  final parts = value.split(' ');
  if (parts.length != 3) return DateTime.now();
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  return DateTime(
    int.tryParse(parts[2]) ?? DateTime.now().year,
    months[parts[1]] ?? 1,
    int.tryParse(parts[0]) ?? 1,
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_monthNames[date.month - 1]} ${date.year}';

const _monthNames = [
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
String get _institutionId =>
    portalAuthService.currentClaims?.role == AuthRole.institution
    ? portalAuthService.currentClaims!.institutionId ?? 'INST-DEMO-0042'
    : 'INST-DEMO-0042';

String get _institutionName {
  final claims = portalAuthService.currentClaims;
  if (claims?.role != AuthRole.institution ||
      claims?.subject == 'institution-demo') {
    return 'Example Institute of Technology';
  }
  return claims!.subject;
}

const _paper = Color(0xFFFFFBF7);
const _orange = Color(0xFFF97316);
const _deepOrange = Color(0xFFEA580C);
const _ink = Color(0xFF242424);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFEAE6E1);
