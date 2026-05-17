// Enums for the Swap/Reassign Task dialog. Wire values match the
// TaskReassignmentReason and TaskReassignmentDuration enums in the
// Prisma schema.

enum TaskReassignmentReason {
  sickLeave('SICK_LEAVE', 'Sick leave'),
  offDay('OFF_DAY', 'Off day'),
  vacation('VACATION', 'Vacation'),
  emergency('EMERGENCY', 'Emergency'),
  shiftBalancing('SHIFT_BALANCING', 'Shift balancing'),
  other('OTHER', 'Other');

  const TaskReassignmentReason(this.wire, this.label);
  final String wire;
  final String label;
}

enum TaskReassignmentDuration {
  today('TODAY', 'Today only'),
  thisShift('THIS_SHIFT', 'This shift'),
  permanent('PERMANENT', 'Permanent'),
  other('OTHER', 'Other');

  const TaskReassignmentDuration(this.wire, this.label);
  final String wire;
  final String label;
}
