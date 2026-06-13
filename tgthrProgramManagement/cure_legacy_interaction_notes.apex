/**
 * cure_legacy_interaction_notes.apex
 *
 * Fixes InteractionSummary records created via the legacy Account quick action
 * where notes were entered into a field other than MeetingNotes.
 *
 * BEFORE RUNNING:
 *   1. Run diagnose_legacy_interaction_notes.soql in Dev Console to see which field
 *      has the actual note text on the affected records.
 *   2. Set SOURCE_FIELD below to that field's API name (e.g. 'Subject' or 'Notes__c').
 *   3. Optionally narrow PROGRAM_ID and DATE_CUTOFF to limit scope.
 *
 * This script is read-safe: set DRY_RUN = true to preview without saving.
 */

// ─── CONFIGURATION ────────────────────────────────────────────────────────────

// API name of the field that holds the note text on legacy records.
// Most likely candidates: 'Name' (Subject/title), 'Notes__c', 'InteractionNotes'
final String SOURCE_FIELD = 'Name'; // ← CONFIRM THIS FROM THE DIAGNOSTIC QUERY

// Set to true to print output without committing changes.
final Boolean DRY_RUN = true; // ← CHANGE TO false WHEN READY TO APPLY

// Optional: restrict to a specific program (paste the 18-char Salesforce Id, or leave blank for all programs)
final String PROGRAM_ID = '';

// Only touch records created on/after this date (ISO string 'YYYY-MM-DD')
final String DATE_CUTOFF = '2025-01-01';

// ─── QUERY ────────────────────────────────────────────────────────────────────

Date cutoff = Date.valueOf(DATE_CUTOFF);

String query =
    'SELECT Id, Name, MeetingNotes, Program__c, CreatedDate ' +
    'FROM InteractionSummary ' +
    'WHERE MeetingNotes = null ' +
    '  AND Program__c != null ' +
    '  AND CreatedDate >= :cutoff ';

if (String.isNotBlank(PROGRAM_ID)) {
    Id progId = (Id) PROGRAM_ID;
    query += ' AND Program__c = :progId ';
}

query += ' ORDER BY CreatedDate DESC LIMIT 2000';

List<SObject> records = Database.query(query);
System.debug('Records found with null MeetingNotes: ' + records.size());

// ─── CURE ─────────────────────────────────────────────────────────────────────

List<SObject> toUpdate = new List<SObject>();

for (SObject rec : records) {
    String sourceValue = (String) rec.get(SOURCE_FIELD);

    if (String.isBlank(sourceValue)) {
        System.debug('Skipping ' + rec.get('Id') + ' — source field is also blank');
        continue;
    }

    System.debug(
        'Will copy ' + SOURCE_FIELD + ' → MeetingNotes for record ' + rec.get('Id') +
        '  |  Value: ' + sourceValue.abbreviate(120)
    );

    if (!DRY_RUN) {
        rec.put('MeetingNotes', sourceValue);
        toUpdate.add(rec);
    }
}

System.debug('Records to update: ' + toUpdate.size() + (DRY_RUN ? ' (DRY RUN — no changes saved)' : ''));

if (!DRY_RUN && !toUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(toUpdate, false);
    Integer successCount = 0;
    Integer failCount    = 0;
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            successCount++;
        } else {
            failCount++;
            System.debug('Update error: ' + sr.getErrors()[0].getMessage());
        }
    }
    System.debug('✅ Updated: ' + successCount + '   ❌ Failed: ' + failCount);
}
