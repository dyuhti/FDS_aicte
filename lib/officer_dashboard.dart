import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'notification_center.dart';
import 'portal_foundations.dart';

const _orange = Color(0xFFF97316);
const _releaseOrange = Color(0xFFFF6B1A);
const _deepOrange = Color(0xFFEA580C);
const _ink = Color(0xFF242424);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFEAE6E1);
const _paper = Color(0xFFFFFBF7);
final ValueNotifier<int> _officerSelectedTab = ValueNotifier<int>(0);

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
    this.sourceValues = const {},
    this.supportedDocuments = const [],
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
  final Map<DocumentSource, Map<String, String?>> sourceValues;
  final List<SupportedDocument> supportedDocuments;
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

List<Institution> _institutionsSelector(Iterable<Submission> submissions) {
  final byId = <String, Institution>{};
  for (final submission in submissions) {
    byId.putIfAbsent(
      submission.institutionId,
      () => Institution(
        id: submission.institutionId,
        name: submission.institution,
      ),
    );
  }
  return List<Institution>.unmodifiable(byId.values);
}

List<Institution> institutions(Iterable<Submission> submissions) =>
    _institutionsSelector(submissions);

List<Submission> submissionsForInstitution(
  Iterable<Submission> submissions,
  String institutionId,
) => submissions
    .where((submission) => submission.institutionId == institutionId)
    .toList(growable: false);

Map<SubmissionStatus, int> statusBreakdownForInstitution(
  Iterable<Submission> submissions,
  String institutionId,
) => {
  for (final status in SubmissionStatus.values)
    status: countByStatus(
      submissionsForInstitution(submissions, institutionId),
      status,
    ),
};

int totalDepositForInstitution(
  Iterable<Submission> submissions,
  String institutionId,
) => submissionsForInstitution(
  submissions,
  institutionId,
).fold(0, (total, submission) => total + submission.depositAmount);

Map<SubmissionStatus, int> totalDepositByStatus(
  Iterable<Submission> submissions,
) => {
  for (final status in SubmissionStatus.values)
    status: submissionsByStatus(
      submissions,
      status,
    ).fold(0, (total, submission) => total + submission.depositAmount),
};

Map<String, int> totalDepositByBank(Iterable<Submission> submissions) {
  final totals = <String, int>{};
  for (final submission in submissions) {
    totals.update(
      submission.bankName,
      (total) => total + submission.depositAmount,
      ifAbsent: () => submission.depositAmount,
    );
  }
  return Map<String, int>.unmodifiable(totals);
}

Map<String, List<Submission>> submissionsByBank(
  Iterable<Submission> submissions,
) {
  final grouped = <String, List<Submission>>{};
  for (final submission in submissions) {
    grouped.putIfAbsent(submission.bankName, () => []).add(submission);
  }
  final result = <String, List<Submission>>{};
  for (final entry in grouped.entries) {
    result[entry.key] = List<Submission>.unmodifiable(entry.value);
  }
  return Map<String, List<Submission>>.unmodifiable(result);
}

Map<SubmissionStatus, int> statusPercentages(Iterable<Submission> submissions) {
  final total = totalSubmissions(submissions);
  if (total == 0) {
    return {for (final status in SubmissionStatus.values) status: 0};
  }
  final percentages = <SubmissionStatus, int>{};
  var assigned = 0;
  for (final status in SubmissionStatus.values) {
    final percentage = (countByStatus(submissions, status) * 100 / total)
        .round();
    percentages[status] = percentage;
    assigned += percentage;
  }
  if (assigned != 100) {
    final largest = SubmissionStatus.values.reduce(
      (left, right) =>
          countByStatus(submissions, left) >= countByStatus(submissions, right)
          ? left
          : right,
    );
    percentages[largest] = percentages[largest]! + 100 - assigned;
  }
  return percentages;
}

Map<SubmissionStatus, int> statusPercentagesFor(
  Iterable<Submission> submissions,
) => statusPercentages(submissions);

