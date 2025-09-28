import 'package:intl/intl.dart';

class DateService {
  // Firestore format (zero-padded, good for sorting & queries)
  static final _storageFormat = DateFormat('yyyy-MM-dd');
  // Month format (zero-padded month)
  static final _monthFormat = DateFormat('yyyy-MM');
  // Time format
  static final _timeFormat = DateFormat('HH:mm');

  /// Convert DateTime -> Firestore string (yyyy-MM-dd)
  static String toStorageDate(DateTime date) {
    return _storageFormat.format(date);
  }

  /// Format for month display (yyyy-MM)
  static String toMonthString(DateTime date) {
    return _monthFormat.format(date);
  }

  /// Format time for UI (HH:mm)
  static String toDisplayTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Get number of days in a month
  static int getDaysInMonth(int year, int month) {
    final nextMonth = month < 12 ? month + 1 : 1;
    final nextMonthYear = month < 12 ? year : year + 1;
    final lastDayOfMonth = DateTime(nextMonthYear, nextMonth, 1).subtract(const Duration(days: 1));
    return lastDayOfMonth.day;
  }

  /// Add this inside DateService
  static DateTime parseStorageDate(String dateStr) {
    return _storageFormat.parse(dateStr);
  }
}
