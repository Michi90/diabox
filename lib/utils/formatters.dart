String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitHours = twoDigits(duration.inHours.remainder(24));

  if (duration.inDays > 0) {
    final days = duration.inDays;
    final dayString = days == 1 ? 'Tag' : 'Tage';
    return '$days $dayString $twoDigitHours:$twoDigitMinutes';
  } else { // If duration is less than a day, only show hours and minutes
    return '$twoDigitHours:$twoDigitMinutes';
  }
}

String formatDateTime(DateTime dateTime) {
  return '${dateTime.toLocal().day.toString().padLeft(2, '0')}.${dateTime.toLocal().month.toString().padLeft(2, '0')}.${dateTime.toLocal().year.toString().substring(2)} ${dateTime.toLocal().hour.toString().padLeft(2, '0')}:${dateTime.toLocal().minute.toString().padLeft(2, '0')}';
}

String formatOffsetDuration(int totalMinutes) {
  if (totalMinutes <= 0) {
    return 'Jetzt'; // Or some other appropriate message
  }

  int days = totalMinutes ~/ (24 * 60);
  int remainingMinutes = totalMinutes % (24 * 60);
  int hours = remainingMinutes ~/ 60;
  int minutes = remainingMinutes % 60;

  List<String> parts = [];
  if (days > 0) {
    parts.add('$days Tag${days == 1 ? '' : 'e'}');
  }
  if (hours > 0) {
    parts.add('$hours Stunde${hours == 1 ? '' : 'n'}');
  }
  if (minutes > 0) {
    parts.add('$minutes Minute${minutes == 1 ? '' : 'n'}');
  }

  if (parts.isEmpty) {
    return 'Weniger als 1 Minute'; // Should not happen if totalMinutes > 0
  }

  return '${parts.join(' und ')} vorher';
}