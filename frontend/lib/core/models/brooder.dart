// Brooder domain enums used by the Log Occurrence dialog and the
// weekly report card. Mirrors the BrooderOccurrenceType /
// BrooderOccurrenceSeverity enums in the Prisma schema.

enum BrooderOccurrenceType {
  mortality('MORTALITY', 'Mortality'),
  disease('DISEASE', 'Disease'),
  temperatureIssue('TEMPERATURE_ISSUE', 'Temperature issue'),
  feedIssue('FEED_ISSUE', 'Feed issue'),
  waterIssue('WATER_ISSUE', 'Water issue'),
  equipmentFailure('EQUIPMENT_FAILURE', 'Equipment failure'),
  vaccination('VACCINATION', 'Vaccination'),
  theft('THEFT', 'Theft'),
  other('OTHER', 'Other');

  const BrooderOccurrenceType(this.wire, this.label);
  final String wire;
  final String label;
}

enum BrooderOccurrenceSeverity {
  low('LOW', 'Low'),
  medium('MEDIUM', 'Medium'),
  high('HIGH', 'High'),
  critical('CRITICAL', 'Critical');

  const BrooderOccurrenceSeverity(this.wire, this.label);
  final String wire;
  final String label;
}
