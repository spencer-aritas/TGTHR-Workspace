// Diagnose why specific GoalAssignment records were NOT cancelled by cancel_stale_goal_assignments.apex
// Paste the ID of one known-skipped record below.

Id sampleId = '1pgVY00000003kHYAQ';

Datetime cutoff = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);

// 1. Inspect the specific record
List<SObject> sample = Database.query(
    'SELECT Id, CustomGoalName, Status, CreatedDate, LastModifiedDate, GoalAssigneeId ' +
    'FROM GoalAssignment WHERE Id = :sampleId'
);

if (sample.isEmpty()) {
    System.debug('Record not found — verify the ID and object API name.');
} else {
    SObject g = sample[0];
    System.debug('=== SAMPLE RECORD ===');
    System.debug('ID:             ' + g.get('Id'));
    System.debug('Name:           ' + g.get('CustomGoalName'));
    System.debug('Status:         ' + g.get('Status'));
    System.debug('CreatedDate:    ' + g.get('CreatedDate'));
    System.debug('LastModifiedDate: ' + g.get('LastModifiedDate'));
    System.debug('GoalAssigneeId: ' + g.get('GoalAssigneeId'));

    Boolean createdBefore2026 = (Datetime)g.get('CreatedDate') < cutoff;
    Boolean lastModBefore2026 = (Datetime)g.get('LastModifiedDate') < cutoff;
    Boolean notCancelled      = (String)g.get('Status') != 'Cancelled';

    System.debug('--- Why was this record skipped? ---');
    System.debug('CreatedDate  < 2026?        ' + createdBefore2026);
    System.debug('LastModified < 2026?        ' + lastModBefore2026);
    System.debug('Status != Cancelled?        ' + notCancelled);
    System.debug('Would have been caught: ' + (createdBefore2026 && lastModBefore2026 && notCancelled));
    System.debug('');

    // 2. Check all goals for the same assignee
    Id assigneeId = (Id)g.get('GoalAssigneeId');
    List<SObject> allGoals = Database.query(
        'SELECT Id, CustomGoalName, Status, CreatedDate, LastModifiedDate ' +
        'FROM GoalAssignment WHERE GoalAssigneeId = :assigneeId ORDER BY CreatedDate DESC'
    );

    System.debug('=== ALL GOALS FOR THIS ASSIGNEE (' + allGoals.size() + ' total) ===');
    Integer skippedDueToLastMod = 0;
    Integer skippedAlreadyCancelled = 0;
    Integer skippedCreatedIn2026 = 0;

    for (SObject rec : allGoals) {
        Boolean c26 = (Datetime)rec.get('CreatedDate') < cutoff;
        Boolean m26 = (Datetime)rec.get('LastModifiedDate') < cutoff;
        Boolean nc  = (String)rec.get('Status') != 'Cancelled';
        String reason = '';
        if (!c26) { reason = 'CREATED IN 2026'; skippedCreatedIn2026++; }
        else if (!nc) { reason = 'ALREADY CANCELLED'; skippedAlreadyCancelled++; }
        else if (!m26) { reason = 'LAST-MODIFIED IN 2026 — EXCLUDED'; skippedDueToLastMod++; }
        else { reason = 'SHOULD HAVE BEEN CANCELLED'; }

        System.debug(
            rec.get('Id') + ' | ' + rec.get('CustomGoalName') +
            ' | Status=' + rec.get('Status') +
            ' | Created=' + rec.get('CreatedDate') +
            ' | LastMod=' + rec.get('LastModifiedDate') +
            ' | => ' + reason
        );
    }

    System.debug('--- Summary for this assignee ---');
    System.debug('Skipped (LastModified in 2026): ' + skippedDueToLastMod);
    System.debug('Skipped (already Cancelled):    ' + skippedAlreadyCancelled);
    System.debug('Skipped (created in 2026):      ' + skippedCreatedIn2026);
}

// 3. Org-wide count of records excluded ONLY because LastModifiedDate >= 2026
//    (CreatedDate < 2026, Status != Cancelled, but LastMod >= 2026)
List<SObject> excludedByLastMod = Database.query(
    'SELECT COUNT() ' +
    'FROM GoalAssignment ' +
    'WHERE CreatedDate < :cutoff ' +
    'AND LastModifiedDate >= :cutoff ' +
    'AND Status != \'Cancelled\''
);
System.debug('=== ORG-WIDE: Records excluded solely by LastModifiedDate filter: ' +
    Database.countQuery(
        'SELECT COUNT() FROM GoalAssignment ' +
        'WHERE CreatedDate < :cutoff ' +
        'AND LastModifiedDate >= :cutoff ' +
        'AND Status != \'Cancelled\''
    )
);
