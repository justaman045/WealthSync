/// Actions a home-screen widget tap can ask the app to perform.
enum WidgetAction {
  /// The `+ Add` shortcut: start a new transaction.
  addTransaction,
}

/// Parses the deep link carried by a home-widget tap.
///
/// The widget body launches the app without a URI (it is a plain launcher
/// intent), so `null` means "just open the app" — there is nothing to route.
/// Only the widget's own scheme and known hosts map to an action: an unknown
/// link from a stale widget (or any other app) must not be guessed into some
/// screen.
WidgetAction? parseWidgetAction(Uri? uri) {
  if (uri == null) return null;
  // `Uri` lower-cases the scheme, so `homeWidget://` reads as `homewidget`.
  if (uri.scheme.toLowerCase() != 'homewidget') return null;
  switch (uri.host) {
    case 'add_transaction':
      return WidgetAction.addTransaction;
  }
  return null;
}
