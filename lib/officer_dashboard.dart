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

enum VerificationStatus { pending, approved, rejected }

class FdrSubmission {
  const FdrSubmission({
    required this.institution,
    required this.submissionId,
    required this.submittedOn,
    required this.reference,
    required this.amount,
    required this.status,
  });

  final String institution;
  final String submissionId;
  final String submittedOn;
  final String reference;
  final String amount;
  final VerificationStatus status;
}

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
  final VerificationStatus status;
}

abstract interface class OfficerDashboardRepository {
  List<FdrSubmission> get pendingSubmissions;
  List<OfficerActivity> get recentActivity;
  Map<String, int> get summary;
}

class MockOfficerDashboardRepository implements OfficerDashboardRepository {
  const MockOfficerDashboardRepository();

  @override
  List<FdrSubmission> get pendingSubmissions => const [
    FdrSubmission(
      institution: 'Example Institute of Technology',
      submissionId: 'FDR-2026-00124',
      submittedOn: '24 Oct 2026',
      reference: 'FDR-EX-884201',
      amount: '₹5,00,000',
      status: VerificationStatus.pending,
    ),
    FdrSubmission(
      institution: 'National College of Engineering',
      submissionId: 'FDR-2026-00125',
      submittedOn: '23 Oct 2026',
      reference: 'FDR-NC-550318',
      amount: '₹3,00,000',
      status: VerificationStatus.pending,
    ),
    FdrSubmission(
      institution: 'Metropolitan Institute of Science',
      submissionId: 'FDR-2026-00126',
      submittedOn: '22 Oct 2026',
      reference: 'FDR-MI-719643',
      amount: '₹7,50,000',
      status: VerificationStatus.pending,
    ),
  ];

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
  Map<String, int> get summary => const {
    'Pending Review': 12,
    'Approved': 48,
    'Rejected': 3,
    'Total Institutions': 63,
  };
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
        builder: (_) => _DestinationPage(title: title, subtitle: subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedTab == 0;
    final title = _destinations[_selectedTab];
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        surfaceTintColor: _paper,
        titleSpacing: 12,
        title: Row(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _openPage(
              'Notifications',
              subtitle: 'No live notification service is connected in demo mode.',
            ),
            icon: const _NotificationIcon(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Officer profile',
            onSelected: (value) {
              if (value == 'profile') {
                setState(() => _selectedTab = 3);
              } else {
                widget.onSignOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile settings')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 14, left: 4),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFFFE8D5),
                child: Text(
                  _initials(widget.userId),
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
      body: isHome
          ? _DashboardHome(
              repository: widget.repository,
              onOpenPage: _openPage,
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Submissions'),
          NavigationDestination(icon: Icon(Icons.domain_outlined), selectedIcon: Icon(Icons.domain_rounded), label: 'Institutions'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({required this.repository, required this.onOpenPage});

  final OfficerDashboardRepository repository;
  final void Function(String, {String? subtitle}) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(
      DateTime.now(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 700 ? 28.0 : 18.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome back, Officer', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: _ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Review submissions and manage institutional security deposits.', style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 13, color: _muted),
                      const SizedBox(width: 6),
                      Text(dateLabel, style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _DemoNotice(),
                  const SizedBox(height: 18),
                  _SectionHeading(title: 'Overview', trailing: 'Sample data'),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, gridConstraints) => GridView.count(
                      crossAxisCount: gridConstraints.maxWidth < 380 ? 1 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: gridConstraints.maxWidth < 380 ? 3.0 : 1.72,
                      children: [
                        _MetricCard(label: 'Pending Review', value: repository.summary['Pending Review']!, note: 'Awaiting verification', icon: Icons.schedule_rounded, color: const Color(0xFFD97706), onTap: () => onOpenPage('Pending Review', subtitle: 'Sample submissions awaiting officer verification.')),
                        _MetricCard(label: 'Approved', value: repository.summary['Approved']!, note: 'Successfully verified', icon: Icons.verified_rounded, color: const Color(0xFF16A34A), onTap: () => onOpenPage('Approved Submissions', subtitle: 'Mock approved entries. No real FDR records are connected.')),
                        _MetricCard(label: 'Rejected', value: repository.summary['Rejected']!, note: 'Requires correction', icon: Icons.cancel_outlined, color: const Color(0xFFDC2626), onTap: () => onOpenPage('Returned for Correction', subtitle: 'Mock records requiring institution updates.')),
                        _MetricCard(label: 'Total Institutions', value: repository.summary['Total Institutions']!, note: 'Registered institutions', icon: Icons.account_balance_outlined, color: _orange, onTap: () => onOpenPage('Institution Registry', subtitle: 'Sample registry view. Live institution data is not connected.')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionHeading(title: 'Quick Actions'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _QuickAction(icon: Icons.fact_check_outlined, label: 'Review Submissions', onTap: () => onOpenPage('Submissions', subtitle: 'Submission queue placeholder for the demo.'))),
                      const SizedBox(width: 9),
                      Expanded(child: _QuickAction(icon: Icons.domain_outlined, label: 'Institution Registry', onTap: () => onOpenPage('Institution Registry', subtitle: 'Registered institution list placeholder.'))),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _QuickAction(icon: Icons.analytics_outlined, label: 'Reports', onTap: () => onOpenPage('Reports', subtitle: 'Deposit verification and approval reports will appear here.')),
                  const SizedBox(height: 21),
                  _SectionHeading(
                    title: 'Pending Verification',
                    actionLabel: 'View all',
                    onAction: () => onOpenPage('Pending Verification', subtitle: 'All sample submissions awaiting review.'),
                  ),
                  const SizedBox(height: 3),
                  const Text('Latest institution submissions awaiting review.', style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  for (final submission in repository.pendingSubmissions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _SubmissionCard(
                        submission: submission,
                        onReview: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _FdrVerificationDetailPage(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _SectionHeading(title: 'Recent Activity', trailing: 'Mock activity'),
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
            style: TextStyle(color: Color(0xFF8A4315), fontSize: 11, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing, this.actionLabel, this.onAction});

  final String title;
  final String? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700))),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(minimumSize: const Size(48, 40), padding: const EdgeInsets.symmetric(horizontal: 7)),
          child: Text(actionLabel!, style: const TextStyle(color: _deepOrange, fontSize: 12, fontWeight: FontWeight.w600)),
        )
      else if (trailing != null)
        Text(trailing!, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w500)),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.note, required this.icon, required this.color, required this.onTap});

  final String label;
  final int value;
  final String note;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icon, color: color, size: 18), const Spacer(), Text('$value', style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w700))]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
            ]),
          ],
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Row(
          children: [
            Icon(icon, color: _deepOrange, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w600))),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(submission.institution, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3))),
          const SizedBox(width: 8),
          const _StatusBadge(status: VerificationStatus.pending),
        ]),
        const SizedBox(height: 9),
        Wrap(spacing: 14, runSpacing: 5, children: [
          _DetailPair(label: 'Submission', value: submission.submissionId),
          _DetailPair(label: 'Submitted', value: submission.submittedOn),
          _DetailPair(label: 'FDR reference', value: submission.reference),
          _DetailPair(label: 'Deposit', value: submission.amount, emphasized: true),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Review'),
            style: TextButton.styleFrom(foregroundColor: _deepOrange, minimumSize: const Size(70, 38), padding: const EdgeInsets.symmetric(horizontal: 9)),
          ),
        ),
      ],
    ),
  );
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({required this.label, required this.value, this.emphasized = false});

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
          TextSpan(text: '$label  ', style: const TextStyle(color: _muted)),
          TextSpan(text: value, style: TextStyle(color: emphasized ? _ink : const Color(0xFF4B5563), fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VerificationStatus.pending => const Color(0xFFB45309),
      VerificationStatus.approved => const Color(0xFF15803D),
      VerificationStatus.rejected => const Color(0xFFB91C1C),
    };
    final background = switch (status) {
      VerificationStatus.pending => const Color(0xFFFFF7E8),
      VerificationStatus.approved => const Color(0xFFF0FDF4),
      VerificationStatus.rejected => const Color(0xFFFEF2F2),
    };
    final label = switch (status) {
      VerificationStatus.pending => 'Pending Review',
      VerificationStatus.approved => 'Approved',
      VerificationStatus.rejected => 'Correction',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, maxLines: 1, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities});

  final List<OfficerActivity> activities;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
    child: Column(
      children: [
        for (var index = 0; index < activities.length; index++) ...[
          _ActivityRow(activity: activities[index]),
          if (index < activities.length - 1) const Divider(height: 1, color: _line),
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
    final color = switch (activity.status) {
      VerificationStatus.pending => const Color(0xFFD97706),
      VerificationStatus.approved => const Color(0xFF16A34A),
      VerificationStatus.rejected => const Color(0xFFDC2626),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.circle, color: color, size: 9),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(activity.description, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(activity.reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
        ])),
        const SizedBox(width: 8),
        Text(activity.when, style: const TextStyle(color: _muted, fontSize: 9)),
      ]),
    );
  }
}

