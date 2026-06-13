// ============================================================
// od_benefits_normalize.apex
// LIVE — executes DML in production.
//
// WHAT THIS DOES:
//   For each canonical service name in the Outreach & Drop-In
//   213 stale benefits (IsActive=false, Lifecycle='Active'):
//
//   A) If active canonical already exists → retire stale records
//   B) BenefitType.Category = 'Housing' → retire without promoting
//      (shelter-era tracking, not applicable to Outreach & Drop-In)
//   C) Otherwise → PROMOTE one stale record to active:
//        - Rename: strip ' - Drop-In' / ' - Outreach' suffix
//        - IsActive = true
//        - Lifecycle_State__c = 'Active'
//        - Available_for_Clinical__c = true
//        - Available_for_Case_Management__c = true
//        - Available_for_Peer__c = true
//        - Available_for_Program_Engagement__c = true
//      Then RETIRE the remaining duplicate records for that name.
//
// RESULT: Each legacy Source Drop-In/Outreach service becomes
//   one normalized active benefit under Outreach & Drop-In,
//   available across all note types and the census board.
//   All 213 stale suffix-named records end up either promoted
//   (IsActive=true, clean name) or retired (Lifecycle='Retired').
//
// SAFETY GUARD: Aborts if stale count is outside 200-230.
// ============================================================

// -----------------------------------------------------------
// 1. Load data
// -----------------------------------------------------------
List<Benefit> stale = [
    SELECT Id, Name, BenefitTypeId,
           BenefitType.Name, BenefitType.Category,
           UnitId, Unit.Name,
           IsActive, Lifecycle_State__c,
           Default_Disbursement_Quantity__c,
           Default_Duration_c__c
    FROM   Benefit
    WHERE  Program.Name = 'Outreach & Drop-In'
    AND    IsActive = false
    AND    Lifecycle_State__c = 'Active'
    ORDER BY Name
];

if (stale.size() < 200 || stale.size() > 230) {
    System.debug('ABORT: Expected 200-230 stale records, found ' + stale.size() + '. Check before proceeding.');
    return;
}
System.debug('Stale count: ' + stale.size() + ' — within expected range, proceeding.');

List<Benefit> activeList = [
    SELECT Id, Name
    FROM   Benefit
    WHERE  Program.Name = 'Outreach & Drop-In'
    AND    IsActive = true
    AND    Lifecycle_State__c NOT IN ('Retired','Replaced')
];
System.debug('Currently active count: ' + activeList.size());

Set<String> activeNameSet = new Set<String>();
for (Benefit b : activeList) {
    activeNameSet.add(b.Name.trim().toLowerCase());
}

// -----------------------------------------------------------
// 2. grp stale by canonical name
// -----------------------------------------------------------
Map<String, List<Benefit>> byCanonical = new Map<String, List<Benefit>>();
for (Benefit b : stale) {
    String n = b.Name.trim();
    String canonical;
    if      (n.endsWithIgnoreCase(' - Drop-In'))  canonical = n.left(n.length() - 10).trim();
    else if (n.endsWithIgnoreCase(' - Outreach')) canonical = n.left(n.length() - 11).trim();
    else if (n.endsWithIgnoreCase('-Drop-In'))    canonical = n.left(n.length() - 9).trim();
    else if (n.endsWithIgnoreCase('-Outreach'))   canonical = n.left(n.length() - 10).trim();
    else                                          canonical = n;

    if (!byCanonical.containsKey(canonical)) {
        byCanonical.put(canonical, new List<Benefit>());
    }
    byCanonical.get(canonical).add(b);
}
System.debug('Canonical groups: ' + byCanonical.size());

// -----------------------------------------------------------
// 3. Build promote / retire lists
// -----------------------------------------------------------
List<Benefit> toUpdate = new List<Benefit>(); // combined list for single bulkified DML

Integer promotedCount = 0;
Integer retiredCount  = 0;

for (String canonical : byCanonical.keySet()) {
    List<Benefit> grp = byCanonical.get(canonical);

    String btCategory = (grp[0].BenefitType != null && grp[0].BenefitType.Category != null)
        ? grp[0].BenefitType.Category : '';
    String btTypeName = (grp[0].BenefitType != null && grp[0].BenefitType.Name != null)
        ? grp[0].BenefitType.Name : '';

    // Case B: Housing-type → retire all, do not activate
    if (btCategory == 'Housing' || btTypeName == 'Housing') {
        for (Benefit b : grp) {
            b.Lifecycle_State__c = 'Retired';
            toUpdate.add(b);
        }
        retiredCount += grp.size();
        System.debug('HOUSING-SKIP (retiring): ' + canonical + ' (' + grp.size() + ' records)');
        continue;
    }

    // Case A: already have an active canonical → just retire stale
    if (activeNameSet.contains(canonical.toLowerCase())) {
        for (Benefit b : grp) {
            b.Lifecycle_State__c = 'Retired';
            toUpdate.add(b);
        }
        retiredCount += grp.size();
        System.debug('ALREADY-COVERED (retiring): ' + canonical);
        continue;
    }

    // Case C: promote one, retire the rest
    // Prefer the ' - Drop-In' variant as the canonical record
    Benefit template = grp[0];
    for (Benefit b : grp) {
        if (b.Name.endsWithIgnoreCase(' - Drop-In') || b.Name.endsWithIgnoreCase('-Drop-In')) {
            template = b;
            break;
        }
    }

    // Promote: rename + activate + set all flags
    template.Name                             = canonical;
    template.IsActive                         = true;
    template.Lifecycle_State__c               = 'Active';
    template.Available_for_Clinical__c        = true;
    template.Available_for_Case_Management__c = true;
    template.Available_for_Peer__c            = true;
    template.Available_for_Program_Engagement__c = true;
    toUpdate.add(template);
    promotedCount++;

    System.debug('PROMOTE: "' + canonical + '" (from "' + template.Name + '")');

    // Retire the duplicates
    for (Benefit b : grp) {
        if (b.Id != template.Id) {
            b.Lifecycle_State__c = 'Retired';
            toUpdate.add(b);
            retiredCount++;
        }
    }
}

// -----------------------------------------------------------
// 4. Execute
// -----------------------------------------------------------
System.debug('');
System.debug('Updating ' + toUpdate.size() + ' records (' + promotedCount + ' promotions, ' + retiredCount + ' retirements)...');

update toUpdate;

System.debug('DML complete.');

// -----------------------------------------------------------
// 5. Verification
// -----------------------------------------------------------
Integer newActiveCount = [
    SELECT COUNT() FROM Benefit
    WHERE  Program.Name = 'Outreach & Drop-In'
    AND    IsActive = true
    AND    Lifecycle_State__c NOT IN ('Retired','Replaced')
];
Integer remainingAnomaly = [
    SELECT COUNT() FROM Benefit
    WHERE  Program.Name = 'Outreach & Drop-In'
    AND    IsActive = false
    AND    Lifecycle_State__c = 'Active'
];

System.debug('');
System.debug('=== VERIFICATION ===');
System.debug('Active benefits (post-run):          ' + newActiveCount);
System.debug('Remaining anomalous (IsActive=false, Lifecycle=Active): ' + remainingAnomaly + ' (should be 0)');
System.debug('Expected active: ~' + (activeList.size() + promotedCount));