Submission? latestActivityForInstitution(
  Iterable<Submission> submissions,
  String institutionId,
) {
  final records = submissionsForInstitution(
    submissions,
    institutionId,
  ).toList();
  if (records.isEmpty) return null;
  records.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return records.first;
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
    return _institutionsSelector(submissions);
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
  static const _destinations = [
    'Home',
    'Submissions',
    'Institutions',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _officerSelectedTab.value = 0;
  }

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
    return ValueListenableBuilder<int>(
      valueListenable: _officerSelectedTab,
      builder: (context, selectedTab, _) {
        final isHome = selectedTab == 0;
        final title = _destinations[selectedTab];
        return OfficerPortalShell(
          userId: widget.userId,
          onNotifications: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => NotificationsPage(
                role: NotificationRecipientRole.officer,
                onSelectTab: (index) => _officerSelectedTab.value = index,
                onOpenRelated: (notification) {
                  Navigator.of(context).pop();
                  final submission = notification.relatedId == null
                      ? null
                      : DemoFdrPortalStore.instance.submissionById(
                          notification.relatedId!,
                        );
                  if (submission != null) _openReview(submission);
                },
              ),
            ),
          ),
          onProfile: () => _officerSelectedTab.value = 3,
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
              : selectedTab == 1
              ? _SubmissionListView(
                  repository: widget.repository,
                  initialFilter: SubmissionListFilter.all,
                  onReviewSubmission: _openReview,
                )
              : selectedTab == 2
              ? _InstitutionRegistryView(
                  repository: widget.repository,
                  onReviewSubmission: _openReview,
                )
              : selectedTab == 3
              ? OfficerProfilePage(
                  userId: widget.userId,
                  onSignOut: widget.onSignOut,
                )
              : _DestinationBody(
                  title: title,
                  subtitle: _tabSubtitle(selectedTab),
                  onOpenPage: _openPage,
                ),
          bottomNavigationBar: NavigationBar(
            height: 88,
            selectedIndex: selectedTab,
            onDestinationSelected: (index) {
              if (index != selectedTab) _officerSelectedTab.value = index;
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
      },
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
    this.extraActions = const [],
  });

  final Widget body;
  final String? title;
  final String userId;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onSignOut;
  final VoidCallback? onBack;
  final Widget? bottomNavigationBar;
  final List<Widget> extraActions;

  void _showDemoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = switch (title) {
      'Profile' => 3,
      'Institutions' || 'Institution Details' => 2,
      'Home' ||
      'Officer Action Queue' ||
      'Deadline Command Center' ||
      'Case History' ||
      'Audit Trail' ||
      'Reports' ||
      'Verification Rules' => 0,
      _ => 1,
    };
    return ScreenScaffold(
      backgroundColor: _paper,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(title == null ? 59 : 107),
        child: SafeArea(
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
                      ...extraActions,
                      IconButton(
                        tooltip: 'Case History',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _CaseHistoryPage(),
                          ),
                        ),
                        icon: const Icon(Icons.history_rounded),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed:
                            onNotifications ??
                            () => _showDemoMessage(
                              context,
                              'Notifications are currently unavailable.',
                            ),
                        icon: AnimatedBuilder(
                          animation: NotificationCenter.instance,
                          builder: (context, _) => Badge(
                            isLabelVisible:
                                NotificationCenter.instance.unreadCount(
                                  NotificationRecipientRole.officer,
                                ) >
                                0,
                            label: Text(
                              '${NotificationCenter.instance.unreadCount(NotificationRecipientRole.officer)}',
                            ),
                            child: const _NotificationIcon(),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Officer profile',
                        onSelected: (value) {
                          if (value == 'profile') {
                            onProfile?.call();
                            if (onProfile == null) {
                              _showDemoMessage(
                                context,
                                'Profile settings are currently unavailable.',
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
      ),
      body: AnimatedBuilder(
        animation: DemoFdrPortalStore.instance,
        builder: (context, _) => body,
      ),
      bottomNavigationBar:
          bottomNavigationBar ??
          NavigationBar(
            height: 88,
            selectedIndex: selectedTab,
            onDestinationSelected: (index) {
              _officerSelectedTab.value = index;
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
                      Expanded(
                        child: Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 18),
                  _SectionHeading(
                    title: 'Overview',
                    trailing: 'Current status',
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final metrics = <_MetricCard>[
                        _MetricCard(
                          label: 'Pending Review',
                          value: repository.countByStatus(
                            SubmissionStatus.pendingReview,
                          ),
                          note: 'Awaiting officer review',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFFD97706),
                        ),
                        _MetricCard(
                          label: 'Approved',
                          value: repository.countByStatus(
                            SubmissionStatus.approved,
                          ),
                          note: 'Final approval reached',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF16A34A),
                        ),
                        _MetricCard(
                          label: 'Rejected',
                          value: repository.countByStatus(
                            SubmissionStatus.rejected,
                          ),
                          note: 'Rejected submissions',
                          icon: Icons.cancel_outlined,
                          color: const Color(0xFFDC2626),
                        ),
                        _MetricCard(
                          label: 'Needs Correction',
                          value: repository.countByStatus(
                            SubmissionStatus.correctionRequested,
                          ),
                          note: 'Correction requested',
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFFB45309),
                        ),
                        _MetricCard(
                          label: 'Blocked',
                          value: repository.countByStatus(
                            SubmissionStatus.blocked,
                          ),
                          note: 'Blocked submissions',
                          icon: Icons.block_rounded,
                          color: const Color(0xFFB91C1C),
                        ),
                        _MetricCard(
                          label: 'Total Submissions',
                          value: repository.totalSubmissions,
                          note: 'All cases',
                          icon: Icons.assignment_outlined,
                          color: _orange,
                        ),
                        _MetricCard(
                          label: 'Total Institutions',
                          value: repository.uniqueInstitutionCount,
                          note: 'Unique institutions',
                          icon: Icons.account_balance_outlined,
                          color: _orange,
                        ),
                      ];
                      final aspectRatio = gridConstraints.maxWidth < 380
                          ? 1.45
                          : 1.72;
                      final baseCardHeight =
                          ((gridConstraints.maxWidth - 10) / 2) / aspectRatio;
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final cardHeight =
                          baseCardHeight + (scale > 1 ? (scale - 1) * 24 : 0);
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < metrics.length;
                            index += 2
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index + 2 < metrics.length ? 10 : 0,
                              ),
                              child: SizedBox(
                                height: cardHeight,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        label: metrics[index].label,
                                        value: metrics[index].value,
                                        note: metrics[index].note,
                                        icon: metrics[index].icon,
                                        color: metrics[index].color,
                                        wide:
                                            index + 1 == metrics.length &&
                                            metrics.length.isOdd,
                                      ),
                                    ),
                                    if (index + 1 < metrics.length) ...[
                                      const SizedBox(width: 10),
                                      Expanded(child: metrics[index + 1]),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SummaryTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Action Queue',
                    count: buildOfficerActionQueue(
                      DemoFdrPortalStore.instance,
                    ).length,
                    subtitle:
                        '${buildOfficerActionQueue(DemoFdrPortalStore.instance).where((item) => item.priority == 'High').length} high priority · ${buildOfficerActionQueue(DemoFdrPortalStore.instance).where((item) => item.priority != 'High').length} routine',
                    accentColor: const Color(0xFFEA580C),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _FullActionQueuePage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SummaryTile(
                    icon: Icons.timer_rounded,
                    title: 'Deadline Command Center',
                    count: DemoFdrPortalStore.instance.deadlineItems.length,
                    subtitle: DemoFdrPortalStore.instance.deadlineItems.isEmpty
                        ? 'No deadlines due'
                        : '${DemoFdrPortalStore.instance.deadlineItems.where((item) => item.status == MaturityStatus.critical).length} critical · ${DemoFdrPortalStore.instance.deadlineItems.where((item) => item.status == MaturityStatus.matured).length} matured · ${DemoFdrPortalStore.instance.deadlineItems.where((item) => item.status == MaturityStatus.expiringSoon).length} expiring soon',
                    accentColor: const Color(0xFFD97706),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _DeadlineCommandCenterPage(),
                      ),
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
                            'Pending Review',
                            subtitle: 'Review submissions awaiting action.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.domain_outlined,
                          label: 'Institution Registry',
                          onTap: () => _officerSelectedTab.value = 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _QuickAction(
                    icon: Icons.analytics_outlined,
                    label: 'Reports',
                    onTap: () => onOpenPage('Reports'),
                  ),
                  const SizedBox(height: 21),
                  _SectionHeading(
                    title: 'Pending Verification',
                    actionLabel:
                        'View all (${repository.pendingSubmissions.length})',
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
                  if (repository.pendingSubmissions.isEmpty)
                    const _InlineEmptyState(
                      message: 'No pending submissions to review.',
                    )
                  else
                    for (final submission in repository.pendingSubmissions.take(
                      2,
                    ))
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
                    trailing: 'Recent activity',
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

class _InstitutionRegistryView extends StatefulWidget {
  const _InstitutionRegistryView({
    required this.repository,
    required this.onReviewSubmission,
  });

  final OfficerDashboardRepository repository;
  final ValueChanged<FdrSubmission> onReviewSubmission;

  @override
  State<_InstitutionRegistryView> createState() =>
      _InstitutionRegistryViewState();
}

class _CaseHistoryPage extends StatelessWidget {
  const _CaseHistoryPage();

  @override
  Widget build(BuildContext context) {
    final events = DemoFdrPortalStore.instance.auditEntries
        .map(
          (entry) => (
            title: entry.action,
            actor: entry.actorRole,
            time: entry.timestamp,
            detail: entry.payload,
          ),
        )
        .toList();

    return OfficerPortalShell(
      title: 'Case History',
      body: events.isEmpty
          ? const Center(child: Text('No history available.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                for (final event in events.reversed)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(
                        Icons.history_rounded,
                        color: _orange,
                      ),
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.actor} · ${event.time}\n${event.detail}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DeadlineCommandCenterPage extends StatelessWidget {
  const _DeadlineCommandCenterPage();

  @override
  Widget build(BuildContext context) {
    final items = DemoFdrPortalStore.instance.deadlineItems;
    return OfficerPortalShell(
      title: 'Deadline Command Center',
      body: AnimatedBuilder(
        animation: DemoFdrPortalStore.instance,
        builder: (context, _) {
          final lastScan = DemoFdrPortalStore.instance.lastReminderScanAt;
          final created = DemoFdrPortalStore.instance.lastReminderCreated;
          final alreadySent =
              DemoFdrPortalStore.instance.lastReminderAlreadySent;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Run Reminder Scan',
                      variant: AppButtonVariant.primary,
                      icon: Icons.notifications_active_rounded,
                      onPressed: () {
                        final created = DemoFdrPortalStore.instance
                            .runReminderScan();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$created reminder(s) created'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lastScan == null
                    ? 'Last scan: Not run yet'
                    : 'Last scan: ${lastScan.day} ${_monthName(lastScan.month)} ${lastScan.year}, ${lastScan.hour.toString().padLeft(2, '0')}:${lastScan.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '$created new reminders sent, $alreadySent already sent',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final item in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      '${item.submission.reference} · ${item.status.label}',
                    ),
                    subtitle: Text(
                      '${item.submission.institution}\n${item.nextAction}',
                    ),
                    isThreeLine: true,
                    trailing:
                        item.status == MaturityStatus.active || item.isRenewed
                        ? null
                        : TextButton(
                            onPressed: () {
                              // no-op placeholder for renewal action in page shell
                            },
                            child: const Text('Renew FDR'),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FullActionQueuePage extends StatefulWidget {
  const _FullActionQueuePage();

  @override
  State<_FullActionQueuePage> createState() => _FullActionQueuePageState();
}

class _FullActionQueuePageState extends State<_FullActionQueuePage> {
  QueueFilter _filter = QueueFilter.all;
  bool _groupByInstitution = false;

  @override
  Widget build(BuildContext context) => OfficerPortalShell(
    title: 'Officer Action Queue',
    body: AnimatedBuilder(
      animation: DemoFdrPortalStore.instance,
      builder: (context, _) {
        final all = StoreReportsRepository(
          DemoFdrPortalStore.instance,
        ).actionQueue;
        final visible = all.where((item) {
          if (_filter == QueueFilter.all) return true;
          return item.category.split(', ').contains(_filter.label);
        }).toList();
        final groups = <String, List<ActionQueueItem>>{};
        for (final item in visible) {
          groups.putIfAbsent(item.institution, () => []).add(item);
        }
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  for (final filter in QueueFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(
                          '${filter.label} ${all.where((item) => filter == QueueFilter.all || item.category.split(', ').contains(filter.label)).length}',
                        ),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Group by institution'),
              value: _groupByInstitution,
              onChanged: (value) => setState(() => _groupByInstitution = value),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: _groupByInstitution
                    ? [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          for (final item in entry.value)
                            _queueTile(context, item),
                        ],
                      ]
                    : [for (final item in visible) _queueTile(context, item)],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _queueTile(BuildContext context, ActionQueueItem item) => Card(
    child: ListTile(
      leading: Icon(
        item.priority == 'High'
            ? Icons.priority_high_rounded
            : Icons.schedule_rounded,
      ),
      title: Text(item.reference),
      subtitle: Text('${item.institution}\n${item.reason}'),
      isThreeLine: true,
      trailing: TextButton(
        onPressed: () => _openQueueItem(context, item),
        child: const Text('Open'),
      ),
    ),
  );

  void _openQueueItem(BuildContext context, ActionQueueItem item) {
    final store = DemoFdrPortalStore.instance;
    final submission = store.submissionById(item.relatedSubmissionId);
    if (submission == null) return;
    final target = queueTargetFor(item);
    store.selectSubmission(submission.submissionId);
    if (target == QueueTarget.releaseClearances && submission.caseId != null) {
      store.selectReleaseCase(item.relatedCaseId ?? submission.caseId!);
    } else if (target == QueueTarget.releaseClearances &&
        item.relatedCaseId != null) {
      store.selectReleaseCase(item.relatedCaseId!);
    }
    if (target == QueueTarget.verificationResults) {
      store.runCurrentVerification();
      if (store.releaseCase == null) store.createReleaseCase();
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => switch (target) {
          QueueTarget.releaseClearances => const _ReleaseCasePage(),
          QueueTarget.correction => const _CorrectDetailsPage(),
          QueueTarget.verificationResults => const _VerificationResultsPage(),
          QueueTarget.deadlineDetails => const _FdrVerificationDetailPage(),
        },
      ),
    );
  }
}

class _DeadlineList extends StatelessWidget {
  const _DeadlineList({required this.items});

  final List<FdrDeadlineInfo> items;

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where((item) => item.status != MaturityStatus.active)
        .take(5)
        .toList();
    if (visible.isEmpty) {
      return const _InlineEmptyState(
        message: 'No approaching or overdue maturities.',
      );
    }
    return Column(
      children: [
        for (final item in visible)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.status == MaturityStatus.matured ||
                      item.status == MaturityStatus.critical
                  ? Icons.warning_amber_rounded
                  : Icons.event_outlined,
              color:
                  item.status == MaturityStatus.matured ||
                      item.status == MaturityStatus.critical
                  ? const Color(0xFFB91C1C)
                  : _orange,
            ),
            title: Text('${item.submission.reference} · ${item.status.label}'),
            subtitle: Text(
              '${item.submission.institution} · ${item.maturityDate == null ? 'Invalid date' : _parsePortalDateLabel(item.maturityDate!)}\n${item.daysRemaining == null
                  ? item.nextAction
                  : item.daysRemaining! < 0
                  ? '${-item.daysRemaining!} days overdue'
                  : '${item.daysRemaining} days remaining'}',
            ),
            isThreeLine: true,
            trailing: item.status == MaturityStatus.active || item.isRenewed
                ? null
                : TextButton(
                    onPressed: () => _showRenewalDialog(context, item),
                    child: const Text('Renew FDR'),
                  ),
          ),
      ],
    );
  }

  Future<void> _showRenewalDialog(
    BuildContext context,
    FdrDeadlineInfo deadline,
  ) async {
    final store = DemoFdrPortalStore.instance;
    final record = store.fdrRecordForSubmission(
      deadline.submission.submissionId,
    );
    if (record == null) return;
    final number = TextEditingController();
    final bank = TextEditingController(text: record.bank);
    final amount = TextEditingController(
      text: '${record.declaredDepositAmount}',
    );
    final issue = TextEditingController(text: record.maturityDate);
    final tenure = TextEditingController(
      text: '${record.declaredTenureMonths}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renew FDR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: number,
                decoration: const InputDecoration(labelText: 'New FDR number'),
              ),
              TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Bank'),
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
                  bank: bank.text.trim(),
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
    bank.dispose();
    amount.dispose();
    issue.dispose();
    tenure.dispose();
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF15803D),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(message, style: const TextStyle(color: _muted)),
        ),
      ],
    ),
  );
}

class _InstitutionRegistryViewState extends State<_InstitutionRegistryView> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: DemoFdrPortalStore.instance,
    builder: (context, _) {
      final records = widget.repository.submissions;
      final query = _searchController.text.trim().toLowerCase();
      final visible = institutions(records).where((institution) {
        final matchesSearch =
            query.isEmpty ||
            institution.name.toLowerCase().contains(query) ||
            institution.id.toLowerCase().contains(query);
        final breakdown = statusBreakdownForInstitution(
          records,
          institution.id,
        );
        final matchesFilter = switch (_filter) {
          'Has Pending' => breakdown[SubmissionStatus.pendingReview]! > 0,
          'Has Correction' =>
            breakdown[SubmissionStatus.correctionRequested]! > 0,
          'Has Blocked' => breakdown[SubmissionStatus.blocked]! > 0,
          _ => true,
        };
        return matchesSearch && matchesFilter;
      }).toList();
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: _DemoNotice(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search by institution name or ID',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Row(
                children: [
                  for (final filter in const [
                    'All',
                    'Has Pending',
                    'Has Correction',
                    'Has Blocked',
                  ]) ...[
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text('No institutions match your search'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      child: Column(
                        children: [
                          for (final institution in visible) ...[
                            _InstitutionCard(
                              institution: institution,
                              submissions: records,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _InstitutionDetailPage(
                                    institution: institution,
                                    onReviewSubmission:
                                        widget.onReviewSubmission,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.institution,
    required this.submissions,
    required this.onTap,
  });

  final Institution institution;
  final Iterable<Submission> submissions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final records = submissionsForInstitution(submissions, institution.id);
    final breakdown = statusBreakdownForInstitution(
      submissions,
      institution.id,
    );
    final latest = latestActivityForInstitution(submissions, institution.id);
    final risk = assessInstitutionRisk(records);
    return Card(
      key: ValueKey('institution:${institution.id}'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      institution.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
              Text(
                institution.id,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                'Risk: ${risk.category} · Score ${risk.score}',
                style: TextStyle(
                  color: risk.category == 'High'
                      ? const Color(0xFFB91C1C)
                      : risk.category == 'Medium'
                      ? const Color(0xFFB45309)
                      : const Color(0xFF15803D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Why this risk?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final reason in risk.reasons)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          reason,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${records.length} submissions',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final status in SubmissionStatus.values)
                    if (breakdown[status]! > 0)
                      _CountChip(status: status, count: breakdown[status]!),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Text(
                    'Total deposit ₹${_formatCurrency(totalDepositForInstitution(submissions, institution.id))}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Last activity ${latest == null ? '—' : _shortDate(latest.updatedAt)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.status, required this.count});
  final SubmissionStatus status;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '${status.label} $count',
      style: TextStyle(
        color: status.color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _InstitutionDetailPage extends StatelessWidget {
  const _InstitutionDetailPage({
    required this.institution,
    required this.onReviewSubmission,
  });
  final Institution institution;
  final ValueChanged<FdrSubmission> onReviewSubmission;

  @override
  Widget build(BuildContext context) => OfficerPortalShell(
    title: 'Institution Details',
    body: AnimatedBuilder(
      animation: DemoFdrPortalStore.instance,
      builder: (context, _) {
        final records = submissionsForInstitution(
          const MockOfficerDashboardRepository().submissions,
          institution.id,
        );
        final breakdown = statusBreakdownForInstitution(
          records,
          institution.id,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            _DemoNotice(),
            const SizedBox(height: 14),
            Text(
              institution.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            Text(institution.id, style: const TextStyle(color: _muted)),
            const SizedBox(height: 12),
            Text(
              'Submissions ${records.length} · Pending ${breakdown[SubmissionStatus.pendingReview]} · Approved ${breakdown[SubmissionStatus.approved]}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Builder(
              builder: (context) {
                final risk = assessInstitutionRisk(records);
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Risk: ${risk.category} · Score ${risk.score}'),
                  children: [
                    for (final reason in risk.reasons)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            reason,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            for (final submission in records) ...[
              _SubmissionRecordCard(
                submission: submission,
                onReview: () => onReviewSubmission(submission),
              ),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    ),
  );
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: DemoFdrPortalStore.instance,
    builder: (context, _) {
      final reports = StoreReportsRepository(DemoFdrPortalStore.instance);
      final records = reports.submissions;
      final deposits = reports.depositByStatus;
      final total = reports.totalSubmissions;
      final resolved = reports.resolvedCount;
      final percentages = reports.statusPercentages;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DemoNotice(),
            const SizedBox(height: 14),
            _ReportSection(
              title: 'Summary',
              child: _ReportSummary(repository: reports),
            ),
            const SizedBox(height: 10),
            _ReportSection(
              title: 'Status Distribution',
              child: Column(
                children: [
                  for (final status in SubmissionStatus.values)
                    _DistributionRow(
                      status: status,
                      count: reports.statusCounts[status]!,
                      percentage: percentages[status]!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ReportSection(
              title: 'Deposit by Status',
              child: Column(
                children: [
                  for (final status in SubmissionStatus.values)
                    _ReportLine(
                      label: status.label,
                      value: '₹${_formatCurrency(deposits[status]!)}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ReportSection(
              title: 'Deposit by Bank',
              child: Column(
                children: [
                  for (final entry in reports.bankCounts.entries)
                    _ReportLine(
                      label: entry.key,
                      value:
                          '${entry.value} submissions · ₹${_formatCurrency(reports.depositByBank[entry.key]!)}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ReportSection(
              title: 'Institution Risk',
              child: Column(
                children: [
                  for (final entry in reports.institutionRisk.entries)
                    _ReportLine(
                      label: entry.key,
                      value:
                          '${entry.value.category} · ${entry.value.score} points',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ReportSection(title: 'Recent Activity', child: _RecentActivity()),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final report in <({String name, String csv})>[
                  (name: 'submissions.csv', csv: buildSubmissionsCsv(records)),
                  (
                    name: 'institutions.csv',
                    csv: buildInstitutionsCsv(reports.institutionRisk),
                  ),
                  (
                    name: 'deadlines.csv',
                    csv: buildDeadlinesCsv(reports.deadlines),
                  ),
                  (
                    name: 'audit-trail.csv',
                    csv: buildAuditCsv(
                      DemoFdrPortalStore.instance.auditEntries,
                    ),
                  ),
                  (
                    name: 'discrepancies.csv',
                    csv: buildDiscrepanciesCsv(records),
                  ),
                ])
                  OutlinedButton.icon(
                    onPressed: () =>
                        exportCsvReport(context, report.name, report.csv),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      report.name == 'submissions.csv'
                          ? 'Export Report'
                          : report.name,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pending $total · Resolved $resolved',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      );
    },
  );
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.repository});
  final ReportsRepository repository;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        _SummaryValue('Total Submissions', '${repository.totalSubmissions}'),
        _SummaryValue('Total Institutions', '${repository.totalInstitutions}'),
        _SummaryValue(
          'Total Deposit Value',
          '₹${_formatCurrency(repository.totalDeposit)}',
        ),
        _SummaryValue(
          'Pending vs Resolved',
          '${repository.statusCounts[SubmissionStatus.pendingReview]} vs ${repository.resolvedCount}',
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    ),
  );
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.status,
    required this.count,
    required this.percentage,
  });
  final SubmissionStatus status;
  final int count;
  final int percentage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(status.label, style: const TextStyle(fontSize: 11)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: percentage / 100,
            color: status.color,
            backgroundColor: _line,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count ($percentage%)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context) {
    final store = DemoFdrPortalStore.instance;
    final records = const MockOfficerDashboardRepository().submissions;
    final rows = store.auditEntries.reversed.take(5).map((entry) {
      final submission = records
          .where((item) => item.submissionId == entry.associatedId)
          .firstOrNull;
      return '${entry.associatedId} · ${submission?.institution ?? 'Portal'} · ${entry.action} · ${entry.timestamp}';
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(row, style: const TextStyle(fontSize: 11)),
          ),
      ],
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
  Widget build(BuildContext context) => const SizedBox.shrink();
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
    this.wide = false,
  });

  final String label;
  final int value;
  final String note;
  final IconData icon;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label, $value',
    button: false,
    child: Container(
      key: ValueKey('metric:$label'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Column(
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
                Flexible(
                  child: FittedBox(
                    alignment: Alignment.bottomLeft,
                    fit: BoxFit.scaleDown,
                    child: Column(
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
                  ),
                ),
              ],
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
            text: _cleanPortalLabel(value),
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

class OfficerProfilePage extends StatefulWidget {
  const OfficerProfilePage({
    super.key,
    required this.userId,
    required this.onSignOut,
  });

  final String userId;
  final VoidCallback onSignOut;

  @override
  State<OfficerProfilePage> createState() => _OfficerProfilePageState();
}

class _OfficerProfilePageState extends State<OfficerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: 'AICTE Officer',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: 'officer@aicte.example',
  );
  bool _editing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      DemoFdrPortalStore.instance,
      NotificationCenter.instance,
    ]),
    builder: (context, _) {
      final summary = const MockOfficerDashboardRepository().summary;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const SizedBox(height: 18),
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFFFE8D5),
            child: Text(
              _initials(_nameController.text),
              style: const TextStyle(
                color: _deepOrange,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Center(
            child: Text(
              _nameController.text,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Text(
              'AICTE Officer · ${widget.userId}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Officer Information',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _editing = !_editing),
                icon: const Icon(Icons.edit_outlined),
                label: Text(_editing ? 'Cancel' : 'Edit profile'),
              ),
            ],
          ),
          if (_editing)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Official email',
                    ),
                    validator: (value) =>
                        value!.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _editing = false);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            )
          else
            _OfficerInfoPanel(
              title: 'Current officer',
              rows: {
                'Full name': _nameController.text,
                'Officer ID': widget.userId,
                'Email address': _emailController.text,
                'Designation': 'AICTE Officer',
                'Department': 'Security Deposit Division',
                'Account status': 'Active',
                'Role': 'AICTE Officer',
              },
            ),
          const Text(
            'Preferences',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          _preferenceTile('In-app notifications', 'inApp'),
          _preferenceTile('Approval and submission notifications', 'workflow'),
          _preferenceTile('Reminder notifications', 'reminders'),
          if (portalAuthService.currentClaims != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Role'),
              subtitle: Text(portalAuthService.currentClaims!.role.name),
              trailing: PopupMenuButton<AuthRole>(
                tooltip: 'Switch role',
                onSelected: (role) async {
                  await portalAuthService.switchRole(role);
                  if (mounted) setState(() {});
                },
                itemBuilder: (context) => [
                  for (final role in AuthRole.values)
                    PopupMenuItem(value: role, child: Text(role.name)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _VerificationRulesPage(),
              ),
            ),
            icon: const Icon(Icons.rule_folder_outlined),
            label: const Text('Verification Rules'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DemoScriptPage()),
            ),
            icon: const Icon(Icons.route_outlined),
            label: const Text('Workflow Guide'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              DemoFdrPortalStore.instance.resetDemoData();
              DemoFdrPortalStore.instance.seedDemoCases();
              await portalAuthService.authenticate(
                widget.userId,
                'demo-password',
              );
              if (!mounted) return;
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(content: Text('Sample data reset.')),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset Sample Data'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Activity Summary',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          _OfficerInfoPanel(
            title: 'Workflow activity',
            rows: {
              'Submissions reviewed':
                  '${summary['Approved']! + summary['Rejected']!}',
              'Approved': '${summary['Approved']}',
              'Returned or rejected':
                  '${summary['Rejected']! + summary['Needs Correction']!}',
              'Pending assigned': '${summary['Pending Review']}',
            },
          ),
          const SizedBox(height: 14),
          const _OfficerInfoPanel(
            title: 'About the Portal',
            rows: {
              'Portal': 'AICTE Security Deposit Management Portal',
              'Version': '1.0.0',
            },
          ),
        ],
      );
    },
  );

  Widget _preferenceTile(String title, String key) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: NotificationCenter.instance.preference(key),
    onChanged: (value) => NotificationCenter.instance.setPreference(key, value),
  );
}

class _VerificationRulesPage extends StatelessWidget {
  const _VerificationRulesPage();

  @override
  Widget build(BuildContext context) => OfficerPortalShell(
    title: 'Verification Rules',
    body: AnimatedBuilder(
      animation: DemoFdrPortalStore.instance,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 12),
          for (final rule in DemoFdrPortalStore.instance.rules)
            Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                title: Text(rule.name),
                subtitle: Text(
                  '${rule.description}\nSeverity: ${rule.severity.displayLabel}',
                ),
                isThreeLine: true,
                leading: Switch(
                  value: rule.enabled,
                  onChanged: (enabled) => DemoFdrPortalStore.instance
                      .updateRule(rule.copyWith(enabled: enabled)),
                ),
                trailing: PopupMenuButton<RuleSeverity>(
                  tooltip: 'Change severity',
                  initialValue: rule.severity,
                  onSelected: (severity) => DemoFdrPortalStore.instance
                      .updateRule(rule.copyWith(severity: severity)),
                  itemBuilder: (context) => [
                    for (final severity in RuleSeverity.values)
                      PopupMenuItem(
                        value: severity,
                        child: Text(severity.displayLabel),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class DemoScriptPage extends StatelessWidget {
  const DemoScriptPage({super.key});

  @override
  Widget build(BuildContext context) => OfficerPortalShell(
    title: 'Workflow Guide',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _DemoNotice(),
        const SizedBox(height: 12),
        const Text(
          'Three-minute workflow',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final step in const [
          (
            'Queue',
            'Open the full officer action queue.',
            Icons.list_alt_rounded,
          ),
          (
            '6-day maturity',
            'Open the critical FDR deadline.',
            Icons.event_outlined,
          ),
          (
            'Reminder scan',
            'Run the reminder scan and review counts.',
            Icons.notifications_active_outlined,
          ),
          (
            'Renewal lineage',
            'Open the parent and child FDR chain.',
            Icons.account_tree_outlined,
          ),
          (
            'Amount mismatch',
            'Open the blocking discrepancy.',
            Icons.warning_amber_rounded,
          ),
          (
            'Duplicate FDR',
            'Open the duplicate reference check.',
            Icons.content_copy_rounded,
          ),
          (
            'Correct and re-verify',
            'Open the correction workflow.',
            Icons.edit_note_rounded,
          ),
          (
            'Release checklist',
            'Open the staged release case.',
            Icons.fact_check_outlined,
          ),
          (
            'Parallel clearances',
            'Review Grievance and Vigilance states.',
            Icons.account_tree_outlined,
          ),
          (
            'Audit verify',
            'Verify the persisted audit chain.',
            Icons.verified_outlined,
          ),
          (
            'Tamper detect',
            'Test detection and restore the stored chain.',
            Icons.security_outlined,
          ),
          (
            'Updated queue counts',
            'Return to the queue after completing an action.',
            Icons.refresh_rounded,
          ),
        ])
          Card(
            child: ListTile(
              leading: Icon(step.$3, color: _orange),
              title: Text(step.$1),
              subtitle: Text(step.$2),
              trailing: IconButton(
                tooltip: 'Open step',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => _openStep(context, step.$1),
              ),
            ),
          ),
      ],
    ),
  );

  void _openStep(BuildContext context, String step) {
    final store = DemoFdrPortalStore.instance;
    if (step == 'Queue' || step == 'Updated queue counts') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _FullActionQueuePage()),
      );
      return;
    }
    if (step == 'Audit verify' || step == 'Tamper detect') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const _AuditTrailPage()));
      return;
    }
    if (step == 'Release checklist' || step == 'Parallel clearances') {
      store.createReleaseCase();
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const _ReleaseCasePage()));
      return;
    }
    if (step == '6-day maturity') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _DeadlineFocusPage()),
      );
      return;
    }
    if (step == 'Reminder scan') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _ReminderScanPage()),
      );
      return;
    }
    if (step == 'Renewal lineage') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _RenewalLineagePage()),
      );
      return;
    }
    if (step == 'Correct and re-verify') {
      store.selectSubmission('FDR-2026-00128');
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _CorrectDetailsPage()),
      );
      return;
    }
    if (step == 'Amount mismatch' || step == 'Duplicate FDR') {
      store.selectSubmission(
        step == 'Duplicate FDR' ? 'FDR-2026-00125' : 'FDR-2026-00124',
      );
      store.createReleaseCase();
      store.runCurrentVerification();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _VerificationResultsPage(),
        ),
      );
      return;
    }
    store.selectSubmission('FDR-2026-00124');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _FdrVerificationDetailPage(),
      ),
    );
  }
}

class _DeadlineFocusPage extends StatelessWidget {
  const _DeadlineFocusPage();

  @override
  Widget build(BuildContext context) {
    final item = DemoFdrPortalStore.instance.deadlineItems
        .where(
          (deadline) => deadline.submission.submissionId == 'FDR-2026-00124',
        )
        .firstOrNull;
    return OfficerPortalShell(
      title: '6-day maturity',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 10),
          if (item == null)
            const _InlineEmptyState(
              message: 'The six-day maturity record is unavailable.',
            )
          else
            _DeadlineList(items: [item]),
        ],
      ),
    );
  }
}

class _ReminderScanPage extends StatefulWidget {
  const _ReminderScanPage();

  @override
  State<_ReminderScanPage> createState() => _ReminderScanPageState();
}

class _ReminderScanPageState extends State<_ReminderScanPage> {
  @override
  Widget build(BuildContext context) => OfficerPortalShell(
    title: 'Reminder Scan',
    body: AnimatedBuilder(
      animation: DemoFdrPortalStore.instance,
      builder: (context, _) {
        final store = DemoFdrPortalStore.instance;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                store.runReminderScan();
                setState(() {});
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Run Reminder Scan'),
            ),
            Text(
              '${store.lastReminderCreated} new reminders sent · ${store.lastReminderAlreadySent} already sent',
            ),
          ],
        );
      },
    ),
  );
}

class _RenewalLineagePage extends StatelessWidget {
  const _RenewalLineagePage();

  @override
  Widget build(BuildContext context) {
    final records = DemoFdrPortalStore.instance.renewalLineage(
      'FDR-EIT-771530',
    );
    return OfficerPortalShell(
      title: 'Renewal Lineage',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 10),
          for (var index = 0; index < records.length; index++)
            ListTile(
              leading: Icon(
                index == 0
                    ? Icons.account_balance_outlined
                    : Icons.subdirectory_arrow_right_rounded,
              ),
              title: Text(records[index].fdrNumber),
              subtitle: Text(
                '${records[index].institution} · ${records[index].submissionStatus}\n${records[index].parentFdrReference == null ? 'Original FDR' : 'Renewed from ${records[index].parentFdrReference}'}',
              ),
            ),
        ],
      ),
    );
  }
}

class _OfficerInfoPanel extends StatelessWidget {
  const _OfficerInfoPanel({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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
      body: widget.title == 'Reports'
          ? const _ReportsView()
          : isSubmissionList
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
                              'Records will appear here when their status changes.',
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
            value: 'Approval by ${submission.approvedBy}',
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
  static const _auditSchemaVersion = 1;

  DemoFdrPortalStore._({Clock clock = const SystemClock()}) : _clock = clock {
    NotificationCenter.instance.seedDemoNotifications();
  }

  static final DemoFdrPortalStore instance = DemoFdrPortalStore._();

  static FdrRecord _seededFdrRecord({
    required String submissionId,
    required String fdrNumber,
    required String institution,
    required String institutionId,
    required String bank,
    required int amount,
    required String issueDate,
    required String maturityDate,
    String lienInformation = 'No lien',
    Map<DocumentSource, Map<String, String?>> sourceValues = const {},
    bool isDeliberateInvalidDate = false,
  }) => FdrRecord(
    institution: institution,
    institutionId: institutionId,
    submissionId: submissionId,
    bank: bank,
    fdrNumber: fdrNumber,
    declaredDepositAmount: amount,
    receiptAmount: amount,
    issueDate: issueDate,
    maturityDate: maturityDate,
    declaredTenureMonths: 36,
    enteredTenureMonths: 36,
    lienInformation: lienInformation,
    submissionStatus: 'Pending Review',
    documents: const [],
    sourceValues: sourceValues,
    isDeliberateInvalidDate: isDeliberateInvalidDate,
  );

  String _dateRelative(int days) {
    final date = _clock.now().add(Duration(days: days));
    return _formatSeedDate(date);
  }

  String _dateMonthsBefore(DateTime date, int months) =>
      _formatSeedDate(DateTime(date.year, date.month - months, date.day));

  String _formatSeedDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][date.month - 1]} ${date.year}';
  final Clock _clock;
  LocalStorage _auditStorage = MemoryLocalStorage();
  Future<void> _auditWrite = Future<void>.value();
  AuditChainAnchor? _auditAnchor;
  AuditIntegrityResult? _auditIntegrity;
  List<AuditEntry>? _auditBackup;
  LocalStorage _reminderStorage = MemoryLocalStorage();
  Future<void> _reminderWrite = Future<void>.value();
  DateTime? _lastReminderScanAt;
  int _lastReminderCreated = 0;
  int _lastReminderAlreadySent = 0;

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
  final Map<String, OfficerClarification> _clarifications =
      <String, OfficerClarification>{};
  final Map<String, FdrRecord> _fdrRecordsBySubmissionId = {
    'FDR-2026-00124': _blockedSubmission,
    'FDR-2026-00128': _rejectedSubmission,
    'FDR-2026-00125': _seededFdrRecord(
      submissionId: 'FDR-2026-00125',
      fdrNumber: 'FDR-NC-550318',
      institution: 'National College of Engineering',
      institutionId: 'INST-00125',
      bank: 'National Commerce Bank',
      amount: 300000,
      issueDate: '15 October 2026',
      maturityDate: '15 October 2029',
    ),
    'FDR-2026-00126': _seededFdrRecord(
      submissionId: 'FDR-2026-00126',
      fdrNumber: 'FDR-MI-719643',
      institution: 'Metropolitan Institute of Science',
      institutionId: 'INST-00126',
      bank: 'Metropolitan Bank',
      amount: 750000,
      issueDate: '22 October 2026',
      maturityDate: '22 November 2026',
    ),
    'FDR-2026-00127': _seededFdrRecord(
      submissionId: 'FDR-2026-00127',
      fdrNumber: 'FDR-EIT-771530',
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      bank: 'Civic Union Bank',
      amount: 350000,
      issueDate: '18 October 2026',
      maturityDate: '18 October 2028',
    ),
    'FDR-2026-00129': _seededFdrRecord(
      submissionId: 'FDR-2026-00129',
      fdrNumber: 'FDR-EIT-330817',
      institution: 'Example Institute of Technology',
      institutionId: 'INST-DEMO-0042',
      bank: 'Example National Bank',
      amount: 425000,
      issueDate: '03 October 2026',
      maturityDate: 'invalid-date',
    ),
  };
  final Map<String, String> _mergerRelationships = <String, String>{};
  String _selectedCaseType = 'Normal Release';
  String? _selectedReleaseCaseId;
  int _nextInstitutionSubmissionSequence = 1;
  int _nextInstitutionCaseSequence = 1;
  final List<AuditEntry> _auditEntries = <AuditEntry>[];
  final Set<String> _reminderKeys = <String>{};
  final Map<String, RuleConfig> _rules = {
    for (final rule in defaultRuleConfigs()) rule.id: rule,
  };
  final Map<String, Discrepancy> _discrepancies = <String, Discrepancy>{};
  final Map<String, List<int>> _documentBytes = <String, List<int>>{};
  LocalStorage _documentStorage = MemoryLocalStorage();
  Future<void> _documentWrite = Future<void>.value();
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
  List<OfficerClarification> get clarifications =>
      List.unmodifiable(_clarifications.values);

  List<OfficerClarification> clarificationsForInstitution(
    String institutionId,
  ) => _clarifications.values
      .where((item) => item.institutionId == institutionId)
      .toList(growable: false);

  OfficerClarification? clarificationForSubmission(String submissionId) =>
      _clarifications[submissionId];
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
          : _releaseCases.values
                .where((item) => item.caseId == _selectedReleaseCaseId)
                .firstOrNull) ??
      _releaseCases[_selectedCaseType];
  String get selectedCaseType => _selectedCaseType;
  FdrRecord get originalFdrRecord => _currentSubmission;
  Map<String, DemoFdrMasterRecord> get demoFdrRecords =>
      Map.unmodifiable(_demoFdrRecords);
  Map<String, String> get mergerRelationships =>
      Map.unmodifiable(_mergerRelationships);
  List<AuditEntry> get auditEntries => List.unmodifiable(_auditEntries);
  AuditIntegrityResult? get auditIntegrity => _auditIntegrity;
  bool get auditIntegrityBroken => _auditIntegrity?.isValid == false;

  Future<void> flushPersistence() async {
    await _auditWrite;
    await _reminderWrite;
    await _documentWrite;
  }

  Future<void> initializeDocumentPersistence(LocalStorage storage) async {
    _documentStorage = storage;
    final raw = await storage.read('aicte.documents');
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    _documentBytes
      ..clear()
      ..addAll({
        for (final entry in decoded.entries)
          entry.key: base64Decode(entry.value as String),
      });
  }

  Future<void> _persistDocumentBytes() => _documentStorage.write(
    'aicte.documents',
    jsonEncode({
      for (final entry in _documentBytes.entries)
        entry.key: base64Encode(entry.value),
    }),
  );

  void requirePermission(
    String action, {
    required Set<AuthRole> allowed,
    String? institutionId,
  }) {
    final claims = portalAuthService.currentClaims;
    final configured = switch (action) {
      'verify FDR submissions' => permissionMatrix['verify']!,
      'approve FDR submissions' ||
      'approve progressive closure' ||
      'approve merger cases' => permissionMatrix['approve']!,
      'issue final NOC' => permissionMatrix['issueNoc']!,
      'update Grievance Redressal Cell clearance' =>
        permissionMatrix['grievanceClearance']!,
      'update Vigilance Cell clearance' =>
        permissionMatrix['vigilanceClearance']!,
      'view audit trail' => permissionMatrix['auditTrail']!,
      _ => allowed,
    };
    if (claims == null || !configured.contains(claims.role)) {
      appendAuditEntry(
        action: 'Access denied',
        associatedId: action,
        actorRole: claims?.role.name ?? 'anonymous',
        payload:
            'Required roles: ${configured.map((role) => role.name).join(', ')}',
      );
      throw PermissionDeniedException('You do not have permission to $action.');
    }
    if (institutionId != null && claims.institutionId != institutionId) {
      appendAuditEntry(
        action: 'Access denied',
        associatedId: action,
        actorRole: claims.role.name,
        payload: 'Institution scope mismatch',
      );
      throw PermissionDeniedException(
        'You can only access your institution data.',
      );
    }
  }

  DocumentIntegrityResult verifyDocumentIntegrity(String documentId) {
    final document = _fdrRecordsBySubmissionId.values
        .expand((record) => record.supportedDocuments)
        .where((item) => item.id == documentId)
        .firstOrNull;
    final bytes = _documentBytes[documentId];
    if (document == null || bytes == null) {
      return const DocumentIntegrityResult(
        isValid: false,
        message: 'Stored document bytes are unavailable.',
      );
    }
    final actual = checksumForDocumentBytes(bytes);
    final auditChecksum = _auditEntries
        .where((entry) => entry.payload.contains(document.sha256))
        .isNotEmpty;
    return DocumentIntegrityResult(
      isValid: actual == document.sha256 && auditChecksum,
      message: actual == document.sha256 && auditChecksum
          ? 'Document checksum matches its upload record and audit entry.'
          : 'Document checksum mismatch: stored bytes may be tampered.',
    );
  }

  void replaceStoredDocumentBytes(String documentId, List<int> bytes) {
    if (!_documentBytes.containsKey(documentId)) {
      throw ArgumentError('Stored document was not found.');
    }
    _documentBytes[documentId] = List<int>.unmodifiable(bytes);
    _documentWrite = _persistDocumentBytes();
  }

  Future<void> initializeAuditPersistence(LocalStorage storage) async {
    _auditStorage = storage;
    final stored = await readJson(storage, 'aicte.auditChain');
    final rawEntries = stored?['entries'];
    _auditEntries.clear();
    if (rawEntries is List) {
      _auditEntries
        ..clear()
        ..addAll(
          rawEntries.whereType<Map<String, dynamic>>().map(_auditFromJson),
        );
    }
    _auditAnchor = null;
    _auditBackup = null;
    final rawAnchor = await readJson(storage, 'aicte.auditAnchor');
    if (rawAnchor != null) {
      _auditAnchor = AuditChainAnchor(
        latestIndex: (rawAnchor['latestIndex'] as num).toInt(),
        latestHash: rawAnchor['latestHash'] as String,
        count: (rawAnchor['count'] as num).toInt(),
      );
    }
    _auditIntegrity = verifyAuditChain(_auditEntries, anchor: _auditAnchor);
    final storedVersion = int.tryParse(
      await storage.read('aicte.auditSchemaVersion') ?? '',
    );
    final chainVersion = (stored?['schemaVersion'] as num?)?.toInt();
    final version = storedVersion ?? chainVersion ?? 0;
    if (version <= _auditSchemaVersion && _auditIntegrity!.isValid) {
      await storage.write('aicte.auditSchemaVersion', '$_auditSchemaVersion');
    }
    notifyListeners();
  }

  Future<void> _persistAuditChain() async {
    await _auditStorage.write(
      'aicte.auditChain',
      jsonEncode({
        'schemaVersion': _auditSchemaVersion,
        'entries': _auditEntries.map(_auditToJson).toList(),
      }),
    );
    await _auditStorage.write(
      'aicte.auditSchemaVersion',
      '$_auditSchemaVersion',
    );
    if (_auditEntries.isNotEmpty) {
      _auditAnchor = AuditChainAnchor(
        latestIndex: _auditEntries.length - 1,
        latestHash: _auditEntries.last.entryHash,
        count: _auditEntries.length,
      );
      await _auditStorage.write(
        'aicte.auditAnchor',
        jsonEncode({
          'latestIndex': _auditAnchor!.latestIndex,
          'latestHash': _auditAnchor!.latestHash,
          'count': _auditAnchor!.count,
        }),
      );
    } else {
      await _auditStorage.delete('aicte.auditAnchor');
    }
    _auditIntegrity = verifyAuditChain(_auditEntries, anchor: _auditAnchor);
  }

  Future<void> verifyPersistedAuditChain() async {
    final stored = await readJson(_auditStorage, 'aicte.auditChain');
    final rawEntries = stored?['entries'];
    final entries = rawEntries is List
        ? rawEntries
              .whereType<Map<String, dynamic>>()
              .map(_auditFromJson)
              .toList()
        : _auditEntries;
    _auditIntegrity = verifyAuditChain(entries, anchor: _auditAnchor);
    notifyListeners();
  }

  Future<void> tamperPersistedAuditRecord() async {
    final stored = await readJson(_auditStorage, 'aicte.auditChain');
    if (stored == null || stored['entries'] is! List) return;
    _auditBackup = List<AuditEntry>.from(_auditEntries);
    final entries = (stored['entries'] as List).toList();
    if (entries.isNotEmpty) {
      final last = Map<String, dynamic>.from(entries.last as Map);
      last['payload'] = '${last['payload']} altered';
      entries[entries.length - 1] = last;
      await _auditStorage.write(
        'aicte.auditChain',
        jsonEncode({'entries': entries}),
      );
    }
    await verifyPersistedAuditChain();
  }

  Future<void> restoreAuditBackup() async {
    final backup = _auditBackup;
    if (backup == null) return;
    _auditEntries
      ..clear()
      ..addAll(backup);
    _auditBackup = null;
    await _persistAuditChain();
    notifyListeners();
  }

  List<RuleConfig> get rules => List.unmodifiable(_rules.values);
  List<Discrepancy> get discrepancies =>
      List.unmodifiable(_discrepancies.values);

  void reconcileDiscrepancies(
    VerificationSummary summary, {
    String actor = 'Officer',
  }) {
    final activeIssues = summary.issues.where(
      (issue) => issue.severity != VerificationIssueSeverity.passed,
    );
    final activeIds = <String>{};
    for (final issue in activeIssues) {
      final id = '${issue.ruleId}:${issue.affectedField}';
      activeIds.add(id);
      final previous = _discrepancies[id];
      final reopened = previous?.status == DiscrepancyStatus.resolved;
      final event = DiscrepancyEvent(
        actor: actor,
        action: reopened
            ? 'Reopened'
            : previous == null
            ? 'Detected'
            : 'Confirmed',
        remark: issue.message,
        at: _clock.now(),
      );
      _discrepancies[id] = Discrepancy(
        id: id,
        ruleId: issue.ruleId,
        field: issue.affectedField,
        severity: issue.severity,
        status: reopened
            ? DiscrepancyStatus.reopened
            : previous?.status == DiscrepancyStatus.waived
            ? DiscrepancyStatus.waived
            : previous?.status == DiscrepancyStatus.correctionSubmitted
            ? DiscrepancyStatus.open
            : previous?.status ?? DiscrepancyStatus.open,
        detectedAt: previous?.detectedAt ?? _clock.now(),
        history: [...?previous?.history, event],
      );
    }
    for (final entry in _discrepancies.entries.toList()) {
      final item = entry.value;
      if (!activeIds.contains(item.id) &&
          (item.status == DiscrepancyStatus.open ||
              item.status == DiscrepancyStatus.reopened ||
              item.status == DiscrepancyStatus.correctionSubmitted)) {
        _discrepancies[entry.key] = Discrepancy(
          id: item.id,
          ruleId: item.ruleId,
          field: item.field,
          severity: item.severity,
          status: DiscrepancyStatus.resolved,
          detectedAt: item.detectedAt,
          history: [
            ...item.history,
            DiscrepancyEvent(
              actor: actor,
              action: 'Resolved',
              remark: 'No longer detected during verification.',
              at: _clock.now(),
            ),
          ],
        );
      }
    }
    notifyListeners();
  }

  void waiveDiscrepancy(
    String id, {
    required String actor,
    required String remark,
  }) {
    final item = _discrepancies[id];
    if (item == null) throw ArgumentError('Discrepancy was not found.');
    if (item.severity != VerificationIssueSeverity.warning) {
      throw StateError('Only warning discrepancies may be waived.');
    }
    if (remark.trim().isEmpty)
      throw ArgumentError('A waiver remark is required.');
    _discrepancies[id] = Discrepancy(
      id: item.id,
      ruleId: item.ruleId,
      field: item.field,
      severity: item.severity,
      status: DiscrepancyStatus.waived,
      detectedAt: item.detectedAt,
      history: [
        ...item.history,
        DiscrepancyEvent(
          actor: actor,
          action: 'Waived',
          remark: remark.trim(),
          at: _clock.now(),
        ),
      ],
    );
    appendAuditEntry(
      action: 'Warning discrepancy waived',
      associatedId: id,
      actorRole: actor,
      payload: remark.trim(),
    );
    notifyListeners();
  }

  DateTime? get lastReminderScanAt => _lastReminderScanAt;
  int get lastReminderCreated => _lastReminderCreated;
  int get lastReminderAlreadySent => _lastReminderAlreadySent;

  Future<void> initializeReminderPersistence(LocalStorage storage) async {
    _reminderStorage = storage;
    final stored = await readJson(storage, 'aicte.reminderState');
    if (stored == null) return;
    _reminderKeys
      ..clear()
      ..addAll((stored['keys'] as List<dynamic>? ?? const []).cast<String>());
    final rawScan = stored['lastScanAt'];
    _lastReminderScanAt = rawScan is String ? DateTime.tryParse(rawScan) : null;
    _lastReminderCreated = (stored['created'] as num?)?.toInt() ?? 0;
    _lastReminderAlreadySent = (stored['alreadySent'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  Future<void> _persistReminderState() => _reminderStorage.write(
    'aicte.reminderState',
    jsonEncode({
      'keys': _reminderKeys.toList(),
      'lastScanAt': _lastReminderScanAt?.toIso8601String(),
      'created': _lastReminderCreated,
      'alreadySent': _lastReminderAlreadySent,
    }),
  );

  List<CaseHistoryEvent> caseHistory(String caseId) =>
      _releaseCases[caseId]?.history ?? const [];

  List<int>? documentBytes(String documentId) => _documentBytes[documentId];

  CaseStatus caseStatus(String value) => _caseStatusFromLabel(value);

  void transition(
    String caseId,
    CaseStatus to,
    String actor,
    String reason, {
    String? displayStatus,
  }) {
    final entry = _releaseCases.entries
        .where((item) => item.value.caseId == caseId)
        .firstOrNull;
    final current = entry?.value;
    if (current == null) {
      throw InvalidTransitionException('Case $caseId was not found.');
    }
    final from = _caseStatusFromLabel(current.status);
    if (from == to) return;
    validateCaseTransition(from, to);
    final nextLabel = displayStatus ?? _caseStatusLabel(to);
    final eligibility = ReleaseEligibilityService.evaluate(
      record: current,
      verification: verificationForEligibility,
      originalFdrExists: _demoFdrRecords.containsKey(
        current.originalFdrReference,
      ),
    );
    if (to == CaseStatus.readyForNoc && !eligibility.canAdvance) {
      throw InvalidTransitionException(
        'Case is not ready: ${eligibility.blockingReasons.join(' ')}',
      );
    }
    final event = CaseHistoryEvent(
      action: 'Status changed',
      actor: actor,
      at: _clock.now(),
      remark: reason,
      fromStatus: current.status,
      toStatus: nextLabel,
    );
    _releaseCases[entry!.key] = current.copyWith(
      status: nextLabel,
      history: [...current.history, event],
    );
    appendAuditEntry(
      action: 'Case status changed',
      associatedId: caseId,
      actorRole: actor,
      payload: '${current.status} -> $nextLabel; $reason',
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: current.originalInstitutionId,
      title: 'Case status updated',
      message: 'Case $caseId is now $nextLabel.',
      category: NotificationCategory.request,
      relatedId: caseId,
      eventKey:
          'case-status-$caseId-${to.name}-${event.at.microsecondsSinceEpoch}',
    );
    notifyListeners();
  }

  void updateRule(RuleConfig rule) {
    _rules[rule.id] = rule;
    appendAuditEntry(
      action: 'Verification rule changed',
      associatedId: rule.id,
      actorRole: 'Demo Officer',
      payload:
          '${rule.enabled ? 'enabled' : 'disabled'}; ${rule.severity.name}',
    );
    notifyListeners();
  }

  List<FdrDeadlineInfo> get deadlineItems =>
      calculateFdrDeadlines(_dashboardSubmissions);

  int runReminderScan({DateTime? today}) {
    final scanDate = today ?? DateTime.now();
    var created = 0;
    var alreadySent = 0;
    for (final item in calculateFdrDeadlines(
      _dashboardSubmissions,
      today: scanDate,
    )) {
      if (item.status != MaturityStatus.critical &&
          item.status != MaturityStatus.matured &&
          item.status != MaturityStatus.expiringSoon) {
        continue;
      }
      final cycle = '${scanDate.year}-${scanDate.month}-${scanDate.day}';
      final key =
          'deadline-${item.submission.submissionId}-${item.status.name}-$cycle';
      if (_reminderKeys.add(key)) {
        NotificationCenter.instance.add(
          recipientRole: NotificationRecipientRole.officer,
          title: '${item.status.label}: ${item.submission.reference}',
          message:
              '${item.submission.institution} requires maturity follow-up.',
          category: NotificationCategory.reminder,
          relatedId: item.submission.submissionId,
          eventKey: key,
        );
        appendAuditEntry(
          action: 'Deadline reminder generated',
          associatedId: item.submission.submissionId,
          actorRole: 'System',
          payload: '${item.status.label}; cycle $cycle',
        );
        created++;
      } else {
        alreadySent++;
      }
    }
    _lastReminderScanAt = scanDate;
    _lastReminderCreated = created;
    _lastReminderAlreadySent = alreadySent;
    _reminderWrite = _persistReminderState();
    notifyListeners();
    return created;
  }

  bool linkRenewal({
    required String submissionId,
    required String parentFdrReference,
  }) {
    final current = submissionById(submissionId);
    if (current == null || current.reference == parentFdrReference) {
      return false;
    }
    final parentExists = _dashboardSubmissions.any(
      (item) => item.reference == parentFdrReference,
    );
    if (!parentExists) return false;
    final record = _fdrRecordsBySubmissionId[submissionId];
    if (record == null) return false;
    _fdrRecordsBySubmissionId[submissionId] = record.copyWith(
      parentFdrReference: parentFdrReference,
    );
    appendAuditEntry(
      action: 'FDR renewal lineage linked',
      associatedId: submissionId,
      actorRole: 'Demo Officer',
      payload: 'Parent FDR $parentFdrReference',
    );
    notifyListeners();
    return true;
  }

  FdrSubmission createRenewal({
    required String parentFdrReference,
    required String newFdrNumber,
    required String bank,
    required int amount,
    required String issueDate,
    required int tenureMonths,
  }) {
    final parentSubmission = _dashboardSubmissions
        .where((item) => item.reference == parentFdrReference)
        .firstOrNull;
    final parentRecord = parentSubmission == null
        ? null
        : _fdrRecordsBySubmissionId[parentSubmission.submissionId];
    if (parentSubmission == null || parentRecord == null) {
      throw ArgumentError('Parent FDR was not found.');
    }
    if (newFdrNumber.trim().isEmpty ||
        _dashboardSubmissions.any((item) => item.reference == newFdrNumber)) {
      throw ArgumentError('Renewal FDR number must be unique.');
    }
    if (amount <= 0 || tenureMonths <= 0) {
      throw ArgumentError(
        'Renewal amount and tenure must be greater than zero.',
      );
    }
    final parsedIssue = _parsePortalDate(issueDate);
    final parentMaturity = _parsePortalDate(parentRecord.maturityDate);
    if (parsedIssue == null ||
        parentMaturity == null ||
        parsedIssue.isBefore(parentMaturity)) {
      throw ArgumentError(
        'Renewal issue date must be on or after parent maturity.',
      );
    }
    final maturity = DateTime(
      parsedIssue.year,
      parsedIssue.month + tenureMonths,
      parsedIssue.day,
    );
    final id = _newInstitutionSubmissionId();
    final childRecord = FdrRecord(
      institution: parentRecord.institution,
      institutionId: parentRecord.institutionId,
      submissionId: id,
      bank: bank,
      fdrNumber: newFdrNumber,
      declaredDepositAmount: amount,
      receiptAmount: amount,
      issueDate: issueDate,
      maturityDate: _parsePortalDateLabel(maturity),
      declaredTenureMonths: tenureMonths,
      enteredTenureMonths: tenureMonths,
      lienInformation: parentRecord.lienInformation,
      submissionStatus: 'Pending Review',
      documents: parentRecord.documents,
      parentFdrReference: parentFdrReference,
    );
    final child = FdrSubmission(
      institution: parentRecord.institution,
      institutionId: parentRecord.institutionId,
      submissionId: id,
      submittedOn: _shortDate(_clock.now()),
      reference: newFdrNumber,
      amount: '₹${_formatCurrency(amount)}',
      status: VerificationStatus.pending,
      bankName: bank,
      issues: const [],
    );
    _fdrRecordsBySubmissionId[id] = childRecord;
    _dashboardSubmissions.add(child);
    _demoFdrRecords[newFdrNumber] = DemoFdrMasterRecord(
      institution: parentRecord.institution,
      institutionId: parentRecord.institutionId,
      fdrReference: newFdrNumber,
      amount: amount,
    );
    _fdrRecordsBySubmissionId[parentSubmission.submissionId] = parentRecord
        .copyWith(submissionStatus: 'Renewed');
    appendAuditEntry(
      action: 'FDR renewal created',
      associatedId: id,
      actorRole: 'Demo Officer',
      payload: 'Parent $parentFdrReference; child $newFdrNumber',
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'FDR renewal submitted',
      message: '$newFdrNumber renews $parentFdrReference.',
      category: NotificationCategory.submission,
      relatedId: id,
      eventKey: 'renewal-$id',
    );
    notifyListeners();
    return child;
  }

  List<FdrRecord> renewalLineage(String fdrReference) {
    final records = <FdrRecord>[];
    var current = _fdrRecordsBySubmissionId.values
        .where((record) => record.fdrNumber == fdrReference)
        .firstOrNull;
    while (current != null) {
      records.insert(0, current);
      final parent = current.parentFdrReference;
      current = parent == null
          ? null
          : _fdrRecordsBySubmissionId.values
                .where((record) => record.fdrNumber == parent)
                .firstOrNull;
    }
    final children = _fdrRecordsBySubmissionId.values.where(
      (record) => record.parentFdrReference == fdrReference,
    );
    records.addAll(children);
    return List.unmodifiable(records);
  }

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
    if (institution.trim().isEmpty ||
        institutionId.trim().isEmpty ||
        bank.trim().isEmpty ||
        fdrNumber.trim().isEmpty ||
        amount <= 0) {
      throw ArgumentError(
        'Institution, bank, FDR reference, and a positive amount are required.',
      );
    }
    final claims = portalAuthService.currentClaims;
    if (claims?.role == AuthRole.institution &&
        claims?.institutionId != institutionId) {
      throw PermissionDeniedException(
        'The authenticated institution cannot submit for another institution.',
      );
    }
    final normalizedFdrNumber = fdrNumber.trim();
    if (_dashboardSubmissions.any(
      (submission) =>
          submission.caseType == 'FDR Submission' &&
          submission.reference.toLowerCase() ==
              normalizedFdrNumber.toLowerCase(),
    )) {
      throw ArgumentError('The FDR reference has already been submitted.');
    }
    final submissionId = _newInstitutionSubmissionId();
    final record = FdrRecord(
      institution: institution,
      institutionId: institutionId,
      submissionId: submissionId,
      bank: bank,
      fdrNumber: normalizedFdrNumber,
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
      reference: normalizedFdrNumber,
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
      payload: normalizedFdrNumber,
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'New FDR Submission',
      message: '$institution submitted an FDR for verification.',
      category: NotificationCategory.submission,
      relatedId: submissionId,
      eventKey: 'fdr-submitted-$submissionId',
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: institutionId,
      title: 'FDR Submission Received',
      message:
          'Your FDR submission has been successfully submitted for review.',
      category: NotificationCategory.submission,
      relatedId: submissionId,
      eventKey: 'fdr-received-$submissionId',
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
    const supportedCaseTypes = {
      'Normal Release',
      'Progressive Closure',
      'Merger',
    };
    if (!supportedCaseTypes.contains(caseType)) {
      throw ArgumentError('Unsupported release or refund request type.');
    }
    if (institution.trim().isEmpty ||
        institutionId.trim().isEmpty ||
        bank.trim().isEmpty ||
        fdrNumber.trim().isEmpty ||
        reason.trim().isEmpty ||
        originalAmount <= 0) {
      throw ArgumentError('Institution, FDR, amount, and reason are required.');
    }
    final claims = portalAuthService.currentClaims;
    if (claims?.role == AuthRole.institution &&
        claims?.institutionId != institutionId) {
      throw PermissionDeniedException(
        'The authenticated institution cannot submit for another institution.',
      );
    }
    if (caseType == 'Merger' &&
        (successorInstitution.trim().isEmpty ||
            mergerReference.trim().isEmpty ||
            effectiveDate.trim().isEmpty)) {
      throw ArgumentError(
        'Successor institution, merger reference, and effective date are required.',
      );
    }
    final master = _demoFdrRecords[fdrNumber];
    if (master == null ||
        master.institutionId != institutionId ||
        master.amount != originalAmount) {
      throw ArgumentError(
        'The selected FDR does not belong to this institution.',
      );
    }
    final availableBalance = _availableBalanceForFdr(fdrNumber, institutionId);
    if (caseType != 'Merger' &&
        (requestedAmount <= 0 ||
            requestedAmount > originalAmount ||
            requestedAmount > availableBalance)) {
      throw ArgumentError(
        'Requested release amount must be within the FDR amount.',
      );
    }
    final duplicate = _dashboardSubmissions
        .where(
          (submission) =>
              submission.caseType == caseType &&
              submission.institutionId == institutionId &&
              submission.reference == fdrNumber &&
              submission.requestedAmount == requestedAmount &&
              submission.requestReason == reason.trim(),
        )
        .firstOrNull;
    if (duplicate != null) return duplicate;

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
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: caseType == 'Merger'
          ? 'Merger Request Pending'
          : 'Refund Request Pending',
      message: '$institution submitted a $caseType request for officer review.',
      category: caseType == 'Merger'
          ? NotificationCategory.merger
          : NotificationCategory.request,
      relatedId: caseId,
      eventKey: 'case-submitted-$caseId',
    );
    notifyListeners();
    return submission;
  }

  int _availableBalanceForFdr(String fdrNumber, String institutionId) {
    var balance = _demoFdrRecords[fdrNumber]?.amount ?? 0;
    for (final item in _releaseCases.values) {
      if (item.originalFdrReference == fdrNumber &&
          item.originalInstitutionId == institutionId &&
          item.caseType == 'Progressive Closure' &&
          item.status == 'Approved') {
        balance -= item.requestedReleaseAmount;
      }
    }
    return balance;
  }

  void selectReleaseCase(String caseId) {
    final record = _releaseCases.values
        .where((item) => item.caseId == caseId)
        .firstOrNull;
    if (record == null) return;
    _selectedCaseType = record.caseType;
    selectSubmission(record.submissionId);
    _selectedReleaseCaseId = caseId;
    notifyListeners();
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
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: submission.institutionId,
      title: 'FDR Returned for Correction',
      message:
          'Your FDR submission has been returned for correction. Open the submission to review the officer comments.',
      category: NotificationCategory.correction,
      relatedId: submissionId,
      eventKey: 'fdr-rejected-$submissionId',
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
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Corrected Submission Resubmitted',
      message:
          '${submission.institution} resubmitted a corrected FDR for review.',
      category: NotificationCategory.submission,
      relatedId: submissionId,
      eventKey:
          'fdr-resubmitted-$submissionId-${DateTime.now().millisecondsSinceEpoch}',
    );
    notifyListeners();
    return true;
  }

  String _newInstitutionSubmissionId() {
    String candidate;
    do {
      candidate =
          'FDR-${DateTime.now().year}-${(129 + _nextInstitutionSubmissionSequence++).toString().padLeft(5, '0')}';
    } while (_dashboardSubmissions.any(
      (submission) => submission.submissionId == candidate,
    ));
    return candidate;
  }

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
    portalAuthService.signOut();
    _verificationScenario = DemoVerificationScenario.blocked;
    _currentSubmission = _blockedSubmission;
    _lastVerification = FdrVerificationService.runVerification(
      _blockedSubmission,
      clock: _clock,
      rules: _rules.values,
    );
    _verificationCurrent = true;
    _releaseCases.clear();
    _clarifications.clear();
    _discrepancies.clear();
    _mergerRelationships.clear();
    _selectedCaseType = 'Normal Release';
    _selectedReleaseCaseId = null;
    _auditEntries.clear();
    _reminderKeys.clear();
    _documentBytes.clear();
    _seedAudit();
    _seedDeterministicAuditEvents();
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
          reference: 'FDR-EX-884201',
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
      ..['FDR-2026-00124'] = _blockedSubmission.copyWith(
        issueDate: _dateMonthsBefore(
          _clock.now().add(const Duration(days: 6)),
          36,
        ),
        maturityDate: _dateRelative(6),
        declaredTenureMonths: 36,
        enteredTenureMonths: 36,
      )
      ..['FDR-2026-00125'] = _seededFdrRecord(
        submissionId: 'FDR-2026-00125',
        fdrNumber: 'FDR-EX-884201',
        institution: 'National College of Engineering',
        institutionId: 'INST-00125',
        bank: 'National Commerce Bank',
        amount: 300000,
        issueDate: _dateMonthsBefore(
          _clock.now().add(const Duration(days: 500)),
          36,
        ),
        maturityDate: _dateRelative(500),
      )
      ..['FDR-2026-00126'] = _seededFdrRecord(
        submissionId: 'FDR-2026-00126',
        fdrNumber: 'FDR-MI-719643',
        institution: 'Metropolitan Institute of Science',
        institutionId: 'INST-00126',
        bank: 'Metropolitan Bank',
        amount: 750000,
        issueDate: _dateMonthsBefore(
          _clock.now().add(const Duration(days: 20)),
          36,
        ),
        maturityDate: _dateRelative(20),
        sourceValues: {
          DocumentSource.fdrMaster: {'trustName': 'Example Educational Trust'},
          DocumentSource.receipt: {
            'trustName': 'Metropolitan Education Society',
          },
          DocumentSource.requestLetter: {
            'trustName': 'Example Educational Trust',
          },
          DocumentSource.affidavit: {'trustName': 'Example Educational Trust'},
        },
        lienInformation: 'Not provided',
      )
      ..['FDR-2026-00127'] = _seededFdrRecord(
        submissionId: 'FDR-2026-00127',
        fdrNumber: 'FDR-EIT-771530',
        institution: 'Example Institute of Technology',
        institutionId: 'INST-DEMO-0042',
        bank: 'Civic Union Bank',
        amount: 350000,
        issueDate: _dateMonthsBefore(
          _clock.now().add(const Duration(days: 30)),
          36,
        ),
        maturityDate: _dateRelative(30),
      )
      ..['FDR-2026-00128'] = _rejectedSubmission.copyWith(
        issueDate: _dateRelative(-500),
        maturityDate: _dateRelative(-10),
        declaredTenureMonths: 0,
        enteredTenureMonths: 0,
      )
      ..['FDR-2026-00129'] = _seededFdrRecord(
        submissionId: 'FDR-2026-00129',
        fdrNumber: 'FDR-EIT-330817',
        institution: 'Example Institute of Technology',
        institutionId: 'INST-DEMO-0042',
        bank: 'Example National Bank',
        amount: 425000,
        issueDate: '03 October 2026',
        maturityDate: 'invalid-date',
        isDeliberateInvalidDate: true,
      );
    final renewedParent = _fdrRecordsBySubmissionId['FDR-2026-00127']!;
    _fdrRecordsBySubmissionId['FDR-CHILD-00127'] = renewedParent.copyWith(
      submissionId: 'FDR-CHILD-00127',
      fdrNumber: 'FDR-EIT-771530-R1',
      issueDate: _dateRelative(31),
      maturityDate: _dateRelative(396),
      parentFdrReference: renewedParent.fdrNumber,
      submissionStatus: 'Pending Review',
    );
    _fdrRecordsBySubmissionId['FDR-2026-00127'] = renewedParent.copyWith(
      submissionStatus: 'Renewed',
    );
    final maturedAt = _clock.now().subtract(const Duration(days: 10));
    _fdrRecordsBySubmissionId['FDR-2026-00128'] = _rejectedSubmission.copyWith(
      issueDate: _dateMonthsBefore(maturedAt, 36),
      maturityDate: _dateRelative(-10),
      declaredTenureMonths: 36,
      enteredTenureMonths: 36,
    );
    _currentSubmission = _fdrRecordsBySubmissionId['FDR-2026-00124']!.copyWith(
      declaredDepositAmount: 500000,
      receiptAmount: 450000,
    );
    _fdrRecordsBySubmissionId['FDR-2026-00124'] = _currentSubmission;
    _lastVerification = FdrVerificationService.runVerification(
      _currentSubmission,
      clock: _clock,
      rules: _rules.values,
    );
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
    _auditWrite = _persistAuditChain();
    notifyListeners();
  }

  void seedDemoCases() {
    if (_releaseCases.isNotEmpty) return;
    createReleaseCase();
    _releaseCases['Normal Release'] = _releaseCases['Normal Release']!.copyWith(
      status: 'Ready for Final NOC',
      clearances: [
        _releaseCases['Normal Release']!.clearances.first.copyWith(
          status: 'Cleared',
        ),
        _releaseCases['Normal Release']!.clearances.last,
      ],
    );
    _releaseCases['Progressive Closure'] = _releaseCases['Progressive Closure']!
        .copyWith(status: 'Clearance Pending');
    _releaseCases['Merger'] = _releaseCases['Merger']!.copyWith(
      status: 'Under Review',
    );
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

  void _seedDeterministicAuditEvents() {
    const actions = [
      'Queue reviewed',
      'Deadline reminder scanned',
      'Renewal lineage opened',
      'Amount discrepancy detected',
      'Duplicate FDR detected',
      'Trust name reviewed',
      'Lien warning recorded',
      'Correction submitted',
      'Verification rerun',
      'Release case opened',
      'Checklist reviewed',
      'Grievance clearance updated',
      'Vigilance clearance updated',
      'Case status changed',
      'Audit chain verified',
      'Report exported',
      'Institution risk calculated',
      'Deadline queue refreshed',
    ];
    for (final action in actions) {
      appendAuditEntry(
        action: action,
        associatedId: 'FDR-2026-00124',
        actorRole: 'Officer',
        payload: 'Seeded workflow event',
      );
    }
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
    _auditWrite = _persistAuditChain();
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

  void requestClarification({
    required String submissionId,
    required String reviewSection,
    required String remark,
    String? requiredDocument,
  }) {
    _validateClarificationRemark(remark);
    final submission = submissionById(submissionId);
    if (submission == null) {
      throw ArgumentError('Submission was not found.');
    }
    final existing = _clarifications[submissionId];
    if (existing != null &&
        existing.remark == remark.trim() &&
        existing.status == 'Clarification Requested') {
      return;
    }
    final officerId =
        portalAuthService.currentClaims?.subject ?? 'officer-demo';
    final clarification = OfficerClarification(
      submissionId: submissionId,
      caseId: submission.caseId,
      institutionId: submission.institutionId,
      institutionName: submission.institution,
      officerId: officerId,
      officerName: officerId,
      reviewSection: reviewSection.trim(),
      remark: remark.trim(),
      requiredDocument: requiredDocument,
      timestamp: _clock.now(),
      status: 'Clarification Requested',
    );
    _clarifications[submissionId] = clarification;
    _upsertSubmission(
      _submissionWithStatus(
        submission,
        status: SubmissionStatus.correctionRequested,
        issues: [
          ...submission.issues,
          '${reviewSection.trim()}: ${remark.trim()}',
        ],
      ),
    );
    appendAuditEntry(
      action: 'Clarification requested',
      associatedId: submission.caseId ?? submissionId,
      actorRole: officerId,
      payload: '${reviewSection.trim()}: ${remark.trim()}',
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: submission.institutionId,
      title: 'Clarification Requested',
      message:
          'Officer clarification is required for ${submission.reference}: ${remark.trim()}',
      category: NotificationCategory.clarification,
      relatedId: submission.caseId ?? submissionId,
      eventKey: 'clarification-$submissionId',
    );
    notifyListeners();
  }

  void respondToFdrClarification({
    required String submissionId,
    required String response,
    String? documentStatus,
  }) {
    if (response.trim().isEmpty) {
      throw ArgumentError('A response is required.');
    }
    final current = _clarifications[submissionId];
    final submission = submissionById(submissionId);
    if (current == null || submission == null) {
      throw ArgumentError('Clarification was not found.');
    }
    if (current.institutionId !=
        (portalAuthService.currentClaims?.institutionId ??
            current.institutionId)) {
      throw PermissionDeniedException(
        'This clarification belongs to another institution.',
      );
    }
    final updated = current.copyWith(
      response: response.trim(),
      documentStatus: documentStatus,
      responseTimestamp: _clock.now(),
      status: 'Response Submitted',
    );
    _clarifications[submissionId] = updated;
    _upsertSubmission(
      _submissionWithStatus(
        submission,
        status: SubmissionStatus.pendingReview,
        issues: submission.issues,
      ),
    );
    appendAuditEntry(
      action: 'Institution clarification response submitted',
      associatedId: submission.caseId ?? submissionId,
      actorRole: portalAuthService.currentClaims?.subject ?? 'Institution User',
      payload: response.trim(),
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Clarification Response Received',
      message:
          '${submission.institution} responded for ${submission.reference}.',
      category: NotificationCategory.clarification,
      relatedId: submission.caseId ?? submissionId,
      eventKey: 'clarification-response-$submissionId',
    );
    notifyListeners();
  }

  void _validateClarificationRemark(String? remark) {
    final value = remark?.trim() ?? '';
    if (value.length < 5 || value.split(RegExp(r'\s+')).length < 2) {
      throw ArgumentError(
        'Enter a meaningful officer remark describing the required action.',
      );
    }
  }

  FdrSubmission _submissionWithStatus(
    FdrSubmission submission, {
    required SubmissionStatus status,
    required List<String> issues,
  }) => FdrSubmission(
    institution: submission.institution,
    institutionId: submission.institutionId,
    submissionId: submission.submissionId,
    submittedOn: submission.submittedOn,
    updatedAtOverride: _clock.now(),
    reference: submission.reference,
    amount: submission.amount,
    status: status,
    bankName: submission.bankName,
    caseType: submission.caseType,
    caseId: submission.caseId,
    requestedAmount: submission.requestedAmount,
    retainedBalance: submission.retainedBalance,
    requestReason: submission.requestReason,
    issues: issues.toSet().toList(growable: false),
    rejectionReason: submission.rejectionReason,
    correctionHistory: submission.correctionHistory,
    verificationPassed: submission.verificationPassed,
    approvedAt: submission.approvedAt,
    approvedBy: submission.approvedBy,
    supportedDocuments: submission.supportedDocuments,
  );

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
    _notifyVerificationResult();
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void setLastVerification(VerificationSummary summary) {
    _lastVerification = summary;
    _verificationCurrent = true;
    reconcileDiscrepancies(summary);
    _syncDashboardSubmission(
      summary.blocking > 0
          ? VerificationStatus.blocked
          : VerificationStatus.verified,
    );
    _notifyVerificationResult();
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

  void _notifyVerificationResult() {
    final submission = submissionById(_currentSubmission.submissionId);
    if (submission == null) return;
    final passed = _lastVerification.blocking == 0;
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: submission.institutionId,
      title: passed
          ? 'FDR Verification Passed'
          : 'FDR Verification Requires Attention',
      message: passed
          ? 'Your FDR verification passed. The submission is awaiting officer action.'
          : 'Blocking discrepancies were found in your FDR submission. Open it to review the issues.',
      category: NotificationCategory.verification,
      relatedId: submission.submissionId,
      eventKey:
          'fdr-verification-${submission.submissionId}-${passed ? 'passed' : 'blocked'}',
    );
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
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: submission.institutionId,
      title: 'FDR Submission Approved',
      message:
          'Your FDR submission has been approved. View the submission for details.',
      category: NotificationCategory.approval,
      relatedId: submission.submissionId,
      eventKey: 'fdr-approved-${submission.submissionId}',
    );
  }

  VerificationSummary runCurrentVerification() {
    if (portalAuthService.currentClaims != null) {
      requirePermission(
        'verify FDR submissions',
        allowed: permissionMatrix['verify']!,
      );
    }
    final summary = _verifyFdrRecord(_currentSubmission);
    setLastVerification(summary);
    return summary;
  }

  VerificationSummary _verifyFdrRecord(FdrRecord record) {
    final initial = FdrVerificationService.runVerification(
      record,
      rules: _rules.values,
    );
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
    if (portalAuthService.currentClaims != null) {
      requirePermission('approve FDR submissions', allowed: {AuthRole.officer});
    }
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
    final normal = _releaseCases['Normal Release'];
    if (normal != null &&
        normal.submissionId != _currentSubmission.submissionId) {
      _releaseCases['Normal Release'] = normal.copyWith(
        submissionId: _currentSubmission.submissionId,
        institution: _currentSubmission.institution,
      );
    }
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
    final claims = portalAuthService.currentClaims;
    if (claims != null &&
        claims.role != AuthRole.officer &&
        !((clearanceName == 'Grievance Redressal Cell' &&
                claims.role == AuthRole.grievanceCell) ||
            (clearanceName == 'Vigilance Cell' &&
                claims.role == AuthRole.vigilanceCell))) {
      requirePermission(
        'update $clearanceName clearance',
        allowed: {
          AuthRole.officer,
          if (clearanceName == 'Grievance Redressal Cell')
            AuthRole.grievanceCell,
          if (clearanceName == 'Vigilance Cell') AuthRole.vigilanceCell,
        },
      );
    }
    final currentCase = releaseCase;
    if (currentCase == null) return;
    if (newStatus == 'Clarification Requested') {
      _validateClarificationRemark(remark);
    }
    final index = currentCase.clearances.indexWhere(
      (item) => item.name == clearanceName,
    );
    if (index == -1) return;
    final updated = currentCase.clearances[index].copyWith(
      status: newStatus,
      remark: remark ?? currentCase.clearances[index].remark,
      remarkHistory: remark == null
          ? currentCase.clearances[index].remarkHistory
          : [
              ...currentCase.clearances[index].remarkHistory,
              ClearanceRemark(
                text: remark.trim(),
                timestamp: _clock.now().toIso8601String(),
                officerId:
                    portalAuthService.currentClaims?.subject ?? 'officer-demo',
                officerName:
                    portalAuthService.currentClaims?.subject ?? 'Demo Officer',
              ),
            ],
      lastUpdated: DateTime.now().toLocal().toString().substring(0, 16),
    );
    final clearances = [...currentCase.clearances];
    clearances[index] = updated;
    _saveReleaseCase(
      currentCase.copyWith(
        clearances: clearances,
        status: newStatus == 'Clarification Requested'
            ? 'Clarification Requested'
            : currentCase.status,
      ),
    );
    if (newStatus == 'Clarification Requested') {
      final clarification = OfficerClarification(
        submissionId: currentCase.submissionId,
        caseId: currentCase.caseId,
        institutionId: currentCase.originalInstitutionId,
        institutionName: currentCase.institution,
        officerId: portalAuthService.currentClaims?.subject ?? 'officer-demo',
        officerName: portalAuthService.currentClaims?.subject ?? 'Demo Officer',
        reviewSection: clearanceName,
        remark: remark!.trim(),
        timestamp: _clock.now(),
        status: 'Clarification Requested',
      );
      _clarifications[currentCase.submissionId] = clarification;
      _upsertSubmission(
        _submissionWithStatus(
          submissionById(currentCase.submissionId)!,
          status: SubmissionStatus.correctionRequested,
          issues: [
            ...submissionById(currentCase.submissionId)!.issues,
            '${clearanceName}: ${remark.trim()}',
          ],
        ),
      );
      appendAuditEntry(
        action: 'Clarification requested',
        associatedId: currentCase.caseId,
        actorRole: clarification.officerId,
        payload: '${clarification.reviewSection}: ${clarification.remark}',
      );
      NotificationCenter.instance.add(
        recipientRole: NotificationRecipientRole.institution,
        recipientId: currentCase.originalInstitutionId,
        title: 'Clarification Requested',
        message:
            '$clearanceName requested clarification for case ${currentCase.caseId}.',
        category: NotificationCategory.clarification,
        relatedId: currentCase.caseId,
        eventKey: 'clarification-${currentCase.caseId}-$clearanceName',
      );
    }
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  void respondToClarification({
    required String submissionId,
    required String clearanceName,
    required String response,
  }) {
    MapEntry<String, ReleaseCase>? caseEntry;
    for (final entry in _releaseCases.entries) {
      if (entry.value.submissionId == submissionId) {
        caseEntry = entry;
        break;
      }
    }
    if (caseEntry == null || response.trim().isEmpty) return;
    final record = caseEntry.value;
    final claims = portalAuthService.currentClaims;
    if (claims?.role == AuthRole.institution &&
        claims?.institutionId != record.originalInstitutionId) {
      throw PermissionDeniedException(
        'This case belongs to another institution.',
      );
    }
    final clearanceIndex = record.clearances.indexWhere(
      (item) => item.name == clearanceName,
    );
    if (clearanceIndex == -1) return;
    final clearance = record.clearances[clearanceIndex];
    final updatedClearance = clearance.copyWith(
      response: response.trim(),
      responseTimestamp: DateTime.now().toLocal().toString().substring(0, 16),
      status: 'Response Submitted',
    );
    final clearances = [...record.clearances]
      ..[clearanceIndex] = updatedClearance;
    _releaseCases[caseEntry.key] = record.copyWith(
      clearances: clearances,
      status: 'Response Submitted',
    );
    appendAuditEntry(
      action: 'Institution clarification response submitted',
      associatedId: record.caseId,
      actorRole: claims?.subject ?? 'Institution User',
      payload: response.trim(),
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Clarification Response Received',
      message:
          '${record.institution} responded to $clearanceName for case ${record.caseId}.',
      category: NotificationCategory.clarification,
      relatedId: record.caseId,
      eventKey: 'clarification-response-${record.caseId}-$clearanceName',
    );
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
    appendAuditEntry(
      action: isPresent
          ? 'Required document marked present'
          : 'Required document marked missing',
      associatedId: currentCase.caseId,
      actorRole: 'Demo Officer',
      payload: fileName,
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.institution,
      recipientId: currentCase.originalInstitutionId,
      title: isPresent ? 'Document Reviewed' : 'Document Requires Attention',
      message: '$fileName status changed for case ${currentCase.caseId}.',
      category: isPresent
          ? NotificationCategory.verification
          : NotificationCategory.reminder,
      relatedId: currentCase.caseId,
      eventKey:
          'document-${currentCase.caseId}-$fileName-${isPresent ? 'present' : 'missing'}',
    );
    _syncNormalReleaseStatus();
    notifyListeners();
  }

  bool replaceRequiredDocument({
    required String caseId,
    required String fileName,
  }) {
    String? mapKey;
    ReleaseCase? currentCase;
    for (final entry in _releaseCases.entries) {
      if (entry.value.caseId == caseId) {
        mapKey = entry.key;
        currentCase = entry.value;
        break;
      }
    }
    if (mapKey == null || currentCase == null) return false;
    var changed = false;
    final checklist = currentCase.checklist.map((item) {
      if (item.fileName != fileName) return item;
      changed = true;
      return item.copyWith(isPresent: true, status: 'Pending Review');
    }).toList();
    if (!changed) return false;
    _releaseCases[mapKey] = currentCase.copyWith(checklist: checklist);
    appendAuditEntry(
      action: 'Required document replacement submitted',
      associatedId: caseId,
      actorRole: 'Institution User',
      payload: fileName,
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Replacement Document Submitted',
      message:
          '${currentCase.institution} submitted a replacement document for review.',
      category: NotificationCategory.submission,
      relatedId: caseId,
      eventKey:
          'document-replacement-$caseId-$fileName-${DateTime.now().millisecondsSinceEpoch}',
    );
    notifyListeners();
    return true;
  }

  Future<String?> pickAndReplaceRequiredDocument({
    required String caseId,
    required String fileName,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    final extension = (file.extension ?? '').toLowerCase();
    if (bytes == null || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError(
        'Document must be available as bytes and no larger than 5 MB.',
      );
    }
    if (!{'pdf', 'jpg', 'jpeg', 'png'}.contains(extension)) {
      throw ArgumentError(
        'Only PDF, JPG, JPEG, and PNG documents are supported.',
      );
    }
    return uploadRequiredDocumentBytes(
      caseId: caseId,
      requiredFileName: fileName,
      selectedFileName: file.name,
      bytes: bytes,
      mimeType: switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      },
    );
  }

  String? uploadRequiredDocumentBytes({
    required String caseId,
    required String requiredFileName,
    required String selectedFileName,
    required List<int> bytes,
    required String mimeType,
  }) {
    validateDocumentUpload(
      fileName: selectedFileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    final caseEntry = _releaseCases.entries
        .where((entry) => entry.value.caseId == caseId)
        .firstOrNull;
    final currentCase = caseEntry?.value;
    if (currentCase == null) return null;
    final index = currentCase.checklist.indexWhere(
      (item) => item.fileName == requiredFileName,
    );
    if (index == -1) return null;
    final record = _fdrRecordsBySubmissionId[currentCase.submissionId];
    if (record == null) return null;
    final previousVersions = record.supportedDocuments.where(
      (document) => document.type == requiredFileName,
    );
    final version = previousVersions.isEmpty
        ? 1
        : previousVersions
                  .map((document) => document.version)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final metadata = SupportedDocument(
      id: '$caseId-$requiredFileName-v$version',
      type: requiredFileName,
      fileName: selectedFileName,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      uploadedAt: _clock.now(),
      uploadedBy: 'Institution User',
      version: version,
      sha256: checksumForDocumentBytes(bytes)!,
    );
    final checklist = [...currentCase.checklist]
      ..[index] = currentCase.checklist[index].copyWith(
        isPresent: true,
        status: 'Present — Uploaded',
      );
    final history = CaseHistoryEvent(
      action: 'Document uploaded',
      actor: 'Institution User',
      at: _clock.now(),
      remark: '$selectedFileName uploaded as version $version',
    );
    _fdrRecordsBySubmissionId[currentCase.submissionId] = record.copyWith(
      supportedDocuments: [...record.supportedDocuments, metadata],
    );
    _documentBytes[metadata.id] = List<int>.unmodifiable(bytes);
    _documentWrite = _persistDocumentBytes();
    _releaseCases[caseEntry!.key] = currentCase.copyWith(
      checklist: checklist,
      history: [...currentCase.history, history],
    );
    appendAuditEntry(
      action: 'Document uploaded',
      associatedId: caseId,
      actorRole: 'Institution User',
      payload:
          '$selectedFileName; SHA-256 ${metadata.sha256}; version $version',
    );
    NotificationCenter.instance.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Replacement Document Submitted',
      message: '$selectedFileName is ready for review.',
      category: NotificationCategory.submission,
      relatedId: caseId,
      eventKey: 'document-upload-$caseId-${metadata.id}',
    );
    notifyListeners();
    return metadata.sha256;
  }

  void updateReleaseCaseType(String caseType) {
    _selectedReleaseCaseId = null;
    if (!_releaseCases.containsKey(caseType)) createReleaseCase();
    _selectedCaseType = caseType;
    notifyListeners();
  }

  void issueDemoNoc() {
    if (portalAuthService.currentClaims != null) {
      requirePermission('issue final NOC', allowed: {AuthRole.officer});
    }
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
    if (portalAuthService.currentClaims != null) {
      requirePermission(
        'approve progressive closure',
        allowed: {AuthRole.officer},
      );
    }
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
    if (portalAuthService.currentClaims != null) {
      requirePermission('approve merger cases', allowed: {AuthRole.officer});
    }
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
    final current = _releaseCases[key];
    if (current == null || current.status == record.status) {
      if (current != null &&
          current.status == record.status &&
          record.history.length == current.history.length) {
        _releaseCases[key] = record.copyWith(
          history: [
            ...record.history,
            CaseHistoryEvent(
              action: 'Case details updated',
              actor: 'Demo Officer',
              at: _clock.now(),
              remark: 'Documents, clearances, or case amounts updated.',
            ),
          ],
        );
      } else {
        _releaseCases[key] = record;
      }
      return;
    }
    transition(
      record.caseId,
      _caseStatusFromLabel(record.status),
      'Demo Officer',
      'Case workflow updated',
      displayStatus: record.status,
    );
    _releaseCases[key] = _releaseCases[key]!.copyWith(
      checklist: record.checklist,
      clearances: record.clearances,
      requestedReleaseAmount: record.requestedReleaseAmount,
      partialReleaseReason: record.partialReleaseReason,
      successorInstitution: record.successorInstitution,
      successorInstitutionId: record.successorInstitutionId,
      mergerReference: record.mergerReference,
      effectiveDate: record.effectiveDate,
    );
  }

  static String _computeHash(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes).toString();
    return digest;
  }
}

enum DocumentSource { fdrMaster, receipt, requestLetter, affidavit }

enum ComparisonStatus { allMatch, partialMismatch, missing }

class FieldComparison {
  const FieldComparison({
    required this.field,
    required this.values,
    required this.status,
    required this.differingSources,
    this.severity = VerificationIssueSeverity.passed,
  });

  final String field;
  final Map<DocumentSource, String?> values;
  final ComparisonStatus status;
  final Set<DocumentSource> differingSources;
  final VerificationIssueSeverity severity;
}

class SupportedDocument {
  const SupportedDocument({
    required this.id,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.version,
    required this.sha256,
    this.extractedFields = const {},
  });

  final String id;
  final String type;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String uploadedBy;
  final int version;
  final String sha256;
  final Map<String, String> extractedFields;
}

class DocumentIntegrityResult {
  const DocumentIntegrityResult({required this.isValid, required this.message});

  final bool isValid;
  final String message;
}

String validateDocumentUpload({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) {
  final extension = fileName.split('.').last.toLowerCase();
  const supportedTypes = <String, String>{
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };
  final expectedMime = supportedTypes[extension];
  if (expectedMime == null || expectedMime != mimeType) {
    throw ArgumentError('Only PDF, JPG, JPEG, and PNG files are supported.');
  }
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw ArgumentError(
      'Document must contain bytes and be no larger than 5 MB.',
    );
  }
  return expectedMime;
}

enum DiscrepancyStatus { open, correctionSubmitted, resolved, waived, reopened }

class DiscrepancyEvent {
  const DiscrepancyEvent({
    required this.actor,
    required this.action,
    required this.remark,
    required this.at,
    this.previousValue,
    this.newValue,
  });

  final String actor;
  final String action;
  final String remark;
  final DateTime at;
  final String? previousValue;
  final String? newValue;
}

class Discrepancy {
  const Discrepancy({
    required this.id,
    required this.ruleId,
    required this.field,
    required this.severity,
    required this.status,
    required this.detectedAt,
    this.history = const [],
  });

  final String id;
  final String ruleId;
  final String field;
  final VerificationIssueSeverity severity;
  final DiscrepancyStatus status;
  final DateTime detectedAt;
  final List<DiscrepancyEvent> history;
}

enum RuleSeverity { blocking, warning, off }

class RuleConfig {
  const RuleConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.severity,
    required this.enabled,
    this.params = const {},
  });

  final String id;
  final String name;
  final String description;
  final RuleSeverity severity;
  final bool enabled;
  final Map<String, num> params;

  RuleConfig copyWith({
    RuleSeverity? severity,
    bool? enabled,
    Map<String, num>? params,
  }) => RuleConfig(
    id: id,
    name: name,
    description: description,
    severity: severity ?? this.severity,
    enabled: enabled ?? this.enabled,
    params: params ?? this.params,
  );
}

List<RuleConfig> defaultRuleConfigs() => const [
  RuleConfig(
    id: 'deposit-amount',
    name: 'Amount tolerance',
    description: 'Compare deposit values.',
    severity: RuleSeverity.blocking,
    enabled: true,
    params: {'tolerance': 0},
  ),
  RuleConfig(
    id: 'date-consistency',
    name: 'Date consistency',
    description: 'Maturity follows issue date.',
    severity: RuleSeverity.blocking,
    enabled: true,
  ),
  RuleConfig(
    id: 'tenure-consistency',
    name: 'Tenure tolerance',
    description: 'Tenure matches the date interval.',
    severity: RuleSeverity.blocking,
    enabled: true,
    params: {'toleranceMonths': 0},
  ),
  RuleConfig(
    id: 'institution-name-mismatch',
    name: 'Institution name similarity',
    description: 'Compare institution names.',
    severity: RuleSeverity.blocking,
    enabled: true,
    params: {'threshold': 0.8},
  ),
  RuleConfig(
    id: 'trust-name-mismatch',
    name: 'Trust name similarity',
    description: 'Compare trust names.',
    severity: RuleSeverity.warning,
    enabled: true,
    params: {'threshold': 0.8},
  ),
  RuleConfig(
    id: 'lien-information',
    name: 'Lien required',
    description: 'Require lien information.',
    severity: RuleSeverity.warning,
    enabled: true,
  ),
  RuleConfig(
    id: 'maturity-warning',
    name: 'Maturity warning',
    description: 'Warn before maturity.',
    severity: RuleSeverity.warning,
    enabled: true,
    params: {'warningDays': 30},
  ),
  RuleConfig(
    id: 'duplicate-fdr',
    name: 'Duplicate FDR',
    description: 'Reject duplicate references.',
    severity: RuleSeverity.blocking,
    enabled: true,
  ),
];

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
    this.institutionNameOnDocuments,
    this.parentFdrReference,
    this.sourceValues = const {},
    this.supportedDocuments = const [],
    this.isDeliberateInvalidDate = false,
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
  final String? institutionNameOnDocuments;
  final String? parentFdrReference;
  final Map<DocumentSource, Map<String, String?>> sourceValues;
  final List<SupportedDocument> supportedDocuments;
  final bool isDeliberateInvalidDate;

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
    String? institutionNameOnDocuments,
    String? parentFdrReference,
    Map<DocumentSource, Map<String, String?>>? sourceValues,
    List<SupportedDocument>? supportedDocuments,
    bool? isDeliberateInvalidDate,
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
    institutionNameOnDocuments:
        institutionNameOnDocuments ?? this.institutionNameOnDocuments,
    parentFdrReference: parentFdrReference ?? this.parentFdrReference,
    sourceValues: sourceValues ?? this.sourceValues,
    supportedDocuments: supportedDocuments ?? this.supportedDocuments,
    isDeliberateInvalidDate:
        isDeliberateInvalidDate ?? this.isDeliberateInvalidDate,
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
    this.affectedField = '',
    this.sourceValues = const {},
    this.resolved = false,
    this.detectedAt,
  });

  final String ruleId;
  final VerificationIssueSeverity severity;
  final String message;
  final String description;
  final String recommendedAction;
  final String affectedField;
  final Map<String, String> sourceValues;
  final bool resolved;
  final DateTime? detectedAt;
}

