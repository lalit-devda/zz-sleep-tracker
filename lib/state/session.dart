import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dartstream_client/dartstream_client.dart';
import '../config.dart';

enum SessionStatus { idle, signingIn, authenticated, error }

class Session extends ChangeNotifier {
  SessionStatus status = SessionStatus.idle;
  String? errorMessage;
  DartStreamConnection? connection;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  Future<void> signUp(String email, String password) async {
    status = SessionStatus.signingIn;
    errorMessage = null;
    notifyListeners();
    try {
      connection = await DartStreamClient.signUp(
        config: AppConfig.dartStream,
        email: email,
        password: password,
      );
      status = SessionStatus.authenticated;
    } on DartStreamApiException catch (e) {
      try {
        final decoded = jsonDecode(e.body);
        errorMessage = decoded['message'] ?? decoded['error'] ?? e.body;
      } catch (_) {
        errorMessage = e.body;
      }
      status = SessionStatus.error;
    } catch (e) {
      errorMessage = e.toString();
      status = SessionStatus.error;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    status = SessionStatus.signingIn;
    errorMessage = null;
    notifyListeners();
    try {
      connection = await DartStreamClient.signIn(
        config: AppConfig.dartStream,
        email: email,
        password: password,
      );
      status = SessionStatus.authenticated;
    } on DartStreamApiException catch (e) {
      try {
        final decoded = jsonDecode(e.body);
        errorMessage = decoded['message'] ?? decoded['error'] ?? e.body;
      } catch (_) {
        errorMessage = e.body;
      }
      status = SessionStatus.error;
    } catch (e) {
      errorMessage = e.toString();
      status = SessionStatus.error;
    }
    notifyListeners();
  }

  void signOut() {
    connection = null;
    status = SessionStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}
