import 'dart:async';
import 'dart:io';
import 'package:taqo_common/model/event.dart';

import 'tesp_message_socket.dart';
import 'tesp_message.dart';

abstract class TespRequestHandler {
  FutureOr<TespResponse> handle(TespRequest tespRequest);
}

mixin TespRequestHandlerMixin implements TespRequestHandler {
  FutureOr<TespResponse> palAddEvents(List<Event> events);
  FutureOr<TespResponse> palPause();
  FutureOr<TespResponse> palResume();
  FutureOr<TespResponse> palWhiteListDataOnly();
  FutureOr<TespResponse> palAllData();

  FutureOr<TespResponse> alarmSchedule();
  FutureOr<TespResponse> alarmCancel(int alarmId);
  FutureOr<TespResponse> alarmSelectAll();
  FutureOr<TespResponse> alarmSelectById(int alarmId);

  FutureOr<TespResponse> notificationCheckActive();
  FutureOr<TespResponse> notificationCancel(int notificationId);
  FutureOr<TespResponse> notificationCancelByExperiment(int experimentId);
  FutureOr<TespResponse> notificationSelectAll();
  FutureOr<TespResponse> notificationSelectById(int notificationId);
  FutureOr<TespResponse> notificationSelectByExperiment(int experimentId);

  FutureOr<TespResponse> createMissedEvent(Event event);

  TespResponse ping() {
    return TespResponseSuccess();
  }

  @override
  FutureOr<TespResponse> handle(TespRequest tespRequest) {
    switch (tespRequest.runtimeType) {
      case TespRequestPalAddEvents:
        return palAddEvents((tespRequest as TespRequestPalAddEvents).events);
      case TespRequestPalPause:
        return palPause();
      case TespRequestPalResume:
        return palResume();
      case TespRequestPalWhiteListDataOnly:
        return palWhiteListDataOnly();
      case TespRequestPalAllData:
        return palAllData();
      case TespRequestPing:
        return ping();
      case TespRequestAlarmSchedule:
        return alarmSchedule();
      case TespRequestAlarmCancel:
        return alarmCancel((tespRequest as TespRequestAlarmCancel).alarmId);
      case TespRequestAlarmSelectAll:
        return alarmSelectAll();
      case TespRequestAlarmSelectById:
        return alarmSelectById(
            (tespRequest as TespRequestAlarmSelectById).alarmId);
      case TespRequestNotificationCheckActive:
        return notificationCheckActive();
      case TespRequestNotificationCancel:
        return notificationCancel(
            (tespRequest as TespRequestNotificationCancel).notificationId);
      case TespRequestNotificationCancelByExperiment:
        return notificationCancelByExperiment(
            (tespRequest as TespRequestNotificationCancelByExperiment)
                .experimentId);
      case TespRequestNotificationSelectAll:
        return notificationSelectAll();
      case TespRequestNotificationSelectById:
        return notificationSelectById(
            (tespRequest as TespRequestNotificationSelectById).notificationId);
      case TespRequestNotificationSelectByExperiment:
        return notificationSelectByExperiment(
            (tespRequest as TespRequestNotificationSelectByExperiment)
                .experimentId);
      case TespRequestCreateMissedEvent:
        return createMissedEvent(
            (tespRequest as TespRequestCreateMissedEvent).event);
      default:
        return TespResponseInvalidRequest.withPayload(
            'Unsupported TespRequest type');
    }
  }
}

class TespServer {
  final TespRequestHandler _tespRequestHandler;
  ServerSocket _serverSocket;
  final Duration timeoutMillis;

  TespServer(this._tespRequestHandler,
      {this.timeoutMillis = const Duration(milliseconds: 500)});

  int get port => _serverSocket?.port;

  Future<void> serve(
      {dynamic address = '127.0.0.1',
      int port = 0,
      int backlog = 0,
      bool v6Only = false,
      bool shared = false}) async {
    _serverSocket = await ServerSocket.bind(address, port,
        backlog: backlog, v6Only: v6Only, shared: shared);

    _serverSocket.listen((socket) {
      var tespSocket = TespMessageSocket<TespRequest, TespResponse>(socket,
          timeoutMillis: timeoutMillis, isAsync: false);
      StreamSubscription<TespRequest> subscription;
      subscription = tespSocket.stream.listen((event) {
        var tespRequest = event as TespRequest;
        FutureOr<TespResponse> tespResponse;
        try {
          tespResponse = _tespRequestHandler.handle(tespRequest);
        } catch (e) {
          tespSocket?.add(TespResponseError(
              TespResponseError.tespServerErrorUnknown, e.toString()));
          return;
        }

        if (tespResponse is Future<TespResponse>) {
          subscription.pause();

          tespResponse
              .then((value) => tespSocket?.add(value),
                  onError: (e) => tespSocket?.add(TespResponseError(
                      TespResponseError.tespServerErrorUnknown, e.toString())))
              .whenComplete(subscription.resume);
        } else {
          tespSocket?.add(tespResponse);
        }
      }, onError: (e) {
        tespSocket?.add(TespResponseInvalidRequest.withPayload(e.toString()));
        if (!(e is CastError)) {
          subscription.cancel();
          tespSocket?.close();
        }
      }, onDone: () => tespSocket?.close());

      tespSocket.done.catchError((e) {
        subscription.cancel();
        socket.destroy();
        tespSocket = null;
      }, test: (e) => e is SocketException);
    });
  }

  Future<void> close() async {
    await _serverSocket.close();
    _serverSocket = null;
  }
}
