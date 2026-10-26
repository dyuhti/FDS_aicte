import 'connection.dart';
import 'models.dart';

Future<void> seedDatabase(Database database) async {
  await database.connect();
  if ((await database.users.getAll()).isNotEmpty) return;

  final now = DateTime.now();
  await database.users.create(
    User(
      id: 'user-demo-officer',
      email: 'officer.demo@aicte.example',
      displayName: 'Demo Officer',
      role: 'officer',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await database.users.create(
    User(
      id: 'user-demo-institution',
      email: 'admin@example-institute.edu',
      displayName: 'Example Institute Administrator',
      role: 'institution',
      createdAt: now,
      updatedAt: now,
    ),
  );

  final submissions = <FdrSubmissionRecord>[
    FdrSubmissionRecord(
      id: 'FDR-2026-00124',
      institutionId: 'INST-DEMO-0042',
      institutionName: 'Example Institute of Technology',
      fdrReference: 'FDR-EX-884201',
      bankName: 'Example National Bank',
      amount: 500000,
      status: 'pending_review',
      createdAt: now,
      updatedAt: now,
    ),
    FdrSubmissionRecord(
      id: 'FDR-2026-00125',
      institutionId: 'INST-00125',
      institutionName: 'National College of Engineering',
      fdrReference: 'FDR-NC-550318',
      bankName: 'National Commerce Bank',
      amount: 300000,
      status: 'pending_review',
      createdAt: now,
      updatedAt: now,
    ),
  ];
  for (final submission in submissions) {
    await database.submissions.create(submission);
  }

  await database.alerts.create(
    Alert(
      id: 'alert-demo-fdr-00124',
      title: 'New FDR submission',
      message: 'Example Institute of Technology submitted an FDR for review.',
      recipientId: 'user-demo-officer',
      severity: 'info',
      createdAt: now,
      updatedAt: now,
    ),
  );
}
