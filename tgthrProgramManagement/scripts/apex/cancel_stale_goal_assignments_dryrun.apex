// DRY RUN — Cancel stale GoalAssignment records
// Runs WITHOUT SHARING via CancelStaleGoalAssignments class to see ALL records, not just user-visible ones.
// Deploy CancelStaleGoalAssignments.cls first, then run this.
CancelStaleGoalAssignments.run(true);
