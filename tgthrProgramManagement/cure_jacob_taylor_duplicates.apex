/**
 * cure_jacob_taylor_duplicates.apex
 *
 * Two targeted fixes:
 *
 *  PART 1 — Jacob Taylor duplicate merge
 *    For each date (5/12 and 5/14) where Jacob has two InteractionSummary records,
 *    keep the one created via the new API path (has Program__c set) and merge any
 *    missing note content from the legacy record before deleting it.
 *
 *  PART 2 — Null Program__c backfill
 *    Any InteractionSummary record still missing Program__c gets set to the
 *    Outreach & Drop In program.
 *
 * Run with DRY_RUN = true first to verify the output in the debug log,
 * then flip to false to commit.
 */

// ─── CONFIGURATION ────────────────────────────────────────────────────────────

final Boolean DRY_RUN = true;   // ← flip to false when ready to apply

// Name of the Outreach & Drop In program (must match exactly)
final String OUTREACH_PROGRAM_NAME = 'Outreach & Drop In';

// ─── PART 1: Find Jacob Taylor ────────────────────────────────────────────────

List<SObject> taylors = Database.query(
    'SELECT Id, FirstName, LastName, Name ' +
    'FROM Account ' +
    'WHERE LastName = \'Taylor\' AND FirstName = \'Jacob\' ' +
    'AND IsPersonAccount = true ' +
    'LIMIT 5'
);

if (taylors.isEmpty()) {
    System.debug('❌ No Person Account found for Jacob Taylor — check name spelling.');
    return;
}
if (taylors.size() > 1) {
    System.debug('⚠️  Multiple accounts matched. Using first result: ' + taylors[0].get('Id'));
}

Id jacobId = (Id) taylors[0].get('Id');
System.debug('✅ Jacob Taylor account: ' + jacobId);

// ─── Query Jacob's recent InteractionSummary records ─────────────────────────

// Cast wide net: anything in May 2026
Date mayStart = Date.newInstance(2026, 5, 1);
Date mayEnd   = Date.newInstance(2026, 5, 31);

List<SObject> allRecords = Database.query(
    'SELECT Id, Name, MeetingNotes, Date_of_Interaction__c, Program__c, ' +
    '       InteractionPurpose, CreatedDate, CreatedBy.Name ' +
    'FROM InteractionSummary ' +
    'WHERE AccountId = :jacobId ' +
    '  AND Date_of_Interaction__c >= :mayStart ' +
    '  AND Date_of_Interaction__c <= :mayEnd ' +
    'ORDER BY Date_of_Interaction__c ASC, CreatedDate ASC'
);

System.debug('Total May IS records for Jacob Taylor: ' + allRecords.size());
for (SObject r : allRecords) {
    System.debug(
        'ID: ' + r.get('Id') +
        '  Date: ' + r.get('Date_of_Interaction__c') +
        '  Program: ' + r.get('Program__c') +
        '  MeetingNotes: ' + (r.get('MeetingNotes') != null ? 'HAS NOTES' : 'NULL') +
        '  Name: ' + r.get('Name') +
        '  CreatedBy: ' + ((SObject) r.getSObject('CreatedBy')).get('Name')
    );
}

// ─── Group by interaction date ────────────────────────────────────────────────

Map<Date, List<SObject>> byDate = new Map<Date, List<SObject>>();
for (SObject r : allRecords) {
    Date d = (Date) r.get('Date_of_Interaction__c');
    if (!byDate.containsKey(d)) byDate.put(d, new List<SObject>());
    byDate.get(d).add(r);
}

List<SObject> toUpdate  = new List<SObject>();
List<Id>      toDelete  = new List<Id>();

