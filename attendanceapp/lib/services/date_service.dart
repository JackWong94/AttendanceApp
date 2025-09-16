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
}
