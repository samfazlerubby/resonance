import 'package:flutter/material.dart';

/// Lets any widget (including the full-screen player, which sits above the
/// tabs) open a page inside the currently selected tab.
class AppNav {
  static final rootKey = GlobalKey<NavigatorState>();
  static final tabKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());
  static final ValueNotifier<int> tab = ValueNotifier(0);

  static NavigatorState? get _tabNav => tabKeys[tab.value].currentState;

  static Future<void> push(Widget page) async {
    // Close the full-screen player / sheets first if they're open.
    rootKey.currentState?.popUntil((r) => r.isFirst);
    await _tabNav?.push(MaterialPageRoute(builder: (_) => page));
  }

  /// Handles the Android back button: pop inside the tab first.
  static bool handleBack() {
    final nav = _tabNav;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    if (tab.value != 0) {
      tab.value = 0;
      return true;
    }
    return false;
  }
}
