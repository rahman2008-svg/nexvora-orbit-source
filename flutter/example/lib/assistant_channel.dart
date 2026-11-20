import 'package:flutter/services.dart';

/// Bridge to the native digital-assistant plumbing (VoiceInteractionService).
///
/// The native side launches ORBIT in "assistant mode" on a power-button hold /
/// assist gesture; this exposes whether the current launch was an assist
/// invocation, lets the app become the default assistant (RoleManager), and
/// delivers assist invocations that arrive while ORBIT is already running.
class AssistantChannel {
  static const MethodChannel _ch = MethodChannel('orbit/assistant');

  /// Registers [onAssist], called when the system invokes ORBIT as the assistant
  /// while the app is already running (singleTop onNewIntent).
  static void setAssistHandler(void Function() onAssist) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onAssist') onAssist();
      return null;
    });
  }

  /// True (once) if this launch came from an assistant invocation.
  static Future<bool> consumeAssistLaunch() async =>
      (await _ch.invokeMethod<bool>('consumeAssistLaunch')) ?? false;

  /// Whether ORBIT currently holds the default-assistant role (Android 10+).
  static Future<bool> isAssistant() async =>
      (await _ch.invokeMethod<bool>('isAssistant')) ?? false;

  /// Asks the user to make ORBIT the default assistant. Returns true if granted.
  /// On OEMs without an in-app dialog this opens the relevant Settings screen
  /// and returns false.
  static Future<bool> requestAssistantRole() async =>
      (await _ch.invokeMethod<bool>('requestAssistantRole')) ?? false;

  /// Opens the system assistant/voice-input settings as a manual fallback.
  static Future<void> openAssistantSettings() =>
      _ch.invokeMethod('openAssistantSettings');
}
