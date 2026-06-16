// Stub for flutter_sms_inbox on web
class SmsQuery {
  Future<List<SmsMessage>> querySms(
      {List<SmsQueryKind>? kinds, int? count}) async {
    return [];
  }
}

class SmsMessage {
  String? get body => '';
  String? get sender => '';
  DateTime? get date => null;
}

class SmsQueryKind {
  static const inbox = SmsQueryKind._();
  const SmsQueryKind._();
}
