import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'database_description.dart';
import 'string_util.dart';

// Describe the database schema
DatabaseDescription buildDatabaseDescription() {
  var dbDescription = DatabaseDescription(meta: const {
    DatabaseDescription.META_PREPEND_ID_COLUMN: true,
    DatabaseDescription.META_VERSION: 1
  });

  String _defaultFromObjectTranslator(DatabaseColumnSpecification dbColSpec) =>
      '${dbColSpec.dbTableInfo.objectName}.${snakeCaseToCamelCase(dbColSpec.name)}';
  String _zonedDateTimeTranslator(DatabaseColumnSpecification dbColSpec) =>
      '${dbColSpec.dbTableInfo.objectName}.${snakeCaseToCamelCase(dbColSpec.name)}?.toIso8601String(withColon: true)';
  dbDescription.addTableSpec(
      name: 'events',
      objectName: 'event',
      defaultFromObjectTranslator: _defaultFromObjectTranslator,
      specContent: [
        ['experiment_id', SqlLiteDatatype.INTEGER],
        ['experiment_server_id', SqlLiteDatatype.INTEGER],
        ['experiment_name', SqlLiteDatatype.TEXT],
        ['experiment_version', SqlLiteDatatype.INTEGER],
        ['schedule_time', SqlLiteDatatype.TEXT, _zonedDateTimeTranslator],
        ['response_time', SqlLiteDatatype.TEXT, _zonedDateTimeTranslator],
        ['uploaded', SqlLiteDatatype.INTEGER],
        ['group_name', SqlLiteDatatype.TEXT],
        ['action_trigger_id', SqlLiteDatatype.INTEGER],
        ['action_trigger_spec_id', SqlLiteDatatype.INTEGER],
        ['action_id', SqlLiteDatatype.INTEGER],
      ]);
  dbDescription.addTableSpec(
      name: 'outputs',
      objectName: 'responseEntry',
      parentObjectName: dbDescription.getDbTableInfo('events').objectName,
      specContent: [
        [
          'event_id',
          SqlLiteDatatype.INTEGER,
          (dbColSpec) => '${dbColSpec.dbTableInfo.parentObjectName}.id'
        ],
        [
          'text',
          SqlLiteDatatype.TEXT,
          (dbColSpec) => '${dbColSpec.dbTableInfo.objectName}.key'
        ],
        [
          'answer',
          SqlLiteDatatype.TEXT,
          (dbColSpec) => '${dbColSpec.dbTableInfo.objectName}.value'
        ]
      ]);
  dbDescription.addTableSpec(
      name: 'notifications',
      objectName: 'notificationHolder',
      defaultFromObjectTranslator: _defaultFromObjectTranslator,
      specContent: [
        ['alarm_time', SqlLiteDatatype.INTEGER],
        ['experiment_id', SqlLiteDatatype.INTEGER],
        ['notice_count', SqlLiteDatatype.INTEGER],
        ['timeout_millis', SqlLiteDatatype.INTEGER],
        ['notification_source', SqlLiteDatatype.TEXT],
        ['message', SqlLiteDatatype.TEXT],
        ['experiment_group_name', SqlLiteDatatype.TEXT],
        ['action_trigger_id', SqlLiteDatatype.INTEGER],
        ['action_id', SqlLiteDatatype.INTEGER],
        ['action_trigger_spec_id', SqlLiteDatatype.INTEGER],
        ['snooze_time', SqlLiteDatatype.INTEGER],
        ['snooze_count', SqlLiteDatatype.INTEGER],
      ]);
  return dbDescription;
}

/// How-tos
///
/// How to create a table?
String buildSqlCreateTable(
    DatabaseDescription dbDescription, String tableName) {
  var dbColumnSpecs = dbDescription.getDatabaseColumnSpecifications(tableName);
  var prependIdColumn =
      dbDescription.meta[DatabaseDescription.META_PREPEND_ID_COLUMN] ?? false;
  return '''
CREATE TABLE $tableName (
${prependIdColumn ? "_id INTEGER PRIMARY KEY AUTOINCREMENT,\n" : ""}'''
      '''
${dbColumnSpecs.map((dbColumn) => "${dbColumn.name} ${dbColumn.typeAsString}").join(', \n')}
  );
  ''';
}

/// How to get all column fields (of a table) from an object, in a default way?
/// The returned string is the representation of a map that can be used by Database.insert()
String buildDartFieldsMap(DatabaseDescription dbDescription, String tableName) {
  var dbColumnSpecs = dbDescription.getDatabaseColumnSpecifications(tableName);
  var prependIdColumn =
      dbDescription.meta[DatabaseDescription.META_PREPEND_ID_COLUMN] ?? false;
  if (prependIdColumn == false) {
    throw UnimplementedError();
  }
  // We don't include the column '_id' in the returned map representation because it will be automatically generated by sqlite.
  return '''
{
  ${dbColumnSpecs.map((dbColumn) => "'${dbColumn.name}': ${dbColumn.fromObject},").join('\n')}
}
  ''';
}

