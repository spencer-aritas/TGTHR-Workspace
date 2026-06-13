/**
 * Fix: Repoint 9 active O&D benefits from the null-category duplicate BenefitType
 * to the correct canonical Case Management BenefitType.
 *
 * Duplicate (null Category):  0jhVY00000000rJYAQ  Name='Case Management', Category=null
 * Correct   (has Category):   0jhVY000000001dYAA  Name='Case Management', Category='Case Management'
 *
 * Root cause: these 9 records were created pointing to the wrong BenefitType Id.
 * Because BenefitDisbursementService.getEventTypes() groups by BenefitType.Id,
 * having two distinct Ids with the same Name produces two "Case Management" entries
 * in the Census Board picker.
 */

Id badTypeId  = '0jhVY00000000rJYAQ';
Id goodTypeId = '0jhVY000000001dYAA';

// Verify both types exist before touching anything
List<SObject> typeCheck = Database.query(
    'SELECT Id, Name FROM BenefitType WHERE Id IN (\'' + badTypeId + '\', \'' + goodTypeId + '\')'
);
if (typeCheck.size() != 2) {
    System.debug('ABORT: Expected 2 BenefitType records, found ' + typeCheck.size() + '. Halting.');
    return;
}
System.debug('BenefitType check passed. Both Ids exist.');

// Query all active benefits pointing to the bad type (not just O&D — catch any org-wide)
List<SObject> toFix = Database.query(
    'SELECT Id, Name, BenefitTypeId, Program.Name FROM Benefit ' +
    'WHERE BenefitTypeId = \'' + badTypeId + '\' ' +
    'AND IsActive = true'
);
System.debug('Active benefits pointing to null-category BenefitType: ' + toFix.size());
for (SObject b : toFix) {
    System.debug('  → ' + b.get('Name') + ' [' + b.get('Id') + ']');
}

if (toFix.isEmpty()) {
    System.debug('Nothing to fix. Exiting.');
    return;
}

// Repoint each to the correct BenefitType
for (SObject b : toFix) {
    b.put('BenefitTypeId', goodTypeId);
}

update toFix;
System.debug('DML complete. Updated ' + toFix.size() + ' records.');

// Verification: confirm zero active benefits still point to the bad type
List<SObject> remaining = Database.query(
    'SELECT Id FROM Benefit WHERE BenefitTypeId = \'' + badTypeId + '\' AND IsActive = true'
);
System.debug('=== VERIFICATION ===');
System.debug('Remaining active benefits on null-category BenefitType: ' + remaining.size());
if (remaining.size() == 0) {
    System.debug('SUCCESS: All active benefits now point to the correct Case Management BenefitType.');
} else {
    System.debug('WARNING: ' + remaining.size() + ' records still point to the bad BenefitType.');
}