class _DestinationBody extends StatelessWidget {
  const _DestinationBody({required this.title, required this.subtitle, required this.onOpenPage});

  final String title;
  final String subtitle;
  final void Function(String, {String? subtitle}) onOpenPage;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_tabIcon(title), color: _orange, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13, height: 1.45)),
          const SizedBox(height: 13),
          const _DemoNotice(),
          const SizedBox(height: 18),
          if (title == 'Submissions' || title == 'Pending Review')
            OutlinedButton.icon(
              onPressed: () => onOpenPage('Pending Verification', subtitle: 'Sample submission queue.'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Open pending verification queue'),
            ),
        ]),
      ),
    ),
  );
}

class _DestinationPage extends StatelessWidget {
  const _DestinationPage({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(title: Text(title), backgroundColor: _paper, surfaceTintColor: _paper),
    body: _DestinationBody(
      title: title,
      subtitle: subtitle ?? 'This destination is prepared for the connected portal workflow.',
      onOpenPage: (nextTitle, {subtitle}) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _DestinationPage(title: nextTitle, subtitle: subtitle)),
      ),
    ),
  );
}

String _initials(String value) {
  final parts = value.split(RegExp(r'[@._\-\s]+')).where((part) => part.isNotEmpty).toList();
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
  'Submissions' || 'Pending Review' || 'Pending Verification' || 'Approved Submissions' || 'Returned for Correction' => Icons.fact_check_outlined,
  'Institutions' || 'Institution Registry' => Icons.domain_outlined,
  'Profile' || 'Profile settings' => Icons.person_outline_rounded,
  'Notifications' => Icons.notifications_none_rounded,
  'Reports' => Icons.analytics_outlined,
  _ => Icons.dashboard_outlined,
};

class DemoFdrPortalStore {
  DemoFdrPortalStore._();

  static final DemoFdrPortalStore instance = DemoFdrPortalStore._();

