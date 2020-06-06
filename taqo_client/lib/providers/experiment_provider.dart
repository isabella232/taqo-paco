import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:taqo_client/service/experiment_paused_status_cache.dart';
import 'package:taqo_common/model/experiment.dart';

import '../service/alarm/taqo_alarm.dart' as taqo_alarm;
import '../service/platform_service.dart' as platform_service;
import '../service/experiment_service.dart';

class ExperimentProvider with ChangeNotifier {
  ExperimentService _service;
  List<Experiment> _experiments;
  ExperimentPausedStatusCache _pausedStatusCache;

  /// A [Provider] with the user's joined Experiments
  ExperimentProvider.withRunningExperiments() {
    _initWithRunning();
  }

  Future _initWithRunning() async {
    _service = await ExperimentService.getInstance();
    _experiments = _service.getJoinedExperiments();
    _pausedStatusCache = await ExperimentPausedStatusCache.getInstance();
    notifyListeners();

    // TODO Not dynamically updated
    platform_service.databaseImpl.then((db) {
      db.getAllNotifications().then((all) {
        for (Experiment e in _experiments) {
          final n = all.firstWhere((n) => n.experimentId == e.id,
              orElse: () => null);
          if (n != null) {
            e.active = n.isActive;
          }
        }
        notifyListeners();
      });
    });
  }

  /// A [Provider] with the Experiments available to join
  ExperimentProvider.withAvailableExperiments() {
    _initWithAvailable();
  }

  Future _initWithAvailable() async {
    _service = await ExperimentService.getInstance();
    _experiments = await _service.getExperimentsFromServer();
    _pausedStatusCache = await ExperimentPausedStatusCache.getInstance();
    notifyListeners();
  }

  List<Experiment> get experiments => _experiments;

  Future<void> setPausedAndNotifyListeners(Experiment e, bool value) async {
    await _pausedStatusCache.setPaused(e, value);
    notifyListeners();
    taqo_alarm.schedule();
  }

  void stopExperiment(Experiment e) {
    _service.stopExperiment(e);
    _experiments.remove(e);
    notifyListeners();
  }
}
