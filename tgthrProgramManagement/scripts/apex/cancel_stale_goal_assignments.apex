// Cancel stale GoalAssignment records in PRODUCTION
// Criteria: CreatedDate < 2026-01-01 AND Status != 'Cancelled'
// NOTE: LastModifiedDate filter removed — original script missed records due to sharing rules.
//       CancelStaleGoalAssignments.cls runs WITHOUT SHARING to reach ALL records in the org.
//
// STEP 1: Deploy CancelStaleGoalAssignments.cls to production.
// STEP 2: Run cancel_stale_goal_assignments_dryrun.apex and confirm the count.
// STEP 3: Run this script.
CancelStaleGoalAssignments.run(false);
