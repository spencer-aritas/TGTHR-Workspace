// Fix existing GoalAssignment records to use Account ID instead of Contact ID
// Get the PersonContactId to Account mapping
List<GoalAssignment> goalsToUpdate = new List<GoalAssignment>();

for (GoalAssignment ga : [SELECT Id, GoalAssigneeId FROM GoalAssignment WHERE GoalAssigneeId != null]) {
    Id assigneeId = ga.GoalAssigneeId;
    // Check if it's a Contact (003 prefix)
    if (assigneeId.getSobjectType() == Schema.Contact.SObjectType) {
        // Find the Account for this Contact (Person Account)
        Contact c = [SELECT AccountId FROM Contact WHERE Id = :assigneeId LIMIT 1];
        if (c.AccountId != null) {
            ga.GoalAssigneeId = c.AccountId;
            goalsToUpdate.add(ga);
            System.debug('Updating GA ' + ga.Id + ' from Contact ' + assigneeId + ' to Account ' + c.AccountId);
        }
    }
}

if (!goalsToUpdate.isEmpty()) {
    update goalsToUpdate;
    System.debug('Updated ' + goalsToUpdate.size() + ' GoalAssignment records');
} else {
    System.debug('No GoalAssignment records needed updating');
}