  FdrRecord _currentSubmission = const FdrRecord(
    institution: 'Example Institute of Technology',
    institutionId: 'INST-00042',
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
      DemoDocument(name: 'FDR receipt', fileName: 'fdr_receipt.pdf', status: 'Uploaded — Demo'),
      DemoDocument(name: 'Institution request letter', fileName: 'request_letter.pdf', status: 'Uploaded — Demo'),
      DemoDocument(name: 'Affidavit', fileName: 'affidavit.pdf', status: 'Uploaded — Demo'),
      DemoDocument(name: 'Supporting documents', fileName: 'supporting_docs.zip', status: 'Uploaded — Demo'),
    ],
  );

  VerificationSummary _lastVerification = const VerificationSummary(
    totalChecks: 3,
    blocking: 2,
    warnings: 1,
    statusText: 'BLOCKED — 2 Blocking Discrepancies',
    issues: [
      VerificationIssue(
        ruleId: 'deposit-amount',
        severity: VerificationIssueSeverity.blocking,
        message: 'Declared deposit amount does not match the receipt amount.',
      ),
      VerificationIssue(
        ruleId: 'lien-information',
        severity: VerificationIssueSeverity.warning,
        message: 'Lien information requires review.',
      ),
      VerificationIssue(
        ruleId: 'duplicate-fdr',
        severity: VerificationIssueSeverity.blocking,
        message: 'This FDR number already appears in another institution\'s record.',
      ),
    ],
  );

  ReleaseCase? _releaseCase;
  final List<AuditEntry> _auditEntries = <AuditEntry>[];

  FdrRecord get currentSubmission => _currentSubmission;
  VerificationSummary get lastVerification => _lastVerification;
  ReleaseCase? get releaseCase => _releaseCase;
  List<AuditEntry> get auditEntries => List.unmodifiable(_auditEntries);

  void resetDemoData() {
    _currentSubmission = const FdrRecord(
      institution: 'Example Institute of Technology',
      institutionId: 'INST-00042',
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
        DemoDocument(name: 'FDR receipt', fileName: 'fdr_receipt.pdf', status: 'Uploaded — Demo'),
        DemoDocument(name: 'Institution request letter', fileName: 'request_letter.pdf', status: 'Uploaded — Demo'),
        DemoDocument(name: 'Affidavit', fileName: 'affidavit.pdf', status: 'Uploaded — Demo'),
        DemoDocument(name: 'Supporting documents', fileName: 'supporting_docs.zip', status: 'Uploaded — Demo'),
      ],
    );
    _lastVerification = const VerificationSummary(
      totalChecks: 3,
      blocking: 2,
      warnings: 1,
      statusText: 'BLOCKED — 2 Blocking Discrepancies',
      issues: [
        VerificationIssue(
          ruleId: 'deposit-amount',
          severity: VerificationIssueSeverity.blocking,
          message: 'Declared deposit amount does not match the receipt amount.',
        ),
        VerificationIssue(
          ruleId: 'lien-information',
          severity: VerificationIssueSeverity.warning,
          message: 'Lien information requires review.',
        ),
        VerificationIssue(
          ruleId: 'duplicate-fdr',
          severity: VerificationIssueSeverity.blocking,
          message: 'This FDR number already appears in another institution\'s record.',
        ),
      ],
    );
    _releaseCase = null;
    _auditEntries.clear();
    _seedAudit();
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
      ..add(AuditEntry(
        eventId: 'AUD-001',
        timestamp: '2026-10-25 08:30:00',
        actorRole: 'Demo Officer',
        action: 'FDR submission created',
        associatedId: 'FDR-2026-00124',
        payload: '',
        previousHash: 'GENESIS',
        entryHash: firstHash,
      ))
      ..add(AuditEntry(
        eventId: 'AUD-002',
        timestamp: '2026-10-25 08:33:10',
        actorRole: 'Demo Officer',
        action: 'Verification initiated',
        associatedId: 'FDR-2026-00124',
        payload: '',
        previousHash: firstHash,
        entryHash: secondHash,
      ));
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
    final previousHash = _auditEntries.isEmpty ? 'GENESIS' : _auditEntries.last.entryHash;
    final eventId = 'AUD-${(_auditEntries.length + 1).toString().padLeft(3, '0')}';
    final timestamp = DateTime.now().toString().replaceAll('.', ':').substring(0, 19);
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
  }

  void setCurrentSubmission(FdrRecord record) {
    _currentSubmission = record;
  }

  void setLastVerification(VerificationSummary summary) {
    _lastVerification = summary;
  }

  void createReleaseCase() {
    final caseId = 'REL-2026-00017';
    _releaseCase = ReleaseCase(
      caseId: caseId,
      submissionId: _currentSubmission.submissionId,
      institution: _currentSubmission.institution,
      caseType: 'Normal Release',
      status: 'Awaiting Clearances',
      checklist: const [
        DemoChecklistItem(name: 'Request Letter', fileName: 'request_letter.pdf', type: 'Institution request letter', status: 'Uploaded — Demo'),
        DemoChecklistItem(name: 'Affidavit', fileName: 'affidavit.pdf', type: 'Institution affidavit', status: 'Uploaded — Demo'),
        DemoChecklistItem(name: 'FDR Copy', fileName: 'fdr_receipt.pdf', type: 'Fixed Deposit Receipt', status: 'Uploaded — Demo'),
      ],
      clearances: const [
        ClearanceState(name: 'Grievance Redressal Cell', status: 'Pending', remark: 'Not reviewed', actionRequired: 'Review grievances and confirm no objections.'),
        ClearanceState(name: 'Vigilance Cell', status: 'Pending', remark: 'Not reviewed', actionRequired: 'Inspect compliance and risk indicators.'),
      ],
    );
  }

  void updateClearanceStatus(String clearanceName, String newStatus, {String? remark}) {
    final currentCase = _releaseCase;
    if (currentCase == null) return;
    final index = currentCase.clearances.indexWhere((item) => item.name == clearanceName);
    if (index == -1) return;
    final updated = currentCase.clearances[index].copyWith(
      status: newStatus,
      remark: remark ?? currentCase.clearances[index].remark,
      lastUpdated: DateTime.now().toLocal().toString().substring(0, 16),
    );
    final clearances = [...currentCase.clearances];
    clearances[index] = updated;
    _releaseCase = currentCase.copyWith(clearances: clearances);
  }

  void updateDocumentPresence(String fileName, bool isPresent) {
    final currentCase = _releaseCase;
    if (currentCase == null) return;
    final checklist = currentCase.checklist.map((item) => item.fileName == fileName
        ? item.copyWith(isPresent: isPresent, status: isPresent ? 'Present — Demo' : 'Missing — Demo')
        : item).toList();
    _releaseCase = currentCase.copyWith(checklist: checklist);
  }

  void updateReleaseCaseType(String caseType) {
    final currentCase = _releaseCase;
    if (currentCase == null) return;
    _releaseCase = currentCase.copyWith(caseType: caseType);
  }

  void issueDemoNoc() {
    final currentCase = _releaseCase;
    if (currentCase == null) return;
    _releaseCase = currentCase.copyWith(status: 'NOC Issued — Demo');
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

class VerificationIssue {
  const VerificationIssue({
    required this.ruleId,
    required this.severity,
    required this.message,
  });

  final String ruleId;
  final VerificationIssueSeverity severity;
  final String message;
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
  });

  final String caseId;
  final String submissionId;
  final String institution;
  final String caseType;
  final String status;
  final List<DemoChecklistItem> checklist;
  final List<ClearanceState> clearances;

  ReleaseCase copyWith({
    String? caseId,
    String? submissionId,
    String? institution,
    String? caseType,
    String? status,
    List<DemoChecklistItem>? checklist,
    List<ClearanceState>? clearances,
  }) => ReleaseCase(
    caseId: caseId ?? this.caseId,
    submissionId: submissionId ?? this.submissionId,
    institution: institution ?? this.institution,
    caseType: caseType ?? this.caseType,
    status: status ?? this.status,
    checklist: checklist ?? this.checklist,
    clearances: clearances ?? this.clearances,
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

  DemoChecklistItem copyWith({bool? isPresent, String? status}) => DemoChecklistItem(
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
        message: 'Tampering detected at audit entry ${entry.eventId}. The stored hash does not match the recalculated hash.',
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
  static final Map<String, String> _duplicateRegistry = {
    'FDR-EX-884201': 'National College of Engineering',
  };

  static VerificationSummary runVerification(FdrRecord record) {
    final issues = <VerificationIssue>[];

    if (record.declaredDepositAmount != record.receiptAmount) {
      issues.add(
        const VerificationIssue(
          ruleId: 'deposit-amount',
          severity: VerificationIssueSeverity.blocking,
          message: 'Declared deposit amount does not match the receipt amount.',
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
        ),
      );
    }

    final duplicateInstitution = _duplicateRegistry[record.fdrNumber];
    if (duplicateInstitution != null && duplicateInstitution != record.institution) {
      issues.add(
        VerificationIssue(
          ruleId: 'duplicate-fdr',
          severity: VerificationIssueSeverity.blocking,
          message: 'This FDR number already appears in another institution\'s record.',
        ),
      );
    }

    final blocking = issues.where((issue) => issue.severity == VerificationIssueSeverity.blocking).length;
    final warnings = issues.where((issue) => issue.severity == VerificationIssueSeverity.warning).length;

    final summary = VerificationSummary(
      totalChecks: issues.length,
      blocking: blocking,
      warnings: warnings,
      statusText: blocking == 0 ? 'PASSED — No Blocking Discrepancies' : 'BLOCKED — $blocking Blocking Discrepancies',
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
  });

  final bool canAdvance;
  final List<String> blockingReasons;
  final List<String> warnings;
  final String nextEligibleStage;
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
    this.updateDocumentPresence = '/release-cases/{caseId}/documents/{documentId}',
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
  void appendAuditEvent({required String action, required String caseId, required String payload});
}

class MockReleaseCaseRepository implements ReleaseCaseRepository {
  MockReleaseCaseRepository(this.store, {this.endpointPaths = const ReleaseCaseEndpointPaths()});

  final DemoFdrPortalStore store;
  final ReleaseCaseEndpointPaths endpointPaths;

  @override
  ReleaseCase? retrieveReleaseCase() => store.releaseCase;

  @override
  List<DemoChecklistItem> retrieveRequiredDocumentChecklist() => store.releaseCase?.checklist ?? const [];

  @override
  void updateRequiredDocumentPresence(String fileName, bool isPresent) => store.updateDocumentPresence(fileName, isPresent);

  @override
  List<ClearanceState> retrieveCellClearanceStatuses() => store.releaseCase?.clearances ?? const [];

  @override
  void recordClearanceDecision(String cellName, String status, String remark) => store.updateClearanceStatus(cellName, status, remark: remark);

  @override
  ReleaseEligibility checkReleaseEligibility(VerificationSummary verification) => canAdvanceReleaseCase(
    verification,
    retrieveRequiredDocumentChecklist(),
    retrieveCellClearanceStatuses(),
  );

  @override
  void issueFinalNocInDemoMode() => store.issueDemoNoc();

  @override
  void appendAuditEvent({required String action, required String caseId, required String payload}) => store.appendAuditEntry(
    action: action,
    associatedId: caseId,
    actorRole: 'Demo Officer',
    payload: payload,
  );
}

class _FdrVerificationDetailPage extends StatefulWidget {
  const _FdrVerificationDetailPage();

  @override
  State<_FdrVerificationDetailPage> createState() => _FdrVerificationDetailPageState();
}

class _FdrVerificationDetailPageState extends State<_FdrVerificationDetailPage> {
  bool _isRunning = false;

  Future<void> _runVerification() async {
    setState(() => _isRunning = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final summary = FdrVerificationService.runVerification(DemoFdrPortalStore.instance.currentSubmission);
    DemoFdrPortalStore.instance.setLastVerification(summary);
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'Verification initiated',
      associatedId: DemoFdrPortalStore.instance.currentSubmission.submissionId,
      actorRole: 'Demo Officer',
      payload: summary.statusText,
    );
    if (!mounted) return;
    setState(() => _isRunning = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _VerificationResultsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = DemoFdrPortalStore.instance.currentSubmission;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('FDR Verification'),
        backgroundColor: _paper,
        surfaceTintColor: _paper,
      ),
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
                'Declared deposit amount': '₹${_formatCurrency(record.declaredDepositAmount)}',
                'Receipt amount': '₹${_formatCurrency(record.receiptAmount)}',
                'Issue date': record.issueDate,
                'Maturity date': record.maturityDate,
                'Declared tenure': '${record.declaredTenureMonths} months',
                'Entered tenure': '${record.enteredTenureMonths} months',
                'Lien information': record.lienInformation,
                'Submission status': record.submissionStatus,
              },
            ),
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
                    style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (record.documents.isEmpty)
                    const Text('No documents available in demo mode.', style: TextStyle(color: _muted, fontSize: 11))
                  else
                    for (final document in record.documents) ...[
                      _DocumentListItem(document: document),
                      if (document != record.documents.last) const Divider(height: 16, color: _line),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isRunning ? null : _runVerification,
                icon: _isRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
                label: Text(_isRunning ? 'Running Verification...' : 'Run Verification'),
                style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationResultsPage extends StatefulWidget {
  const _VerificationResultsPage();

  @override
  State<_VerificationResultsPage> createState() => _VerificationResultsPageState();
}

class _VerificationResultsPageState extends State<_VerificationResultsPage> {
  @override
  Widget build(BuildContext context) {
    final summary = DemoFdrPortalStore.instance.lastVerification;
    final record = DemoFdrPortalStore.instance.currentSubmission;
    final isBlocked = summary.blocking > 0;

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('Verification Results'),
        backgroundColor: _paper,
        surfaceTintColor: _paper,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
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
                      Expanded(
                        child: Text(
                          summary.statusText,
                          style: TextStyle(
                            color: isBlocked ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _SummaryMetric(label: 'Total checks', value: summary.totalChecks.toString())),
                      Expanded(child: _SummaryMetric(label: 'Blocking', value: summary.blocking.toString())),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _SummaryMetric(label: 'Warnings', value: summary.warnings.toString())),
                      Expanded(child: _SummaryMetric(label: 'Status', value: isBlocked ? 'Blocked' : 'Passed')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...summary.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IssueCard(issue: issue),
            )),
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
                  const Text('Side-by-Side Comparison', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 560;
                      final columns = [
                        _ComparisonColumn(title: 'Institution-Entered Values', entries: [
                          ('Institution', record.institution),
                          ('FDR number', record.fdrNumber),
                          ('Deposit amount', '₹${_formatCurrency(record.declaredDepositAmount)}'),
                          ('Lien information', record.lienInformation),
                        ]),
                        _ComparisonColumn(title: 'Receipt Values', entries: [
                          ('FDR number', 'FDR-EX-884201'),
                          ('Deposit amount', '₹4,50,000'),
                          ('Lien information', 'Not provided'),
                        ]),
                        _ComparisonColumn(title: 'Declared Values', entries: [
                          ('Institution', 'Example Institute of Technology'),
                          ('FDR number', record.fdrNumber),
                          ('Deposit amount', '₹${_formatCurrency(record.declaredDepositAmount)}'),
                          ('Lien information', record.lienInformation),
                        ]),
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
                    MaterialPageRoute<void>(builder: (_) => const _ReleaseCasePage()),
                  );
                },
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('Open Release / Refund Case'),
                style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(48)),
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
                    MaterialPageRoute<void>(builder: (_) => const _ReleaseCasePage()),
                  );
                },
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Open Blocked Release Case'),
                style: OutlinedButton.styleFrom(foregroundColor: _deepOrange, minimumSize: const Size.fromHeight(44)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _CorrectDetailsPage()),
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
                  onPressed: () async {
                    final summary = FdrVerificationService.runVerification(DemoFdrPortalStore.instance.currentSubmission);
                    DemoFdrPortalStore.instance.setLastVerification(summary);
                    DemoFdrPortalStore.instance.appendAuditEntry(
                      action: 'Verification rerun',
                      associatedId: DemoFdrPortalStore.instance.currentSubmission.submissionId,
                      actorRole: 'Demo Officer',
                      payload: summary.statusText,
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Re-run Verification'),
                  style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: _line), minimumSize: const Size.fromHeight(44)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _AuditTrailPage()),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Audit Trail'),
                  style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: _line), minimumSize: const Size.fromHeight(44)),
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

  @override
  void initState() {
    super.initState();
    final record = DemoFdrPortalStore.instance.currentSubmission;
    _fdrNumberController = TextEditingController(text: record.fdrNumber);
    _amountController = TextEditingController(text: record.declaredDepositAmount.toString());
    _issueDateController = TextEditingController(text: record.issueDate);
    _maturityDateController = TextEditingController(text: record.maturityDate);
    _tenureController = TextEditingController(text: record.declaredTenureMonths.toString());
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

    final correctedRecord = DemoFdrPortalStore.instance.currentSubmission.copyWith(
      fdrNumber: _fdrNumberController.text.trim(),
      declaredDepositAmount: int.parse(_amountController.text.trim()),
      receiptAmount: int.parse(_amountController.text.trim()),
      issueDate: _issueDateController.text.trim(),
      maturityDate: _maturityDateController.text.trim(),
      declaredTenureMonths: int.parse(_tenureController.text.trim()),
      enteredTenureMonths: int.parse(_tenureController.text.trim()),
      lienInformation: _lienController.text.trim().isEmpty ? 'Not provided' : _lienController.text.trim(),
    );

    DemoFdrPortalStore.instance.setCurrentSubmission(correctedRecord);
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'FDR details corrected',
      associatedId: correctedRecord.submissionId,
      actorRole: 'Demo Officer',
      payload: 'FDR corrected to ${correctedRecord.fdrNumber} / ₹${_formatCurrency(correctedRecord.declaredDepositAmount)}',
    );

    final summary = FdrVerificationService.runVerification(correctedRecord);
    DemoFdrPortalStore.instance.setLastVerification(summary);
    DemoFdrPortalStore.instance.appendAuditEntry(
      action: 'Verification rerun',
      associatedId: correctedRecord.submissionId,
      actorRole: 'Demo Officer',
      payload: summary.statusText,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const _VerificationResultsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('Correct FDR Details'),
        backgroundColor: _paper,
        surfaceTintColor: _paper,
      ),
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
                validator: (value) => (value == null || value.trim().isEmpty) ? 'FDR number is required' : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Deposit amount',
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Deposit amount is required' : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Issue date',
                controller: _issueDateController,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Issue date is required' : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Maturity date',
                controller: _maturityDateController,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Maturity date is required' : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Tenure',
                controller: _tenureController,
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Tenure is required' : null,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'Lien information',
                controller: _lienController,
                validator: (value) => value == null || value.trim().isEmpty ? 'Lien information is required' : null,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Corrected Details'),
                style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(48)),
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
  late final ReleaseCaseRepository _repository = MockReleaseCaseRepository(_store);

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
      _repository.checkReleaseEligibility(_store.lastVerification);

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
      action: present ? 'Required document marked present' : 'Required document marked missing',
      caseId: _case.caseId,
      payload: document.fileName,
    );
    _recordEligibilityChange(before);
    setState(() {});
  }

  Future<void> _recordClearanceDecision(ClearanceState clearance, String status) async {
    final decision = await showDialog<_ClearanceDecisionResult>(
      context: context,
      builder: (_) => _ClearanceDecisionDialog(
        cellName: clearance.name,
        status: status,
      ),
    );
    if (decision == null || !mounted) return;

    final before = _eligibility();
    _repository.recordClearanceDecision(clearance.name, status, decision.remark);
    _repository.appendAuditEvent(
      action: status == 'Cleared' ? 'Clearance decision recorded' : 'Clarification requested',
      caseId: _case.caseId,
      payload: '${clearance.name}: $status; ${decision.remark}',
    );
    _recordEligibilityChange(before);
    setState(() {});
  }

  Future<void> _simulateNoc() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate final NOC?'),
        content: const Text('This records a local demo outcome only. It is not an official NOC and does not release funds.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm demo action')),
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

  void _openVerificationResults() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _VerificationResultsPage()),
  );

  void _openAuditTrail() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _AuditTrailPage()),
  );

  void _showDocumentDetails(DemoChecklistItem document) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.name),
        content: Text('${document.type}\n${document.fileName}\n\nDemo checklist presence only. No real file is stored or validated.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _case;
    final eligibility = _eligibility(record);
    final isNormalRelease = record.caseType == 'Normal Release';
    final verificationBlocked = _store.lastVerification.blocking > 0;
    final nocIssued = record.status == 'NOC Issued — Demo';

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('Release / Refund Case'),
        backgroundColor: _paper,
        surfaceTintColor: _paper,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 700 ? 28.0 : 18.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 28),
              children: [
                const Text('Manage required documents and institutional clearances.', style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                const _DemoNotice(),
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Case Summary',
                  trailing: const _DemoPill(),
                  child: Column(
                    children: [
                      _MiniInfoRow(label: 'Case ID', value: record.caseId),
                      _MiniInfoRow(label: 'Submission ID', value: record.submissionId),
                      _MiniInfoRow(label: 'Institution', value: record.institution),
                      _MiniInfoRow(label: 'FDR number', value: _store.currentSubmission.fdrNumber),
                      _MiniInfoRow(label: 'Deposit amount', value: '₹${_formatCurrency(_store.currentSubmission.declaredDepositAmount)}'),
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
                        initialValue: record.caseType,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        items: _caseTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                        onChanged: (type) {
                          if (type == null || type == record.caseType) return;
                          _store.updateReleaseCaseType(type);
                          _store.appendAuditEntry(action: 'Case type selected', associatedId: record.caseId, actorRole: 'Demo Officer', payload: type);
                          setState(() {});
                        },
                      ),
                      if (!isNormalRelease) ...[
                        const SizedBox(height: 10),
                        const _InlineNotice(
                          message: 'This workflow template is not implemented yet. Normal Release is the only supported demo workflow.',
                          color: Color(0xFFFFF7ED),
                          textColor: Color(0xFF9A3412),
                          icon: Icons.info_outline_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Workflow Progress',
                  child: _WorkflowProgress(
                    verificationComplete: !verificationBlocked,
                    documentsComplete: record.checklist.where((item) => item.isRequired).every((item) => item.isPresent),
                    clearancesComplete: record.clearances.every((item) => item.status == 'Cleared'),
                    nocIssued: nocIssued,
                    nextStage: eligibility.nextEligibleStage,
                  ),
                ),
                if (verificationBlocked) ...[
                  const SizedBox(height: 10),
                  _InlineNotice(
                    message: 'Case blocked — resolve all blocking FDR discrepancies before proceeding. ${_store.lastVerification.blocking} blocking item(s) remain.',
                    color: const Color(0xFFFEF2F2),
                    textColor: const Color(0xFF991B1B),
                    icon: Icons.block_rounded,
                    action: TextButton.icon(
                      onPressed: _openVerificationResults,
                      icon: const Icon(Icons.fact_check_outlined, size: 17),
                      label: const Text('View Verification Results'),
                    ),
                  ),
                ],
                if (isNormalRelease) ...[
                  const SizedBox(height: 12),
                  _ReleaseSection(
                    title: 'Required Documents',
                    child: Column(
                      children: [
                        for (final document in record.checklist)
                          _ReleaseDocumentRow(
                            document: document,
                            onChanged: (present) => _setDocumentPresence(document, present),
                            onDetails: () => _showDocumentDetails(document),
                          ),
                        if (record.checklist.any((item) => item.isRequired && !item.isPresent)) ...[
                          const SizedBox(height: 6),
                          const _InlineNotice(
                            message: 'Missing required documents must be marked present before this case can advance. No file upload is connected in demo mode.',
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
                            onClear: () => _recordClearanceDecision(clearance, 'Cleared'),
                            onClarification: () => _recordClearanceDecision(clearance, 'Clarification Requested'),
                          ),
                        const SizedBox(height: 4),
                        const Text('Required clearances are processed independently. The case cannot proceed until every required clearance is complete.', style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ReleaseSection(
                  title: 'Final NOC',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Status', style: TextStyle(color: _muted, fontSize: 12))),
                          _ReleaseStatusBadge(status: nocIssued ? 'NOC Issued — Demo' : 'Awaiting Clearances'),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const Text('Required: all blocking discrepancies resolved, required documents present, and required cell clearances completed.', style: TextStyle(color: _ink, fontSize: 12, height: 1.4)),
                      const SizedBox(height: 10),
                      for (final clearance in record.clearances)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [Expanded(child: Text(clearance.name, style: const TextStyle(color: _muted, fontSize: 11))), _ReleaseStatusBadge(status: clearance.status)]),
                        ),
                      if (!eligibility.canAdvance) ...[
                        const SizedBox(height: 8),
                        for (final reason in eligibility.blockingReasons)
                          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $reason', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, height: 1.35))),
                      ],
                      if (eligibility.warnings.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        for (final warning in eligibility.warnings)
                          Text('Warning: $warning', style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, height: 1.35)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: eligibility.canAdvance && !nocIssued && isNormalRelease ? _simulateNoc : null,
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(nocIssued ? 'NOC Issued — Demo' : 'Simulate Final NOC'),
                          style: FilledButton.styleFrom(backgroundColor: _releaseOrange, minimumSize: const Size.fromHeight(46)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Demo only. This action is not an official NOC and does not release funds.', style: TextStyle(color: _muted, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _openAuditTrail, icon: const Icon(Icons.history_rounded), label: const Text('View Audit Trail')),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('Audit hash-chain is local demo functionality; backend integrity has not been connected or verified.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 10, height: 1.35)),
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
  const _ReleaseSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700))), ?trailing]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFFFF1E4), borderRadius: BorderRadius.circular(20)),
    child: const Text('DEMO DATA', style: TextStyle(color: _deepOrange, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.color, required this.textColor, required this.icon, this.action});

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9), border: Border.all(color: textColor.withValues(alpha: 0.18))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: textColor, size: 17), const SizedBox(width: 7), Expanded(child: Text(message, style: TextStyle(color: textColor, fontSize: 11, height: 1.4, fontWeight: FontWeight.w600)))]),
      if (action != null) Align(alignment: Alignment.centerLeft, child: action!),
    ]),
  );
}

