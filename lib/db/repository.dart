/// In-memory implementation used for demo. Swap with SQLAlchemy/MongoDB repository for production.
library;

import 'dart:developer' as developer;
import 'dart:math';

import 'models.dart';

abstract interface class Repository<T extends PersistedModel> {
  Future<T> create(T record);
  Future<T> getById(String id);
  Future<List<T>> getAll();
  Future<T> update(String id, T record);
  Future<void> delete(String id);
  String generateId();
}

class RepositoryException implements Exception {
  RepositoryException(this.message);

  final String message;

  @override
  String toString() => 'RepositoryException: $message';
}

class NotFoundException extends RepositoryException {
  NotFoundException(String entity, String id)
    : super('$entity with id "$id" was not found');
}

class ValidationException extends RepositoryException {
  ValidationException(super.message);
}

class InMemoryRepository<T extends PersistedModel> implements Repository<T> {
  final Map<String, T> _records = <String, T>{};

  @override
  Future<T> create(T record) async {
    if (record.id.trim().isEmpty) {
      throw ValidationException('Record id must not be empty');
    }
    if (_records.containsKey(record.id)) {
      throw ValidationException('Record "${record.id}" already exists');
    }
    _records[record.id] = record;
    developer.log('Created record ${record.id}', name: 'aicte.db.repository');
    return record;
  }

  @override
  Future<T> getById(String id) async {
    final record = _records[id];
    if (record == null) {
      throw NotFoundException(T.toString(), id);
    }
    return record;
  }

  @override
  Future<List<T>> getAll() async =>
      List<T>.unmodifiable(_records.values.toList(growable: false));

  @override
  Future<T> update(String id, T record) async {
    if (!_records.containsKey(id)) {
      throw NotFoundException(T.toString(), id);
    }
    if (record.id != id) {
      throw ValidationException('Updated record id must match "$id"');
    }
    _records[id] = record;
    developer.log('Updated record $id', name: 'aicte.db.repository');
    return record;
  }

  @override
  Future<void> delete(String id) async {
    if (_records.remove(id) == null) {
      throw NotFoundException(T.toString(), id);
    }
    developer.log('Deleted record $id', name: 'aicte.db.repository');
  }

  @override
  String generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