for (Date d : byDate.keySet()) {
    List<SObject> recs = byDate.get(d);
    if (recs.size() < 2) {
        System.debug('Date ' + d + ' — only 1 record, skipping.');
        continue;
    }

    System.debug('--- Processing duplicates for date: ' + d + ' (' + recs.size() + ' records) ---');

    // The "canonical" record is the one with Program__c set (created via new API).
    // If both or neither have Program__c, fall back to preferring the one with MeetingNotes.
    SObject canonical = null;
    SObject legacy    = null;

    for (SObject r : recs) {
        Boolean hasProgram = r.get('Program__c') != null;
        Boolean hasNotes   = r.get('MeetingNotes') != null && String.isNotBlank((String) r.get('MeetingNotes'));
        if (hasProgram && canonical == null) {
            canonical = r;
        } else if (!hasProgram && legacy == null) {
            legacy = r;
        }
    }

    // Fallback: if both have Program__c, use the one with notes as canonical and the other as legacy
    if (canonical == null || legacy == null) {
        canonical = recs[0];
        legacy    = recs[1];
        for (SObject r : recs) {
            if (r.get('MeetingNotes') != null) { canonical = r; }
        }
        for (SObject r : recs) {
            if (r.get('Id') != canonical.get('Id')) { legacy = r; }
        }
    }

    System.debug('  KEEP   → ' + canonical.get('Id') + '  MeetingNotes: ' +
        (canonical.get('MeetingNotes') != null ? 'present' : 'null') +
        '  Program: ' + canonical.get('Program__c'));
    System.debug('  DELETE → ' + legacy.get('Id') + '  MeetingNotes: ' +
        (legacy.get('MeetingNotes') != null ? 'present' : 'null') +
        '  Program: ' + legacy.get('Program__c') +
        '  Name: ' + legacy.get('Name'));

    // Merge: if legacy has notes that canonical lacks, copy them over
    String canonicalNotes = (String) canonical.get('MeetingNotes');
    String legacyNotes    = (String) legacy.get('MeetingNotes');
    String legacyName     = (String) legacy.get('Name');

    String notesToMerge = null;
    if (String.isNotBlank(legacyNotes)) {
        notesToMerge = legacyNotes;
        System.debug('  → Merging MeetingNotes from legacy record.');
    }

    if (notesToMerge != null) {
        if (String.isBlank(canonicalNotes)) {
            canonical.put('MeetingNotes', notesToMerge);
        } else {
            // Append with separator so neither entry is lost
            canonical.put('MeetingNotes', canonicalNotes.trim() + '\n\n--- (merged from duplicate) ---\n\n' + notesToMerge.trim());
        }
        toUpdate.add(canonical);
    }

    toDelete.add((Id) legacy.get('Id'));
}

// ─── PART 2: Null Program__c backfill ─────────────────────────────────────────

List<SObject> outreachPrograms = Database.query(
    'SELECT Id, Name FROM Program WHERE Name = :OUTREACH_PROGRAM_NAME LIMIT 1'
);
if (outreachPrograms.isEmpty()) {
    System.debug('❌ Program not found: "' + OUTREACH_PROGRAM_NAME + '" — check spelling. Null-program backfill skipped.');
} else {
    Id outreachProgramId = (Id) outreachPrograms[0].get('Id');
    System.debug('✅ Outreach & Drop In program ID: ' + outreachProgramId);

    List<SObject> nullProgRecs = Database.query(
        'SELECT Id, Program__c FROM InteractionSummary WHERE Program__c = null LIMIT 2000'
    );
    System.debug('InteractionSummary records with null Program__c: ' + nullProgRecs.size());

    for (SObject r : nullProgRecs) {
        r.put('Program__c', outreachProgramId);
        toUpdate.add(r);
    }
}

// ─── Apply changes ─────────────────────────────────────────────────────────────

System.debug('── Summary ──────────────────────────────────────────────────────');
System.debug('Records to update : ' + toUpdate.size() + (DRY_RUN ? ' (DRY RUN)' : ''));
System.debug('Records to delete : ' + toDelete.size() + (DRY_RUN ? ' (DRY RUN)' : ''));

if (!DRY_RUN) {
    if (!toUpdate.isEmpty()) {
        Database.SaveResult[] sr = Database.update(toUpdate, false);
        Integer ok = 0; Integer fail = 0;
        for (Database.SaveResult s : sr) {
            if (s.isSuccess()) ok++;
            else { fail++; System.debug('Update error: ' + s.getErrors()[0].getMessage()); }
        }
        System.debug('✅ Updated: ' + ok + '   ❌ Failed: ' + fail);
    }

    if (!toDelete.isEmpty()) {
        Database.DeleteResult[] dr = Database.delete(toDelete, false);
        Integer ok = 0; Integer fail = 0;
        for (Database.DeleteResult d : dr) {
            if (d.isSuccess()) ok++;
            else { fail++; System.debug('Delete error: ' + d.getErrors()[0].getMessage()); }
        }
        System.debug('✅ Deleted: ' + ok + '   ❌ Failed: ' + fail);
    }
}