class _WorkflowProgress extends StatelessWidget {
  const _WorkflowProgress({required this.verificationComplete, required this.documentsComplete, required this.clearancesComplete, required this.nocIssued, required this.nextStage});

  final bool verificationComplete;
  final bool documentsComplete;
  final bool clearancesComplete;
  final bool nocIssued;
  final String nextStage;

  @override
  Widget build(BuildContext context) {
    const labels = ['FDR Verification', 'Required Documents', 'Cell Clearances', 'Final NOC'];
    final complete = [verificationComplete, documentsComplete, clearancesComplete, nocIssued];
    var currentIndex = labels.indexOf(nextStage);
    if (currentIndex < 0) currentIndex = 3;
    return Column(children: [
      for (var index = 0; index < labels.length; index++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 25, height: 25, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: complete[index] ? const Color(0xFF15803D) : index == currentIndex && index == 0 && !verificationComplete ? const Color(0xFFB91C1C) : index == currentIndex ? _releaseOrange : const Color(0xFFF3F4F6)), child: Icon(complete[index] ? Icons.check_rounded : index == currentIndex && index == 0 && !verificationComplete ? Icons.priority_high_rounded : Icons.circle, size: complete[index] ? 16 : 12, color: complete[index] || index == currentIndex ? Colors.white : const Color(0xFF9CA3AF))),
            if (index < labels.length - 1) Container(width: 2, height: 18, color: complete[index] ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB)),
          ]),
          const SizedBox(width: 10),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[index], style: TextStyle(color: complete[index] ? const Color(0xFF166534) : index == currentIndex && index == 0 && !verificationComplete ? const Color(0xFFB91C1C) : index == currentIndex ? _deepOrange : _muted, fontSize: 12, fontWeight: index == currentIndex ? FontWeight.w700 : FontWeight.w500))),
          if (index == currentIndex) const Padding(padding: EdgeInsets.only(left: 7, top: 4), child: Text('CURRENT', style: TextStyle(color: _deepOrange, fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
      ],
    ]);
  }
}

