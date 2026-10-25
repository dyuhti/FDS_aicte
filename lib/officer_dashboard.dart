import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

const _orange = Color(0xFFF97316);
const _releaseOrange = Color(0xFFFF6B1A);
const _deepOrange = Color(0xFFEA580C);
const _ink = Color(0xFF242424);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFEAE6E1);
const _paper = Color(0xFFFFFBF7);

enum SubmissionStatus {
  pendingReview('Pending Review', Color(0xFFB45309)),
  approved('Approved', Color(0xFF15803D)),
  rejected('Rejected', Color(0xFFB91C1C)),
  correctionRequested('Correction', Color(0xFFB45309)),
  blocked('Blocked', Color(0xFFB91C1C));

  const SubmissionStatus(this.label, this.color);

  final String label;
  final Color color;
}

abstract final class VerificationStatus {
  static const pending = SubmissionStatus.pendingReview;
  static const blocked = SubmissionStatus.blocked;
  static const verified = SubmissionStatus.pendingReview;
  static const approved = SubmissionStatus.approved;
  static const rejected = SubmissionStatus.correctionRequested;
}

class Institution {
  const Institution({required this.id, required this.name});

  final String id;
  final String name;
}

enum DemoVerificationScenario { blocked, resolved }

class Submission {
  const Submission({
    required this.institution,
    required this.institutionId,
    required this.submissionId,
    required this.submittedOn,
    required this.reference,
    required this.amount,
    required this.status,
    this.bankName = 'Example National Bank',
    this.caseType = 'FDR Submission',
    this.caseId,
    this.requestedAmount,
    this.retainedBalance,
    this.issues = const [],
    this.requestReason,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.correctionHistory = const [],
    this.verificationPassed = false,
    this.updatedAtOverride,
  });

  factory Submission.fromFields({
    required String id,
    required String institutionId,
    required String institutionName,
    required String fdrReference,
    required String bank,
    required String caseType,
    required int depositAmount,
    required SubmissionStatus status,
    required DateTime updatedAt,
  }) => Submission(
    institution: institutionName,
    institutionId: institutionId,
    submissionId: id,
    submittedOn: _shortDate(updatedAt),
    reference: fdrReference,
    amount: '₹${_formatCurrency(depositAmount)}',
    status: status,
    bankName: bank,
    caseType: caseType,
    updatedAtOverride: updatedAt,
  );

  final String institution;
  final String institutionId;
  final String submissionId;
  final String submittedOn;
  final String reference;
  final String amount;
  final SubmissionStatus status;
  final String bankName;
  final String caseType;
  final String? caseId;
  final int? requestedAmount;
  final int? retainedBalance;
  final String? requestReason;
  final List<String> issues;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final List<String> correctionHistory;
  final bool verificationPassed;
  final DateTime? updatedAtOverride;

  String get id => submissionId;
  String get institutionName => institution;
  String get fdrReference => reference;
  String get bank => bankName;
  int get depositAmount => _parseCurrency(amount);
  DateTime get updatedAt => updatedAtOverride ?? _parseUpdatedAt(submittedOn);
}

typedef FdrSubmission = Submission;

int countByStatus(Iterable<Submission> submissions, SubmissionStatus status) =>
    submissions.where((submission) => submission.status == status).length;

int totalSubmissions(Iterable<Submission> submissions) {
  final records = submissions.toList(growable: false);
  final total = records.length;
  assert(
    SubmissionStatus.values.fold<int>(
          0,
          (sum, status) => sum + countByStatus(records, status),
        ) ==
        total,
  );
  return total;
}

int uniqueInstitutionCount(Iterable<Submission> submissions) =>
    submissions.map((submission) => submission.institutionId).toSet().length;

List<Submission> submissionsByStatus(
  Iterable<Submission> submissions,
  SubmissionStatus status,
) => submissions
    .where((submission) => submission.status == status)
    .toList(growable: false);

Map<String, List<Submission>> groupedByInstitution(
  Iterable<Submission> submissions,
) {
  final grouped = <String, List<Submission>>{};
  for (final submission in submissions) {
    grouped.putIfAbsent(submission.institutionId, () => []).add(submission);
  }
  return grouped.map(
    (id, records) => MapEntry(id, List<Submission>.unmodifiable(records)),
  );
}

int _repositoryCountByStatus(
  Iterable<Submission> submissions,
  SubmissionStatus status,
) => countByStatus(submissions, status);

int _repositoryTotalSubmissions(Iterable<Submission> submissions) =>
    totalSubmissions(submissions);

int _repositoryUniqueInstitutionCount(Iterable<Submission> submissions) =>
    uniqueInstitutionCount(submissions);

List<Submission> _repositorySubmissionsByStatus(
  Iterable<Submission> submissions,
  SubmissionStatus status,
) => submissionsByStatus(submissions, status);

Map<String, List<Submission>> _repositoryGroupedByInstitution(
  Iterable<Submission> submissions,
) => groupedByInstitution(submissions);

class OfficerActivity {
  const OfficerActivity({
    required this.description,
    required this.reference,
    required this.when,
    required this.status,
  });

  final String description;
  final String reference;
  final String when;
  final SubmissionStatus status;
}

abstract interface class OfficerDashboardRepository {
  List<FdrSubmission> get submissions;
  List<FdrSubmission> get pendingSubmissions;
  List<OfficerActivity> get recentActivity;
  Map<String, int> get summary;
  List<Institution> get institutions;

  int countByStatus(SubmissionStatus status);
  int get totalSubmissions;
  int get uniqueInstitutionCount;
  List<Submission> submissionsByStatus(SubmissionStatus status);
  Map<String, List<Submission>> groupedByInstitution();
}

class MockOfficerDashboardRepository implements OfficerDashboardRepository {
  const MockOfficerDashboardRepository();

  @override
  List<FdrSubmission> get submissions =>
      DemoFdrPortalStore.instance.dashboardSubmissions;

  @override
  List<FdrSubmission> get pendingSubmissions => submissions
      .where(
        (submission) => submission.status == SubmissionStatus.pendingReview,
      )
      .toList(growable: false);

  @override
  int countByStatus(SubmissionStatus status) =>
      _repositoryCountByStatus(submissions, status);

  @override
  int get totalSubmissions => _repositoryTotalSubmissions(submissions);

  @override
  int get uniqueInstitutionCount =>
      _repositoryUniqueInstitutionCount(submissions);

  @override
  List<Institution> get institutions {
    final byId = <String, Institution>{};
    for (final submission in submissions) {
      byId[submission.institutionId] = Institution(
        id: submission.institutionId,
        name: submission.institution,
      );
    }
    return List<Institution>.unmodifiable(byId.values);
  }

  @override
  List<Submission> submissionsByStatus(SubmissionStatus status) =>
      _repositorySubmissionsByStatus(submissions, status);

  @override
  Map<String, List<Submission>> groupedByInstitution() {
    return _repositoryGroupedByInstitution(submissions);
  }

  @override
  List<OfficerActivity> get recentActivity => const [
    OfficerActivity(
      description: 'FDR verification completed',
      reference: 'Example Institute of Technology',
      when: 'Yesterday',
      status: VerificationStatus.approved,
    ),
    OfficerActivity(
      description: 'New submission received',
      reference: 'National College of Engineering',
      when: '2 days ago',
      status: VerificationStatus.pending,
    ),
    OfficerActivity(
      description: 'Document flagged for correction',
      reference: 'Metropolitan Institute of Science',
      when: '3 days ago',
      status: VerificationStatus.rejected,
    ),
  ];

  @override
  Map<String, int> get summary {
    return {
      'Pending Review': countByStatus(SubmissionStatus.pendingReview),
      'Approved': countByStatus(SubmissionStatus.approved),
      'Rejected': countByStatus(SubmissionStatus.rejected),
      'Needs Correction': countByStatus(SubmissionStatus.correctionRequested),
      'Blocked': countByStatus(SubmissionStatus.blocked),
      'Total Submissions': totalSubmissions,
      'Total Institutions': uniqueInstitutionCount,
    };
  }
}

class OfficerDashboardScreen extends StatefulWidget {
  const OfficerDashboardScreen({
    super.key,
    required this.userId,
    required this.onSignOut,
    this.repository = const MockOfficerDashboardRepository(),
  });

  final String userId;
  final VoidCallback onSignOut;
  final OfficerDashboardRepository repository;

