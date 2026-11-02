/// Splits one display name into first/last name parts.
///
/// Google returns a single `displayName`, but the profile form stores and
/// edits `firstName`/`lastName` separately. Stuffing the whole display name
/// into *First name* (the old behavior) made every Google account look like it
/// had no surname and persisted the full name on the next save.
///
/// Rules: trim, collapse internal whitespace, first token is the first name,
/// the remainder (which may itself contain spaces) is the last name. A
/// single-token name yields an empty last name rather than repeating itself.
/// Kept pure (no Firebase/Flutter types) so it is unit-testable.
({String firstName, String lastName}) splitDisplayName(String? displayName) {
  final normalized = (displayName ?? '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return (firstName: '', lastName: '');
  }
  final firstSpace = normalized.indexOf(' ');
  if (firstSpace == -1) {
    return (firstName: normalized, lastName: '');
  }
  return (
    firstName: normalized.substring(0, firstSpace),
    lastName: normalized.substring(firstSpace + 1),
  );
}
