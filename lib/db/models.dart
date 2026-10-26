abstract interface class PersistedModel {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
}

class User implements PersistedModel {
  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  @override
  final String id;
  final String email;
  final String displayName;
  final String role;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  User copyWith({
    String? email,
    String? displayName,
    String? role,
    DateTime? updatedAt,
  }) => User(
    id: id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class FdrSubmissionRecord implements PersistedModel {
  FdrSubmissionRecord({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.fdrReference,
    required this.bankName,
    required this.amount,
    required this.status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  @override
  final String id;
  final String institutionId;
  final String institutionName;
  final String fdrReference;
  final String bankName;
  final int amount;
  final String status;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  FdrSubmissionRecord copyWith({
    String? institutionId,
    String? institutionName,
    String? fdrReference,
    String? bankName,
    int? amount,
    String? status,
    DateTime? updatedAt,
  }) => FdrSubmissionRecord(
    id: id,
    institutionId: institutionId ?? this.institutionId,
    institutionName: institutionName ?? this.institutionName,
    fdrReference: fdrReference ?? this.fdrReference,
    bankName: bankName ?? this.bankName,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class Alert implements PersistedModel {
  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.recipientId,
    required this.severity,
    this.isRead = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  @override
  final String id;
  final String title;
  final String message;
  final String recipientId;
  final String severity;
  final bool isRead;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  Alert copyWith({bool? isRead, DateTime? updatedAt}) => Alert(
    id: id,
    title: title,
    message: message,
    recipientId: recipientId,
    severity: severity,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
