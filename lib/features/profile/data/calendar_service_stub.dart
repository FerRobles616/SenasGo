/// En web/escritorio no hay calendario del dispositivo integrado.
bool get calendarSupported => false;

Future<bool> addPracticeReminder({
  required int weekday,
  required int hour,
  required int minute,
}) async =>
    false;
