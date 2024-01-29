import 'dart:async';

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectionStatusSingleton {
  /// Creates the single instance by calling the `_internal` constructor specified below
  static final ConnectionStatusSingleton _singleton = new ConnectionStatusSingleton._internal();
  ConnectionStatusSingleton._internal() {
    initialize();
  }

  /// Retrieves the singleton instance
  static ConnectionStatusSingleton getInstance() => _singleton;

  /// Tracks the current connection status
  bool hasConnection = false;

  /// Allows subscribing to connection changes
  StreamController connectionChangeController = new StreamController.broadcast();

  /// flutter_connectivity object
  late InternetConnection _internetConnection;

  bool _initialized = false;

  /// Hooks into [_connectivity]'s Stream to listen for changes
  /// and checks the connection status out of the gate
  void initialize() {
    if (_initialized) return;

    _internetConnection = InternetConnection.createInstance(
      customCheckOptions: [
        InternetCheckOption(uri: Uri.parse('https://google.com')),
      ],
      useDefaultOptions: false,
    );

    _internetConnection.onStatusChange.listen(_connectionChange);
    checkConnection();

    _initialized = true;
  }

  Stream get connectionChange => connectionChangeController.stream;

  /// A clean up method to close our StreamController
  void dispose() {
    connectionChangeController.close();
  }

  /// [_connectivity]'s listener
  void _connectionChange(InternetStatus status) => checkConnection();

  /// Tests to verify if there's indeed connected to the internet
  Future<bool> checkConnection() async {
    bool previousConnection = hasConnection;

    try {
      hasConnection = await _internetConnection.hasInternetAccess;
    } catch(_) {
      hasConnection = false;
    }

    //The connection status changed send out an update to all listeners
    if (previousConnection != hasConnection) {
      connectionChangeController.add(hasConnection);
    }

    return hasConnection;
  }
}