enum VerificationIssueSeverity { blocking, warning, passed }

class VerificationSummary {
  const VerificationSummary({
    required this.totalChecks,
    required this.blocking,
    required this.warnings,
    required this.statusText,
    required this.issues,
    this.comparisonMatrix = const [],
  });

  final int totalChecks;
  final int blocking;
  final int warnings;
  final String statusText;
  final List<VerificationIssue> issues;
  final List<FieldComparison> comparisonMatrix;
}

enum MaturityStatus { active, expiringSoon, critical, matured, invalid }

extension MaturityStatusLabel on MaturityStatus {
  String get label => switch (this) {
    MaturityStatus.active => 'Active',
    MaturityStatus.expiringSoon => 'Expiring Soon',
    MaturityStatus.critical => 'Critical',
    MaturityStatus.matured => 'Matured',
    MaturityStatus.invalid => 'Review Date',
  };
}

class FdrDeadlineInfo {
  const FdrDeadlineInfo({
    required this.submission,
    required this.maturityDate,
    required this.daysRemaining,
    required this.status,
    required this.nextAction,
    this.isRenewed = false,
  });

  final FdrSubmission submission;
  final DateTime? maturityDate;
  final int? daysRemaining;
  final MaturityStatus status;
  final String nextAction;
  final bool isRenewed;
}

