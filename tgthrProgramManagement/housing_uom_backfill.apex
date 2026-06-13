/**
 * housing_uom_backfill.apex
 *
 * Backfills three reporting fields on all active 1440 Pine benefits that are
 * currently missing them, plus sets available_for_housing__c = true on all:
 *
 *   unitid                         — Unit of Measure (Session, Group Hour, etc.)
 *   default_disbursement_quantity__c — Scale: default units per encounter (1.0 for all services)
 *   default_duration_c__c          — Interval: typical duration in minutes (60 for session/group)
 *   available_for_housing__c       — true (all catalog benefits belong to the Housing program)
 *
 * Idempotent: only writes fields that are currently null so it is safe to re-run.
 */

final String HOUSING_PROGRAM_NAME = '1440 Pine';
final Boolean DRY_RUN = true;

System.debug('=== Housing UOM Backfill START (DRY_RUN=' + DRY_RUN + ') ===');

// ── Load UnitOfMeasure map ──────────────────────────────────────────────────
Map<String, Id> uomById = new Map<String, Id>();
for (SObject u : Database.query('SELECT Id, Name FROM UnitOfMeasure ORDER BY Name')) {
    uomById.put(((String)u.get('Name')).trim().toLowerCase(), (Id)u.get('Id'));
}
System.debug('UnitOfMeasure records: ' + uomById.size());

// ── UOM plan: normalized benefit name → { uomName, defaultQty, durationMin }
// durationMin null = don't set (non-time-based units like Pass, Referral, Meal)
// ──────────────────────────────────────────────────────────────────────────────
// ▸ Group 1: Session-type — 1 session, 60 min
List<String> sessionBenefits = new List<String>{
    'bipoc support',
    'community resource navigation',
    'education support',
    'emergency service coordination (star, emergency room/ urgent care support)',
    'employment support',
    'eviction/ mutual rescission support',
    'external medical provider',
    'external professional team',
    'external therapy provider',
    'family reunification support',
    'financial education and navigation',
    'housekeeping',
    'initial planning meeting (goal setting)',
    'lease violation meeting',
    'legal support',
    'lgbtqia support',
    'medical, legal, or employment',
    'move out assistance',
    'parenting support',
    'peer support',
    'police interaction- arrest',
    'police interaction- general support',
    'pre-lease violation support',
    'public benefits support',
    'rental assistance with budget',
    'tenant retention plan',
    'updates and progress (goal setting)',
    'vital document support',
    'voucher support',
    // NO_CHANGE benefits (null lifecycle, never touched)
    'conflict resolution support',
    'emotional processing',
    'individual session',
    'individual support',
    'mental health support',
    'substance use support'           // covers both "Substance Use Support" records
};

// ▸ Group 2: Group Hour — 1 group hour, 60 min
List<String> groupHourBenefits = new List<String>{
    'community engagement',
    'food access',
    'ged group',
    'group support',
    'life skills group',
    'peer support group',
    'resident advisory council',
    'therapeutic group',
    'wellness, mental health, mindfulness and meditation group',
    // NO_CHANGE
    'physical/mental wellness - community outing'
};

// ▸ Group 3: Referral — 1 referral, no duration
List<String> referralBenefits = new List<String>{
    'education',
    'mental health',
    'other supports',
    'physical health'
};

// ▸ Group 4: Pass — 1 pass, no duration
List<String> passBenefits = new List<String>{
    'bus pass'
};

// ▸ Group 5: Meal — 1 meal, no duration
List<String> mealBenefits = new List<String>{
    'food pantry access - onsite',
    'food pantry access- onsite',   // handle potential hyphen variant
    'meal provided'
};

// ▸ Group 6: Bed Night — 1 bed night, no duration
List<String> bedNightBenefits = new List<String>{
    'housing'
};

// ▸ Group 7: Encounter — 1 encounter, no duration (point store access)
List<String> encounterBenefits = new List<String>{
    'point store access'
};

