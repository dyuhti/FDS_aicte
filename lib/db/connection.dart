import 'dart:developer' as developer;

import 'models.dart';
import 'repository.dart';

class Database {
  Database({String? databaseUrl})
    : databaseUrl =
          databaseUrl ??
          const String.fromEnvironment(
            'DATABASE_URL',
            defaultValue: 'memory://demo',
          ),
      users = InMemoryRepository<User>(),
      submissions = InMemoryRepository<FdrSubmissionRecord>(),
      alerts = InMemoryRepository<Alert>();

  final String databaseUrl;
  final InMemoryRepository<User> users;
  final InMemoryRepository<FdrSubmissionRecord> submissions;
  final InMemoryRepository<Alert> alerts;
  bool _connected = false;

  Future<void> connect() async {
    if (_connected) return;
    _connected = true;
    developer.log(
      'Connected to database (in-memory): $databaseUrl',
      name: 'aicte.db',
    );
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    developer.log('Disconnected from database', name: 'aicte.db');
  }

  bool isConnected() => _connected;
}

final Database _database = Database();

Database getDb() => _database;