class _ReleaseDocumentRow extends StatelessWidget {
  const _ReleaseDocumentRow({required this.document, required this.onChanged, required this.onDetails});

  final DemoChecklistItem document;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(document.isPresent ? Icons.description_outlined : Icons.insert_drive_file_outlined, color: document.isPresent ? const Color(0xFF15803D) : _muted, size: 21),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(document.name, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
        Text('${document.fileName} · Required', style: const TextStyle(color: _muted, fontSize: 10)),
        Text(document.status, style: TextStyle(color: document.isPresent ? const Color(0xFF166534) : const Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w600)),
      ])),
      IconButton(tooltip: 'View document details', onPressed: onDetails, icon: const Icon(Icons.info_outline_rounded, size: 19)),
      SizedBox(width: 44, child: Switch(value: document.isPresent, onChanged: onChanged, activeTrackColor: const Color(0xFF86EFAC))),
    ]),
  );
}

class _ClearanceCard extends StatelessWidget {
  const _ClearanceCard({required this.clearance, required this.onClear, required this.onClarification});

  final ClearanceState clearance;
  final VoidCallback onClear;
  final VoidCallback onClarification;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(clearance.name, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700))), _ReleaseStatusBadge(status: clearance.status)]),
      const SizedBox(height: 5),
      Text(clearance.lastUpdated == null ? 'Not reviewed' : 'Updated ${clearance.lastUpdated}', style: const TextStyle(color: _muted, fontSize: 10)),
      const SizedBox(height: 4),
      Text(clearance.remark, style: const TextStyle(color: _ink, fontSize: 11, height: 1.35)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 4, children: [
        OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Mark Cleared')),
        OutlinedButton.icon(onPressed: onClarification, icon: const Icon(Icons.help_outline_rounded, size: 16), label: const Text('Request Clarification')),
      ]),
    ]),
  );
}