List<FdrDeadlineInfo> calculateFdrDeadlines(
  Iterable<FdrSubmission> submissions, {
  DateTime? today,
  Map<String, String?> maturityDates = const {},
}) {
  final currentDate = DateTime(
    (today ?? DateTime.now()).year,
    (today ?? DateTime.now()).month,
    (today ?? DateTime.now()).day,
  );
  final results = submissions.map((submission) {
    final record = DemoFdrPortalStore.instance.fdrRecordForSubmission(
      submission.submissionId,
    );
    final renewed = record?.submissionStatus == 'Renewed';
    final rawMaturity = maturityDates.containsKey(submission.submissionId)
        ? maturityDates[submission.submissionId]
        : record?.maturityDate;
    final maturity = rawMaturity == null ? null : _parsePortalDate(rawMaturity);
    if (maturity == null) {
      return FdrDeadlineInfo(
        submission: submission,
        maturityDate: null,
        daysRemaining: null,
        status: MaturityStatus.invalid,
        nextAction: 'Review maturity date',
        isRenewed: renewed,
      );
    }
    final date = DateTime(maturity.year, maturity.month, maturity.day);
    final days = date.difference(currentDate).inDays;
    final status = days < 0
        ? MaturityStatus.matured
        : days <= 7
        ? MaturityStatus.critical
        : days <= 30
        ? MaturityStatus.expiringSoon
        : MaturityStatus.active;
    return FdrDeadlineInfo(
      submission: submission,
      maturityDate: date,
      daysRemaining: days,
      status: status,
      nextAction: status == MaturityStatus.matured
          ? 'Review renewal or release'
          : status == MaturityStatus.invalid
          ? 'Review maturity date'
          : 'Monitor maturity window',
      isRenewed: renewed,
    );
  }).toList();
  results.sort((left, right) {
    final leftDays = left.daysRemaining ?? 999999;
    final rightDays = right.daysRemaining ?? 999999;
    return leftDays.compareTo(rightDays);
  });
  return List.unmodifiable(results);
}

