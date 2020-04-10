import 'package:uuid/uuid.dart';

abstract class Snapshot {
  static const String ModifiedAt = 'modifiedAt';
  static const String CreatedAt = 'createdAt';
  static DateTime utcDateNow() => DateTime.now().toUtc();
  static int utcDateMillisecond() => utcDateNow().millisecondsSinceEpoch;
}

mixin DocumentSnapshotMixin {
  Map<String, dynamic> get data;
  DocumentReferenceMixin get reference;
  DateTime get createdAt => data[Snapshot.CreatedAt] ?? null;
  int get modifiedAt => data[Snapshot.ModifiedAt] ?? null;
  set modifiedAt(int value) {
    data[Snapshot.ModifiedAt] = value;
  }
}

mixin DocumentReferenceMixin {
  String get id;
  Future<void> updateData(
    Map<String, dynamic> data,
  );
  Future<void> deleteObject();
}

mixin SnapshotAccessorMixin {
  /// Keeps fields that were updated but were not commited on original data
  final Map<String, dynamic> updatedFields = {};

  /// Lists references in updatedFields are passed as is and modifying them well break the logic
  Map<String, dynamic> get updatedFieldsCopy => Map.from(updatedFields);

  ///When this parameter is true, first checks [updatedFields] for value
  ///If there is no entriy in [updatedFields], only then tries to returns value from original data
  bool get returnUpdatedValuesEvenIfNotSaved;

  DocumentSnapshotMixin get snapshot;

  String get id => snapshot.reference.id;

  DocumentReferenceMixin get reference => snapshot.reference;

  operator [](String key) {
    if (this.returnUpdatedValuesEvenIfNotSaved &&
        this.updatedFields.containsKey(key)) {
      return this.updatedFields[key];
    }
    return (snapshot.data != null && snapshot.data.containsKey(key))
        ? snapshot.data[key]
        : null;
  }

  operator []=(String key, dynamic value) {
    final prevValue = snapshot.data[key];
    if (prevValue != null && !(isCollection(prevValue)) && prevValue == value) {
      return;
    }
    updatedFields[key] = value;
  }

  /// Removes all pending updates on the data
  reset() => this.updatedFields.clear();

  /// Saves all pending updates on the snapshot and asks reference to update backing data
  Future save([bool forceUpdateAllFields = false]) async {
    if (!forceUpdateAllFields && updatedFields.isEmpty) return;
    snapshot.data.addAll(updatedFields);
    await snapshot.reference
        .updateData(forceUpdateAllFields ? snapshot.data : updatedFields);
    updatedFields.clear();
  }

  List<String> getAsStringList(String key) {
    if (this[key] == null) return null;
    return List<String>.from(this[key]);
  }

  @override
  String toString() {
    return '${this.id}';
  }
}

mixin TempValuesMixin {
  final Map<String, dynamic> _tempValues = {};
  getTemp(String key, [dynamic defaultValue]) =>
      _tempValues[key] ?? defaultValue;
  setTemp(String key, dynamic value) => _tempValues[key] = value;
}

isCollection(dynamic value) {
  return (value is Iterable) || (value is Map);
}

class MemorySnapshot with DocumentSnapshotMixin {
  final MemoryReference _reference;

  MemorySnapshot(Map<String, dynamic> data)
      : _reference = MemoryReference(data);

  @override
  DocumentReferenceMixin get reference => _reference;

  @override
  Map<String, dynamic> get data => _reference.data;
}

class MemoryReference with DocumentReferenceMixin {
  final Map<String, dynamic> data;
  final String uuId = Uuid().v4();
  MemoryReference(this.data);

  @override
  deleteObject() async {}

  @override
  String get id => data['id'] ?? uuId;

  @override
  updateData(Map<String, dynamic> data, {bool replace = false}) async {
    for (var key in data.keys) {
      this.data[key] = data[key];
    }
  }
}
