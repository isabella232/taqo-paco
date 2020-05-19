import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:taqo_common/model/event.dart';
import 'package:taqo_common/model/event_save_outcome.dart';
import 'package:taqo_common/net/paco_api.dart';
import 'package:taqo_common/net/google_auth.dart';
import 'package:taqo_common/storage/base_database.dart';

final logger = Logger('SyncService');

class SyncEvent {}

class SyncService {
  static final SyncService _instance = SyncService._();

  final _syncEventsController = StreamController<SyncEvent>();
  Completer<bool> _completer;

  SyncService._() {
    StreamSubscription<SyncEvent> syncEventsSubscription;
    syncEventsSubscription = _syncEventsController.stream.listen((event) {
      syncEventsSubscription.pause();
      var completer = _completer;
      _completer = null;
      __syncData().then((value) {
        completer.complete(value);
        syncEventsSubscription.resume();
      }, onError: (e, st) {
        completer.completeError(e, st);
        syncEventsSubscription.resume();
      });
    });
  }

  Future<bool> _syncData() {
    if (_completer == null) {
      _completer = Completer();
      _syncEventsController.add(SyncEvent());
    }
    return _completer.future;
  }

  static Future<bool> syncData() => _instance._syncData();

  static List<EventSaveOutcome> _parseSyncResponse(PacoResponse response) {
    final outcomes = <EventSaveOutcome>[];
    try {
      //print(response.body);
      final List responseOutcomes = jsonDecode(response.body);
      //print(responseOutcomes);
      for (var json in responseOutcomes) {
        //print(json);
        outcomes.add(EventSaveOutcome.fromJson(json));
      }
    } catch (e) {
      print(e);
    }
    //print(outcomes);
    return outcomes;
  }

  static List<Event> _getUploadedEvents(
      List<Event> allEvents, List<EventSaveOutcome> outcomes) {
    final uploaded = <Event>[];
    for (var i = 0; i < outcomes.length; i++) {
      if (outcomes[i].status) {
        uploaded.add(allEvents[i]);
      } else {
        logger.warning('Event failed to upload: ${outcomes[i].errorMessage}'
            'Event was: ${allEvents[i].toString()}');
      }
    }
    return uploaded;
  }

  static Future<bool> __syncData() async {
    logger.info("Start syncing data...");
    final db = await DatabaseFactory.makeDatabaseOrFuture();
    final events = await db.getUnuploadedEvents();
    final pacoApi = PacoApi();
    final gauth = GoogleAuth();

    // TODO: handle upload limit size
    if (events.length > 0) {
      final response = await gauth.isAuthenticated
          ? await pacoApi.postEvents(jsonEncode(events))
          : await pacoApi.postEventsPublic(jsonEncode(events));
      if (response.isSuccess) {
        final outcomes = _parseSyncResponse(response);
        if (outcomes.length == events.length) {
          final eventList = events.toList();
          await db
              .markEventsAsUploaded(_getUploadedEvents(eventList, outcomes));
        } else {
          logger.warning(
              'Event upload result length differs from number of Events uploaded');
        }
        logger.info('Syncing complete.');
        return true;
      } else if (response.isFailure) {
        logger.warning('Could not complete upload of events '
            'because of the following error: '
            '${response.body}\n');
        return false;
      } else {
        logger.warning('Could not complete upload of events. '
            'The server returns the following response: '
            '${response.statusCode} ${response.statusMsg}\n${response.body}\n');
        return false;
      }
    } else {
      logger.info('There is no unsynced data.');
      return true;
    }
  }
}