String _parsePortalDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][date.month - 1]} ${date.year}';

DateTime? _parsePortalDate(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final match = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$',
  ).firstMatch(value.trim());
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
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime.tryParse(
    '${match.group(3)}-${month.toString().padLeft(2, '0')}-${match.group(1)!.padLeft(2, '0')}',
  );
}

class InstitutionRiskAssessment {
  const InstitutionRiskAssessment({
    required this.category,
    required this.score,
    required this.reasons,
  });

  final String category;
  final int score;
  final List<String> reasons;
}

class RiskReason {
  const RiskReason(this.label, this.points);

  final String label;
  final int points;
}

const Map<String, int> riskWeights = {
  'blocking discrepancy': 30,
  'matured FDR without renewal': 20,
  'overdue clearance': 10,
  'repeated correction': 10,
};

InstitutionRiskAssessment assessInstitutionRisk(
  Iterable<FdrSubmission> submissions, {
  DateTime? today,
}) {
  var score = 0;
  final reasons = <String>[];
  final records = submissions.toList();
  final blocked = records
      .where((item) => item.status == SubmissionStatus.blocked)
      .length;
  if (blocked > 0) {
    score += blocked * riskWeights['blocking discrepancy']!;
    reasons.add(
      '$blocked blocking discrepancies +${blocked * riskWeights['blocking discrepancy']!}',
    );
  }
  final corrections = records
      .where(
        (item) =>
            item.status == SubmissionStatus.rejected ||
            item.status == SubmissionStatus.correctionRequested,
      )
      .length;
  if (corrections > 0) {
    score += corrections * riskWeights['repeated correction']!;
    reasons.add(
      '$corrections repeated corrections +${corrections * riskWeights['repeated correction']!}',
    );
  }
  final deadlines = calculateFdrDeadlines(records, today: today);
  final urgent = deadlines
      .where(
        (item) =>
            item.status == MaturityStatus.critical ||
            item.status == MaturityStatus.matured,
      )
      .length;
  if (urgent > 0) {
    final matured = deadlines
        .where(
          (item) => item.status == MaturityStatus.matured && !item.isRenewed,
        )
        .length;
    final critical = urgent - matured;
    score += matured * riskWeights['matured FDR without renewal']!;
    score += critical * 5;
    if (matured > 0)
      reasons.add(
        '$matured matured FDR without renewal +${matured * riskWeights['matured FDR without renewal']!}',
      );
    if (critical > 0)
      reasons.add('$critical critical maturity item(s) +${critical * 5}');
  }
  return InstitutionRiskAssessment(
    category: score >= 100
        ? 'Critical'
        : score >= 30
        ? 'High'
        : score >= 10
        ? 'Medium'
        : 'Low',
    score: score,
    reasons: reasons.isEmpty
        ? const ['No active risk factors found']
        : List.unmodifiable(reasons),
  );
}