class _ReleaseStatusBadge extends StatelessWidget {
  const _ReleaseStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isCleared = status == 'Cleared' || status == 'NOC Issued — Demo';
    final isClarification = status == 'Clarification Requested';
    final color = isCleared ? const Color(0xFF166534) : isClarification ? const Color(0xFF9A3412) : const Color(0xFF92400E);
    final fill = isCleared ? const Color(0xFFDCFCE7) : isClarification ? const Color(0xFFFFEDD5) : const Color(0xFFFEF3C7);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)));
  }
}

class _ClearanceDecisionResult {
  const _ClearanceDecisionResult(this.remark);
  final String remark;
}

class _ClearanceDecisionDialog extends StatefulWidget {
  const _ClearanceDecisionDialog({required this.cellName, required this.status});

  final String cellName;
  final String status;

  @override
  State<_ClearanceDecisionDialog> createState() => _ClearanceDecisionDialogState();
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.cellName}\nDemo action only. No official AICTE clearance is being recorded.', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarkController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Officer remark', hintText: 'Enter review remark', border: OutlineInputBorder()),
            validator: (value) => !isClearing && (value == null || value.trim().isEmpty) ? 'Explain what information is needed.' : null,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final remark = _remarkController.text.trim().isEmpty ? 'Demo clearance recorded after review.' : _remarkController.text.trim();
            Navigator.pop(context, _ClearanceDecisionResult(remark));
          },
          child: Text(isClearing ? 'Confirm demo clearance' : 'Record clarification'),
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

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('Audit Trail'),
        backgroundColor: _paper,
        surfaceTintColor: _paper,
      ),
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
                      const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          integrity.isValid ? 'Verified' : 'Integrity issue found',
                          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verificationMessage.isEmpty ? integrity.message : _verificationMessage,
                    style: TextStyle(color: integrity.isValid ? const Color(0xFF166534) : const Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w600),
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
                    Text('Event ID: ${entry.eventId}', style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Timestamp: ${entry.timestamp}', style: const TextStyle(color: _muted, fontSize: 10)),
                    Text('Actor: ${entry.actorRole}', style: const TextStyle(color: _muted, fontSize: 10)),
                    Text('Action: ${entry.action}', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Associated: ${entry.associatedId}', style: const TextStyle(color: _muted, fontSize: 10)),
                    if (entry.payload.isNotEmpty) Text('Detail: ${entry.payload}', style: const TextStyle(color: _muted, fontSize: 10)),
                    const SizedBox(height: 8),
                    Text('Previous hash: ${entry.previousHash}', style: const TextStyle(color: _ink, fontSize: 9)),
                    Text('Current entry hash: ${entry.entryHash}', style: const TextStyle(color: _ink, fontSize: 9)),
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
        Text(title, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final row in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(row.key, style: const TextStyle(color: _muted, fontSize: 11)),
                ),
                Expanded(
                  child: Text(row.value, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w600)),
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
        Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
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
        border: Border.all(color: isBlocking ? const Color(0xFFFECACA) : const Color(0xFFFCD9A6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isBlocking ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: isBlocking ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
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
                    color: isBlocking ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(issue.message, style: const TextStyle(color: _ink, fontSize: 12, height: 1.4)),
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
        Text(title, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(entry.$1, style: const TextStyle(color: _muted, fontSize: 10)),
                ),
                Expanded(
                  child: Text(
                    entry.$2,
                    style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w600),
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
      const Icon(Icons.insert_drive_file_outlined, color: _deepOrange, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.fileName, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(document.name, style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      ),
      Text(document.status, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w700)),
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
      Text(label, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          child: Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

String _formatCurrency(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match match) => ',',
    );