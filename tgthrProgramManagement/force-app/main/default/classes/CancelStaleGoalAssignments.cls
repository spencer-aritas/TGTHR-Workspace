// Executes without sharing to bypass record-level sharing rules on GoalAssignment.
// Called from anonymous Apex: cancel_stale_goal_assignments_v2.apex
public without sharing class CancelStaleGoalAssignments {

    public static void run(Boolean dryRun) {
        Datetime cutoff = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);

        List<SObject> stale = Database.query(
            'SELECT Id, CustomGoalName, Status, CreatedDate, LastModifiedDate ' +
            'FROM GoalAssignment ' +
            'WHERE CreatedDate < :cutoff ' +
            'AND Status != \'Cancelled\''
        );

        System.debug('Total matching records (CreatedDate < 2026, not already Cancelled): ' + stale.size());

        // Break down by current status
        Map<String, Integer> statusCount = new Map<String, Integer>();
        for (SObject g : stale) {
            String s = (String)g.get('Status');
            statusCount.put(s, (statusCount.containsKey(s) ? statusCount.get(s) : 0) + 1);
        }
        System.debug('Status breakdown: ' + statusCount);

        if (dryRun) {
            System.debug('DRY RUN — no changes made.');
            return;
        }

        // Mark all as Cancelled
        for (SObject g : stale) {
            g.put('Status', 'Cancelled');
        }

        Integer succeeded = 0;
        Integer failed    = 0;

        // Process in chunks of 200 to stay within DML limits
        Integer batchSize = 200;
        for (Integer i = 0; i < stale.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, stale.size());
            List<SObject> chunk = new List<SObject>();
            for (Integer j = i; j < endIdx; j++) {
                chunk.add(stale[j]);
            }
            Database.SaveResult[] results = Database.update(chunk, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    succeeded++;
                } else {
                    failed++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('ERROR ' + sr.getId() + ': ' + err.getStatusCode() + ' — ' + err.getMessage());
                    }
                }
            }
        }

        System.debug('=== COMPLETE ===');
        System.debug('Successfully cancelled: ' + succeeded);
        System.debug('Errors:                 ' + failed);
    }
}
