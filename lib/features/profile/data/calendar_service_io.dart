import 'package:add_2_calendar/add_2_calendar.dart';

bool get calendarSupported => true;

/// Crea un recordatorio semanal local. La próxima fecha se calcula a partir
/// del día elegido; si ya pasó la hora de hoy, empieza la semana siguiente.
Future<bool> addPracticeReminder({
  required int weekday,
  required int hour,
  required int minute,
}) async {
  final now = DateTime.now();
  var daysAhead = (weekday - now.weekday) % 7;
  if (daysAhead == 0 &&
      (now.hour > hour || (now.hour == hour && now.minute >= minute))) {
    daysAhead = 7;
  }
  final start = DateTime(
    now.year,
    now.month,
    now.day + daysAhead,
    hour,
    minute,
  );
  final event = Event(
    title: 'Practicar LSPy en SeñasGo',
    description: 'Diez minutos para practicar Lengua de Señas Paraguaya.',
    location: 'SeñasGo',
    startDate: start,
    endDate: start.add(const Duration(minutes: 10)),
    recurrence: Recurrence(frequency: Frequency.weekly),
    iosParams: const IOSParams(reminder: Duration(minutes: 15)),
  );
  return Add2Calendar.addEvent2Cal(event);
}