class ActionQueueItem {
  const ActionQueueItem({
    required this.id,
    required this.institution,
    required this.reference,
    required this.status,
    required this.priority,
    required this.reason,
    required this.relatedSubmissionId,
    this.category = 'Pending review',
    this.dueDate,
    this.relatedCaseId,
  });

  final String id;
  final String institution;
  final String reference;
  final String status;
  final String priority;
  final String reason;
  final String relatedSubmissionId;
  final String category;
  final DateTime? dueDate;
  final String? relatedCaseId;
}

abstract interface class ReportsRepository {
  List<FdrSubmission> get submissions;
  int get totalSubmissions;
  int get totalInstitutions;
  int get totalDeposit;
  int get resolvedCount;
  Map<SubmissionStatus, int> get statusCounts;
  Map<SubmissionStatus, int> get statusPercentages;
  Map<SubmissionStatus, int> get depositByStatus;
  Map<String, int> get bankCounts;
  Map<String, int> get depositByBank;
  Map<String, InstitutionRiskAssessment> get institutionRisk;
  List<FdrDeadlineInfo> get deadlines;
  List<ActionQueueItem> get actionQueue;
}

class StoreReportsRepository implements ReportsRepository {
  StoreReportsRepository(this.store);

  final DemoFdrPortalStore store;

  @override
  List<FdrSubmission> get submissions => store.dashboardSubmissions;

  @override
  int get totalSubmissions => submissions.length;

  @override
  int get totalInstitutions => institutions(submissions).length;

  @override
  int get totalDeposit =>
      submissions.fold(0, (sum, item) => sum + item.depositAmount);

  @override
  int get resolvedCount => submissions
      .where((item) => item.status != SubmissionStatus.pendingReview)
      .length;

  @override
  Map<SubmissionStatus, int> get statusCounts => {
    for (final status in SubmissionStatus.values)
      status: countByStatus(submissions, status),
  };

  @override
  Map<SubmissionStatus, int> get statusPercentages =>
      statusPercentagesFor(submissions);

  @override
  Map<SubmissionStatus, int> get depositByStatus =>
      totalDepositByStatus(submissions);

  @override
  Map<String, int> get depositByBank => totalDepositByBank(submissions);

  @override
  Map<String, int> get bankCounts => {
    for (final entry in submissionsByBank(submissions).entries)
      entry.key: entry.value.length,
  };

  @override
  Map<String, InstitutionRiskAssessment> get institutionRisk => {
    for (final institution in institutions(submissions))
      institution.id: assessInstitutionRisk(
        submissionsForInstitution(submissions, institution.id),
      ),
  };

  @override
  List<FdrDeadlineInfo> get deadlines => store.deadlineItems;

  @override
  List<ActionQueueItem> get actionQueue => buildOfficerActionQueue(store);
}

enum QueueFilter {
  all,
  blocking,
  pendingReview,
  clearances,
  deadlines,
  corrections,
}

enum QueueTarget {
  verificationResults,
  releaseClearances,
  deadlineDetails,
  correction,
}

QueueTarget queueTargetFor(ActionQueueItem item) {
  final categories = item.category.split(', ');
  if (categories.contains('Corrections')) return QueueTarget.correction;
  if (categories.contains('Clearances')) return QueueTarget.releaseClearances;
  if (categories.contains('Deadlines')) return QueueTarget.deadlineDetails;
  if (categories.contains('Blocking discrepancies')) {
    return QueueTarget.verificationResults;
  }
  return QueueTarget.deadlineDetails;
}

extension QueueFilterLabel on QueueFilter {
  String get label => switch (this) {
    QueueFilter.all => 'All',
    QueueFilter.blocking => 'Blocking discrepancies',
    QueueFilter.pendingReview => 'Pending review',
    QueueFilter.clearances => 'Clearances',
    QueueFilter.deadlines => 'Deadlines',
    QueueFilter.corrections => 'Corrections',
  };
}

