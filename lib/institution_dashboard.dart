import 'package:flutter/material.dart';

import 'officer_dashboard.dart';

enum InstitutionSubmissionStatus {
  pending,
  verified,
  approved,
  rejected,
  actionRequired,
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
  });

  final String id;
  final String fdrNumber;
  final String requestType;
  final int amount;
  final String reason;
  final DateTime submittedOn;
  final String caseType;
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

  List<InstitutionReleaseRequest> get releaseRequests => _store
      .dashboardSubmissions
      .where(
        (record) =>
            record.institutionId == _institutionId &&
            record.caseType != 'FDR Submission',
      )
      .map(
        (record) => InstitutionReleaseRequest(
          id: record.caseId ?? record.submissionId,
          fdrNumber: record.reference,
          requestType: record.caseType,
          amount: record.requestedAmount ?? 0,
          reason: record.requestReason ?? '',
          submittedOn: _parseSubmissionDate(record.submittedOn),
          caseType: record.caseType,
        ),
      )
      .toList(growable: false);

  void resetDemoData() {
    _store.resetDemoData();
  }

  InstitutionSubmission? submissionById(String id) {
    final submission = _store.submissionById(id);
    if (submission == null || submission.institutionId != _institutionId) {
      return null;
    }
    return _fromOfficerSubmission(submission);
  }

  InstitutionSubmission addSubmission({
    required String fdrNumber,
    required String bankName,
    required int amount,
  }) {
    final submission = _store.submitInstitutionFdr(
      institution: _institutionName,
      institutionId: _institutionId,
      bank: bankName,
      fdrNumber: fdrNumber,
      amount: amount,
    );
    return _fromOfficerSubmission(submission);
  }

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

  void _openSubmissions([InstitutionSubmissionStatus? status]) {
    setState(() {
      _selectedTab = 1;
      _statusFilter = status;
    });
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
    builder: (context, _) => Scaffold(
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
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() {
          _selectedTab = index;
          if (index != 1) _statusFilter = null;
        }),
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
        const Expanded(
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
                _institutionId,
                style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notifications'),
            content: const Text('No new demo notifications.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.notifications_none_rounded, color: _ink),
      ),
      PopupMenuButton<String>(
        tooltip: 'Institution administrator profile',
        onSelected: (value) {
          if (value == 'profile') setState(() => _selectedTab = 3);
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
          const Text(
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
            subtitle: 'Create a demo request draft',
            icon: Icons.account_balance_wallet_outlined,
            onTap: onReleaseRequest,
          ),
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Items Requiring Attention'),
            const SizedBox(height: 8),
            for (final record in attention)
              for (final issue in record.issues)
                _AttentionRow(
                  issue: issue,
                  record: record,
                  onTap: () => onOpenSubmission(record),
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
            for (final record in recent)
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
    final records = InstitutionDemoStore.instance.submissions;
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
      final record = InstitutionDemoStore.instance.submissionById(submissionId);
      return _InstitutionSubpage(
        title: 'Submission Details',
        child: record == null
            ? const _EmptyState(
                title: 'Submission not found',
                message: 'This demo record may no longer be available.',
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
    child: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
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

  @override
  void dispose() {
    _bankController.dispose();
    _fdrController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final submission = InstitutionDemoStore.instance.addSubmission(
      fdrNumber: _fdrController.text.trim(),
      bankName: _bankController.text.trim(),
      amount: int.parse(_amountController.text.trim()),
    );
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${submission.fdrNumber} added to demo submissions.'),
      ),
    );
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
          'Enter receipt details. This demo saves the record locally as Pending Verification.',
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
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Save Demo Submission'),
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
    final fdrs = InstitutionDemoStore.instance.submissions
        .map((record) => record.fdrNumber)
        .toSet()
        .toList();
    return _InstitutionSubpage(
      title: 'Request Release / Refund',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 12),
          const _InfoBanner(
            text:
                'Requests are stored as local demo drafts only. No release, refund, NOC, or officer approval is performed.',
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
                        .submissions
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
                    label: const Text('Save Demo Request'),
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
          text:
              'Demo requests remain local drafts and do not alter officer release decisions.',
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          const _EmptyState(
            title: 'No release requests',
            message: 'Create a release or refund request draft to begin.',
          )
        else
          for (final request in requests)
            _InfoPanel(
              title: '${request.requestType} request · ${request.id}',
              rows: {
                'FDR': request.fdrNumber,
                'Amount': _money(request.amount),
                'Submitted': _formatDate(request.submittedOn),
                'Reason': request.reason,
              },
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
      const _InfoPanel(
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
  const _InstitutionSubpage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
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
    body: SafeArea(top: false, child: child),
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

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.issue,
    required this.record,
    required this.onTap,
  });

  final String issue;
  final InstitutionSubmission record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
    visualDensity: VisualDensity.compact,
    tileColor: const Color(0xFFFFF7ED),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFFED7AA)),
    ),
    leading: const Icon(
      Icons.warning_amber_rounded,
      color: Color(0xFFB45309),
      size: 20,
    ),
    title: Text(
      issue,
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      record.fdrNumber,
      style: const TextStyle(color: _muted, fontSize: 11),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
    onTap: onTap,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final InstitutionSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      InstitutionSubmissionStatus.pending => (
        'Pending Review',
        const Color(0xFF92400E),
        const Color(0xFFFEF3C7),
      ),
      InstitutionSubmissionStatus.verified => (
        'Verified',
        const Color(0xFF166534),
        const Color(0xFFDCFCE7),
      ),
      InstitutionSubmissionStatus.approved => (
        'Approved',
        const Color(0xFF166534),
        const Color(0xFFDCFCE7),
      ),
      InstitutionSubmissionStatus.rejected => (
        'Rejected',
        const Color(0xFF991B1B),
        const Color(0xFFFEE2E2),
      ),
      InstitutionSubmissionStatus.actionRequired => (
        'Action Required',
        const Color(0xFF9A3412),
        const Color(0xFFFFEDD5),
      ),
    };
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
  Widget build(BuildContext context) => const _InfoBanner(
    text:
        'Demo mode · Sample institution records are fictional and stored on this device only.',
  );
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
const _institutionName = 'Example Institute of Technology';
const _institutionId = 'INST-DEMO-0042';
const _paper = Color(0xFFFFFBF7);
const _orange = Color(0xFFF97316);
const _deepOrange = Color(0xFFEA580C);
const _ink = Color(0xFF242424);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFEAE6E1);
