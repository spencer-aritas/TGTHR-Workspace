/**
 * cure_null_program_backfill.apex
 *
 * Sets Program__c = Outreach & Drop In on every InteractionSummary record
 * that currently has a null Program__c.
 *
 * Run with DRY_RUN = true first to preview the count, then flip to false.
 */

final Boolean DRY_RUN = true;   // ← flip to false when ready to apply
final String  OUTREACH_PROGRAM_NAME = 'Outreach & Drop In';

// ─── Resolve program ──────────────────────────────────────────────────────────

List<SObject> programs = Database.query(
    'SELECT Id, Name FROM Program WHERE Name = :OUTREACH_PROGRAM_NAME LIMIT 1'
);

if (programs.isEmpty()) {
    System.debug('❌ Program not found: "' + OUTREACH_PROGRAM_NAME + '" — check the exact name.');
    return;
}

Id outreachProgramId = (Id) programs[0].get('Id');
System.debug('✅ Outreach & Drop In program ID: ' + outreachProgramId);

// ─── Query affected records ────────────────────────────────────────────────────

List<SObject> nullProgramRecs = Database.query(
    'SELECT Id, Program__c, AccountId, Date_of_Interaction__c, Name ' +
    'FROM InteractionSummary ' +
    'WHERE Program__c = null ' +
    'LIMIT 2000'
);

System.debug('InteractionSummary records with null Program__c: ' + nullProgramRecs.size() + (DRY_RUN ? ' (DRY RUN — no changes)' : ''));

for (Integer i = 0; i < Math.min(10, nullProgramRecs.size()); i++) {
    SObject r = nullProgramRecs[i];
    System.debug('  Sample → ' + r.get('Id') + '  Date: ' + r.get('Date_of_Interaction__c') + '  Name: ' + r.get('Name'));
}

// ─── Apply ────────────────────────────────────────────────────────────────────

if (!DRY_RUN) {
    for (SObject r : nullProgramRecs) {
        r.put('Program__c', outreachProgramId);
    }
    Database.SaveResult[] results = Database.update(nullProgramRecs, false);
    Integer ok = 0; Integer fail = 0;
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) ok++;
        else { fail++; System.debug('Update error: ' + sr.getErrors()[0].getMessage()); }
    }
    System.debug('✅ Updated: ' + ok + '   ❌ Failed: ' + fail);
}