List<ActionQueueItem> buildOfficerActionQueue(
  DemoFdrPortalStore store, {
  DateTime? today,
}) {
  final items = <ActionQueueItem>[];
  for (final submission in store.dashboardSubmissions) {
    if (submission.status == SubmissionStatus.pendingReview ||
        submission.status == SubmissionStatus.blocked ||
        submission.status == SubmissionStatus.correctionRequested) {
      final blocked =
          submission.status == SubmissionStatus.blocked ||
          submission.issues.isNotEmpty;
      final deadline = calculateFdrDeadlines([submission], today: today).first;
      final hasDeadline =
          !deadline.isRenewed &&
          (deadline.status == MaturityStatus.critical ||
              deadline.status == MaturityStatus.matured);
      final categories = <String>[
        if (submission.status == SubmissionStatus.correctionRequested)
          'Corrections'
        else if (blocked)
          'Blocking discrepancies'
        else
          'Pending review',
        if (hasDeadline) 'Deadlines',
      ];
      final reasons = <String>[
        if (submission.status == SubmissionStatus.correctionRequested)
          'Correction requires review'
        else if (blocked)
          'Review blocking discrepancies'
        else
          'Awaiting officer review',
        if (hasDeadline) deadline.nextAction,
      ];
      items.add(
        ActionQueueItem(
          id: 'submission-${submission.submissionId}',
          institution: submission.institution,
          reference: submission.reference,
          status: submission.status.label,
          priority: blocked ? 'High' : 'Routine',
          reason: reasons.join('; '),
          relatedSubmissionId: submission.submissionId,
          category: categories.join(', '),
          dueDate: hasDeadline ? deadline.maturityDate : null,
        ),
      );
    }
  }
  for (final deadline in calculateFdrDeadlines(
    store.dashboardSubmissions,
    today: today,
  )) {
    if (deadline.isRenewed) continue;
    if (deadline.status == MaturityStatus.critical ||
        deadline.status == MaturityStatus.matured) {
      items.add(
        ActionQueueItem(
          id: 'deadline-${deadline.submission.submissionId}',
          institution: deadline.submission.institution,
          reference: deadline.submission.reference,
          status: deadline.status.label,
          priority: 'High',
          reason: deadline.nextAction,
          relatedSubmissionId: deadline.submission.submissionId,
          category: 'Deadlines',
          dueDate: deadline.maturityDate,
        ),
      );
    }
  }
  for (final caseRecord in store.releaseCases) {
    final pendingCells = caseRecord.clearances
        .where((item) => item.status != 'Cleared')
        .length;
    if (pendingCells > 0 && caseRecord.status != 'NOC Issued — Demo') {
      items.add(
        ActionQueueItem(
          id: 'case-${caseRecord.caseId}',
          institution: caseRecord.institution,
          reference: caseRecord.caseId,
          status: caseRecord.status,
          priority: 'High',
          reason: '$pendingCells clearance(s) require attention',
          relatedSubmissionId: caseRecord.submissionId,
          category: 'Clearances',
          relatedCaseId: caseRecord.caseId,
        ),
      );
    }
  }
  final unique = <String, ActionQueueItem>{};
  for (final item in items) {
    final key = 'submission-${item.relatedSubmissionId}';
    final existing = unique[key];
    unique[key] = existing == null
        ? item
        : ActionQueueItem(
            id: existing.id,
            institution: existing.institution,
            reference: existing.reference,
            status: existing.status,
            priority: existing.priority == 'High' || item.priority == 'High'
                ? 'High'
                : 'Routine',
            reason: '${existing.reason}; ${item.reason}',
            relatedSubmissionId: existing.relatedSubmissionId,
            category: '${existing.category}, ${item.category}',
            dueDate: existing.dueDate ?? item.dueDate,
            relatedCaseId: item.relatedCaseId ?? existing.relatedCaseId,
          );
  }
  final result = unique.values.toList();
  result.sort((left, right) {
    final priority = {'High': 0, 'Routine': 1};
    return (priority[left.priority] ?? 2).compareTo(
              priority[right.priority] ?? 2,
            ) !=
            0
        ? (priority[left.priority] ?? 2).compareTo(
            priority[right.priority] ?? 2,
          )
        : (left.dueDate ?? DateTime(9999)).compareTo(
            right.dueDate ?? DateTime(9999),
          );
  });
  return List.unmodifiable(result);
}

String buildSubmissionsCsv(Iterable<FdrSubmission> submissions) {
  String escape(String value) {
    final trimmed = value.trimLeft();
    final neutralized = trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])
        ? "'$value"
        : value;
    return '"${neutralized.replaceAll('"', '""')}"';
  }

  final rows = <String>[
    'Submission ID,Institution ID,Institution,FDR Reference,Case Type,Status,Amount,Submitted,Issues,Maturity Date',
  ];
  for (final item in submissions) {
    final record = DemoFdrPortalStore.instance.fdrRecordForSubmission(
      item.submissionId,
    );
    rows.add(
      [
        item.submissionId,
        item.institutionId,
        item.institution,
        item.reference,
        item.caseType,
        item.status.label,
        item.amount,
        item.submittedOn,
        item.issues.join('; '),
        record?.maturityDate ?? '',
      ].map(escape).join(','),
    );
  }
  return rows.join('\r\n');
}

Future<void> exportCsvReport(
  BuildContext context,
  String fileName,
  String csv,
) async {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('CSV report copied: $fileName')));
  try {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName';
    await writeCsvFile(path, csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: fileName),
    );
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'CSV report exported',
      associatedId: fileName,
      actorRole: 'Officer',
      payload: '${csv.length} bytes; ${directory.path}',
    );
  } on Object {
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export unavailable; CSV copied to clipboard.'),
        ),
      );
    }
  }
}

Future<String> writeCsvFile(String path, String csv) async {
  await XFile.fromData(
    utf8.encode(csv),
    name: path.split(RegExp(r'[/\\]')).last,
    mimeType: 'text/csv',
  ).saveTo(path);
  return path;
}

String? checksumForDocumentBytes(List<int>? bytes) =>
    bytes == null ? null : sha256.convert(bytes).toString();

String buildInstitutionsCsv(Map<String, InstitutionRiskAssessment> risks) => [
  'Institution,Risk Category,Risk Score,Reasons',
  for (final entry in risks.entries)
    [
      entry.key,
      entry.value.category,
      '${entry.value.score}',
      entry.value.reasons.join('; '),
    ].map(_csvCell).join(','),
].join('\r\n');

String buildDeadlinesCsv(Iterable<FdrDeadlineInfo> deadlines) => [
  'FDR,Institution,Bucket,Days Remaining,Maturity Date,Renewed',
  for (final item in deadlines)
    [
      item.submission.reference,
      item.submission.institution,
      item.status.label,
      '${item.daysRemaining ?? ''}',
      item.maturityDate?.toIso8601String() ?? '',
      '${item.isRenewed}',
    ].map(_csvCell).join(','),
].join('\r\n');

String buildAuditCsv(Iterable<AuditEntry> entries) => [
  'Event ID,Timestamp,Actor,Action,Associated ID,Payload,Previous Hash,Entry Hash',
  for (final entry in entries)
    [
      entry.eventId,
      entry.timestamp,
      entry.actorRole,
      entry.action,
      entry.associatedId,
      entry.payload,
      entry.previousHash,
      entry.entryHash,
    ].map(_csvCell).join(','),
].join('\r\n');

String buildDiscrepanciesCsv(Iterable<FdrSubmission> submissions) => [
  'Submission ID,Institution,FDR,Issue',
  for (final submission in submissions)
    for (final issue in submission.issues)
      [
        submission.submissionId,
        submission.institution,
        submission.reference,
        issue,
      ].map(_csvCell).join(','),
].join('\r\n');

String _csvCell(String value) {
  final trimmed = value.trimLeft();
  final safe = trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])
      ? "'$value"
      : value;
  return '"${safe.replaceAll('"', '""')}"';
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
    this.history = const [],
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
  final List<CaseHistoryEvent> history;
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
    List<CaseHistoryEvent>? history,
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
    history: history ?? this.history,
  );
}

enum CaseStatus {
  draft,
  submitted,
  underReview,
  clarificationRequested,
  clearancePending,
  readyForNoc,
  nocIssued,
  rejected,
  closed,
  approved,
}

CaseStatus _caseStatusFromLabel(String label) => switch (label) {
  'Draft' => CaseStatus.draft,
  'Submitted' || 'Pending Review' => CaseStatus.submitted,
  'Under Review' ||
  'Awaiting Clearances' ||
  'Blocked — FDR Verification' => CaseStatus.underReview,
  'Clarification Requested' => CaseStatus.clarificationRequested,
  'Clearance Pending' ||
  'Awaiting Required Documents' => CaseStatus.clearancePending,
  'Ready for Final NOC' => CaseStatus.readyForNoc,
  'NOC Issued — Demo' => CaseStatus.nocIssued,
  'Rejected' || 'Returned for Correction' => CaseStatus.rejected,
  'Closed' => CaseStatus.closed,
  'Approved' ||
  'FDR Approved — Demo' ||
  'Partial Release Approved — Demo' ||
  'Merger Approved — Demo' => CaseStatus.approved,
  _ => CaseStatus.underReview,
};

String _caseStatusLabel(CaseStatus status) => switch (status) {
  CaseStatus.draft => 'Draft',
  CaseStatus.submitted => 'Submitted',
  CaseStatus.underReview => 'Under Review',
  CaseStatus.clarificationRequested => 'Clarification Requested',
  CaseStatus.clearancePending => 'Clearance Pending',
  CaseStatus.readyForNoc => 'Ready for Final NOC',
  CaseStatus.nocIssued => 'NOC Issued — Demo',
  CaseStatus.rejected => 'Rejected',
  CaseStatus.closed => 'Closed',
  CaseStatus.approved => 'Approved',
};

// ignore: constant_identifier_names
const Map<CaseStatus, Set<CaseStatus>> ALLOWED_TRANSITIONS = {
  CaseStatus.draft: {CaseStatus.submitted, CaseStatus.rejected},
  CaseStatus.submitted: {
    CaseStatus.underReview,
    CaseStatus.clearancePending,
    CaseStatus.clarificationRequested,
    CaseStatus.approved,
    CaseStatus.rejected,
  },
  CaseStatus.underReview: {
    CaseStatus.clarificationRequested,
    CaseStatus.clearancePending,
    CaseStatus.approved,
    CaseStatus.rejected,
  },
  CaseStatus.clarificationRequested: {
    CaseStatus.underReview,
    CaseStatus.rejected,
  },
  CaseStatus.clearancePending: {
    CaseStatus.readyForNoc,
    CaseStatus.clarificationRequested,
    CaseStatus.rejected,
  },
  CaseStatus.readyForNoc: {
    CaseStatus.nocIssued,
    CaseStatus.approved,
    CaseStatus.rejected,
  },
  CaseStatus.nocIssued: {CaseStatus.approved, CaseStatus.closed},
  CaseStatus.approved: {CaseStatus.closed},
  CaseStatus.rejected: {CaseStatus.submitted, CaseStatus.closed},
  CaseStatus.closed: <CaseStatus>{},
};

void validateCaseTransition(CaseStatus from, CaseStatus to) {
  if (!(ALLOWED_TRANSITIONS[from] ?? const {}).contains(to)) {
    throw InvalidTransitionException(
      'Cannot transition ${_caseStatusLabel(from)} to ${_caseStatusLabel(to)}.',
    );
  }
}

class InvalidTransitionException implements Exception {
  InvalidTransitionException(this.message);

  final String message;

  @override
  String toString() => 'InvalidTransitionException: $message';
}

class CaseHistoryEvent {
  const CaseHistoryEvent({
    required this.action,
    required this.actor,
    required this.at,
    required this.remark,
    this.fromStatus,
    this.toStatus,
  });

  final String action;
  final String actor;
  final DateTime at;
  final String remark;
  final String? fromStatus;
  final String? toStatus;
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
    this.remarkHistory = const [],
    this.response,
    this.responseTimestamp,
  });

  final String name;
  final String status;
  final String remark;
  final String actionRequired;
  final String? lastUpdated;
  final List<ClearanceRemark> remarkHistory;
  final String? response;
  final String? responseTimestamp;

  ClearanceState copyWith({
    String? name,
    String? status,
    String? remark,
    String? actionRequired,
    String? lastUpdated,
    List<ClearanceRemark>? remarkHistory,
    String? response,
    String? responseTimestamp,
  }) => ClearanceState(
    name: name ?? this.name,
    status: status ?? this.status,
    remark: remark ?? this.remark,
    actionRequired: actionRequired ?? this.actionRequired,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    remarkHistory: remarkHistory ?? this.remarkHistory,
    response: response ?? this.response,
    responseTimestamp: responseTimestamp ?? this.responseTimestamp,
  );
}

class ClearanceRemark {
  const ClearanceRemark({
    required this.text,
    required this.timestamp,
    required this.officerId,
    this.officerName = '',
  });

  final String text;
  final String timestamp;
  final String officerId;
  final String officerName;
}

class OfficerClarification {
  const OfficerClarification({
    required this.submissionId,
    this.caseId,
    required this.institutionId,
    required this.institutionName,
    required this.officerId,
    required this.officerName,
    required this.reviewSection,
    required this.remark,
    required this.timestamp,
    required this.status,
    this.requiredDocument,
    this.response,
    this.documentStatus,
    this.responseTimestamp,
  });

  final String submissionId;
  final String? caseId;
  final String institutionId;
  final String institutionName;
  final String officerId;
  final String officerName;
  final String reviewSection;
  final String remark;
  final String? requiredDocument;
  final DateTime timestamp;
  final String status;
  final String? response;
  final String? documentStatus;
  final DateTime? responseTimestamp;