  @override
  State<OfficerDashboardScreen> createState() => _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState extends State<OfficerDashboardScreen> {
  int _selectedTab = 0;

  static const _destinations = [
    'Home',
    'Submissions',
    'Institutions',
    'Profile',
  ];

  void _openPage(String title, {String? subtitle}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DestinationPage(
          title: title,
          subtitle: subtitle,
          onReviewSubmission: _openReview,
        ),
      ),
    );
  }

  void _openReview(FdrSubmission submission) {
    final store = DemoFdrPortalStore.instance;
    store.selectSubmission(submission.submissionId);
    if (submission.caseId != null) {
      store.selectReleaseCase(submission.caseId!);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => submission.caseId == null
            ? const _FdrVerificationDetailPage()
            : const _ReleaseCasePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedTab == 0;
    final title = _destinations[_selectedTab];
    return OfficerPortalShell(
      userId: widget.userId,
      onNotifications: () => _openPage(
        'Notifications',
        subtitle: 'No live notification service is connected in demo mode.',
      ),
      onProfile: () => setState(() => _selectedTab = 3),
      onSignOut: widget.onSignOut,
      body: isHome
          ? AnimatedBuilder(
              animation: DemoFdrPortalStore.instance,
              builder: (context, _) => _DashboardHome(
                repository: widget.repository,
                onOpenPage: _openPage,
                onReviewSubmission: _openReview,
              ),
            )
          : _selectedTab == 1
          ? _SubmissionListView(
              repository: widget.repository,
              initialFilter: SubmissionListFilter.all,
              onReviewSubmission: _openReview,
            )
          : _DestinationBody(
              title: title,
              subtitle: _tabSubtitle(_selectedTab),
              onOpenPage: _openPage,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
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
            label: 'Submissions',
          ),
          NavigationDestination(
            icon: Icon(Icons.domain_outlined),
            selectedIcon: Icon(Icons.domain_rounded),
            label: 'Institutions',
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
}

class OfficerPortalShell extends StatelessWidget {
  const OfficerPortalShell({
    super.key,
    required this.body,
    this.title,
    this.userId = 'officer',
    this.onNotifications,
    this.onProfile,
    this.onSignOut,
    this.onBack,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? title;
  final String userId;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onSignOut;
  final VoidCallback? onBack;
  final Widget? bottomNavigationBar;

  void _showDemoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    resizeToAvoidBottomInset: true,
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 58,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1E4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: _deepOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AICTE Officer Portal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Security Deposit Management',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed:
                            onNotifications ??
                            () => _showDemoMessage(
                              context,
                              'Notifications are demo-only. No live notification service is connected.',
                            ),
                        icon: const _NotificationIcon(),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Officer profile',
                        onSelected: (value) {
                          if (value == 'profile') {
                            onProfile?.call();
                            if (onProfile == null) {
                              _showDemoMessage(
                                context,
                                'Profile settings are demo-only. No backend profile is connected.',
                              );
                            }
                          } else if (value == 'signout') {
                            onSignOut?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: Text('Profile settings'),
                          ),
                          if (onSignOut != null)
                            const PopupMenuItem(
                              value: 'signout',
                              child: Text('Sign out'),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10, left: 2),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: const Color(0xFFFFE8D5),
                            child: Text(
                              _initials(userId),
                              style: const TextStyle(
                                color: _deepOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (title != null)
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 1, color: _line),
            ],
          ),
        ),
        Expanded(child: SafeArea(top: false, child: body)),
      ],
    ),
    bottomNavigationBar: bottomNavigationBar,
  );
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.repository,
    required this.onOpenPage,
    required this.onReviewSubmission,
  });

  final OfficerDashboardRepository repository;
  final void Function(String, {String? subtitle}) onOpenPage;
  final ValueChanged<FdrSubmission> onReviewSubmission;

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 700 ? 28.0 : 18.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back, Officer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review submissions and manage institutional security deposits.',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: _muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _DemoNotice(),
                  const SizedBox(height: 18),
                  _SectionHeading(
                    title: 'Overview',
                    trailing: 'Live demo state',
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, gridConstraints) => GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: gridConstraints.maxWidth < 380
                          ? 1.45
                          : 1.72,
                      children: [
                        _MetricCard(
                          label: 'Pending Review',
                          value: repository.countByStatus(
                            SubmissionStatus.pendingReview,
                          ),
                          note: 'Awaiting officer review',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFFD97706),
                          onTap: () => onOpenPage(
                            'Pending Review',
                            subtitle:
                                'Shared submissions awaiting officer review.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Approved',
                          value: repository.countByStatus(
                            SubmissionStatus.approved,
                          ),
                          note: 'Final approval reached',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF16A34A),
                          onTap: () => onOpenPage(
                            'Approved Submissions',
                            subtitle:
                                'Demo cases that reached an approval state.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Rejected',
                          value: repository.countByStatus(
                            SubmissionStatus.rejected,
                          ),
                          note: 'Rejected submissions',
                          icon: Icons.cancel_outlined,
                          color: const Color(0xFFDC2626),
                          onTap: () => onOpenPage(
                            'Rejected Submissions',
                            subtitle:
                                'Demo submissions genuinely marked rejected.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Needs Correction',
                          value: repository.countByStatus(
                            SubmissionStatus.correctionRequested,
                          ),
                          note: 'Correction requested',
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFFB45309),
                          onTap: () => onOpenPage(
                            'Correction Submissions',
                            subtitle: 'Submissions returned for correction.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Blocked',
                          value: repository.countByStatus(
                            SubmissionStatus.blocked,
                          ),
                          note: 'Blocked submissions',
                          icon: Icons.block_rounded,
                          color: const Color(0xFFB91C1C),
                          onTap: () => onOpenPage(
                            'Blocked Submissions',
                            subtitle: 'Submissions blocked from review.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Total Submissions',
                          value: repository.totalSubmissions,
                          note: 'All cases',
                          icon: Icons.assignment_outlined,
                          color: _orange,
                          onTap: () => onOpenPage(
                            'All Submissions',
                            subtitle: 'All submitted cases.',
                          ),
                        ),
                        _MetricCard(
                          label: 'Total Institutions',
                          value: repository.uniqueInstitutionCount,
                          note: 'Unique institutions',
                          icon: Icons.account_balance_outlined,
                          color: _orange,
                          onTap: () => onOpenPage(
                            'Institution Registry',
                            subtitle: 'Demo institution registry.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionHeading(title: 'Quick Actions'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.fact_check_outlined,
                          label: 'Review Submissions',
                          onTap: () => onOpenPage(
                            'Submissions',
                            subtitle:
                                'Submission queue placeholder for the demo.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.domain_outlined,
                          label: 'Institution Registry',
                          onTap: () => onOpenPage(
                            'Institution Registry',
                            subtitle:
                                'Registered institution list placeholder.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _QuickAction(
                    icon: Icons.analytics_outlined,
                    label: 'Reports',
                    onTap: () => onOpenPage(
                      'Reports',
                      subtitle:
                          'Deposit verification and approval reports will appear here.',
                    ),
                  ),
                  const SizedBox(height: 21),
                  _SectionHeading(
                    title: 'Pending Verification',
                    actionLabel: 'View all',
                    onAction: () => onOpenPage(
                      'Pending Verification',
                      subtitle: 'All shared submissions awaiting review.',
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Latest institution submissions awaiting review.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final submission in repository.pendingSubmissions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _SubmissionCard(
                        submission: submission,
                        onReview: () => onReviewSubmission(submission),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _SectionHeading(
                    title: 'Recent Activity',
                    trailing: 'Mock activity',
                  ),
                  const SizedBox(height: 8),
                  _ActivityCard(activities: repository.recentActivity),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(Icons.notifications_none_rounded, color: _ink),
      Positioned(
        top: -1,
        right: -1,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _orange,
            shape: BoxShape.circle,
            border: Border.all(color: _paper, width: 1),
          ),
        ),
      ),
    ],
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E8),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF8D8B8)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: _deepOrange, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Demo mode · All institutions, cases and statuses shown are fictional sample data.',
            style: TextStyle(
              color: Color(0xFF8A4315),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? trailing;
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
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 7),
          ),
          child: Text(
            actionLabel!,
            style: const TextStyle(
              color: _deepOrange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
      else if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int value;
  final String note;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('metric:$label'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _line),
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
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(icon, color: _deepOrange, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission, required this.onReview});

  final FdrSubmission submission;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                submission.institution,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: submission.status),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 14,
          runSpacing: 5,
          children: [
            _DetailPair(label: 'Submission', value: submission.submissionId),
            _DetailPair(label: 'Submitted', value: submission.submittedOn),
            _DetailPair(label: 'FDR reference', value: submission.reference),
            _DetailPair(
              label: 'Deposit',
              value: submission.amount,
              emphasized: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Review'),
            style: TextButton.styleFrom(
              foregroundColor: _deepOrange,
              minimumSize: const Size(70, 38),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 10),
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: _muted),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: emphasized ? _ink : const Color(0xFF4B5563),
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final background = switch (status) {
      SubmissionStatus.pendingReview => const Color(0xFFFFF7E8),
      SubmissionStatus.approved => const Color(0xFFF0FDF4),
      SubmissionStatus.rejected => const Color(0xFFFEF2F2),
      SubmissionStatus.correctionRequested => const Color(0xFFFFF7E8),
      SubmissionStatus.blocked => const Color(0xFFFEF2F2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        style: TextStyle(
          color: status.color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities});

  final List<OfficerActivity> activities;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      children: [
        for (var index = 0; index < activities.length; index++) ...[
          _ActivityRow(activity: activities[index]),
          if (index < activities.length - 1)
            const Divider(height: 1, color: _line),
        ],
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final OfficerActivity activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: activity.status.color, size: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            activity.when,
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _DestinationBody extends StatelessWidget {
  const _DestinationBody({
    required this.title,
    required this.subtitle,
    required this.onOpenPage,
  });

  final String title;
  final String subtitle;
  final void Function(String, {String? subtitle}) onOpenPage;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_tabIcon(title), color: _orange, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 13),
            const _DemoNotice(),
            const SizedBox(height: 18),
            if (title == 'Submissions' || title == 'Pending Review')
              OutlinedButton.icon(
                onPressed: () => onOpenPage(
                  'Pending Verification',
                  subtitle: 'Sample submission queue.',
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Open pending verification queue'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DestinationPage extends StatefulWidget {
  const _DestinationPage({
    required this.title,
    this.subtitle,
    this.onReviewSubmission,
  });

  final String title;
  final String? subtitle;
  final ValueChanged<FdrSubmission>? onReviewSubmission;

  @override
  State<_DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<_DestinationPage> {
  late SubmissionListFilter _filter = _filterForTitle(widget.title);

  @override
  Widget build(BuildContext context) {
    final isSubmissionList =
        widget.title == 'Submissions' ||
        widget.title == 'All Submissions' ||
        widget.title == 'Pending Review' ||
        widget.title == 'Pending Verification' ||
        widget.title == 'Approved Submissions' ||
        widget.title == 'Rejected Submissions' ||
        widget.title == 'Correction Submissions' ||
        widget.title == 'Blocked Submissions';
    return OfficerPortalShell(
      title: isSubmissionList ? _filterTitle(_filter) : widget.title,
      body: isSubmissionList
          ? _SubmissionListView(
              repository: const MockOfficerDashboardRepository(),
              initialFilter: _filter,
              onReviewSubmission: widget.onReviewSubmission,
              onFilterChanged: (filter) => setState(() => _filter = filter),
              showHeading: false,
            )
          : _DestinationBody(
              title: widget.title,
              subtitle:
                  widget.subtitle ??
                  'This destination is prepared for the connected portal workflow.',
              onOpenPage: (nextTitle, {subtitle}) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _DestinationPage(
                    title: nextTitle,
                    subtitle: subtitle,
                    onReviewSubmission: widget.onReviewSubmission,
                  ),
                ),
              ),
            ),
    );
  }
}

SubmissionListFilter _filterForTitle(String title) => switch (title) {
  'Pending Review' ||
  'Pending Verification' => SubmissionListFilter.pendingReview,
  'Approved Submissions' => SubmissionListFilter.approved,
  'Rejected Submissions' => SubmissionListFilter.rejected,
  'Correction Submissions' ||
  'Returned for Correction' => SubmissionListFilter.correction,
  'Blocked Submissions' => SubmissionListFilter.blocked,
  _ => SubmissionListFilter.all,
};

String _filterTitle(SubmissionListFilter filter) => switch (filter) {
  SubmissionListFilter.all => 'All Submissions',
  SubmissionListFilter.pendingReview => 'Pending Review',
  SubmissionListFilter.approved => 'Approved Submissions',
  SubmissionListFilter.rejected => 'Rejected Submissions',
  SubmissionListFilter.correction => 'Correction Submissions',
  SubmissionListFilter.blocked => 'Blocked Submissions',
};

enum SubmissionListFilter {
  all,
  pendingReview,
  approved,
  rejected,
  correction,
  blocked,
}

class _SubmissionListView extends StatefulWidget {
  const _SubmissionListView({
    required this.repository,
    required this.initialFilter,
    this.onReviewSubmission,
    this.onFilterChanged,
    this.showHeading = true,
  });

  final OfficerDashboardRepository repository;
  final SubmissionListFilter initialFilter;
  final ValueChanged<FdrSubmission>? onReviewSubmission;
  final ValueChanged<SubmissionListFilter>? onFilterChanged;
  final bool showHeading;

  @override
  State<_SubmissionListView> createState() => _SubmissionListViewState();
}

class _SubmissionListViewState extends State<_SubmissionListView> {
  late SubmissionListFilter _filter = widget.initialFilter;

  List<Submission> _matching(SubmissionListFilter filter) => switch (filter) {
    SubmissionListFilter.all => widget.repository.submissions,
    SubmissionListFilter.pendingReview => widget.repository.submissionsByStatus(
      SubmissionStatus.pendingReview,
    ),
    SubmissionListFilter.approved => widget.repository.submissionsByStatus(
      SubmissionStatus.approved,
    ),
    SubmissionListFilter.rejected => widget.repository.submissionsByStatus(
      SubmissionStatus.rejected,
    ),
    SubmissionListFilter.correction => widget.repository.submissionsByStatus(
      SubmissionStatus.correctionRequested,
    ),
    SubmissionListFilter.blocked => widget.repository.submissionsByStatus(
      SubmissionStatus.blocked,
    ),
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: DemoFdrPortalStore.instance,
    builder: (context, _) {
      final pending = _matching(SubmissionListFilter.pendingReview);
      final approved = _matching(SubmissionListFilter.approved);
      final rejected = _matching(SubmissionListFilter.rejected);
      final correction = _matching(SubmissionListFilter.correction);
      final blocked = _matching(SubmissionListFilter.blocked);
      final visible = _matching(_filter);
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeading)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
                child: Text(
                  _filterTitle(_filter),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: _DemoNotice(),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: SegmentedButton<SubmissionListFilter>(
                segments: [
                  ButtonSegment(
                    value: SubmissionListFilter.all,
                    label: Text('All (${widget.repository.totalSubmissions})'),
                  ),
                  ButtonSegment(
                    value: SubmissionListFilter.pendingReview,
                    label: Text('Pending Review (${pending.length})'),
                  ),
                  ButtonSegment(
                    value: SubmissionListFilter.approved,
                    label: Text('Approved (${approved.length})'),
                  ),
                  ButtonSegment(
                    value: SubmissionListFilter.rejected,
                    label: Text('Rejected (${rejected.length})'),
                  ),
                  ButtonSegment(
                    value: SubmissionListFilter.correction,
                    label: Text('Correction (${correction.length})'),
                  ),
                  ButtonSegment(
                    value: SubmissionListFilter.blocked,
                    label: Text('Blocked (${blocked.length})'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selected) {
                  setState(() => _filter = selected.single);
                  widget.onFilterChanged?.call(selected.single);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: const Color(0xFFFFE8D5),
                  selectedForegroundColor: _deepOrange,
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _filter == SubmissionListFilter.approved
                                  ? Icons.verified_outlined
                                  : Icons.inbox_outlined,
                              color: _muted,
                              size: 38,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              switch (_filter) {
                                SubmissionListFilter.approved =>
                                  'No approved submissions',
                                SubmissionListFilter.pendingReview =>
                                  'No submissions awaiting review',
                                SubmissionListFilter.rejected =>
                                  'No rejected submissions',
                                SubmissionListFilter.correction =>
                                  'No submissions needing correction',
                                SubmissionListFilter.blocked =>
                                  'No blocked submissions',
                                SubmissionListFilter.all => 'No submissions',
                              },
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Demo records will appear here when their status changes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 9),
                      itemBuilder: (context, index) => _SubmissionRecordCard(
                        submission: visible[index],
                        onReview: widget.onReviewSubmission == null
                            ? null
                            : () => widget.onReviewSubmission!(visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _SubmissionRecordCard extends StatelessWidget {
  const _SubmissionRecordCard({required this.submission, this.onReview});

  final FdrSubmission submission;
  final VoidCallback? onReview;

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                submission.institution,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: submission.status),
          ],
        ),
        const SizedBox(height: 10),
        _DetailPair(label: 'Submission', value: submission.submissionId),
        const SizedBox(height: 5),
        _DetailPair(label: 'Institution ID', value: submission.institutionId),
        const SizedBox(height: 5),
        _DetailPair(label: 'FDR reference', value: submission.reference),
        const SizedBox(height: 5),
        _DetailPair(label: 'Bank', value: submission.bankName),
        const SizedBox(height: 5),
        _DetailPair(
          label: 'Deposit',
          value: submission.amount,
          emphasized: true,
        ),
        if (submission.requestedAmount != null) ...[
          const SizedBox(height: 5),
          _DetailPair(
            label: 'Requested',
            value: '₹${_formatCurrency(submission.requestedAmount!)}',
            emphasized: true,
          ),
        ],
        if (submission.retainedBalance != null) ...[
          const SizedBox(height: 5),
          _DetailPair(
            label: 'Retained',
            value: '₹${_formatCurrency(submission.retainedBalance!)}',
          ),
        ],
        if (submission.approvedAt != null) ...[
          const SizedBox(height: 5),
          _DetailPair(
            label: 'Approved',
            value: _shortDate(submission.approvedAt!),
          ),
        ],
        const SizedBox(height: 8),
        _DetailPair(label: 'Case type', value: submission.caseType),
        if (submission.requestedAmount != null) ...[
          const SizedBox(height: 5),
          _DetailPair(
            label: 'Requested',
            value: '₹${_formatCurrency(submission.requestedAmount!)}',
          ),
        ],
        if (onReview != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Review'),
              style: TextButton.styleFrom(foregroundColor: _deepOrange),
            ),
          ),
        if (submission.approvedBy != null) ...[
          const SizedBox(height: 5),
          _DetailPair(
            label: 'Action',
            value: 'Demo approval by ${submission.approvedBy}',
          ),
        ],
      ],
    ),
  );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} ${_monthName(value.month)} ${value.year}';

String _monthName(int month) => const [
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
][month - 1];

String _initials(String value) {
  final parts = value
      .split(RegExp(r'[@._\-\s]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'OF';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _tabSubtitle(int index) => switch (index) {
  1 => 'Review and track institution FDR submissions.',
  2 => 'Browse institutions registered with the portal.',
  3 => 'Officer profile and access preferences.',
  _ => 'Dashboard overview.',
};

IconData _tabIcon(String title) => switch (title) {
  'Submissions' ||
  'Pending Review' ||
  'Pending Verification' ||
  'Approved Submissions' ||
  'Returned for Correction' => Icons.fact_check_outlined,
  'Institutions' || 'Institution Registry' => Icons.domain_outlined,
  'Profile' || 'Profile settings' => Icons.person_outline_rounded,
  'Notifications' => Icons.notifications_none_rounded,
  'Reports' => Icons.analytics_outlined,
  _ => Icons.dashboard_outlined,
};

class DemoFdrPortalStore extends ChangeNotifier {
  DemoFdrPortalStore._();

  static final DemoFdrPortalStore instance = DemoFdrPortalStore._();

  FdrRecord _currentSubmission = _blockedSubmission;

  final List<FdrSubmission> _dashboardSubmissions = [
    const FdrSubmission(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      submissionId: 'FDR-2026-00124',
      submittedOn: '24 Oct 2026',
      reference: 'FDR-EX-884201',
      amount: '₹5,00,000',
      status: VerificationStatus.pending,
      bankName: 'Example National Bank',
      caseType: 'FDR Submission',
      issues: ['Lien information requires review.'],
    ),
    const FdrSubmission(
      institution: 'National College of Engineering',
      institutionId: 'INST-00125',
      submissionId: 'FDR-2026-00125',
      submittedOn: '23 Oct 2026',
      reference: 'FDR-NC-550318',
      amount: '₹3,00,000',
      status: VerificationStatus.pending,
      bankName: 'National Commerce Bank',
    ),
    const FdrSubmission(
      institution: 'Metropolitan Institute of Science',
      institutionId: 'INST-00126',
      submissionId: 'FDR-2026-00126',
      submittedOn: '22 Oct 2026',
      reference: 'FDR-MI-719643',
      amount: '₹7,50,000',
      status: VerificationStatus.pending,
      bankName: 'Metropolitan Bank',
    ),
    const FdrSubmission(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      submissionId: 'FDR-2026-00127',
      submittedOn: '18 Oct 2026',
      reference: 'FDR-EIT-771530',
      amount: '₹3,50,000',
      status: VerificationStatus.verified,
      verificationPassed: true,
      bankName: 'Civic Union Bank',
    ),
    const FdrSubmission(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      submissionId: 'FDR-2026-00128',
      submittedOn: '11 Oct 2026',
      reference: 'FDR-EIT-440098',
      amount: '₹7,50,000',
      status: VerificationStatus.rejected,
      bankName: 'National Cooperative Bank',
      issues: ['FDR amount mismatch', 'Duplicate FDR reference'],
      rejectionReason: 'FDR amount mismatch; Duplicate FDR reference',
    ),
    const FdrSubmission(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      submissionId: 'FDR-2026-00129',
      submittedOn: '03 Oct 2026',
      reference: 'FDR-EIT-330817',
      amount: '₹4,25,000',
      status: VerificationStatus.blocked,
      bankName: 'Example National Bank',
      issues: [
        'Missing supporting document',
        'Officer clarification requested',
      ],
    ),
  ];
  final Map<String, String> _institutionRegistry = {
    'INST-DEMO-0042': 'Example Institute of Technology',
    'INST-00125': 'National College of Engineering',
    'INST-00126': 'Metropolitan Institute of Science',
  };

  VerificationSummary _lastVerification =
      FdrVerificationService.runVerification(_blockedSubmission);

  final Map<String, DemoFdrMasterRecord> _demoFdrRecords = {
    'FDR-EX-884201': const DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-EX-884201',
      amount: 500000,
    ),
    'FDR-EIT-771530': const DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-EIT-771530',
      amount: 350000,
    ),
    'FDR-EIT-440098': const DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-EIT-440098',
      amount: 750000,
    ),
    'FDR-EIT-330817': const DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-EIT-330817',
      amount: 425000,
    ),
    'FDR-PCL-552901': DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-PCL-552901',
      amount: 500000,
    ),
    'FDR-MRG-330812': DemoFdrMasterRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      fdrReference: 'FDR-MRG-330812',
      amount: 500000,
    ),
  };
  final Map<String, ReleaseCase> _releaseCases = <String, ReleaseCase>{};
  final Map<String, FdrRecord> _fdrRecordsBySubmissionId = {
    'FDR-2026-00124': _blockedSubmission,
    'FDR-2026-00128': _rejectedSubmission,
  };
  final Map<String, String> _mergerRelationships = <String, String>{};
  String _selectedCaseType = 'Normal Release';
  String? _selectedReleaseCaseId;
  int _nextInstitutionSubmissionSequence = 1;
  int _nextInstitutionCaseSequence = 1;
  final List<AuditEntry> _auditEntries = <AuditEntry>[];
  DemoVerificationScenario _verificationScenario =
      DemoVerificationScenario.blocked;
  bool _verificationCurrent = true;

  static const FdrRecord _blockedSubmission = FdrRecord(
    institution: 'Example Institute of Technology',
    institutionId: 'INST-DEMO-0042',
    submissionId: 'FDR-2026-00124',
    bank: 'Example National Bank',
    fdrNumber: 'FDR-EX-884201',
    declaredDepositAmount: 500000,
    receiptAmount: 450000,
    issueDate: '01 October 2025',
    maturityDate: '01 October 2028',
    declaredTenureMonths: 36,
    enteredTenureMonths: 36,
    lienInformation: 'Not provided',
    submissionStatus: 'Pending Review',
    documents: [
      DemoDocument(
        name: 'FDR receipt',
        fileName: 'fdr_receipt.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Institution request letter',
        fileName: 'request_letter.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Affidavit',
        fileName: 'affidavit.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Supporting documents',
        fileName: 'supporting_docs.zip',
        status: 'Uploaded — Demo',
      ),
    ],
  );

  static const FdrRecord _rejectedSubmission = FdrRecord(
    institution: 'Example Institute of Technology',
    institutionId: 'INST-DEMO-0042',
    submissionId: 'FDR-2026-00128',
    bank: 'National Cooperative Bank',
    fdrNumber: 'FDR-EIT-440098',
    declaredDepositAmount: 750000,
    receiptAmount: 700000,
    issueDate: '11 October 2026',
    maturityDate: '11 October 2029',
    declaredTenureMonths: 36,
    enteredTenureMonths: 36,
    lienInformation: 'No lien',
    submissionStatus: 'Rejected',
    documents: [
      DemoDocument(
        name: 'FDR receipt',
        fileName: 'fdr_receipt.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Institution request letter',
        fileName: 'request_letter.pdf',
        status: 'Uploaded — Demo',
      ),
    ],
  );

  static const FdrRecord _resolvedSubmission = FdrRecord(
    institution: 'Example Institute of Technology',
    institutionId: 'INST-DEMO-0042',
    submissionId: 'FDR-2026-00124',
    bank: 'Example National Bank',
    fdrNumber: 'FDR-EX-884201-RESOLVED',
    declaredDepositAmount: 500000,
    receiptAmount: 500000,
    issueDate: '01 October 2025',
    maturityDate: '01 October 2028',
    declaredTenureMonths: 36,
    enteredTenureMonths: 36,
    lienInformation: 'No lien; security is clear.',
    submissionStatus: 'Pending Review',
    documents: [
      DemoDocument(
        name: 'FDR receipt',
        fileName: 'fdr_receipt.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Institution request letter',
        fileName: 'request_letter.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Affidavit',
        fileName: 'affidavit.pdf',
        status: 'Uploaded — Demo',
      ),
      DemoDocument(
        name: 'Supporting documents',
        fileName: 'supporting_docs.zip',
        status: 'Uploaded — Demo',
      ),
    ],
  );

  FdrRecord get currentSubmission => _currentSubmission;
  List<FdrSubmission> get dashboardSubmissions =>
      List.unmodifiable(_dashboardSubmissions);
  Map<String, String> get institutionRegistry =>
      Map.unmodifiable(_institutionRegistry);
  List<ReleaseCase> get releaseCases => List.unmodifiable(_releaseCases.values);
  VerificationSummary get lastVerification => _lastVerification;
  bool get verificationCurrent => _verificationCurrent;
  VerificationSummary get verificationResults => _verificationCurrent
      ? _lastVerification
      : const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'NOT RUN — Verify saved FDR details',
          issues: [],
        );
  DemoVerificationScenario get verificationScenario => _verificationScenario;
  ReleaseCase? get releaseCase =>
      (_selectedReleaseCaseId == null
          ? null
          : _releaseCases[_selectedReleaseCaseId]) ??
      _releaseCases[_selectedCaseType];
  String get selectedCaseType => _selectedCaseType;
  FdrRecord get originalFdrRecord => _currentSubmission;
  Map<String, DemoFdrMasterRecord> get demoFdrRecords =>
      Map.unmodifiable(_demoFdrRecords);
  Map<String, String> get mergerRelationships =>
      Map.unmodifiable(_mergerRelationships);
  List<AuditEntry> get auditEntries => List.unmodifiable(_auditEntries);

  FdrRecord? fdrRecordForSubmission(String submissionId) =>
      _fdrRecordsBySubmissionId[submissionId];

  FdrSubmission? submissionById(String submissionId) {
    for (final submission in _dashboardSubmissions) {
      if (submission.submissionId == submissionId) return submission;
    }
    return null;
  }

  void selectSubmission(String submissionId) {
    final submission = submissionById(submissionId);
    if (submission == null) return;
    _currentSubmission =
        _fdrRecordsBySubmissionId[submissionId] ??
        FdrRecord(
          institution: submission.institution,
          institutionId: submission.institutionId,
          submissionId: submission.submissionId,
          bank: submission.bankName,
          fdrNumber: submission.reference,
          declaredDepositAmount: _parseCurrency(submission.amount),
          receiptAmount: _parseCurrency(submission.amount),
          issueDate: submission.submittedOn,
          maturityDate: 'Not provided',
          declaredTenureMonths: 0,
          enteredTenureMonths: 0,
          lienInformation: 'Not provided',
          submissionStatus: _statusLabel(submission.status),
          documents: const [
            DemoDocument(
              name: 'FDR receipt',
              fileName: 'fdr_receipt.pdf',
              status: 'Uploaded — Demo',
            ),
            DemoDocument(
              name: 'Institution request letter',
              fileName: 'request_letter.pdf',
              status: 'Uploaded — Demo',
            ),
          ],
        );
    _selectedReleaseCaseId = submission.caseId;
    _selectedCaseType = submission.caseType;
    _lastVerification = FdrVerificationService.runVerification(
      _currentSubmission,
    );
    _verificationCurrent = true;
    notifyListeners();
  }

  FdrSubmission submitInstitutionFdr({
    required String institution,
    required String institutionId,
    required String bank,
    required String fdrNumber,
    required int amount,
    List<DemoDocument> documents = const [],
  }) {
    final submissionId = _newInstitutionSubmissionId();
    final record = FdrRecord(
      institution: institution,
      institutionId: institutionId,
      submissionId: submissionId,
      bank: bank,
      fdrNumber: fdrNumber,
      declaredDepositAmount: amount,
      receiptAmount: amount,
      issueDate: _shortDate(DateTime.now()),
      maturityDate: 'Not provided',
      declaredTenureMonths: 0,
      enteredTenureMonths: 0,
      lienInformation: 'Not provided',
      submissionStatus: 'Pending Review',
      documents: documents.isEmpty
          ? const [
              DemoDocument(
                name: 'FDR receipt',
                fileName: 'fdr_receipt.pdf',
                status: 'Uploaded — Demo',
              ),
              DemoDocument(
                name: 'Institution request letter',
                fileName: 'request_letter.pdf',
                status: 'Uploaded — Demo',
              ),
            ]
          : documents,
    );
    final submission = FdrSubmission(
      institution: institution,
      institutionId: institutionId,
      submissionId: submissionId,
      submittedOn: _shortDate(DateTime.now()),
      reference: fdrNumber,
      amount: '₹${_formatCurrency(amount)}',
      status: VerificationStatus.pending,
      bankName: bank,
    );
    _fdrRecordsBySubmissionId[submissionId] = record;
    _demoFdrRecords.putIfAbsent(
      fdrNumber,
      () => DemoFdrMasterRecord(
        institution: institution,
        institutionId: institutionId,
        fdrReference: fdrNumber,
        amount: amount,
      ),
    );
    _upsertSubmission(submission);
    _institutionRegistry[institutionId] = institution;
    appendAuditEntry(
      action: 'Institution FDR submission received',
      associatedId: submissionId,
      actorRole: 'Institution User',
      payload: fdrNumber,
    );
    notifyListeners();
    return submission;
  }

  FdrSubmission submitInstitutionReleaseCase({
    required String institution,
    required String institutionId,
    required String bank,
    required String fdrNumber,
    required int originalAmount,
    required String caseType,
    required int requestedAmount,
    required String reason,
    String successorInstitution = '',
    String mergerReference = '',
    String effectiveDate = '',
    List<DemoDocument> documents = const [],
  }) {
    if (caseType == 'Progressive Closure' &&
        (requestedAmount <= 0 || requestedAmount > originalAmount)) {
      throw ArgumentError(
        'Requested release amount must be within the FDR amount.',
      );
    }
    final submissionId = _newInstitutionSubmissionId();
    final caseId = _newReleaseCaseId(caseType);
    final fdrRecord = FdrRecord(
      institution: institution,
      institutionId: institutionId,
      submissionId: submissionId,
      bank: bank,
      fdrNumber: fdrNumber,
      declaredDepositAmount: originalAmount,
      receiptAmount: originalAmount,
      issueDate: _shortDate(DateTime.now()),
      maturityDate: 'Not provided',
      declaredTenureMonths: 0,
      enteredTenureMonths: 0,
      lienInformation: 'Not provided',
      submissionStatus: 'Pending Review',
      documents: documents.isEmpty
          ? const [
              DemoDocument(
                name: 'FDR receipt',
                fileName: 'fdr_receipt.pdf',
                status: 'Uploaded — Demo',
              ),
              DemoDocument(
                name: 'Release request',
                fileName: 'release_request.pdf',
                status: 'Uploaded — Demo',
              ),
            ]
          : documents,
    );
    final submission = FdrSubmission(
      institution: institution,
      institutionId: institutionId,
      submissionId: submissionId,
      submittedOn: _shortDate(DateTime.now()),
      reference: fdrNumber,
      amount: '₹${_formatCurrency(originalAmount)}',
      status: VerificationStatus.pending,
      bankName: bank,
      caseType: caseType,
      caseId: caseId,
      requestedAmount: requestedAmount > 0 ? requestedAmount : null,
      retainedBalance: caseType == 'Progressive Closure'
          ? originalAmount - requestedAmount
          : null,
      requestReason: reason,
      issues: const [],
    );
    final checklist = documents
        .map(
          (document) => DemoChecklistItem(
            name: document.name,
            fileName: document.fileName,
            type: document.name,
            status: document.status,
          ),
        )
        .toList();
    final caseRecord = ReleaseCase(
      caseId: caseId,
      submissionId: submissionId,
      institution: institution,
      caseType: caseType,
      status: 'Pending Review',
      checklist: checklist.isEmpty
          ? [
              DemoChecklistItem(
                name: 'FDR copy',
                fileName: 'fdr_receipt.pdf',
                type: 'FDR receipt',
                status: 'Uploaded — Demo',
              ),
              DemoChecklistItem(
                name: 'Institution request',
                fileName: 'release_request.pdf',
                type: 'Release request',
                status: 'Uploaded — Demo',
              ),
            ]
          : checklist,
      clearances: _newDemoClearances(),
      originalFdrAmount: originalAmount,
      availableBalance: originalAmount,
      requestedReleaseAmount: requestedAmount,
      partialReleaseReason: reason,
      originalFdrReference: fdrNumber,
      originalInstitutionId: institutionId,
      successorInstitution: successorInstitution,
      mergerReference: mergerReference,
      effectiveDate: effectiveDate,
    );
    _fdrRecordsBySubmissionId[submissionId] = fdrRecord;
    _demoFdrRecords.putIfAbsent(
      fdrNumber,
      () => DemoFdrMasterRecord(
        institution: institution,
        institutionId: institutionId,
        fdrReference: fdrNumber,
        amount: originalAmount,
      ),
    );
    _releaseCases[caseId] = caseRecord;
    _upsertSubmission(submission);
    _institutionRegistry[institutionId] = institution;
    appendAuditEntry(
      action: 'Institution release request received',
      associatedId: caseId,
      actorRole: 'Institution User',
      payload:
          '$caseType; FDR $fdrNumber; requested amount $requestedAmount; $reason',
    );
    notifyListeners();
    return submission;
  }

  void selectReleaseCase(String caseId) {
    final record = _releaseCases[caseId];
    if (record == null) return;
    _selectedReleaseCaseId = caseId;
    _selectedCaseType = record.caseType;
    selectSubmission(record.submissionId);
  }

  void rejectSubmission(String submissionId, {String? reason}) {
    final index = _dashboardSubmissions.indexWhere(
      (submission) => submission.submissionId == submissionId,
    );
    if (index == -1) return;
    final submission = _dashboardSubmissions[index];
    final rejectionReason = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : submission.issues.isNotEmpty
        ? submission.issues.join('; ')
        : 'Returned by officer for correction.';
    _dashboardSubmissions[index] = FdrSubmission(
      institution: submission.institution,
      institutionId: submission.institutionId,
      submissionId: submission.submissionId,
      submittedOn: submission.submittedOn,
      updatedAtOverride: DateTime.now(),
      reference: submission.reference,
      amount: submission.amount,
      status: VerificationStatus.rejected,
      bankName: submission.bankName,
      caseType: submission.caseType,
      caseId: submission.caseId,
      requestedAmount: submission.requestedAmount,
      retainedBalance: submission.retainedBalance,
      requestReason: submission.requestReason,
      issues: submission.issues.isEmpty ? [rejectionReason] : submission.issues,
      rejectionReason: rejectionReason,
      correctionHistory: submission.correctionHistory,
      approvedAt: submission.approvedAt,
      approvedBy: submission.approvedBy,
    );
    final record = _fdrRecordsBySubmissionId[submissionId];
    if (record != null) {
      _fdrRecordsBySubmissionId[submissionId] = record.copyWith(
        submissionStatus: 'Rejected',
      );
    }
    if (submission.caseId != null) {
      final releaseCase = _releaseCases[submission.caseId];
      if (releaseCase != null) {
        _releaseCases[submission.caseId!] = releaseCase.copyWith(
          status: 'Rejected',
        );
      }
    }
    appendAuditEntry(
      action: 'Submission rejected in demo review',
      associatedId: submission.caseId ?? submissionId,
      actorRole: 'Demo Officer',
      payload: submission.reference,
    );
    notifyListeners();
  }

  VerificationSummary saveInstitutionCorrection({
    required String submissionId,
    required String institutionId,
    required String bank,
    required String fdrNumber,
    required int declaredAmount,
    required int receiptAmount,
  }) {
    final index = _dashboardSubmissions.indexWhere(
      (submission) => submission.submissionId == submissionId,
    );
    if (index == -1) throw ArgumentError('Submission was not found.');
    final submission = _dashboardSubmissions[index];
    if (submission.institutionId != institutionId ||
        submission.caseType != 'FDR Submission' ||
        submission.status != VerificationStatus.rejected) {
      throw StateError(
        'Only this institution\'s rejected FDR submission can be corrected.',
      );
    }

    final existingRecord =
        _fdrRecordsBySubmissionId[submissionId] ??
        FdrRecord(
          institution: submission.institution,
          institutionId: submission.institutionId,
          submissionId: submissionId,
          bank: submission.bankName,
          fdrNumber: submission.reference,
          declaredDepositAmount: _parseCurrency(submission.amount),
          receiptAmount: _parseCurrency(submission.amount),
          issueDate: submission.submittedOn,
          maturityDate: 'Not provided',
          declaredTenureMonths: 0,
          enteredTenureMonths: 0,
          lienInformation: 'Not provided',
          submissionStatus: 'Rejected',
          documents: const [],
        );
    final corrected = existingRecord.copyWith(
      bank: bank,
      fdrNumber: fdrNumber,
      declaredDepositAmount: declaredAmount,
      receiptAmount: receiptAmount,
      submissionStatus: 'Returned for Correction',
    );
    _fdrRecordsBySubmissionId[submissionId] = corrected;
    _currentSubmission = corrected;
    _lastVerification = _verifyFdrRecord(corrected);
    _verificationCurrent = true;

    final history = [
      ...submission.correctionHistory,
      'Saved correction: $fdrNumber; declared ₹${_formatCurrency(declaredAmount)}; receipt ₹${_formatCurrency(receiptAmount)}',
    ];
    _dashboardSubmissions[index] = FdrSubmission(
      institution: submission.institution,
      institutionId: submission.institutionId,
      submissionId: submission.submissionId,
      submittedOn: submission.submittedOn,
      updatedAtOverride: DateTime.now(),
      reference: fdrNumber,
      amount: '₹${_formatCurrency(declaredAmount)}',
      status: VerificationStatus.rejected,
      bankName: bank,
      caseType: submission.caseType,
      caseId: submission.caseId,
      requestedAmount: submission.requestedAmount,
      retainedBalance: submission.retainedBalance,
      requestReason: submission.requestReason,
      issues: _lastVerification.issues.map((issue) => issue.message).toList(),
      rejectionReason:
          submission.rejectionReason ?? submission.issues.join('; '),
      correctionHistory: history,
    );
    _demoFdrRecords.removeWhere(
      (_, record) =>
          record.institutionId == institutionId &&
          record.fdrReference == submission.reference,
    );
    final existingMaster = _demoFdrRecords[fdrNumber];
    final otherSubmissionUsesReference = _dashboardSubmissions.any(
      (item) =>
          item.submissionId != submissionId &&
          item.caseType == 'FDR Submission' &&
          item.reference == fdrNumber,
    );
    if (!otherSubmissionUsesReference &&
        (existingMaster == null ||
            (existingMaster.institutionId == institutionId &&
                submission.reference == fdrNumber))) {
      _demoFdrRecords[fdrNumber] = DemoFdrMasterRecord(
        institution: submission.institution,
        institutionId: institutionId,
        fdrReference: fdrNumber,
        amount: receiptAmount,
      );
    }
    appendAuditEntry(
      action: 'Institution saved corrected FDR details',
      associatedId: submissionId,
      actorRole: 'Institution User',
      payload: 'FDR $fdrNumber; verification ${_lastVerification.statusText}',
    );
    notifyListeners();
    return _lastVerification;
  }

  bool resubmitCorrectedSubmission(String submissionId, String institutionId) {
    final index = _dashboardSubmissions.indexWhere(
      (submission) => submission.submissionId == submissionId,
    );
    if (index == -1) return false;
    final submission = _dashboardSubmissions[index];
    final record = _fdrRecordsBySubmissionId[submissionId];
    if (submission.institutionId != institutionId ||
        submission.status != VerificationStatus.rejected ||
        record == null) {
      return false;
    }

    final verification = _verifyFdrRecord(record);
    _lastVerification = verification;
    _verificationCurrent = true;
    if (verification.blocking > 0) {
      _dashboardSubmissions[index] = FdrSubmission(
        institution: submission.institution,
        institutionId: submission.institutionId,
        submissionId: submission.submissionId,
        submittedOn: submission.submittedOn,
        updatedAtOverride: DateTime.now(),
        reference: submission.reference,
        amount: submission.amount,
        status: VerificationStatus.rejected,
        bankName: submission.bankName,
        caseType: submission.caseType,
        caseId: submission.caseId,
        requestReason: submission.requestReason,
        issues: verification.issues.map((issue) => issue.message).toList(),
        rejectionReason: submission.rejectionReason,
        correctionHistory: submission.correctionHistory,
      );
      notifyListeners();
      return false;
    }

    _fdrRecordsBySubmissionId[submissionId] = record.copyWith(
      submissionStatus: 'Pending Review',
    );
    _dashboardSubmissions[index] = FdrSubmission(
      institution: submission.institution,
      institutionId: submission.institutionId,
      submissionId: submission.submissionId,
      submittedOn: _shortDate(DateTime.now()),
      updatedAtOverride: DateTime.now(),
      reference: submission.reference,
      amount: submission.amount,
      status: VerificationStatus.pending,
      bankName: submission.bankName,
      caseType: submission.caseType,
      caseId: submission.caseId,
      requestedAmount: submission.requestedAmount,
      retainedBalance: submission.retainedBalance,
      requestReason: submission.requestReason,
      issues: verification.issues.map((issue) => issue.message).toList(),
      rejectionReason: submission.rejectionReason,
      correctionHistory: submission.correctionHistory,
    );
    if (_currentSubmission.submissionId == submissionId) {
      _currentSubmission = record.copyWith(submissionStatus: 'Pending Review');
    }
    appendAuditEntry(
      action: 'Corrected FDR submission resubmitted for officer review',
      associatedId: submissionId,
      actorRole: 'Institution User',
      payload: submission.reference,
    );
    notifyListeners();
    return true;
  }

  String _newInstitutionSubmissionId() =>
      'FDR-${DateTime.now().year}-${(129 + _nextInstitutionSubmissionSequence++).toString().padLeft(5, '0')}';

  String _newReleaseCaseId(String caseType) {
    final prefix = switch (caseType) {
      'Progressive Closure' => 'PCL',
      'Merger' => 'MRG',
      _ => 'REL',
    };
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-${(_nextInstitutionCaseSequence++).toString().padLeft(4, '0')}';
  }

  void _upsertSubmission(FdrSubmission submission) {
    final index = _dashboardSubmissions.indexWhere(
      (item) => item.submissionId == submission.submissionId,
    );
    if (index == -1) {
      _dashboardSubmissions.insert(0, submission);
    } else {
      _dashboardSubmissions[index] = submission;
    }
  }

  void resetDemoData() {
    _verificationScenario = DemoVerificationScenario.blocked;
    _currentSubmission = _blockedSubmission;
    _lastVerification = FdrVerificationService.runVerification(
      _blockedSubmission,
    );
    _verificationCurrent = true;
    _releaseCases.clear();
    _mergerRelationships.clear();
    _selectedCaseType = 'Normal Release';
    _selectedReleaseCaseId = null;
    _auditEntries.clear();
    _seedAudit();
    _dashboardSubmissions
      ..clear()
      ..addAll([
        const FdrSubmission(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          submissionId: 'FDR-2026-00124',
          submittedOn: '24 Oct 2026',
          reference: 'FDR-EX-884201',
          amount: '₹5,00,000',
          status: VerificationStatus.pending,
          bankName: 'Example National Bank',
          issues: ['Lien information requires review.'],
        ),
        const FdrSubmission(
          institution: 'National College of Engineering',
          institutionId: 'INST-00125',
          submissionId: 'FDR-2026-00125',
          submittedOn: '23 Oct 2026',
          reference: 'FDR-NC-550318',
          amount: '₹3,00,000',
          status: VerificationStatus.pending,
          bankName: 'National Commerce Bank',
        ),
        const FdrSubmission(
          institution: 'Metropolitan Institute of Science',
          institutionId: 'INST-00126',
          submissionId: 'FDR-2026-00126',
          submittedOn: '22 Oct 2026',
          reference: 'FDR-MI-719643',
          amount: '₹7,50,000',
          status: VerificationStatus.pending,
          bankName: 'Metropolitan Bank',
        ),
        const FdrSubmission(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          submissionId: 'FDR-2026-00127',
          submittedOn: '18 Oct 2026',
          reference: 'FDR-EIT-771530',
          amount: '₹3,50,000',
          status: VerificationStatus.verified,
          verificationPassed: true,
          bankName: 'Civic Union Bank',
        ),
        const FdrSubmission(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          submissionId: 'FDR-2026-00128',
          submittedOn: '11 Oct 2026',
          reference: 'FDR-EIT-440098',
          amount: '₹7,50,000',
          status: VerificationStatus.rejected,
          bankName: 'National Cooperative Bank',
          issues: ['FDR amount mismatch', 'Duplicate FDR reference'],
          rejectionReason: 'FDR amount mismatch; Duplicate FDR reference',
        ),
        const FdrSubmission(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          submissionId: 'FDR-2026-00129',
          submittedOn: '03 Oct 2026',
          reference: 'FDR-EIT-330817',
          amount: '₹4,25,000',
          status: VerificationStatus.blocked,
          bankName: 'Example National Bank',
          issues: [
            'Missing supporting document',
            'Officer clarification requested',
          ],
        ),
      ]);
    _institutionRegistry
      ..clear()
      ..addAll({
        'INST-DEMO-0042': 'Example Institute of Technology',
        'INST-00125': 'National College of Engineering',
        'INST-00126': 'Metropolitan Institute of Science',
      });
    _fdrRecordsBySubmissionId
      ..clear()
      ..['FDR-2026-00124'] = _blockedSubmission
      ..['FDR-2026-00128'] = _rejectedSubmission;
    _demoFdrRecords
      ..clear()
      ..addAll({
        'FDR-EX-884201': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-EX-884201',
          amount: 500000,
        ),
        'FDR-EIT-771530': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-EIT-771530',
          amount: 350000,
        ),
        'FDR-EIT-440098': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-EIT-440098',
          amount: 750000,
        ),
        'FDR-EIT-330817': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-EIT-330817',
          amount: 425000,
        ),
        'FDR-PCL-552901': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-PCL-552901',
          amount: 500000,
        ),
        'FDR-MRG-330812': const DemoFdrMasterRecord(
          institution: 'Example Institute of Technology',
          institutionId: 'INST-DEMO-0042',
          fdrReference: 'FDR-MRG-330812',
          amount: 500000,
        ),
      });
    _selectedReleaseCaseId = null;
    notifyListeners();
  }

  void _seedAudit() {
    final firstCanonical = jsonEncode({
      'eventId': 'AUD-001',
      'timestamp': '2026-10-25 08:30:00',
      'actorRole': 'Demo Officer',
      'action': 'FDR submission created',
      'associatedId': 'FDR-2026-00124',
      'payload': '',
      'previousHash': 'GENESIS',
    });
    final firstHash = _computeHash(firstCanonical);

    final secondCanonical = jsonEncode({
      'eventId': 'AUD-002',
      'timestamp': '2026-10-25 08:33:10',
      'actorRole': 'Demo Officer',
      'action': 'Verification initiated',
      'associatedId': 'FDR-2026-00124',
      'payload': '',
      'previousHash': firstHash,
    });
    final secondHash = _computeHash(secondCanonical);

    _auditEntries
      ..clear()
      ..add(
        AuditEntry(
          eventId: 'AUD-001',
          timestamp: '2026-10-25 08:30:00',
          actorRole: 'Demo Officer',
          action: 'FDR submission created',
          associatedId: 'FDR-2026-00124',
          payload: '',
          previousHash: 'GENESIS',
          entryHash: firstHash,
        ),
      )
      ..add(
        AuditEntry(
          eventId: 'AUD-002',
          timestamp: '2026-10-25 08:33:10',
          actorRole: 'Demo Officer',
          action: 'Verification initiated',
          associatedId: 'FDR-2026-00124',
          payload: '',
          previousHash: firstHash,
          entryHash: secondHash,
        ),
      );
  }

  void appendAuditEntry({
    required String action,
    required String associatedId,
    required String actorRole,
    String? payload,
  }) {
    if (_auditEntries.isEmpty) {
      _seedAudit();
    }
    final previousHash = _auditEntries.isEmpty
        ? 'GENESIS'
        : _auditEntries.last.entryHash;
    final eventId =
        'AUD-${(_auditEntries.length + 1).toString().padLeft(3, '0')}';
    final timestamp = DateTime.now()
        .toString()
        .replaceAll('.', ':')
        .substring(0, 19);
    final canonical = {
      'eventId': eventId,
      'timestamp': timestamp,
      'actorRole': actorRole,
      'action': action,
      'associatedId': associatedId,
      'payload': payload ?? '',
      'previousHash': previousHash,
    };
    final entryHash = _computeHash(jsonEncode(canonical));
    _auditEntries.add(
      AuditEntry(
        eventId: eventId,
        timestamp: timestamp,
        actorRole: actorRole,
        action: action,
        associatedId: associatedId,
        payload: payload ?? '',
        previousHash: previousHash,
        entryHash: entryHash,
      ),
    );
    notifyListeners();
  }

  void setCurrentSubmission(FdrRecord record) {
    final existing = submissionById(record.submissionId);
    if (existing != null &&
        (existing.institutionId != record.institutionId ||
            existing.institution != record.institution)) {
      record = record.copyWith(
        institution: existing.institution,
        institutionId: existing.institutionId,
      );
    }
    _currentSubmission = record;
    _fdrRecordsBySubmissionId[record.submissionId] = record;
    _verificationCurrent = false;
    _syncDashboardSubmission(
      existing?.status == VerificationStatus.rejected
          ? VerificationStatus.rejected
          : existing?.status == VerificationStatus.approved
          ? VerificationStatus.approved
          : VerificationStatus.pending,
    );
    final normalCase = _releaseCases['Normal Release'];
    if (normalCase != null) {
      _releaseCases['Normal Release'] = normalCase.copyWith(
        submissionId: record.submissionId,
        institution: record.institution,
      );
    }
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void setVerificationScenario(DemoVerificationScenario scenario) {
    _verificationScenario = scenario;
    _currentSubmission = scenario == DemoVerificationScenario.resolved
        ? _resolvedSubmission
        : _blockedSubmission;
    _lastVerification = FdrVerificationService.runVerification(
      _currentSubmission,
    );
    _verificationCurrent = true;
    _syncDashboardSubmission(
      _lastVerification.blocking > 0
          ? VerificationStatus.blocked
          : VerificationStatus.verified,
    );
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void setLastVerification(VerificationSummary summary) {
    _lastVerification = summary;
    _verificationCurrent = true;
    _syncDashboardSubmission(
      summary.blocking > 0
          ? VerificationStatus.blocked
          : VerificationStatus.verified,
    );
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void _syncDashboardSubmission(SubmissionStatus status) {
    final existingIndex = _dashboardSubmissions.indexWhere(
      (submission) =>
          submission.submissionId == _currentSubmission.submissionId,
    );
    final existing = existingIndex == -1
        ? null
        : _dashboardSubmissions[existingIndex];
    final isFdrSubmission = existing?.caseType == 'FDR Submission';
    final effectiveStatus =
        isFdrSubmission &&
            existing?.status == VerificationStatus.rejected &&
            status != VerificationStatus.approved
        ? VerificationStatus.rejected
        : isFdrSubmission &&
              status == VerificationStatus.verified &&
              (existing?.status == VerificationStatus.pending ||
                  existing?.status == VerificationStatus.blocked)
        ? VerificationStatus.pending
        : status;
    final recordStatus = switch (effectiveStatus) {
      SubmissionStatus.pendingReview =>
        _verificationCurrent && _lastVerification.blocking == 0
            ? 'FDR Verified — Awaiting Officer Approval'
            : 'Pending Review',
      SubmissionStatus.approved => 'Approved',
      SubmissionStatus.rejected => 'Rejected',
      SubmissionStatus.correctionRequested => 'Returned for Correction',
      SubmissionStatus.blocked => 'Blocked — FDR Verification',
    };
    _currentSubmission = _currentSubmission.copyWith(
      submissionStatus: recordStatus,
    );
    final updated = FdrSubmission(
      institution: _currentSubmission.institution,
      institutionId:
          existing?.institutionId ?? _currentSubmission.institutionId,
      submissionId: _currentSubmission.submissionId,
      submittedOn: existing?.submittedOn ?? '25 Oct 2026',
      updatedAtOverride: DateTime.now(),
      reference: _currentSubmission.fdrNumber,
      amount: '₹${_formatCurrency(_currentSubmission.declaredDepositAmount)}',
      status: effectiveStatus,
      verificationPassed:
          _verificationCurrent && _lastVerification.blocking == 0,
      bankName: _currentSubmission.bank,
      caseType: existing?.caseType ?? 'FDR Submission',
      caseId: existing?.caseId,
      requestedAmount: existing?.requestedAmount,
      retainedBalance: existing?.retainedBalance,
      requestReason: existing?.requestReason,
      issues: _verificationCurrent
          ? _lastVerification.issues.map((issue) => issue.message).toList()
          : existing?.issues ?? const [],
      rejectionReason: existing?.rejectionReason,
      correctionHistory: existing?.correctionHistory ?? const [],
    );
    _upsertSubmission(updated);
    _fdrRecordsBySubmissionId[_currentSubmission.submissionId] =
        _currentSubmission;
    if (updated.institutionId.isNotEmpty) {
      _institutionRegistry[updated.institutionId] = updated.institution;
    }
  }

  void _approveSubmissionForCase(ReleaseCase record) {
    final index = _dashboardSubmissions.indexWhere(
      (submission) => submission.submissionId == record.submissionId,
    );
    if (index == -1) return;
    final submission = _dashboardSubmissions[index];
    if (submission.status == VerificationStatus.approved) return;
    final approvedAt = DateTime.now();
    _dashboardSubmissions[index] = FdrSubmission(
      institution: submission.institution,
      institutionId: submission.institutionId,
      submissionId: submission.submissionId,
      submittedOn: submission.submittedOn,
      updatedAtOverride: approvedAt,
      reference: submission.reference,
      amount: submission.amount,
      status: VerificationStatus.approved,
      bankName: submission.bankName,
      caseType: submission.caseType,
      caseId: submission.caseId,
      requestedAmount: submission.requestedAmount,
      retainedBalance: submission.retainedBalance,
      requestReason: submission.requestReason,
      issues: submission.issues,
      approvedAt: approvedAt,
      approvedBy: 'Demo Officer',
      rejectionReason: submission.rejectionReason,
      correctionHistory: submission.correctionHistory,
    );
    if (_currentSubmission.submissionId == submission.submissionId) {
      _currentSubmission = _currentSubmission.copyWith(
        submissionStatus: 'Approved — Demo',
      );
    }
  }

  VerificationSummary runCurrentVerification() {
    final summary = _verifyFdrRecord(_currentSubmission);
    setLastVerification(summary);
    return summary;
  }

  VerificationSummary _verifyFdrRecord(FdrRecord record) {
    final initial = FdrVerificationService.runVerification(record);
    if (submissionById(record.submissionId)?.caseType != 'FDR Submission') {
      return initial;
    }
    final duplicateSubmission = _dashboardSubmissions.where(
      (submission) =>
          submission.submissionId != record.submissionId &&
          submission.caseType == 'FDR Submission' &&
          submission.reference == record.fdrNumber,
    );
    final duplicateMaster = _demoFdrRecords[record.fdrNumber];
    final duplicateBelongsElsewhere =
        duplicateMaster != null &&
        duplicateMaster.institutionId != record.institutionId;
    if ((duplicateSubmission.isEmpty && !duplicateBelongsElsewhere) ||
        initial.issues.any((issue) => issue.ruleId == 'duplicate-fdr')) {
      return initial;
    }
    final duplicateIssue = VerificationIssue(
      ruleId: 'duplicate-fdr',
      severity: VerificationIssueSeverity.blocking,
      message:
          'This FDR reference is already used by another submission or institution.',
      recommendedAction:
          'Use the correct unique FDR reference before resubmitting.',
    );
    final issues = [...initial.issues, duplicateIssue];
    final blocking = issues
        .where((issue) => issue.severity == VerificationIssueSeverity.blocking)
        .length;
    return VerificationSummary(
      totalChecks: initial.totalChecks + 1,
      blocking: blocking,
      warnings: initial.warnings,
      statusText: 'BLOCKED — $blocking Blocking Discrepancies',
      issues: issues,
    );
  }

  bool canApproveFdrSubmissionInDemoMode() {
    final submission = submissionById(_currentSubmission.submissionId);
    final currentCase = releaseCase;
    if (submission == null ||
        submission.caseType != 'FDR Submission' ||
        submission.status != VerificationStatus.pending ||
        !_verificationCurrent ||
        _lastVerification.blocking > 0 ||
        currentCase == null ||
        currentCase.submissionId != submission.submissionId ||
        currentCase.caseType != 'Normal Release') {
      return false;
    }
    final currentVerification = _verifyFdrRecord(_currentSubmission);
    if (currentVerification.blocking > 0) return false;
    return ReleaseEligibilityService.evaluate(
      record: currentCase,
      verification: currentVerification,
    ).canAdvance;
  }

  bool approveFdrSubmissionInDemoMode() {
    if (!canApproveFdrSubmissionInDemoMode()) return false;
    final currentCase = releaseCase!;
    _approveSubmissionForCase(currentCase);
    _saveReleaseCase(currentCase.copyWith(status: 'FDR Approved — Demo'));
    appendAuditEntry(
      action: 'FDR submission approved in demo mode',
      associatedId: currentCase.submissionId,
      actorRole: 'Demo Officer',
      payload:
          'All FDR checks, required documents, and clearances passed; no funds transferred',
    );
    notifyListeners();
    return true;
  }

  VerificationSummary get verificationForEligibility => _verificationCurrent
      ? _lastVerification
      : const VerificationSummary(
          totalChecks: 1,
          blocking: 1,
          warnings: 0,
          statusText: 'VERIFICATION REQUIRED',
          issues: [
            VerificationIssue(
              ruleId: 'verification-required',
              severity: VerificationIssueSeverity.blocking,
              message: 'Run verification after saving corrected FDR details.',
            ),
          ],
        );

  void createReleaseCase() {
    _selectedCaseType = 'Normal Release';
    _selectedReleaseCaseId = null;
    _nextInstitutionSubmissionSequence = 1;
    _nextInstitutionCaseSequence = 1;
    _releaseCases.putIfAbsent(
      'Normal Release',
      () => ReleaseCase(
        caseId: 'REL-2026-00017',
        submissionId: _currentSubmission.submissionId,
        institution: _currentSubmission.institution,
        caseType: 'Normal Release',
        status: 'Awaiting Clearances',
        checklist: const [
          DemoChecklistItem(
            name: 'Request Letter',
            fileName: 'request_letter.pdf',
            type: 'Institution request letter',
            status: 'Uploaded — Demo',
          ),
          DemoChecklistItem(
            name: 'Affidavit',
            fileName: 'affidavit.pdf',
            type: 'Institution affidavit',
            status: 'Uploaded — Demo',
          ),
          DemoChecklistItem(
            name: 'FDR Copy',
            fileName: 'fdr_receipt.pdf',
            type: 'Fixed Deposit Receipt',
            status: 'Uploaded — Demo',
          ),
        ],
        clearances: const [
          ClearanceState(
            name: 'Grievance Redressal Cell',
            status: 'Pending',
            remark: 'Not reviewed',
            actionRequired: 'Review grievances and confirm no objections.',
          ),
          ClearanceState(
            name: 'Vigilance Cell',
            status: 'Pending',
            remark: 'Not reviewed',
            actionRequired: 'Inspect compliance and risk indicators.',
          ),
        ],
      ),
    );
    _releaseCases.putIfAbsent(
      'Progressive Closure',
      () => ReleaseCase(
        caseId: 'PCL-2026-00008',
        submissionId: _currentSubmission.submissionId,
        institution: 'Example Institute of Technology',
        caseType: 'Progressive Closure',
        status: 'Pending Review',
        checklist: const [
          DemoChecklistItem(
            name: 'Institution partial release request',
            fileName: 'pcl_request_letter.pdf',
            type: 'Signed request letter',
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Updated FDR evidence',
            fileName: 'pcl_fdr_copy.pdf',
            type: 'FDR copy',
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Partial release justification',
            fileName: 'pcl_justification.pdf',
            type: 'Supporting justification',
            status: 'Present — Demo',
          ),
        ],
        clearances: _newDemoClearances(),
        originalFdrAmount: 500000,
        availableBalance: 500000,
        requestedReleaseAmount: 150000,
        partialReleaseReason: 'Staged institutional requirement',
        originalFdrReference: 'FDR-PCL-552901',
      ),
    );
    _releaseCases.putIfAbsent(
      'Merger',
      () => ReleaseCase(
        caseId: 'MRG-2026-00004',
        submissionId: _currentSubmission.submissionId,
        institution: 'Example Institute of Technology',
        caseType: 'Merger',
        status: 'Pending Review',
        checklist: const [
          DemoChecklistItem(
            name: 'Merger or amalgamation approval document',
            fileName: 'merger_approval.pdf',
            type: 'Merger approval',
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Institution request letter',
            fileName: 'merger_request_letter.pdf',
            type: 'Institution request',
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Original FDR copy',
            fileName: 'merger_original_fdr.pdf',
            type: 'Original FDR copy',
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Supporting institution records',
            fileName: 'merger_institution_records.pdf',
            type: 'Institution records',
            status: 'Present — Demo',
          ),
        ],
        clearances: _newDemoClearances(),
        originalFdrAmount: 500000,
        originalFdrReference: 'FDR-MRG-330812',
        originalInstitutionId: 'INST-DEMO-0042',
        successorInstitution: 'Example Technical University',
        successorInstitutionId: 'INST-DEMO-0108',
        mergerReference: 'MERGER-2026-0019',
        effectiveDate: '01 November 2026',
      ),
    );
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void _syncNormalReleaseStatus() {
    final currentCase = _releaseCases['Normal Release'];
    if (currentCase == null ||
        (currentCase.status == 'NOC Issued — Demo' && _verificationCurrent)) {
      return;
    }

    final eligibility = ReleaseEligibilityService.evaluate(
      record: currentCase,
      verification: verificationForEligibility,
    );
    final status = !_verificationCurrent
        ? 'Verification Required'
        : _lastVerification.blocking > 0
        ? 'Blocked — FDR Verification'
        : eligibility.missingDocuments.isNotEmpty
        ? 'Awaiting Required Documents'
        : eligibility.pendingClearances.isNotEmpty
        ? 'Awaiting Clearances'
        : 'Ready for Final NOC';
    _releaseCases['Normal Release'] = currentCase.copyWith(status: status);
  }

  static List<ClearanceState> _newDemoClearances() => const [
    ClearanceState(
      name: 'Grievance Redressal Cell',
      status: 'Pending',
      remark: 'Not reviewed',
      actionRequired: 'Review grievances and confirm no objections.',
    ),
    ClearanceState(
      name: 'Vigilance Cell',
      status: 'Pending',
      remark: 'Not reviewed',
      actionRequired: 'Inspect compliance and risk indicators.',
    ),
  ];

  void updateClearanceStatus(
    String clearanceName,
    String newStatus, {
    String? remark,
  }) {
    final currentCase = releaseCase;
    if (currentCase == null) return;
    final index = currentCase.clearances.indexWhere(
      (item) => item.name == clearanceName,
    );
    if (index == -1) return;
    final updated = currentCase.clearances[index].copyWith(
      status: newStatus,
      remark: remark ?? currentCase.clearances[index].remark,
      lastUpdated: DateTime.now().toLocal().toString().substring(0, 16),
    );
    final clearances = [...currentCase.clearances];
    clearances[index] = updated;
    _saveReleaseCase(currentCase.copyWith(clearances: clearances));
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void updateDocumentPresence(String fileName, bool isPresent) {
    final currentCase = releaseCase;
    if (currentCase == null) return;
    final checklist = currentCase.checklist
        .map(
          (item) => item.fileName == fileName
              ? item.copyWith(
                  isPresent: isPresent,
                  status: isPresent ? 'Present — Demo' : 'Missing — Demo',
                )
              : item,
        )
        .toList();
    _saveReleaseCase(currentCase.copyWith(checklist: checklist));
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void updateReleaseCaseType(String caseType) {
    _selectedReleaseCaseId = null;
    if (!_releaseCases.containsKey(caseType)) createReleaseCase();
    _selectedCaseType = caseType;
    notifyListeners();
  }

  void issueDemoNoc() {
    final currentCase = releaseCase;
    if (currentCase == null ||
        currentCase.caseType != 'Normal Release' ||
        currentCase.status == 'NOC Issued — Demo' ||
        !ReleaseEligibilityService.evaluate(
          record: currentCase,
          verification: verificationForEligibility,
        ).canAdvance) {
      return;
    }
    _saveReleaseCase(currentCase.copyWith(status: 'NOC Issued — Demo'));
    notifyListeners();
  }

  void updateProgressiveClosure({int? requestedAmount, String? reason}) {
    final currentCase = releaseCase;
    if (currentCase == null || currentCase.caseType != 'Progressive Closure') {
      return;
    }
    _saveReleaseCase(
      currentCase.copyWith(
        requestedReleaseAmount:
            requestedAmount ?? currentCase.requestedReleaseAmount,
        partialReleaseReason: reason ?? currentCase.partialReleaseReason,
      ),
    );
    notifyListeners();
  }

  void updateMergerDetails({
    String? successorInstitution,
    String? mergerReference,
    String? effectiveDate,
  }) {
    final currentCase = releaseCase;
    if (currentCase == null || currentCase.caseType != 'Merger') return;
    _saveReleaseCase(
      currentCase.copyWith(
        successorInstitution: successorInstitution,
        mergerReference: mergerReference,
        effectiveDate: effectiveDate,
      ),
    );
    notifyListeners();
  }

  void approveProgressiveClosureInDemoMode() {
    final currentCase = releaseCase;
    if (currentCase == null || currentCase.caseType != 'Progressive Closure') {
      return;
    }
    if (!ReleaseEligibilityService.evaluate(
      record: currentCase,
      verification: verificationForEligibility,
    ).canAdvance) {
      return;
    }
    _saveReleaseCase(
      currentCase.copyWith(status: 'Partial Release Approved — Demo'),
    );
    _approveSubmissionForCase(currentCase);
    notifyListeners();
  }

  void approveMergerInDemoMode() {
    final currentCase = releaseCase;
    if (currentCase == null || currentCase.caseType != 'Merger') {
      return;
    }
    if (!ReleaseEligibilityService.evaluate(
      record: currentCase,
      verification: verificationForEligibility,
      originalFdrExists: _demoFdrRecords.containsKey(
        currentCase.originalFdrReference,
      ),
    ).canAdvance) {
      return;
    }
    _mergerRelationships[currentCase.originalFdrReference] =
        currentCase.successorInstitution;
    _saveReleaseCase(currentCase.copyWith(status: 'Merger Approved — Demo'));
    _approveSubmissionForCase(currentCase);
    notifyListeners();
  }

  void _saveReleaseCase(ReleaseCase record) {
    final key = _selectedReleaseCaseId ?? _selectedCaseType;
    _releaseCases[key] = record;
  }

  static String _computeHash(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes).toString();
    return digest;
  }
}

class FdrRecord {
  const FdrRecord({
    required this.institution,
    required this.institutionId,
    required this.submissionId,
    required this.bank,
    required this.fdrNumber,
    required this.declaredDepositAmount,
    required this.receiptAmount,
    required this.issueDate,
    required this.maturityDate,
    required this.declaredTenureMonths,
    required this.enteredTenureMonths,
    required this.lienInformation,
    required this.submissionStatus,
    required this.documents,
  });

  final String institution;
  final String institutionId;
  final String submissionId;
  final String bank;
  final String fdrNumber;
  final int declaredDepositAmount;
  final int receiptAmount;
  final String issueDate;
  final String maturityDate;
  final int declaredTenureMonths;
  final int enteredTenureMonths;
  final String lienInformation;
  final String submissionStatus;
  final List<DemoDocument> documents;

  FdrRecord copyWith({
    String? institution,
    String? institutionId,
    String? submissionId,
    String? bank,
    String? fdrNumber,
    int? declaredDepositAmount,
    int? receiptAmount,
    String? issueDate,
    String? maturityDate,
    int? declaredTenureMonths,
    int? enteredTenureMonths,
    String? lienInformation,
    String? submissionStatus,
    List<DemoDocument>? documents,
  }) => FdrRecord(
    institution: institution ?? this.institution,
    institutionId: institutionId ?? this.institutionId,
    submissionId: submissionId ?? this.submissionId,
    bank: bank ?? this.bank,
    fdrNumber: fdrNumber ?? this.fdrNumber,
    declaredDepositAmount: declaredDepositAmount ?? this.declaredDepositAmount,
    receiptAmount: receiptAmount ?? this.receiptAmount,
    issueDate: issueDate ?? this.issueDate,
    maturityDate: maturityDate ?? this.maturityDate,
    declaredTenureMonths: declaredTenureMonths ?? this.declaredTenureMonths,
    enteredTenureMonths: enteredTenureMonths ?? this.enteredTenureMonths,
    lienInformation: lienInformation ?? this.lienInformation,
    submissionStatus: submissionStatus ?? this.submissionStatus,
    documents: documents ?? this.documents,
  );
}

class DemoDocument {
  const DemoDocument({
    required this.name,
    required this.fileName,
    required this.status,
  });

  final String name;
  final String fileName;
  final String status;
}

class DemoFdrMasterRecord {
  const DemoFdrMasterRecord({
    required this.institution,
    required this.institutionId,
    required this.fdrReference,
    required this.amount,
  });

  final String institution;
  final String institutionId;
  final String fdrReference;
  final int amount;
}

class VerificationIssue {
  const VerificationIssue({
    required this.ruleId,
    required this.severity,
    required this.message,
    this.description = '',
    this.recommendedAction = '',
  });

  final String ruleId;
  final VerificationIssueSeverity severity;
  final String message;
  final String description;
  final String recommendedAction;
}

enum VerificationIssueSeverity { blocking, warning, passed }

class VerificationSummary {
  const VerificationSummary({
    required this.totalChecks,
    required this.blocking,
    required this.warnings,
    required this.statusText,
    required this.issues,
  });

  final int totalChecks;
  final int blocking;
  final int warnings;
  final String statusText;
  final List<VerificationIssue> issues;
}

class ReleaseCase {
  const ReleaseCase({
    required this.caseId,
    required this.submissionId,
    required this.institution,
    required this.caseType,
    required this.status,
    required this.checklist,
    required this.clearances,
    this.originalFdrAmount = 0,
    this.availableBalance = 0,
    this.requestedReleaseAmount = 0,
    this.partialReleaseReason = '',
    this.originalFdrReference = '',
    this.originalInstitutionId = '',
    this.successorInstitution = '',
    this.successorInstitutionId = '',
    this.mergerReference = '',
    this.effectiveDate = '',
  });

  final String caseId;
  final String submissionId;
  final String institution;
  final String caseType;
  final String status;
  final List<DemoChecklistItem> checklist;
  final List<ClearanceState> clearances;
  final int originalFdrAmount;
  final int availableBalance;
  final int requestedReleaseAmount;
  final String partialReleaseReason;
  final String originalFdrReference;
  final String originalInstitutionId;
  final String successorInstitution;
  final String successorInstitutionId;
  final String mergerReference;
  final String effectiveDate;
  int get retainedBalance => originalFdrAmount - requestedReleaseAmount;

  ReleaseCase copyWith({
    String? caseId,
    String? submissionId,
    String? institution,
    String? caseType,
    String? status,
    List<DemoChecklistItem>? checklist,
    List<ClearanceState>? clearances,
    int? originalFdrAmount,
    int? availableBalance,
    int? requestedReleaseAmount,
    String? partialReleaseReason,
    String? originalFdrReference,
    String? originalInstitutionId,
    String? successorInstitution,
    String? successorInstitutionId,
    String? mergerReference,
    String? effectiveDate,
  }) => ReleaseCase(
    caseId: caseId ?? this.caseId,
    submissionId: submissionId ?? this.submissionId,
    institution: institution ?? this.institution,
    caseType: caseType ?? this.caseType,
    status: status ?? this.status,
    checklist: checklist ?? this.checklist,
    clearances: clearances ?? this.clearances,
    originalFdrAmount: originalFdrAmount ?? this.originalFdrAmount,
    availableBalance: availableBalance ?? this.availableBalance,
    requestedReleaseAmount:
        requestedReleaseAmount ?? this.requestedReleaseAmount,
    partialReleaseReason: partialReleaseReason ?? this.partialReleaseReason,
    originalFdrReference: originalFdrReference ?? this.originalFdrReference,
    originalInstitutionId: originalInstitutionId ?? this.originalInstitutionId,
    successorInstitution: successorInstitution ?? this.successorInstitution,
    successorInstitutionId:
        successorInstitutionId ?? this.successorInstitutionId,
    mergerReference: mergerReference ?? this.mergerReference,
    effectiveDate: effectiveDate ?? this.effectiveDate,
  );
}

class DemoChecklistItem {
  const DemoChecklistItem({
    required this.name,
    this.fileName = '',
    this.type = '',
    this.isRequired = true,
    this.isPresent = true,
    required this.status,
  });

  final String name;
  final String fileName;
  final String type;
  final bool isRequired;
  final bool isPresent;
  final String status;

  DemoChecklistItem copyWith({bool? isPresent, String? status}) =>
      DemoChecklistItem(
        name: name,
        fileName: fileName,
        type: type,
        isRequired: isRequired,
        isPresent: isPresent ?? this.isPresent,
        status: status ?? this.status,
      );
}

class ClearanceState {
  const ClearanceState({
    required this.name,
    required this.status,
    required this.remark,
    required this.actionRequired,
    this.lastUpdated,
  });

  final String name;
  final String status;
  final String remark;
  final String actionRequired;
  final String? lastUpdated;

  ClearanceState copyWith({
    String? name,
    String? status,
    String? remark,
    String? actionRequired,
    String? lastUpdated,
  }) => ClearanceState(
    name: name ?? this.name,
    status: status ?? this.status,
    remark: remark ?? this.remark,
    actionRequired: actionRequired ?? this.actionRequired,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
}

class AuditEntry {
  const AuditEntry({
    required this.eventId,
    required this.timestamp,
    required this.actorRole,
    required this.action,
    required this.associatedId,
    this.payload = '',
    required this.previousHash,
    required this.entryHash,
  });

  final String eventId;
  final String timestamp;
  final String actorRole;
  final String action;
  final String associatedId;
  final String payload;
  final String previousHash;
  final String entryHash;

  AuditEntry copyWith({
    String? eventId,
    String? timestamp,
    String? actorRole,
    String? action,
    String? associatedId,
    String? payload,
    String? previousHash,
    String? entryHash,
  }) => AuditEntry(
    eventId: eventId ?? this.eventId,
    timestamp: timestamp ?? this.timestamp,
    actorRole: actorRole ?? this.actorRole,
    action: action ?? this.action,
    associatedId: associatedId ?? this.associatedId,
    payload: payload ?? this.payload,
    previousHash: previousHash ?? this.previousHash,
    entryHash: entryHash ?? this.entryHash,
  );
}

class AuditIntegrityResult {
  const AuditIntegrityResult({
    required this.isValid,
    required this.invalidEntryId,
    required this.message,
  });

  final bool isValid;
  final String? invalidEntryId;
  final String message;
}

AuditIntegrityResult verifyAuditChain(Iterable<AuditEntry> entries) {
  String previousHash = 'GENESIS';
  for (final entry in entries) {
    final canonical = jsonEncode({
      'eventId': entry.eventId,
      'timestamp': entry.timestamp,
      'actorRole': entry.actorRole,
      'action': entry.action,
      'associatedId': entry.associatedId,
      'payload': entry.payload,
      'previousHash': previousHash,
    });
    final expectedHash = sha256.convert(utf8.encode(canonical)).toString();
    if (entry.previousHash != previousHash || entry.entryHash != expectedHash) {
      return AuditIntegrityResult(
        isValid: false,
        invalidEntryId: entry.eventId,
        message:
            'Tampering detected at audit entry ${entry.eventId}. The stored hash does not match the recalculated hash.',
      );
    }
    previousHash = expectedHash;
  }
  return const AuditIntegrityResult(
    isValid: true,
    invalidEntryId: null,
    message: 'All audit entries match the chain integrity check.',
  );
}

class FdrVerificationService {
  static final Map<String, DemoFdrMasterRecord> _duplicateRegistry = {
    'FDR-EX-884201': const DemoFdrMasterRecord(
      institution: 'National College of Engineering',
      institutionId: 'INST-00110',
      fdrReference: 'FDR-EX-884201',
      amount: 500000,
    ),
  };

  static VerificationSummary runVerification(FdrRecord record) {
    final issues = <VerificationIssue>[];

    final amountDifference =
        (record.declaredDepositAmount - record.receiptAmount).abs();
    if (record.declaredDepositAmount != record.receiptAmount) {
      issues.add(
        VerificationIssue(
          ruleId: 'deposit-amount',
          severity: VerificationIssueSeverity.blocking,
          message:
              'Declared deposit amount does not match the receipt amount. Difference: ₹${_formatCurrency(amountDifference)}.',
          description:
              'The institution-declared deposit amount differs from the receipt amount recorded for the FDR.',
          recommendedAction:
              'Review the declared and receipt values side-by-side and correct the disputed amount before release approval.',
        ),
      );
    }

    if (record.lienInformation.trim().isEmpty ||
        record.lienInformation.toLowerCase() == 'not provided') {
      issues.add(
        const VerificationIssue(
          ruleId: 'lien-information',
          severity: VerificationIssueSeverity.warning,
          message: 'Lien information requires review.',
          description:
              'Lien information is missing or marked as not provided for this FDR.',
          recommendedAction:
              'Confirm whether a lien exists and update the record before final approval.',
        ),
      );
    }

    final duplicateRecord = _duplicateRegistry[record.fdrNumber];
    if (duplicateRecord != null &&
        duplicateRecord.institution != record.institution) {
      issues.add(
        VerificationIssue(
          ruleId: 'duplicate-fdr',
          severity: VerificationIssueSeverity.blocking,
          message:
              'This FDR number already belongs to ${duplicateRecord.institution} under record ${duplicateRecord.fdrReference}.',
          description:
              'The FDR reference clashes with a different institution in the demo dataset.',
          recommendedAction:
              'Correct the FDR reference to a unique value or resolve the duplicate record before release approval.',
        ),
      );
    }

    final blocking = issues
        .where((issue) => issue.severity == VerificationIssueSeverity.blocking)
        .length;
    final warnings = issues
        .where((issue) => issue.severity == VerificationIssueSeverity.warning)
        .length;

    final summary = VerificationSummary(
      totalChecks: issues.length,
      blocking: blocking,
      warnings: warnings,
      statusText: blocking == 0
          ? 'PASSED — No Blocking Discrepancies'
          : 'BLOCKED — $blocking Blocking Discrepancies',
      issues: issues,
    );

    return summary;
  }
}

class ReleaseEligibility {
  const ReleaseEligibility({
    required this.canAdvance,
    required this.blockingReasons,
    required this.warnings,
    required this.nextEligibleStage,
    this.missingDocuments = const [],
    this.pendingClearances = const [],
  });

  final bool canAdvance;
  final List<String> blockingReasons;
  final List<String> warnings;
  final String nextEligibleStage;
  final List<String> missingDocuments;
  final List<String> pendingClearances;
}

class ReleaseEligibilityService {
  static String? validateRequestedAmount(
    String? rawValue, {
    required int originalFdrAmount,
    required int availableBalance,
  }) {
    final sanitized = rawValue?.trim() ?? '';
    if (sanitized.isEmpty) {
      return 'Requested release amount is required.';
    }

    final parsedValue = int.tryParse(sanitized);
    if (parsedValue == null) {
      return 'Requested release amount must be numeric.';
    }
    if (parsedValue <= 0) {
      return 'Requested release amount must be greater than zero.';
    }
    if (parsedValue > originalFdrAmount) {
      return 'Requested release amount cannot exceed the original FDR amount.';
    }
    if (parsedValue > availableBalance) {
      return 'Requested release amount cannot exceed the currently available balance.';
    }
    return null;
  }

  static ReleaseEligibility evaluate({
    required ReleaseCase record,
    required VerificationSummary verification,
    bool originalFdrExists = true,
  }) {
    final blockers = <String>[];
    final warnings = verification.issues
        .where((issue) => issue.severity == VerificationIssueSeverity.warning)
        .map((issue) => issue.message)
        .toList();
    if (verification.blocking > 0) {
      blockers.add('Resolve all blocking FDR discrepancies before proceeding.');
    }

    final missingDocuments = record.checklist
        .where((document) => document.isRequired && !document.isPresent)
        .map((document) => document.name)
        .toList();
    final pendingClearances = record.clearances
        .where((clearance) => clearance.status != 'Cleared')
        .map((clearance) => clearance.name)
        .toList();
    if (missingDocuments.isNotEmpty) {
      blockers.add(
        'Required documents missing: ${missingDocuments.join(', ')}.',
      );
    }
    if (pendingClearances.isNotEmpty) {
      blockers.add('Every required cell clearance must be marked cleared.');
    }

    if (record.caseType == 'Progressive Closure') {
      final amountValidationError = validateRequestedAmount(
        record.requestedReleaseAmount.toString(),
        originalFdrAmount: record.originalFdrAmount,
        availableBalance: record.availableBalance,
      );
      if (amountValidationError != null) {
        blockers.add(amountValidationError);
      }
      if (record.retainedBalance < 0) {
        blockers.add('Retained balance cannot be negative.');
      }
      if (record.partialReleaseReason.trim().isEmpty) {
        blockers.add('A reason for partial release is required.');
      }
    } else if (record.caseType == 'Merger') {
      if (!originalFdrExists ||
          record.originalFdrReference.trim().isEmpty ||
          record.originalFdrAmount <= 0) {
        blockers.add('The original FDR record could not be verified.');
      }
      if (record.successorInstitution.trim().isEmpty) {
        blockers.add('Successor institution is required.');
      }
      if (record.mergerReference.trim().isEmpty) {
        blockers.add('Merger reference number is required.');
      }
      if (record.effectiveDate.trim().isEmpty) {
        blockers.add('Effective date is required.');
      }
    }

    final nextStage = verification.blocking > 0
        ? record.caseType == 'Merger'
              ? 'Original FDR Verification'
              : 'FDR Verification'
        : blockers.any(
            (reason) =>
                reason.contains('amount') ||
                reason.contains('balance') ||
                reason.contains('reason') ||
                reason.contains('institution') ||
                reason.contains('reference') ||
                reason.contains('date'),
          )
        ? record.caseType == 'Progressive Closure'
              ? 'Partial Release Request'
              : record.caseType == 'Merger'
              ? 'Institution and Merger Details'
              : 'Required Documents'
        : missingDocuments.isNotEmpty
        ? 'Required Documents'
        : pendingClearances.isNotEmpty
        ? pendingClearances.first
        : record.caseType == 'Progressive Closure'
        ? 'Final NOC'
        : record.caseType == 'Merger'
        ? 'Final Review and NOC'
        : 'Final NOC';
    return ReleaseEligibility(
      canAdvance: blockers.isEmpty,
      blockingReasons: blockers,
      warnings: warnings,
      nextEligibleStage: nextStage,
      missingDocuments: missingDocuments,
      pendingClearances: pendingClearances,
    );
  }
}

ReleaseEligibility canAdvanceReleaseCase(
  VerificationSummary verificationResults,
  List<DemoChecklistItem> documents,
  List<ClearanceState> clearances,
) {
  final blockers = <String>[];
  final warnings = verificationResults.issues
      .where((issue) => issue.severity == VerificationIssueSeverity.warning)
      .map((issue) => issue.message)
      .toList();

  if (verificationResults.blocking > 0) {
    blockers.add('Resolve all blocking FDR discrepancies before proceeding.');
  }
  final missingDocuments = documents
      .where((document) => document.isRequired && !document.isPresent)
      .map((document) => document.name)
      .toList();
  if (missingDocuments.isNotEmpty) {
    blockers.add('Required documents missing: ${missingDocuments.join(', ')}.');
  }
  if (clearances.any((clearance) => clearance.status != 'Cleared')) {
    blockers.add('Every required cell clearance must be marked cleared.');
  }

  final nextStage = verificationResults.blocking > 0
      ? 'FDR Verification'
      : missingDocuments.isNotEmpty
      ? 'Required Documents'
      : clearances.any((clearance) => clearance.status != 'Cleared')
      ? 'Cell Clearances'
      : 'Final NOC';

  return ReleaseEligibility(
    canAdvance: blockers.isEmpty,
    blockingReasons: blockers,
    warnings: warnings,
    nextEligibleStage: nextStage,
  );
}

class ReleaseCaseEndpointPaths {
  const ReleaseCaseEndpointPaths({
    this.retrieveCase = '/release-cases/{caseId}',
    this.retrieveChecklist = '/release-cases/{caseId}/documents',
    this.updateDocumentPresence =
        '/release-cases/{caseId}/documents/{documentId}',
    this.retrieveClearances = '/release-cases/{caseId}/clearances',
    this.recordClearance = '/release-cases/{caseId}/clearances/{cellId}',
    this.checkEligibility = '/release-cases/{caseId}/eligibility',
    this.issueFinalNoc = '/release-cases/{caseId}/final-noc',
    this.appendAuditEvent = '/audit-events',
  });

  final String retrieveCase;
  final String retrieveChecklist;
  final String updateDocumentPresence;
  final String retrieveClearances;
  final String recordClearance;
  final String checkEligibility;
  final String issueFinalNoc;
  final String appendAuditEvent;
}

abstract interface class ReleaseCaseRepository {
  ReleaseCase? retrieveReleaseCase();
  List<DemoChecklistItem> retrieveRequiredDocumentChecklist();
  void updateRequiredDocumentPresence(String fileName, bool isPresent);
  List<ClearanceState> retrieveCellClearanceStatuses();
  void recordClearanceDecision(String cellName, String status, String remark);
  ReleaseEligibility checkReleaseEligibility(VerificationSummary verification);
  void issueFinalNocInDemoMode();
  void appendAuditEvent({
    required String action,
    required String caseId,
    required String payload,
  });
}

class MockReleaseCaseRepository implements ReleaseCaseRepository {
  MockReleaseCaseRepository(
    this.store, {
    this.endpointPaths = const ReleaseCaseEndpointPaths(),
  });

  final DemoFdrPortalStore store;
  final ReleaseCaseEndpointPaths endpointPaths;

  @override
  ReleaseCase? retrieveReleaseCase() => store.releaseCase;

  @override
  List<DemoChecklistItem> retrieveRequiredDocumentChecklist() =>
      store.releaseCase?.checklist ?? const [];

  @override
  void updateRequiredDocumentPresence(String fileName, bool isPresent) =>
      store.updateDocumentPresence(fileName, isPresent);

  @override
  List<ClearanceState> retrieveCellClearanceStatuses() =>
      store.releaseCase?.clearances ?? const [];

  @override
  void recordClearanceDecision(String cellName, String status, String remark) =>
      store.updateClearanceStatus(cellName, status, remark: remark);

  @override
  ReleaseEligibility checkReleaseEligibility(VerificationSummary verification) {
    final currentCase = retrieveReleaseCase();
    if (currentCase == null) {
      return const ReleaseEligibility(
        canAdvance: false,
        blockingReasons: ['Create a release case before checking eligibility.'],
        warnings: [],
        nextEligibleStage: 'Case Creation',
      );
    }
    return ReleaseEligibilityService.evaluate(
      record: currentCase,
      verification: verification,
      originalFdrExists: store.demoFdrRecords.containsKey(
        currentCase.originalFdrReference,
      ),
    );
  }

  @override
  void issueFinalNocInDemoMode() => store.issueDemoNoc();

  @override
  void appendAuditEvent({
    required String action,
    required String caseId,
    required String payload,
  }) => store.appendAuditEntry(
    action: action,
    associatedId: caseId,
    actorRole: 'Demo Officer',
    payload: payload,
  );
}

class _FdrVerificationDetailPage extends StatefulWidget {
  const _FdrVerificationDetailPage();

  @override
  State<_FdrVerificationDetailPage> createState() =>
      _FdrVerificationDetailPageState();
}

class _FdrVerificationDetailPageState
    extends State<_FdrVerificationDetailPage> {
  bool _isRunning = false;

  Future<void> _runVerification() async {
    setState(() => _isRunning = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final summary = DemoFdrPortalStore.instance.runCurrentVerification();
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'Verification initiated',
      associatedId: DemoFdrPortalStore.instance.currentSubmission.submissionId,
      actorRole: 'Demo Officer',
      payload: summary.statusText,
    );
    if (DemoFdrPortalStore.instance.releaseCase == null) {
      DemoFdrPortalStore.instance.createReleaseCase();
      DemoFdrPortalStore.instance.appendAuditEntry(
        action: 'Release case created',
        associatedId: 'REL-2026-00017',
        actorRole: 'Demo Officer',
        payload: 'Normal Release',
      );
    }
    if (!mounted) return;
    setState(() => _isRunning = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _VerificationResultsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DemoFdrPortalStore.instance;
    final record = store.currentSubmission;
    final submission = store.submissionById(record.submissionId);
    return OfficerPortalShell(
      title: 'FDR Verification',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const _DemoNotice(),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Institution Details',
              rows: {
                'Institution': record.institution,
                'Institution ID': record.institutionId,
                'Submission ID': record.submissionId,
              },
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'FDR Master Details',
              rows: {
                'Bank': record.bank,
                'FDR number': record.fdrNumber,
                'Declared deposit amount':
                    '₹${_formatCurrency(record.declaredDepositAmount)}',
                'Receipt amount': '₹${_formatCurrency(record.receiptAmount)}',
                'Issue date': record.issueDate,
                'Maturity date': record.maturityDate,
                'Declared tenure': '${record.declaredTenureMonths} months',
                'Entered tenure': '${record.enteredTenureMonths} months',
                'Lien information': record.lienInformation,
                'Submission status': record.submissionStatus,
              },
            ),
            if (submission != null &&
                submission.caseType != 'FDR Submission') ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Institution Request Details',
                rows: {
                  'Case ID': submission.caseId ?? 'Not assigned',
                  'Case type': submission.caseType,
                  if (submission.requestedAmount != null)
                    'Requested amount':
                        '₹${_formatCurrency(submission.requestedAmount!)}',
                  if (submission.retainedBalance != null)
                    'Retained balance':
                        '₹${_formatCurrency(submission.retainedBalance!)}',
                  if (submission.requestReason != null)
                    'Reason': submission.requestReason!,
                },
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submitted Documents',
                    key: ValueKey('submitted_documents_title'),
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (record.documents.isEmpty)
                    const Text(
                      'No documents available in demo mode.',
                      style: TextStyle(color: _muted, fontSize: 11),
                    )
                  else
                    for (final document in record.documents) ...[
                      _DocumentListItem(document: document),
                      if (document != record.documents.last)
                        const Divider(height: 16, color: _line),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isRunning ? null : _runVerification,
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _isRunning ? 'Running Verification...' : 'Run Verification',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationResultsPage extends StatefulWidget {
  const _VerificationResultsPage({this.correctionSaved = false});

  final bool correctionSaved;

  @override
  State<_VerificationResultsPage> createState() =>
      _VerificationResultsPageState();
}

class _VerificationResultsPageState extends State<_VerificationResultsPage> {
  @override
  Widget build(BuildContext context) {
    final store = DemoFdrPortalStore.instance;
    final summary = store.verificationResults;
    final record = store.currentSubmission;
    final releaseCase = store.releaseCase!;
    final isBlocked = !store.verificationCurrent || summary.blocking > 0;

    return OfficerPortalShell(
      title: 'Verification Results',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            if (widget.correctionSaved) ...[
              const _InlineNotice(
                message:
                    'Corrected FDR details were saved. Verification has not been rerun; run it below to refresh discrepancies.',
                color: Color(0xFFFFF7ED),
                textColor: Color(0xFF9A3412),
                icon: Icons.save_outlined,
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.statusText,
                          style: TextStyle(
                            color: isBlocked
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF15803D),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryMetric(label: 'Case ID', value: releaseCase.caseId),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Total checks',
                          value: store.verificationCurrent
                              ? summary.totalChecks.toString()
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Blocking',
                          value: store.verificationCurrent
                              ? summary.blocking.toString()
                              : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Warnings',
                          value: store.verificationCurrent
                              ? summary.warnings.toString()
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Status',
                          value: !store.verificationCurrent
                              ? 'Not run'
                              : isBlocked
                              ? 'Blocked'
                              : 'Passed',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...summary.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IssueCard(issue: issue),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Side-by-Side Comparison',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 560;
                      final columns = [
                        _ComparisonColumn(
                          title: 'Institution-Entered Values',
                          entries: [
                            ('Institution', record.institution),
                            ('FDR number', record.fdrNumber),
                            (
                              'Deposit amount',
                              '₹${_formatCurrency(record.declaredDepositAmount)}',
                            ),
                            ('Lien information', record.lienInformation),
                          ],
                        ),
                        _ComparisonColumn(
                          title: 'Receipt Values',
                          entries: [
                            ('FDR number', record.fdrNumber),
                            (
                              'Deposit amount',
                              '₹${_formatCurrency(record.receiptAmount)}',
                            ),
                            ('Lien information', record.lienInformation),
                          ],
                        ),
                        _ComparisonColumn(
                          title: 'Declared Values',
                          entries: [
                            ('Institution', 'Example Institute of Technology'),
                            ('FDR number', record.fdrNumber),
                            (
                              'Deposit amount',
                              '₹${_formatCurrency(record.declaredDepositAmount)}',
                            ),
                            ('Lien information', record.lienInformation),
                          ],
                        ),
                      ];

                      if (stacked) {
                        return Column(
                          children: [
                            for (final column in columns) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: column,
                              ),
                            ],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final column in columns)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: column,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!isBlocked)
              FilledButton.icon(
                onPressed: () {
                  if (DemoFdrPortalStore.instance.releaseCase == null) {
                    DemoFdrPortalStore.instance.createReleaseCase();
                    DemoFdrPortalStore.instance.appendAuditEntry(
                      action: 'Release case created',
                      associatedId: 'REL-2026-00017',
                      actorRole: 'Demo Officer',
                      payload: 'Normal Release',
                    );
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _ReleaseCasePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('Open Release / Refund Case'),
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () {
                  if (DemoFdrPortalStore.instance.releaseCase == null) {
                    DemoFdrPortalStore.instance.createReleaseCase();
                    DemoFdrPortalStore.instance.appendAuditEntry(
                      action: 'Release case created',
                      associatedId: 'REL-2026-00017',
                      actorRole: 'Demo Officer',
                      payload: 'Normal Release; verification currently blocked',
                    );
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _ReleaseCasePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Open Blocked Release Case'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _deepOrange,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _CorrectDetailsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Correct Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _deepOrange,
                    side: const BorderSide(color: Color(0xFFF4C29A)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final summary = store.runCurrentVerification();
                    store.appendAuditEntry(
                      action: 'Verification rerun',
                      associatedId: store.currentSubmission.submissionId,
                      actorRole: 'Demo Officer',
                      payload: summary.statusText,
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    store.verificationCurrent
                        ? 'Re-run Verification'
                        : 'Run Verification',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _line),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _AuditTrailPage(),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Audit Trail'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _line),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
            if (store.submissionById(record.submissionId)?.caseType ==
                    'FDR Submission' &&
                store.submissionById(record.submissionId)?.status !=
                    VerificationStatus.rejected &&
                store.submissionById(record.submissionId)?.status !=
                    VerificationStatus.approved) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  store.rejectSubmission(
                    record.submissionId,
                    reason: summary.issues
                        .map((issue) => issue.message)
                        .join('; '),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.assignment_return_outlined),
                label: const Text(
                  'Return to Institution for Correction (Demo)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CorrectDetailsPage extends StatefulWidget {
  const _CorrectDetailsPage();

  @override
  State<_CorrectDetailsPage> createState() => _CorrectDetailsPageState();
}

class _CorrectDetailsPageState extends State<_CorrectDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fdrNumberController;
  late final TextEditingController _amountController;
  late final TextEditingController _issueDateController;
  late final TextEditingController _maturityDateController;
  late final TextEditingController _tenureController;
  late final TextEditingController _lienController;

  DateTime? _parseDate(String? value) {
    final input = value?.trim() ?? '';
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      final parsed = DateTime(year, month, day);
      if (parsed.year == year && parsed.month == month && parsed.day == day) {
        return parsed;
      }
      return null;
    }

    final match = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$',
    ).firstMatch(input);
    if (match == null) return null;
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final day = int.parse(match.group(1)!);
    final month = months[match.group(2)!.toLowerCase()];
    final year = int.parse(match.group(3)!);
    if (month == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String? _issueDateError(String? value) => _parseDate(value) == null
      ? 'Enter a valid issue date (for example, 01 October 2025)'
      : null;

  String? _maturityDateError(String? value) {
    final maturity = _parseDate(value);
    if (maturity == null) {
      return 'Enter a valid maturity date (for example, 01 October 2028)';
    }
    final issue = _parseDate(_issueDateController.text);
    if (issue == null) return 'Enter a valid issue date first';
    if (!maturity.isAfter(issue)) {
      return 'Maturity date must be after issue date';
    }
    return null;
  }

  String? _tenureError(String? value) {
    final tenure = int.tryParse(value?.trim() ?? '');
    if (tenure == null || tenure <= 0) return 'Enter a valid tenure in months';
    final issue = _parseDate(_issueDateController.text);
    final maturity = _parseDate(_maturityDateController.text);
    if (issue == null || maturity == null || !maturity.isAfter(issue)) {
      return 'Enter a valid issue and maturity date first';
    }
    var months =
        (maturity.year - issue.year) * 12 + maturity.month - issue.month;
    if (maturity.day < issue.day) months--;
    if (tenure != months) {
      return 'Tenure does not match the issue and maturity dates ($months months)';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final record = DemoFdrPortalStore.instance.currentSubmission;
    _fdrNumberController = TextEditingController(text: record.fdrNumber);
    _amountController = TextEditingController(
      text: record.declaredDepositAmount.toString(),
    );
    _issueDateController = TextEditingController(text: record.issueDate);
    _maturityDateController = TextEditingController(text: record.maturityDate);
    _tenureController = TextEditingController(
      text: record.declaredTenureMonths.toString(),
    );
    _lienController = TextEditingController(text: record.lienInformation);
  }

  @override
  void dispose() {
    _fdrNumberController.dispose();
    _amountController.dispose();
    _issueDateController.dispose();
    _maturityDateController.dispose();
    _tenureController.dispose();
    _lienController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final correctedRecord = DemoFdrPortalStore.instance.currentSubmission
        .copyWith(
          fdrNumber: _fdrNumberController.text.trim(),
          declaredDepositAmount: int.parse(_amountController.text.trim()),
          issueDate: _issueDateController.text.trim(),
          maturityDate: _maturityDateController.text.trim(),
          declaredTenureMonths: int.parse(_tenureController.text.trim()),
          enteredTenureMonths: int.parse(_tenureController.text.trim()),
          lienInformation: _lienController.text.trim().isEmpty
              ? 'Not provided'
              : _lienController.text.trim(),
        );

    DemoFdrPortalStore.instance.setCurrentSubmission(correctedRecord);
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'FDR details corrected',
      associatedId: correctedRecord.submissionId,
      actorRole: 'Demo Officer',
      payload:
          'Saved FDR ${correctedRecord.fdrNumber}; declared amount ₹${_formatCurrency(correctedRecord.declaredDepositAmount)}; receipt amount remains ₹${_formatCurrency(correctedRecord.receiptAmount)}',
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const _VerificationResultsPage(correctionSaved: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OfficerPortalShell(
      title: 'Correct FDR Details',
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              const _DemoNotice(),
              const SizedBox(height: 12),
              _FieldCard(
                label: 'FDR number',
                controller: _fdrNumberController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'FDR number is required'
                    : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Declared deposit amount',
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = value == null
                      ? null
                      : int.tryParse(value.trim());
                  if (amount == null) return 'Enter a valid declared amount';
                  if (amount <= 0) {
                    return 'Declared amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _MiniInfoRow(
                label: 'Receipt amount (read only)',
                value:
                    '₹${_formatCurrency(DemoFdrPortalStore.instance.currentSubmission.receiptAmount)}',
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Issue date',
                controller: _issueDateController,
                validator: _issueDateError,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Maturity date',
                controller: _maturityDateController,
                validator: _maturityDateError,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Tenure',
                controller: _tenureController,
                keyboardType: TextInputType.number,
                validator: _tenureError,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Lien information',
                controller: _lienController,
                validator: (value) => (value?.length ?? 0) > 500
                    ? 'Lien information must be 500 characters or fewer'
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Leave blank if unknown; missing lien information remains a verification warning.',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Corrected Details'),
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseCasePage extends StatefulWidget {
  const _ReleaseCasePage();

  @override
  State<_ReleaseCasePage> createState() => _ReleaseCasePageState();
}

class _ReleaseCasePageState extends State<_ReleaseCasePage> {
  static const _caseTypes = ['Normal Release', 'Progressive Closure', 'Merger'];
  final _store = DemoFdrPortalStore.instance;
  late final ReleaseCaseRepository _repository = MockReleaseCaseRepository(
    _store,
  );

  ReleaseCase get _case => _repository.retrieveReleaseCase()!;

  @override
  void initState() {
    super.initState();
    if (_store.releaseCase == null) {
      _store.createReleaseCase();
      _repository.appendAuditEvent(
        action: 'Release case created',
        caseId: 'REL-2026-00017',
        payload: 'Normal Release',
      );
    }
  }

  ReleaseEligibility _eligibility([ReleaseCase? record]) =>
      ReleaseEligibilityService.evaluate(
        record: record ?? _case,
        verification: _store.verificationForEligibility,
        originalFdrExists: _store.demoFdrRecords.containsKey(
          (record ?? _case).originalFdrReference,
        ),
      );

  void _recordEligibilityChange(ReleaseEligibility before) {
    final after = _eligibility();
    if (before.canAdvance != after.canAdvance ||
        before.blockingReasons.join('|') != after.blockingReasons.join('|')) {
      _repository.appendAuditEvent(
        action: 'Case eligibility changed',
        caseId: _case.caseId,
        payload: after.canAdvance
            ? 'Eligible for ${after.nextEligibleStage}'
            : after.blockingReasons.join(' '),
      );
    }
  }

  void _setDocumentPresence(DemoChecklistItem document, bool present) {
    final before = _eligibility();
    _repository.updateRequiredDocumentPresence(document.fileName, present);
    _repository.appendAuditEvent(
      action: present
          ? 'Required document marked present'
          : 'Required document marked missing',
      caseId: _case.caseId,
      payload: document.fileName,
    );
    _recordEligibilityChange(before);
    setState(() {});
  }

  Future<void> _recordClearanceDecision(
    ClearanceState clearance,
    String status,
  ) async {
    final decision = await showDialog<_ClearanceDecisionResult>(
      context: context,
      builder: (_) =>
          _ClearanceDecisionDialog(cellName: clearance.name, status: status),
    );
    if (decision == null || !mounted) return;

    final before = _eligibility();
    _repository.recordClearanceDecision(
      clearance.name,
      status,
      decision.remark,
    );
    _repository.appendAuditEvent(
      action: status == 'Cleared'
          ? 'Clearance decision recorded'
          : 'Clarification requested',
      caseId: _case.caseId,
      payload: '${clearance.name}: $status; ${decision.remark}',
    );
    _recordEligibilityChange(before);
    setState(() {});
  }

  Future<void> _simulateNoc() async {
    if (!_eligibility().canAdvance) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate final NOC?'),
        content: const Text(
          'This records a local demo outcome only. It is not an official NOC and does not release funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm demo action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _repository.issueFinalNocInDemoMode();
    _repository.appendAuditEvent(
      action: 'Final NOC simulated',
      caseId: _case.caseId,
      payload: 'NOC Issued — Demo; no official release or fund transfer',
    );
    setState(() {});
  }

  Future<void> _simulateFdrApproval() async {
    if (!_store.canApproveFdrSubmissionInDemoMode()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate FDR approval?'),
        content: const Text(
          'This records an approved status in local demo data only. It is not official approval and does not transfer funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm demo action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _store.approveFdrSubmissionInDemoMode();
    setState(() {});
  }

  Future<void> _simulateProgressiveApproval() async {
    if (!_eligibility().canAdvance) return;
    final current = _case;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate partial release approval?'),
        content: Text(
          'Record a demo decision for ₹${_formatCurrency(current.requestedReleaseAmount)} and retain ₹${_formatCurrency(current.retainedBalance)}. No funds will be transferred and this is not an official approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm demo action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_eligibility().canAdvance) return;
    _store.approveProgressiveClosureInDemoMode();
    _store.appendAuditEntry(
      action: 'Progressive closure approved in demo mode',
      associatedId: current.caseId,
      actorRole: 'Demo Officer',
      payload:
          'Approved amount ₹${current.requestedReleaseAmount}; retained balance ₹${current.retainedBalance}; no funds transferred',
    );
    setState(() {});
  }

  Future<void> _simulateMergerApproval() async {
    if (!_eligibility().canAdvance) return;
    final current = _case;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate merger approval?'),
        content: Text(
          'Record a demo relationship from ${current.institution} (${current.originalInstitutionId}) to ${current.successorInstitution} (${current.successorInstitutionId}). This has no legal or official effect and does not transfer or modify the original FDR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm demo action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_eligibility().canAdvance) return;
    _store.approveMergerInDemoMode();
    _store.appendAuditEntry(
      action: 'Merger case approved in demo mode',
      associatedId: current.caseId,
      actorRole: 'Demo Officer',
      payload:
          'Relationship recorded: ${current.institution} (${current.originalInstitutionId}) -> ${current.successorInstitution} (${current.successorInstitutionId}); original FDR ${current.originalFdrReference} preserved',
    );
    setState(() {});
  }

  void _openVerificationResults() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _VerificationResultsPage()),
  );

  void _openAuditTrail() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _AuditTrailPage()));

  void _showDocumentDetails(DemoChecklistItem document) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.name),
        content: Text(
          '${document.type}\n${document.fileName}\n\nDemo checklist presence only. No real file is stored or validated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _case;
    final eligibility = _eligibility(record);
    final isNormalRelease = record.caseType == 'Normal Release';
    final isProgressiveClosure = record.caseType == 'Progressive Closure';
    final isMerger = record.caseType == 'Merger';
    final isFdrSubmission =
        _store.submissionById(record.submissionId)?.caseType ==
        'FDR Submission';
    final verificationBlocked =
        !_store.verificationCurrent ||
        _store.verificationForEligibility.blocking > 0;
    final nocIssued = record.status == 'NOC Issued — Demo';
    final caseApproved = record.status.endsWith('Approved — Demo');
    final progressiveAmountValidation =
        ReleaseEligibilityService.validateRequestedAmount(
          record.requestedReleaseAmount.toString(),
          originalFdrAmount: record.originalFdrAmount,
          availableBalance: record.availableBalance,
        );
    final progressiveAmountIsValid = progressiveAmountValidation == null;
    final displayedRetainedBalance = progressiveAmountIsValid
        ? record.retainedBalance
        : 0;

    return OfficerPortalShell(
      title: 'Release / Refund Case',
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 700 ? 28.0 : 18.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                28,
              ),
              children: [
                const Text(
                  'Manage required documents and institutional clearances.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                const _DemoNotice(),
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Case Summary',
                  trailing: const _DemoPill(),
                  child: Column(
                    children: [
                      _MiniInfoRow(label: 'Case ID', value: record.caseId),
                      _MiniInfoRow(
                        label: 'Submission ID',
                        value: record.submissionId,
                      ),
                      _MiniInfoRow(
                        label: 'Institution',
                        value: record.institution,
                      ),
                      if (record.partialReleaseReason.isNotEmpty)
                        _MiniInfoRow(
                          label: 'Request reason',
                          value: record.partialReleaseReason,
                        ),
                      if (isNormalRelease) ...[
                        _MiniInfoRow(
                          label: 'FDR number',
                          value: _store.currentSubmission.fdrNumber,
                        ),
                        _MiniInfoRow(
                          label: 'Deposit amount',
                          value:
                              '₹${_formatCurrency(_store.currentSubmission.declaredDepositAmount)}',
                        ),
                      ] else if (isProgressiveClosure) ...[
                        _MiniInfoRow(
                          label: 'FDR reference',
                          value: record.originalFdrReference,
                        ),
                        _MiniInfoRow(
                          label: 'Original FDR amount',
                          value:
                              '₹${_formatCurrency(record.originalFdrAmount)}',
                        ),
                        _MiniInfoRow(
                          label: 'Requested release',
                          value:
                              '₹${_formatCurrency(record.requestedReleaseAmount)}',
                        ),
                        _MiniInfoRow(
                          label: 'Retained balance',
                          value: '₹${_formatCurrency(record.retainedBalance)}',
                        ),
                      ] else ...[
                        _MiniInfoRow(
                          label: 'Original FDR reference',
                          value: record.originalFdrReference,
                        ),
                        _MiniInfoRow(
                          label: 'Original FDR amount',
                          value:
                              '₹${_formatCurrency(record.originalFdrAmount)}',
                        ),
                        _MiniInfoRow(
                          label: 'Successor institution',
                          value: record.successorInstitution,
                        ),
                        _MiniInfoRow(
                          label: 'Merger reference',
                          value: record.mergerReference,
                        ),
                      ],
                      _MiniInfoRow(label: 'Case status', value: record.status),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Case Type',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('case-type-${record.caseType}'),
                        initialValue: record.caseType,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: _caseTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (type) {
                          if (type == null || type == record.caseType) return;
                          _store.updateReleaseCaseType(type);
                          _store.appendAuditEntry(
                            action: 'Case type selected',
                            associatedId: _store.releaseCase!.caseId,
                            actorRole: 'Demo Officer',
                            payload: type,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Workflow Progress',
                  child: _WorkflowProgress(
                    stages: isNormalRelease
                        ? const [
                            'FDR Verification',
                            'Required Documents',
                            'Grievance Redressal Cell',
                            'Vigilance Cell',
                            'Final NOC',
                          ]
                        : isProgressiveClosure
                        ? const [
                            'FDR Verification',
                            'Partial Release Request',
                            'Required Documents',
                            'Grievance Redressal Cell',
                            'Vigilance Cell',
                            'Final NOC',
                          ]
                        : const [
                            'Original FDR Verification',
                            'Institution and Merger Details',
                            'Required Documents',
                            'Grievance Redressal Cell',
                            'Vigilance Cell',
                            'Final Review and NOC',
                          ],
                    completed: isNormalRelease
                        ? [
                            !verificationBlocked,
                            record.checklist
                                .where((item) => item.isRequired)
                                .every((item) => item.isPresent),
                            record.clearances.first.status == 'Cleared',
                            record.clearances.last.status == 'Cleared',
                            nocIssued,
                          ]
                        : isProgressiveClosure
                        ? [
                            !verificationBlocked,
                            record.requestedReleaseAmount > 0 &&
                                record.requestedReleaseAmount <=
                                    record.availableBalance &&
                                record.partialReleaseReason.trim().isNotEmpty,
                            record.checklist
                                .where((item) => item.isRequired)
                                .every((item) => item.isPresent),
                            record.clearances.first.status == 'Cleared',
                            record.clearances.last.status == 'Cleared',
                            caseApproved,
                          ]
                        : [
                            !verificationBlocked,
                            record.successorInstitution.trim().isNotEmpty &&
                                record.mergerReference.trim().isNotEmpty &&
                                record.effectiveDate.trim().isNotEmpty,
                            record.checklist
                                .where((item) => item.isRequired)
                                .every((item) => item.isPresent),
                            record.clearances.first.status == 'Cleared',
                            record.clearances.last.status == 'Cleared',
                            caseApproved,
                          ],
                    nextStage: eligibility.nextEligibleStage,
                  ),
                ),
                if (verificationBlocked) ...[
                  const SizedBox(height: 10),
                  _InlineNotice(
                    message: _store.verificationCurrent
                        ? 'Case blocked — resolve all blocking FDR discrepancies before proceeding. ${_store.lastVerification.blocking} blocking item(s) remain.'
                        : 'Verification required — run verification for the saved FDR details before proceeding.',
                    color: const Color(0xFFFEF2F2),
                    textColor: const Color(0xFF991B1B),
                    icon: Icons.block_rounded,
                    action: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        TextButton.icon(
                          onPressed: _openVerificationResults,
                          icon: const Icon(Icons.fact_check_outlined, size: 17),
                          label: const Text('View Verification Results'),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const _CorrectDetailsPage(),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 17),
                          label: const Text('Correct FDR Details'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isProgressiveClosure) ...[
                  const SizedBox(height: 12),
                  _ReleaseSection(
                    title: 'Partial Release Request',
                    trailing: const _DemoPill(),
                    child: Form(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MiniInfoRow(
                            label: 'Original FDR amount',
                            value:
                                '₹${_formatCurrency(record.originalFdrAmount)}',
                          ),
                          _MiniInfoRow(
                            label: 'FDR reference',
                            value: record.originalFdrReference,
                          ),
                          _MiniInfoRow(
                            label: 'Currently available balance',
                            value:
                                '₹${_formatCurrency(record.availableBalance)}',
                          ),
                          TextFormField(
                            key: ValueKey('pcl-amount-${record.caseId}'),
                            initialValue: record.requestedReleaseAmount
                                .toString(),
                            keyboardType: TextInputType.number,
                            autovalidateMode: AutovalidateMode.always,
                            decoration: const InputDecoration(
                              labelText: 'Requested release amount (₹)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final amount = value == null
                                  ? null
                                  : int.tryParse(value.trim());
                              if (value == null || value.trim().isEmpty) {
                                return 'Requested release amount is required.';
                              }
                              if (amount == null) {
                                return 'Requested release amount must be numeric.';
                              }
                              if (amount <= 0) {
                                return 'Requested release amount must be greater than zero.';
                              }
                              if (amount > record.originalFdrAmount) {
                                return 'Requested release amount cannot exceed the original FDR amount.';
                              }
                              if (amount > record.availableBalance) {
                                return 'Requested release amount cannot exceed the currently available balance.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final trimmed = value.trim();
                              final parsed = int.tryParse(trimmed);
                              if (trimmed.isEmpty || parsed == null) {
                                return;
                              }
                              final oldAmount = _case.requestedReleaseAmount;
                              if (parsed == oldAmount) return;
                              _store.updateProgressiveClosure(
                                requestedAmount: parsed,
                              );
                              _store.appendAuditEntry(
                                action: 'Partial release amount changed',
                                associatedId: record.caseId,
                                actorRole: 'Demo Officer',
                                payload: 'Requested amount ₹$parsed',
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Calculated retained balance: ₹${_formatCurrency(displayedRetainedBalance)}',
                            style: TextStyle(
                              color: displayedRetainedBalance < 0
                                  ? const Color(0xFFB91C1C)
                                  : _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey('pcl-reason-${record.caseId}'),
                            initialValue: record.partialReleaseReason,
                            maxLines: 2,
                            autovalidateMode: AutovalidateMode.always,
                            decoration: const InputDecoration(
                              labelText: 'Reason for partial release',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'A reason is required.'
                                : null,
                            onChanged: (value) {
                              final changed =
                                  value != _case.partialReleaseReason;
                              _store.updateProgressiveClosure(reason: value);
                              if (changed) {
                                _store.appendAuditEntry(
                                  action: 'Partial release reason changed',
                                  associatedId: record.caseId,
                                  actorRole: 'Demo Officer',
                                  payload: value,
                                );
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (isMerger) ...[
                  const SizedBox(height: 12),
                  _ReleaseSection(
                    title: 'Institution and Merger Details',
                    trailing: const _DemoPill(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniInfoRow(
                          label: 'Original institution',
                          value: record.institution,
                        ),
                        _MiniInfoRow(
                          label: 'Original institution ID',
                          value: record.originalInstitutionId,
                        ),
                        _MiniInfoRow(
                          label: 'Successor institution ID',
                          value: record.successorInstitutionId,
                        ),
                        _MiniInfoRow(
                          label: 'Original FDR reference',
                          value: record.originalFdrReference,
                        ),
                        _MiniInfoRow(
                          label: 'Original FDR amount',
                          value:
                              '₹${_formatCurrency(record.originalFdrAmount)}',
                        ),
                        TextFormField(
                          key: ValueKey('merger-successor-${record.caseId}'),
                          initialValue: record.successorInstitution,
                          autovalidateMode: AutovalidateMode.always,
                          decoration: const InputDecoration(
                            labelText: 'Successor institution',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Successor institution is required.'
                              : null,
                          onChanged: (value) {
                            final changed = value != _case.successorInstitution;
                            _store.updateMergerDetails(
                              successorInstitution: value,
                            );
                            if (changed) {
                              _store.appendAuditEntry(
                                action: 'Successor institution details changed',
                                associatedId: record.caseId,
                                actorRole: 'Demo Officer',
                                payload: value,
                              );
                            }
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: ValueKey('merger-reference-${record.caseId}'),
                          initialValue: record.mergerReference,
                          autovalidateMode: AutovalidateMode.always,
                          decoration: const InputDecoration(
                            labelText: 'Merger reference number',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Merger reference is required.'
                              : null,
                          onChanged: (value) {
                            final changed = value != _case.mergerReference;
                            _store.updateMergerDetails(mergerReference: value);
                            if (changed) {
                              _store.appendAuditEntry(
                                action: 'Merger reference changed',
                                associatedId: record.caseId,
                                actorRole: 'Demo Officer',
                                payload: value,
                              );
                            }
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: ValueKey('merger-date-${record.caseId}'),
                          initialValue: record.effectiveDate,
                          autovalidateMode: AutovalidateMode.always,
                          decoration: const InputDecoration(
                            labelText: 'Effective date',
                            hintText: 'DD Month YYYY',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Effective date is required.'
                              : null,
                          onChanged: (value) {
                            final changed = value != _case.effectiveDate;
                            _store.updateMergerDetails(effectiveDate: value);
                            if (changed) {
                              _store.appendAuditEntry(
                                action: 'Merger effective date changed',
                                associatedId: record.caseId,
                                actorRole: 'Demo Officer',
                                payload: value,
                              );
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                ...[
                  const SizedBox(height: 12),
                  _ReleaseSection(
                    title: 'Required Documents',
                    child: Column(
                      children: [
                        for (final document in record.checklist)
                          _ReleaseDocumentRow(
                            document: document,
                            onChanged: (present) =>
                                _setDocumentPresence(document, present),
                            onDetails: () => _showDocumentDetails(document),
                          ),
                        if (record.checklist.any(
                          (item) => item.isRequired && !item.isPresent,
                        )) ...[
                          const SizedBox(height: 6),
                          const _InlineNotice(
                            message:
                                'Missing required documents must be marked present before this case can advance. No file upload is connected in demo mode.',
                            color: Color(0xFFFFF7ED),
                            textColor: Color(0xFF9A3412),
                            icon: Icons.upload_file_outlined,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReleaseSection(
                    title: 'Cell Clearances',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final clearance in record.clearances)
                          _ClearanceCard(
                            clearance: clearance,
                            onClear: () =>
                                _recordClearanceDecision(clearance, 'Cleared'),
                            onClarification: () => _recordClearanceDecision(
                              clearance,
                              'Clarification Requested',
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Required clearances are processed independently. The case cannot proceed until every required clearance is complete.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: isMerger ? 'Final Review and NOC' : 'Final NOC',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Status',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ),
                          _ReleaseStatusBadge(status: record.status),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        isProgressiveClosure
                            ? 'Required: valid partial amount and reason, required documents, resolved FDR discrepancies, and both cell clearances.'
                            : isMerger
                            ? 'Required: verified original FDR, complete merger details, required documents, resolved discrepancies, and both cell clearances.'
                            : 'Required: all blocking discrepancies resolved, required documents present, and required cell clearances completed.',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      if (isProgressiveClosure && caseApproved) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Approved amount: ₹${_formatCurrency(record.requestedReleaseAmount)} · Retained balance: ₹${_formatCurrency(record.retainedBalance)}',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Demo decision only. No real funds were transferred.',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                      if (isMerger && caseApproved) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Demo relationship recorded: ${record.institution} (${record.originalInstitutionId}) → ${record.successorInstitution} (${record.successorInstitutionId})',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Original FDR ${record.originalFdrReference} remains preserved. This demo record has no legal or official effect.',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                      const SizedBox(height: 10),
                      for (final clearance in record.clearances)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  clearance.name,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              _ReleaseStatusBadge(status: clearance.status),
                            ],
                          ),
                        ),
                      if (!eligibility.canAdvance) ...[
                        const SizedBox(height: 8),
                        for (final reason in eligibility.blockingReasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $reason',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        for (final document in eligibility.missingDocuments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Missing document: $document',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        for (final clearance in eligibility.pendingClearances)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Pending clearance: $clearance',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                      if (eligibility.warnings.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        for (final warning in eligibility.warnings)
                          Text(
                            'Warning: $warning',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      if (isNormalRelease && isFdrSubmission) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _store.canApproveFdrSubmissionInDemoMode()
                                ? _simulateFdrApproval
                                : null,
                            icon: const Icon(Icons.verified_rounded),
                            label: Text(
                              _store
                                          .submissionById(record.submissionId)
                                          ?.status ==
                                      VerificationStatus.approved
                                  ? 'FDR Approved — Demo'
                                  : 'Approve FDR Submission (Demo)',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              !eligibility.canAdvance ||
                                  nocIssued ||
                                  caseApproved
                              ? null
                              : isNormalRelease
                              ? _simulateNoc
                              : isProgressiveClosure
                              ? _simulateProgressiveApproval
                              : _simulateMergerApproval,
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(
                            nocIssued
                                ? 'NOC Issued — Demo'
                                : caseApproved
                                ? record.status
                                : isProgressiveClosure
                                ? 'Simulate Partial Release Approval'
                                : isMerger
                                ? 'Simulate Merger Approval'
                                : 'Simulate Final NOC',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _releaseOrange,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Demo only. No official approval, legal effect, or real fund transfer is represented.',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAuditTrail,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Audit Trail'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Audit hash-chain is local demo functionality; backend integrity has not been connected or verified.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

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
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'DEMO DATA',
      style: TextStyle(
        color: _deepOrange,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
    this.action,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: textColor.withValues(alpha: 0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor, size: 17),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (action != null)
          Align(alignment: Alignment.centerLeft, child: action!),
      ],
    ),
  );
}

class _WorkflowProgress extends StatelessWidget {
  const _WorkflowProgress({
    required this.stages,
    required this.completed,
    required this.nextStage,
  });

  final List<String> stages;
  final List<bool> completed;
  final String nextStage;

  @override
  Widget build(BuildContext context) {
    var currentIndex = stages.indexOf(nextStage);
    if (currentIndex < 0) currentIndex = stages.length - 1;
    if (completed[currentIndex]) {
      currentIndex = completed.indexWhere((isCompleted) => !isCompleted);
    }
    return Column(
      children: [
        for (var index = 0; index < stages.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed[index]
                          ? const Color(0xFF15803D)
                          : index == currentIndex
                          ? _releaseOrange
                          : const Color(0xFFF3F4F6),
                    ),
                    child: Icon(
                      completed[index] ? Icons.check_rounded : Icons.circle,
                      size: completed[index] ? 16 : 12,
                      color: completed[index] || index == currentIndex
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (index < stages.length - 1)
                    Container(
                      width: 2,
                      height: 18,
                      color: completed[index]
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE5E7EB),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    stages[index],
                    style: TextStyle(
                      color: completed[index]
                          ? const Color(0xFF166534)
                          : index == currentIndex
                          ? _deepOrange
                          : _muted,
                      fontSize: 12,
                      fontWeight: index == currentIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (index == currentIndex)
                const Padding(
                  padding: EdgeInsets.only(left: 7, top: 4),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      color: _deepOrange,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReleaseDocumentRow extends StatelessWidget {
  const _ReleaseDocumentRow({
    required this.document,
    required this.onChanged,
    required this.onDetails,
  });

  final DemoChecklistItem document;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          document.isPresent
              ? Icons.description_outlined
              : Icons.insert_drive_file_outlined,
          color: document.isPresent ? const Color(0xFF15803D) : _muted,
          size: 21,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${document.fileName} · Required',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              Text(
                document.status,
                style: TextStyle(
                  color: document.isPresent
                      ? const Color(0xFF166534)
                      : const Color(0xFFB45309),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'View document details',
          onPressed: onDetails,
          icon: const Icon(Icons.info_outline_rounded, size: 19),
        ),
        SizedBox(
          width: 44,
          child: Switch(
            value: document.isPresent,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF86EFAC),
          ),
        ),
      ],
    ),
  );
}

class _ClearanceCard extends StatelessWidget {
  const _ClearanceCard({
    required this.clearance,
    required this.onClear,
    required this.onClarification,
  });

  final ClearanceState clearance;
  final VoidCallback onClear;
  final VoidCallback onClarification;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                clearance.name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ReleaseStatusBadge(status: clearance.status),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          clearance.lastUpdated == null
              ? 'Not reviewed'
              : 'Updated ${clearance.lastUpdated}',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          clearance.remark,
          style: const TextStyle(color: _ink, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Mark Cleared'),
            ),
            OutlinedButton.icon(
              onPressed: onClarification,
              icon: const Icon(Icons.help_outline_rounded, size: 16),
              label: const Text('Request Clarification'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReleaseStatusBadge extends StatelessWidget {
  const _ReleaseStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isCleared = status == 'Cleared' || status == 'NOC Issued — Demo';
    final isClarification = status == 'Clarification Requested';
    final color = isCleared
        ? const Color(0xFF166534)
        : isClarification
        ? const Color(0xFF9A3412)
        : const Color(0xFF92400E);
    final fill = isCleared
        ? const Color(0xFFDCFCE7)
        : isClarification
        ? const Color(0xFFFFEDD5)
        : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClearanceDecisionResult {
  const _ClearanceDecisionResult(this.remark);
  final String remark;
}

class _ClearanceDecisionDialog extends StatefulWidget {
  const _ClearanceDecisionDialog({
    required this.cellName,
    required this.status,
  });

  final String cellName;
  final String status;

  @override
  State<_ClearanceDecisionDialog> createState() =>
      _ClearanceDecisionDialogState();
}

class _ClearanceDecisionDialogState extends State<_ClearanceDecisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClearing = widget.status == 'Cleared';
    return AlertDialog(
      title: Text(isClearing ? 'Simulate clearance' : 'Request clarification'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.cellName}\nDemo action only. No official AICTE clearance is being recorded.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarkController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Officer remark',
                hintText: 'Enter review remark',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  !isClearing && (value == null || value.trim().isEmpty)
                  ? 'Explain what information is needed.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final remark = _remarkController.text.trim().isEmpty
                ? 'Demo clearance recorded after review.'
                : _remarkController.text.trim();
            Navigator.pop(context, _ClearanceDecisionResult(remark));
          },
          child: Text(
            isClearing ? 'Confirm demo clearance' : 'Record clarification',
          ),
        ),
      ],
    );
  }
}

class _AuditTrailPage extends StatefulWidget {
  const _AuditTrailPage();

  @override
  State<_AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<_AuditTrailPage> {
  String _verificationMessage = 'Integrity check not requested.';

  AuditIntegrityResult _verifyChain() {
    return verifyAuditChain(DemoFdrPortalStore.instance.auditEntries);
  }

  void _simulateTampering() {
    if (DemoFdrPortalStore.instance.auditEntries.length < 2) return;
    final tamperedIndex = 1;
    final current = DemoFdrPortalStore.instance.auditEntries[tamperedIndex];
    DemoFdrPortalStore.instance._auditEntries[tamperedIndex] = current.copyWith(
      entryHash: 'TAMPERED-${current.eventId}',
    );
    final result = _verifyChain();
    setState(() => _verificationMessage = result.message);
  }

  void _resetDemoData() {
    DemoFdrPortalStore.instance.resetDemoData();
    setState(() => _verificationMessage = 'Demo data reset. Chain restored.');
  }

  @override
  Widget build(BuildContext context) {
    final entries = DemoFdrPortalStore.instance.auditEntries;
    final integrity = _verifyChain();

    return OfficerPortalShell(
      title: 'Audit Trail',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          integrity.isValid
                              ? 'Verified'
                              : 'Integrity issue found',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verificationMessage.isEmpty
                        ? integrity.message
                        : _verificationMessage,
                    style: TextStyle(
                      color: integrity.isValid
                          ? const Color(0xFF166534)
                          : const Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final result = _verifyChain();
                            setState(
                              () => _verificationMessage = result.message,
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Verify Integrity'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _simulateTampering,
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: const Text('Simulate Tampering'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _resetDemoData,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset Demo Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _deepOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final entry in entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event ID: ${entry.eventId}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Timestamp: ${entry.timestamp}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    Text(
                      'Actor: ${entry.actorRole}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    Text(
                      'Action: ${entry.action}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Associated: ${entry.associatedId}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    if (entry.payload.isNotEmpty)
                      Text(
                        'Detail: ${entry.payload}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Previous hash: ${entry.previousHash}',
                      style: const TextStyle(color: _ink, fontSize: 9),
                    ),
                    Text(
                      'Current entry hash: ${entry.entryHash}',
                      style: const TextStyle(color: _ink, fontSize: 9),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final row in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    row.key,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final VerificationIssue issue;

  @override
  Widget build(BuildContext context) {
    final isBlocking = issue.severity == VerificationIssueSeverity.blocking;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBlocking ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocking ? const Color(0xFFFECACA) : const Color(0xFFFCD9A6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isBlocking
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: isBlocking
                ? const Color(0xFFB91C1C)
                : const Color(0xFFB45309),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBlocking ? 'Blocking issue' : 'Warning',
                  style: TextStyle(
                    color: isBlocking
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFFB45309),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  issue.message,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    height: 1.4,
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

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({required this.title, required this.entries});

  final String title;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF7),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    entry.$1,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.$2,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

class _DocumentListItem extends StatelessWidget {
  const _DocumentListItem({required this.document});

  final DemoDocument document;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.insert_drive_file_outlined,
        color: _deepOrange,
        size: 18,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.fileName,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              document.name,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ],
        ),
      ),
      Text(
        document.status,
        style: const TextStyle(
          color: Color(0xFF16A34A),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        validator: validator,
      ),
    ],
  );
}

class _MiniInfoRow extends StatelessWidget {
  const _MiniInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatCurrency(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (Match match) => ',',
);

int _parseCurrency(String amount) =>
    int.tryParse(amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

String _statusLabel(SubmissionStatus status) => switch (status) {
  SubmissionStatus.pendingReview => 'Pending Review',
  SubmissionStatus.approved => 'Approved — Demo',
  SubmissionStatus.rejected => 'Rejected',
  SubmissionStatus.correctionRequested => 'Returned for Correction',
  SubmissionStatus.blocked => 'Blocked — FDR Verification',
};

DateTime _parseUpdatedAt(String value) {
  final parts = value.split(' ');
  if (parts.length == 3) {
    const months = [
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
    final month = months.indexOf(parts[1]) + 1;
    final day = int.tryParse(parts[0]);
    final year = int.tryParse(parts[2]);
    if (month > 0 && day != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return DateTime.tryParse(value) ?? DateTime.now();
}