/// Dart code builder
class LocalDatabaseBuilder implements Builder {
  static const partOfFilename = 'local_database.dart';
  static const outputFilename = 'local_database.inc.dart';

  static AssetId _output(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      p.join('lib', 'storage', outputFilename),
    );
  }

  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      r'$lib$': const ['storage/$outputFilename'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    var dbDescription = buildDatabaseDescription();
    var eventsTableInfo = dbDescription.getDbTableInfo('events');
    var outputsTableInfo = dbDescription.getDbTableInfo('outputs');
    var notificationsTableInfo = dbDescription.getDbTableInfo('notifications');
    var formatter = DartFormatter();
    final content = formatter.format('''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by package:data_binding_builder|database_inc
// Code template can be found at package:data_binding_builder/src/local_database_builder.dart

part of '$partOfFilename';

var _dbVersion = ${dbDescription.meta[DatabaseDescription.META_VERSION]};

Future<void> _onCreate(Database db, int version) async {
${dbDescription.tableNames.map((tableName) => 'await db.execute(\'\'\'${buildSqlCreateTable(dbDescription, tableName)}\'\'\');').join('\n')}
}

Future<void> _insertEvent(Database db, Event ${eventsTableInfo.objectName}) async {
  try {
    db.transaction((txn) async {
      ${eventsTableInfo.objectName}.id = await txn.insert(
      'events',
      ${buildDartFieldsMap(dbDescription, 'events')},
      conflictAlgorithm: ConflictAlgorithm.replace,
      );
      var batch = txn.batch();
      for (var ${outputsTableInfo.objectName} in ${outputsTableInfo.parentObjectName}.responses.entries) {
        batch.insert('outputs', 
        ${buildDartFieldsMap(dbDescription, 'outputs')},
        conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  } catch (e) {
    ${eventsTableInfo.objectName}.id = null;
    rethrow;
  }
}

Future<int> _insertNotification(Database db, NotificationHolder ${notificationsTableInfo.objectName}) async {
  try {
    return db.transaction((txn) {
      return txn.insert(
      'notifications',
      ${buildDartFieldsMap(dbDescription, 'notifications')},
      conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  } catch (_) {
    rethrow;
  }
}

Future<int> _removeNotification(Database db, int id) async {
  return db.transaction((txn) {
    return txn.delete('notifications', where: '_id = \$id');
  }).catchError((e, st) => null);
}

Future<int> _removeAllNotifications(Database db) async {
  return db.transaction((txn) {
    return txn.delete('notifications');
  }).catchError((e, st) => null);
}

List<NotificationHolder> _buildNotificationHolder(List<Map<String, dynamic>> res) =>
  res.map((json) => NotificationHolder.fromJson({
      'id': json['_id'],
      'alarmTime': json['alarm_time'],
      'experimentId': json['experiment_id'],
      'noticeCount': json['notice_count'],
      'timeoutMillis': json['timeout_millis'],
      'notificationSource': json['notification_source'],
      'message': json['message'],
      'experimentGroupName': json['experiment_group_name'],
      'actionTriggerId': json['action_trigger_id'],
      'actionId': json['action_id'],
      'actionTriggerSpecId': json['action_trigger_spec_id'],
      'snoozeTime': json['snooze_time'],
      'snoozeCount': json['snooze_count'],
  })).toList(growable: false);

Future<NotificationHolder> _getNotification(Database db, int id) {
  return db.transaction((txn) async {
    List<Map<String, dynamic>> res = await txn.query('notifications', where: '_id = \$id');
    if (res == null || res.isEmpty) return null;
    return _buildNotificationHolder(res).first;
  }).catchError((e, st) => null);
}

Future<List<NotificationHolder>> _getAllNotifications(Database db) {
  return db.transaction((txn) async {
    List<Map<String, dynamic>> res = await txn.query('notifications');
    if (res == null || res.isEmpty) return <NotificationHolder>[];
    return _buildNotificationHolder(res);
  }).catchError((e, st) => <NotificationHolder>[]);
}

Future<List<NotificationHolder>> _getAllNotificationsForExperiment(Database db, int expId) {
  return db.transaction((txn) async {
    List<Map<String, dynamic>> res = await txn.query('notifications', where: 'experiment_id = \$expId');
    if (res == null || res.isEmpty) return <NotificationHolder>[];
    return _buildNotificationHolder(res);
  }).catchError((e, st) => <NotificationHolder>[]);
}

    ''');

    final output = _output(buildStep);
    await buildStep.writeAsString(output, content);
  }
}