  OfficerClarification copyWith({
    String? response,
    String? documentStatus,
    DateTime? responseTimestamp,
    String? status,
  }) => OfficerClarification(
    submissionId: submissionId,
    caseId: caseId,
    institutionId: institutionId,
    institutionName: institutionName,
    officerId: officerId,
    officerName: officerName,
    reviewSection: reviewSection,
    remark: remark,
    requiredDocument: requiredDocument,
    timestamp: timestamp,
    status: status ?? this.status,
    response: response ?? this.response,
    documentStatus: documentStatus ?? this.documentStatus,
    responseTimestamp: responseTimestamp ?? this.responseTimestamp,
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

Map<String, dynamic> _auditToJson(AuditEntry entry) => {
  'eventId': entry.eventId,
  'timestamp': entry.timestamp,
  'actorRole': entry.actorRole,
  'action': entry.action,
  'associatedId': entry.associatedId,
  'payload': entry.payload,
  'previousHash': entry.previousHash,
  'entryHash': entry.entryHash,
};

AuditEntry _auditFromJson(Map<String, dynamic> json) => AuditEntry(
  eventId: json['eventId'] as String,
  timestamp: json['timestamp'] as String,
  actorRole: json['actorRole'] as String,
  action: json['action'] as String,
  associatedId: json['associatedId'] as String,
  payload: json['payload'] as String? ?? '',
  previousHash: json['previousHash'] as String,
  entryHash: json['entryHash'] as String,
);

class AuditIntegrityResult {
  const AuditIntegrityResult({
    required this.isValid,
    required this.invalidEntryId,
    required this.message,
    this.invalidIndex,
    this.reason,
  });

  final bool isValid;
  final String? invalidEntryId;
  final String message;
  final int? invalidIndex;
  final String? reason;
}

class AuditChainAnchor {
  const AuditChainAnchor({
    required this.latestIndex,
    required this.latestHash,
    required this.count,
  });

  final int latestIndex;
  final String latestHash;
  final int count;
}

AuditIntegrityResult verifyAuditChain(
  Iterable<AuditEntry> entries, {
  AuditChainAnchor? anchor,
}) {
  String previousHash = 'GENESIS';
  final records = entries.toList(growable: false);
  for (var index = 0; index < records.length; index++) {
    final entry = records[index];
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
        invalidIndex: index,
        reason: entry.previousHash != previousHash
            ? 'broken previous-hash link'
            : 'hash mismatch',
        message:
            'Tampering detected at audit entry ${entry.eventId}. The stored hash does not match the recalculated hash.',
      );
    }
    previousHash = expectedHash;
  }
  if (anchor != null &&
      (records.length != anchor.count ||
          (records.isNotEmpty &&
              (anchor.latestIndex != records.length - 1 ||
                  anchor.latestHash != records.last.entryHash)))) {
    return AuditIntegrityResult(
      isValid: false,
      invalidEntryId: records.isEmpty ? null : records.last.eventId,
      invalidIndex: records.length,
      reason: records.length < anchor.count ? 'truncation' : 'anchor mismatch',
      message: 'Audit chain does not match its persisted anchor.',
    );
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

  static VerificationSummary runVerification(
    FdrRecord record, {
    Clock clock = const SystemClock(),
    Iterable<RuleConfig>? rules,
  }) {
    final now = clock.now();
    final configuredRules = {
      for (final rule in rules ?? defaultRuleConfigs()) rule.id: rule,
    };
    bool enabled(String id) => configuredRules[id]?.enabled ?? true;
    VerificationIssueSeverity severityFor(
      String id,
      VerificationIssueSeverity fallback,
    ) {
      final configured = configuredRules[id];
      if (configured?.severity == RuleSeverity.off) {
        return VerificationIssueSeverity.passed;
      }
      return switch (configured?.severity) {
        RuleSeverity.blocking => VerificationIssueSeverity.blocking,
        RuleSeverity.warning => VerificationIssueSeverity.warning,
        _ => fallback,
      };
    }

    final issues = <VerificationIssue>[];
    final comparisonMatrix = _comparisonMatrix(record);

    final amountDifference =
        (record.declaredDepositAmount - record.receiptAmount).abs();
    if (enabled('deposit-amount') &&
        (record.declaredDepositAmount - record.receiptAmount).abs() >
            (configuredRules['deposit-amount']?.params['tolerance'] ?? 0)) {
      issues.add(
        VerificationIssue(
          ruleId: 'deposit-amount',
          severity: severityFor(
            'deposit-amount',
            VerificationIssueSeverity.blocking,
          ),
          message:
              'Declared deposit amount does not match the receipt amount. Difference: ₹${_formatCurrency(amountDifference)}.',
          description:
              'The institution-declared deposit amount differs from the receipt amount recorded for the FDR.',
          recommendedAction:
              'Review the declared and receipt values side-by-side and correct the disputed amount before release approval.',
          affectedField: 'declaredDepositAmount',
          sourceValues: {
            'declared': '${record.declaredDepositAmount}',
            'receipt': '${record.receiptAmount}',
          },
          detectedAt: now,
        ),
      );
    }

    if (enabled('lien-information') &&
        (record.lienInformation.trim().isEmpty ||
            record.lienInformation.toLowerCase() == 'not provided')) {
      issues.add(
        VerificationIssue(
          ruleId: 'lien-information',
          severity: severityFor(
            'lien-information',
            VerificationIssueSeverity.warning,
          ),
          message: 'Lien information requires review.',
          description:
              'Lien information is missing or marked as not provided for this FDR.',
          recommendedAction:
              'Confirm whether a lien exists and update the record before final approval.',
          affectedField: 'lienInformation',
          detectedAt: now,
        ),
      );
    }

    final duplicateRecord = _duplicateRegistry[record.fdrNumber];
    if (enabled('duplicate-fdr') &&
        duplicateRecord != null &&
        duplicateRecord.institution != record.institution) {
      issues.add(
        VerificationIssue(
          ruleId: 'duplicate-fdr',
          severity: severityFor(
            'duplicate-fdr',
            VerificationIssueSeverity.blocking,
          ),
          message:
              'This FDR number already belongs to ${duplicateRecord.institution} under record ${duplicateRecord.fdrReference}.',
          description:
              'The FDR reference clashes with a different institution in the sample records.',
          recommendedAction:
              'Correct the FDR reference to a unique value or resolve the duplicate record before release approval.',
          affectedField: 'fdrNumber',
          sourceValues: {'existingInstitution': duplicateRecord.institution},
          detectedAt: now,
        ),
      );
    }

    final issueDate = _parsePortalDate(record.issueDate);
    final maturityDate = _parsePortalDate(record.maturityDate);
    if (issueDate == null || maturityDate == null) {
      if (enabled('date-consistency')) {
        issues.add(
          VerificationIssue(
            ruleId: 'date-consistency',
            severity: VerificationIssueSeverity.warning,
            message: 'Issue and maturity dates are incomplete or inconsistent.',
            description:
                'The maturity date must be present and after the issue date.',
            recommendedAction: 'Correct the issue and maturity dates.',
            affectedField: 'maturityDate',
            detectedAt: now,
          ),
        );
      }
    } else if (enabled('date-consistency') &&
        !maturityDate.isAfter(issueDate)) {
      issues.add(
        VerificationIssue(
          ruleId: 'date-consistency',
          severity: severityFor(
            'date-consistency',
            VerificationIssueSeverity.blocking,
          ),
          message: 'Issue and maturity dates are incomplete or inconsistent.',
          description: 'The maturity date must be after the issue date.',
          recommendedAction: 'Correct the issue and maturity dates.',
          affectedField: 'maturityDate',
          detectedAt: now,
        ),
      );
    } else {
      final months =
          (maturityDate.year - issueDate.year) * 12 +
          maturityDate.month -
          issueDate.month -
          (maturityDate.day < issueDate.day ? 1 : 0);
      if (enabled('tenure-consistency') &&
          record.declaredTenureMonths > 0 &&
          (record.declaredTenureMonths - months).abs() >
              (configuredRules['tenure-consistency']
                      ?.params['toleranceMonths'] ??
                  0)) {
        issues.add(
          VerificationIssue(
            ruleId: 'tenure-consistency',
            severity: severityFor(
              'tenure-consistency',
              VerificationIssueSeverity.blocking,
            ),
            message:
                'Declared tenure does not match the issue and maturity dates.',
            recommendedAction: 'Correct the declared tenure or maturity date.',
            affectedField: 'declaredTenureMonths',
            sourceValues: {
              'declared': '${record.declaredTenureMonths}',
              'calculated': '$months',
            },
            detectedAt: now,
          ),
        );
      }
      if (enabled('maturity-warning') &&
          maturityDate.isBefore(now) &&
          record.parentFdrReference == null) {
        issues.add(
          VerificationIssue(
            ruleId: 'matured-without-renewal',
            severity: VerificationIssueSeverity.warning,
            message:
                'This FDR is matured and has no recorded renewal relationship.',
            recommendedAction:
                'Record a renewal or open the appropriate release case.',
            affectedField: 'parentFdrReference',
            detectedAt: now,
          ),
        );
      }
    }
    if (enabled('institution-name-mismatch') &&
        record.institutionNameOnDocuments != null &&
        record.institutionNameOnDocuments!.trim().isNotEmpty &&
        record.institutionNameOnDocuments!.trim().toLowerCase() !=
            record.institution.trim().toLowerCase()) {
      issues.add(
        VerificationIssue(
          ruleId: 'institution-name-mismatch',
          severity: severityFor(
            'institution-name-mismatch',
            VerificationIssueSeverity.blocking,
          ),
          message:
              'The institution name in supporting data does not match the registry.',
          recommendedAction:
              'Correct the institution name or supporting document.',
          affectedField: 'institutionNameOnDocuments',
          sourceValues: {
            'registry': record.institution,
            'document': record.institutionNameOnDocuments!,
          },
          detectedAt: now,
        ),
      );
    }

    final institutionValues = comparisonMatrix
        .where((item) => item.field == 'institutionName')
        .firstOrNull;
    final institutionThreshold =
        configuredRules['institution-name-mismatch']?.params['threshold'] ??
        0.8;
    final institutionNames = institutionValues?.values.values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    if (enabled('institution-name-mismatch') &&
        record.sourceValues.isNotEmpty &&
        institutionNames != null &&
        institutionNames.any(
          (name) =>
              _similarity(record.institution, name) < institutionThreshold,
        ) &&
        !issues.any((issue) => issue.ruleId == 'institution-name-mismatch')) {
      issues.add(
        VerificationIssue(
          ruleId: 'institution-name-mismatch',
          severity: severityFor(
            'institution-name-mismatch',
            VerificationIssueSeverity.blocking,
          ),
          message: 'The institution name differs across supporting sources.',
          recommendedAction:
              'Correct the institution name or supporting document.',
          affectedField: 'institutionName',
          sourceValues: {
            for (final entry in institutionValues!.values.entries)
              entry.key.name: entry.value ?? '',
          },
          detectedAt: now,
        ),
      );
    }

    final trustValues = record.sourceValues.isEmpty
        ? null
        : comparisonMatrix
              .where((item) => item.field == 'trustName')
              .firstOrNull;
    final trustThreshold =
        configuredRules['trust-name-mismatch']?.params['threshold'] ?? 0.8;
    final trustNames = trustValues?.values.values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    if (enabled('trust-name-mismatch') &&
        trustNames != null &&
        trustNames.length > 1 &&
        trustNames
            .skip(1)
            .any(
              (name) => _similarity(trustNames.first, name) < trustThreshold,
            )) {
      issues.add(
        VerificationIssue(
          ruleId: 'trust-name-mismatch',
          severity: severityFor(
            'trust-name-mismatch',
            VerificationIssueSeverity.blocking,
          ),
          message: 'The trust name differs across supporting sources.',
          recommendedAction: 'Correct the trust name or supporting document.',
          affectedField: 'trustName',
          sourceValues: {
            for (final entry in trustValues!.values.entries)
              entry.key.name: entry.value ?? '',
          },
          detectedAt: now,
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
      comparisonMatrix: comparisonMatrix,
    );

    return summary;
  }

  static List<FieldComparison> _comparisonMatrix(FdrRecord record) {
    final values = record.sourceValues.isEmpty
        ? <DocumentSource, Map<String, String?>>{
            DocumentSource.fdrMaster: {
              'institutionName': record.institution,
              'trustName': record.institution,
              'fdrNumber': record.fdrNumber,
              'bank': record.bank,
              'depositAmount': '${record.declaredDepositAmount}',
              'issueDate': record.issueDate,
              'maturityDate': record.maturityDate,
              'tenureMonths': '${record.declaredTenureMonths}',
              'lienInfo': record.lienInformation,
            },
            DocumentSource.receipt: {
              'institutionName':
                  record.institutionNameOnDocuments ?? record.institution,
              'trustName':
                  record.institutionNameOnDocuments ?? record.institution,
              'fdrNumber': record.fdrNumber,
              'bank': record.bank,
              'depositAmount': '${record.receiptAmount}',
              'issueDate': record.issueDate,
              'maturityDate': record.maturityDate,
              'tenureMonths': '${record.enteredTenureMonths}',
              'lienInfo': record.lienInformation,
            },
            DocumentSource.requestLetter: {},
            DocumentSource.affidavit: {},
          }
        : record.sourceValues;
    const fields = [
      'institutionName',
      'trustName',
      'fdrNumber',
      'bank',
      'depositAmount',
      'issueDate',
      'maturityDate',
      'tenureMonths',
      'lienInfo',
    ];
    return [for (final field in fields) _compareField(field, values)];
  }

  static FieldComparison _compareField(
    String field,
    Map<DocumentSource, Map<String, String?>> values,
  ) {
    final row = <DocumentSource, String?>{
      for (final source in DocumentSource.values)
        source: values[source]?[field],
    };
    final present = row.values
        .where((value) => value?.trim().isNotEmpty ?? false)
        .toSet();
    final differingSources = <DocumentSource>{};
    if (present.length > 1) {
      final first = present.first;
      for (final entry in row.entries) {
        if (entry.value != null &&
            entry.value!.trim().isNotEmpty &&
            entry.value != first) {
          differingSources.add(entry.key);
        }
      }
    }
    return FieldComparison(
      field: field,
      values: row,
      status: present.isEmpty
          ? ComparisonStatus.missing
          : present.length > 1
          ? ComparisonStatus.partialMismatch
          : row.values.any((value) => value == null || value.trim().isEmpty)
          ? ComparisonStatus.missing
          : ComparisonStatus.allMatch,
      differingSources: differingSources,
    );
  }

  static String _normalizedName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\b(trust|society|educational|education)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _similarity(String left, String right) {
    final a = _normalizedName(left);
    final b = _normalizedName(right);
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = List<int>.generate(b.length + 1, (index) => index);
    for (var row = 1; row <= a.length; row++) {
      var diagonal = distance[0];
      distance[0] = row;
      for (var column = 1; column <= b.length; column++) {
        final above = distance[column];
        distance[column] = a[row - 1] == b[column - 1]
            ? diagonal
            : 1 +
                  [
                    above,
                    distance[column - 1],
                    diagonal,
                  ].reduce((x, y) => x < y ? x : y);
        diagonal = above;
      }
    }
    final longestLength = a.length > b.length ? a.length : b.length;
    return 1 - distance[b.length] / longestLength;
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 14),
          if (record.isDeliberateInvalidDate)
            const _InlineNotice(
              message: 'Deliberately invalid-date example',
              color: Color(0xFFFFF7ED),
              textColor: Color(0xFF9A3412),
              icon: Icons.event_busy_outlined,
            ),
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
          if (store.renewalLineage(record.fdrNumber).length > 1 ||
              record.parentFdrReference != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const _RenewalLineagePage(),
                ),
              ),
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(
                record.parentFdrReference == null
                    ? 'View renewal lineage'
                    : 'Renewed from ${record.parentFdrReference}',
              ),
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
                    'No documents available.',
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
  Future<void> _runVerification() async {
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = DemoFdrPortalStore.instance;
    final summary = store.verificationResults;
    final record = store.currentSubmission;
    final releaseCase = store.releaseCase!;
    final isBlocked = !store.verificationCurrent || summary.blocking > 0;

    return OfficerPortalShell(
      title: 'Verification Results',
      body: ListView(
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
                InteractiveViewer(
                  minScale: 0.75,
                  maxScale: 1.5,
                  child: SizedBox(
                    width: 940,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowColor: WidgetStatePropertyAll(
                        const Color(0xFFFFF7ED),
                      ),
                      columns: const [
                        DataColumn(
                          label: SizedBox(width: 110, child: Text('Field')),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 110,
                            child: Text('FDR master'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(width: 110, child: Text('Receipt')),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 110,
                            child: Text('Request letter'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(width: 110, child: Text('Affidavit')),
                        ),
                        DataColumn(
                          label: SizedBox(width: 110, child: Text('Result')),
                        ),
                      ],
                      rows: [
                        for (final comparison in summary.comparisonMatrix)
                          DataRow(
                            cells: [
                              DataCell(Text(comparison.field)),
                              for (final source in DocumentSource.values)
                                DataCell(
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 110,
                                    ),
                                    color:
                                        comparison.differingSources.contains(
                                          source,
                                        )
                                        ? const Color(0xFFFFE4E6)
                                        : null,
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      comparison.values[source] ?? 'Missing',
                                    ),
                                  ),
                                ),
                              DataCell(
                                Text(
                                  comparison.status == ComparisonStatus.allMatch
                                      ? 'Match'
                                      : comparison.status ==
                                            ComparisonStatus.missing
                                      ? 'Missing'
                                      : 'Mismatch',
                                  style: TextStyle(
                                    color:
                                        comparison.status ==
                                            ComparisonStatus.allMatch
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Actions',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: !store.verificationCurrent
                      ? 'Correct Details'
                      : isBlocked
                      ? 'Open Blocked Release Case'
                      : 'Open Release / Refund Case',
                  variant: AppButtonVariant.primary,
                  icon: Icons.checklist_rounded,
                  onPressed: () {
                    if (!store.verificationCurrent) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _CorrectDetailsPage(),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _ReleaseCasePage(),
                        ),
                      );
                    }
                  },
                ),
                if (isBlocked) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Correct Details',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.edit_note_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _CorrectDetailsPage(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    AppButton(
                      label: 'Run Verification',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.play_arrow_rounded,
                      onPressed: _runVerification,
                    ),
                    AppButton(
                      label: 'Re-run Verification',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        final verificationSummary = store
                            .runCurrentVerification();
                        store.appendAuditEntry(
                          action: 'Verification rerun',
                          associatedId: store.currentSubmission.submissionId,
                          actorRole: 'Officer',
                          payload: verificationSummary.statusText,
                        );
                        setState(() {});
                      },
                    ),
                    AppButton(
                      label: 'View Audit Trail',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.history_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _AuditTrailPage(),
                        ),
                      ),
                    ),
                    AppButton(
                      label: 'Open Release / Refund Case',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.fact_check_rounded,
                      enabled: !isBlocked,
                      onPressed: !isBlocked
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const _ReleaseCasePage(),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Return to Institution for Correction',
                  variant: AppButtonVariant.destructive,
                  icon: Icons.assignment_return_outlined,
                  onPressed: () {
                    final submission = store.submissionById(
                      record.submissionId,
                    );
                    if (submission == null) return;
                    store.rejectSubmission(
                      record.submissionId,
                      reason: summary.issues
                          .map((issue) => issue.message)
                          .join('; '),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
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

    final current = DemoFdrPortalStore.instance.currentSubmission;
    final correctedRecord = DemoFdrPortalStore.instance.currentSubmission
        .copyWith(
          fdrNumber: _fdrNumberController.text.trim(),
          declaredDepositAmount: int.parse(_amountController.text.trim()),
          receiptAmount: current.receiptAmount,
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
      body: Form(
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
          'This records the outcome without issuing an NOC or releasing funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm action'),
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
        title: const Text('Approve FDR submission?'),
        content: const Text(
          'This records an approved status. It does not transfer funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm action'),
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
          'Record a decision for ₹${_formatCurrency(current.requestedReleaseAmount)} and retain ₹${_formatCurrency(current.retainedBalance)}. No funds will be transferred and this is not an official approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_eligibility().canAdvance) return;
    _store.approveProgressiveClosureInDemoMode();
    _store.appendAuditEntry(
      action: 'Progressive closure approved',
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
          'Record a relationship from ${current.institution} (${current.originalInstitutionId}) to ${current.successorInstitution} (${current.successorInstitutionId}). This has no legal or official effect and does not transfer or modify the original FDR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_eligibility().canAdvance) return;
    _store.approveMergerInDemoMode();
    _store.appendAuditEntry(
      action: 'Merger case approved',
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
          '${document.type}\n${document.fileName}\n\nChecklist presence only. No file is stored or validated.',
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
    final verificationBlocked =
        !_store.verificationCurrent ||
        _store.verificationForEligibility.blocking > 0;
    final nocIssued = record.status == 'NOC Issued — Demo';
    final caseApproved = record.status.endsWith('Approved — Demo');
    final fdrApproved =
        _store.submissionById(record.submissionId)?.status ==
        VerificationStatus.approved;
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
      body: LayoutBuilder(
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
                        value: '₹${_formatCurrency(record.originalFdrAmount)}',
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
                        value: '₹${_formatCurrency(record.originalFdrAmount)}',
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
                          value: '₹${_formatCurrency(record.availableBalance)}',
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
                            final changed = value != _case.partialReleaseReason;
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
                        value: '₹${_formatCurrency(record.originalFdrAmount)}',
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
                if (record.history.isNotEmpty)
                  _ReleaseSection(
                    title: 'Case History',
                    child: Column(
                      children: [
                        for (final event in record.history)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.timeline_rounded,
                              color: _orange,
                            ),
                            title: Text(event.action),
                            subtitle: Text(
                              '${event.actor} · ${event.at.toLocal()}\n${event.remark}',
                            ),
                          ),
                      ],
                    ),
                  ),
                if (record.history.isNotEmpty) const SizedBox(height: 12),
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
                              'Missing required documents must be marked present before this case can advance.',
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
                        'Recorded decision only. No real funds were transferred.',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                    if (isMerger && caseApproved) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Relationship recorded: ${record.institution} (${record.originalInstitutionId}) → ${record.successorInstitution} (${record.successorInstitutionId})',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Original FDR ${record.originalFdrReference} remains preserved. This recorded relationship has no legal or official effect.',
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
                    if (isNormalRelease) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              !fdrApproved &&
                                  _store.canApproveFdrSubmissionInDemoMode()
                              ? _simulateFdrApproval
                              : null,
                          icon: const Icon(Icons.verified_rounded),
                          label: Text(
                            fdrApproved
                                ? 'FDR Approved'
                                : 'Approve FDR Submission',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (fdrApproved)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _officerSelectedTab.value = 0;
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Back to Home'),
                          ),
                        ),
                    ],
                    if (!fdrApproved)
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
                                ? 'NOC Issued'
                                : caseApproved
                                ? _cleanPortalLabel(record.status)
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
                      'No fund transfer is performed by this action.',
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
                  'Audit records are maintained locally.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
                ),
              ),
            ],
          );
        },
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
  Widget build(BuildContext context) => const SizedBox.shrink();
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
                _cleanPortalLabel(document.status),
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
        if (clearance.status != 'Cleared')
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
        _cleanPortalLabel(status),
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
              widget.cellName,
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
    final store = DemoFdrPortalStore.instance;
    return store.auditIntegrity ?? verifyAuditChain(store.auditEntries);
  }

  Future<void> _tamperStoredRecord() async {
    await DemoFdrPortalStore.instance.tamperPersistedAuditRecord();
    final result = _verifyChain();
    setState(() => _verificationMessage = result.message);
  }

  Future<void> _restoreBackup() async {
    await DemoFdrPortalStore.instance.restoreAuditBackup();
    final result = _verifyChain();
    setState(() => _verificationMessage = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final entries = DemoFdrPortalStore.instance.auditEntries;
    final integrity = _verifyChain();
    final claims = portalAuthService.currentClaims;
    if (claims != null && claims.role != AuthRole.officer) {
      return OfficerPortalShell(
        title: 'Audit Trail',
        body: const Center(
          child: Text('Audit Trail is available to officers only.'),
        ),
      );
    }

    return OfficerPortalShell(
      title: 'Audit Trail',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          const _DemoNotice(),
          const SizedBox(height: 12),
          if (!integrity.isValid)
            const _InlineNotice(
              message:
                  'Audit integrity is broken. Review the first invalid index and reason below.',
              color: Color(0xFFFEE2E2),
              textColor: Color(0xFF991B1B),
              icon: Icons.warning_amber_rounded,
            ),
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
                if (!integrity.isValid)
                  Text(
                    'First invalid index: ${integrity.invalidIndex ?? 'unknown'} · ${integrity.reason ?? 'unknown reason'}',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final result = _verifyChain();
                          setState(() => _verificationMessage = result.message);
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Verify Integrity'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _tamperStoredRecord,
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: const Text('Tamper stored record'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _restoreBackup,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore from backup'),
                  style: OutlinedButton.styleFrom(foregroundColor: _deepOrange),
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
                    'Actor: ${_cleanPortalLabel(entry.actorRole)}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  Text(
                    'Action: ${_cleanPortalLabel(entry.action)}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Associated: ${_cleanPortalLabel(entry.associatedId)}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  if (entry.payload.isNotEmpty)
                    Text(
                      'Detail: ${_cleanPortalLabel(entry.payload)}',
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
                    _cleanPortalLabel(row.value),
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
        _cleanPortalLabel(document.status),
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
            _cleanPortalLabel(value),
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

String _cleanPortalLabel(String value) => value
    .replaceAll('INST-DEMO-', 'INST-')
    .replaceAll(RegExp(r'\b(demo|live|mock)\b', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*[-—–]\s*([,.;])'), r'$1')
    .replaceAll(RegExp(r'\s*[-—–]\s*$'), '')
    .trim();

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