// ── Build name → { uomKey, qty, durationMin } map ─────────────────────────
Map<String, List<Object>> planByName = new Map<String, List<Object>>();
for (String n : sessionBenefits)    { planByName.put(n, new List<Object>{'session',     1.0, 60.0}); }
for (String n : groupHourBenefits)  { planByName.put(n, new List<Object>{'group hour',  1.0, 60.0}); }
for (String n : referralBenefits)   { planByName.put(n, new List<Object>{'referral',    1.0, null}); }
for (String n : passBenefits)       { planByName.put(n, new List<Object>{'pass',        1.0, null}); }
for (String n : mealBenefits)       { planByName.put(n, new List<Object>{'meal',        1.0, null}); }
for (String n : bedNightBenefits)   { planByName.put(n, new List<Object>{'bed night',   1.0, null}); }
for (String n : encounterBenefits)  { planByName.put(n, new List<Object>{'encounter',   1.0, null}); }

// ── Query all active benefits in 1440 Pine ─────────────────────────────────
List<SObject> programs = Database.query(
    'SELECT Id FROM Program WHERE Name = :HOUSING_PROGRAM_NAME AND Status = \'Active\' LIMIT 1'
);
Id programId = (Id)programs[0].get('Id');

List<SObject> benefits = Database.query(
    'SELECT Id, Name, UnitId, Default_Disbursement_Quantity__c, Default_Duration_C__c, Available_for_Housing__c ' +
    'FROM Benefit WHERE ProgramId = :programId AND IsActive = true ORDER BY Name'
);
System.debug('Active benefits to process: ' + benefits.size());

// ── Build update list ──────────────────────────────────────────────────────
List<SObject> toUpdate = new List<SObject>();
Integer matchCount = 0, skipCount = 0, unmatchedCount = 0;
List<String> unmatched = new List<String>();

for (SObject b : benefits) {
    String bName    = ((String)b.get('Name')).trim();
    String bNameKey = bName.toLowerCase();
    List<Object> plan = planByName.get(bNameKey);

    if (plan == null) {
        System.debug('[UNMATCHED] "' + bName + '" — no UOM plan entry');
        unmatched.add(bName);
        unmatchedCount++;
        continue;
    }

    String uomKey     = (String)  plan[0];
    Double defaultQty = (Double)  plan[1];
    Object durationObj = plan[2];  // null or Double

    Id uomId = uomById.get(uomKey);
    if (uomId == null) {
        System.debug('[WARN] UOM "' + uomKey + '" not found in org — skipping ' + bName);
        skipCount++;
        continue;
    }

    // Check what needs updating
    Boolean needsUom      = b.get('UnitId') == null;
    Boolean needsQty      = b.get('Default_Disbursement_Quantity__c') == null;
    Boolean needsDuration = (durationObj != null) && b.get('Default_Duration_C__c') == null;
    Boolean needsHousing  = (Boolean)b.get('Available_for_Housing__c') == false
                            || b.get('Available_for_Housing__c') == null;

    if (!needsUom && !needsQty && !needsDuration && !needsHousing) {
        System.debug('[SKIP] "' + bName + '" — all fields already set');
        skipCount++;
        continue;
    }

    System.debug('[UPDATE] "' + bName + '" → uom=' + uomKey
        + (needsUom      ? '' : ' (uom already set)')
        + ' | qty=1'
        + (durationObj != null ? ' | dur=' + durationObj + 'min' : '')
        + ' | housing=true');

    if (!DRY_RUN) {
        SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
        upd.put('Id', (Id)b.get('Id'));
        if (needsUom)      { try { upd.put('UnitId', uomId); } catch (Exception ign) {} }
        if (needsQty)      { try { upd.put('Default_Disbursement_Quantity__c', defaultQty); } catch (Exception ign) {} }
        if (needsDuration) { try { upd.put('Default_Duration_C__c', (Double)durationObj); } catch (Exception ign) {} }
        if (needsHousing)  { try { upd.put('Available_for_Housing__c', true); } catch (Exception ign) {} }
        toUpdate.add(upd);
    }
    matchCount++;
}

if (!DRY_RUN && !toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' benefits.');
}

System.debug('=== Housing UOM Backfill COMPLETE (DRY_RUN=' + DRY_RUN + ') ===');
System.debug('  Queued for update: ' + matchCount);
System.debug('  Already complete:  ' + skipCount);
System.debug('  No plan entry:     ' + unmatchedCount);
if (!unmatched.isEmpty()) {
    System.debug('Unmatched benefit names (add to plan if needed):');
    for (String u : unmatched) { System.debug('  "' + u + '"'); }
}
