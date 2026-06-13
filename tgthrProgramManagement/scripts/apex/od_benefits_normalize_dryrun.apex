// ============================================================
// od_benefits_normalize_dryrun.apex
// DRY RUN — no DML executed. Read System.debug output to
// verify the plan before running od_benefits_normalize.apex.
// ============================================================

// Load stale O&D benefits (IsActive=false, Lifecycle='Active')
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
System.debug('Stale count: ' + stale.size());

// Load active O&D benefits
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

// grp stale by canonical name (strip ' - Drop-In' / ' - Outreach')
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

// Plan each grp
List<Benefit> willPromote  = new List<Benefit>();
List<Benefit> willRetire   = new List<Benefit>();
List<String>  housingSkip  = new List<String>();
List<String>  alreadyCover = new List<String>();

for (String canonical : byCanonical.keySet()) {
    List<Benefit> grp = byCanonical.get(canonical);

    String btCategory = (grp[0].BenefitType != null && grp[0].BenefitType.Category != null)
        ? grp[0].BenefitType.Category : '';
    String btTypeName = (grp[0].BenefitType != null && grp[0].BenefitType.Name != null)
        ? grp[0].BenefitType.Name : '';

    // Skip Housing-category benefits (shelter-era, not for O&D)
    if (btCategory == 'Housing' || btTypeName == 'Housing') {
        housingSkip.add(canonical);
        willRetire.addAll(grp);
        continue;
    }

    // Already have an active benefit with this canonical name
    if (activeNameSet.contains(canonical.toLowerCase())) {
        alreadyCover.add(canonical);
        willRetire.addAll(grp);
        continue;
    }

    // Pick the Drop-In variant as the one to promote
    Benefit template = grp[0];
    for (Benefit b : grp) {
        if (b.Name.endsWithIgnoreCase(' - Drop-In') || b.Name.endsWithIgnoreCase('-Drop-In')) {
            template = b;
            break;
        }
    }
    willPromote.add(template);

    // Everything else in the grp → retire
    for (Benefit b : grp) {
        if (b.Id != template.Id) {
            willRetire.add(b);
        }
    }
}

// Report
System.debug('');
System.debug('=== DRY RUN SUMMARY ===');
System.debug('  Will PROMOTE (rename + activate):      ' + willPromote.size());
System.debug('  Will RETIRE (stamp Lifecycle=Retired): ' + willRetire.size());
System.debug('  Housing-category (retire only):        ' + housingSkip.size());
System.debug('  Already covered by active benefit:     ' + alreadyCover.size());
System.debug('');
System.debug('Housing-skipped: ' + String.join(housingSkip, ' | '));
System.debug('Already covered: ' + String.join(alreadyCover, ' | '));
System.debug('');

System.debug('--- PROMOTIONS (will become active normalized benefits) ---');
for (Benefit b : willPromote) {
    String n = b.Name.trim();
    String canonical;
    if      (n.endsWithIgnoreCase(' - Drop-In'))  canonical = n.left(n.length() - 10).trim();
    else if (n.endsWithIgnoreCase(' - Outreach')) canonical = n.left(n.length() - 11).trim();
    else if (n.endsWithIgnoreCase('-Drop-In'))    canonical = n.left(n.length() - 9).trim();
    else if (n.endsWithIgnoreCase('-Outreach'))   canonical = n.left(n.length() - 10).trim();
    else                                          canonical = n;
    String btN = (b.BenefitType != null) ? b.BenefitType.Name : 'null';
    String btC = (b.BenefitType != null && b.BenefitType.Category != null) ? b.BenefitType.Category : 'null';
    String unit = (b.Unit != null) ? b.Unit.Name : 'null';
    System.debug('  "' + canonical + '" | Type: ' + btN + ' (' + btC + ') | Unit: ' + unit
        + ' | Qty: ' + b.Default_Disbursement_Quantity__c + ' | Dur: ' + b.Default_Duration_c__c);
}

System.debug('');
System.debug('Expected total active after run: ' + (activeList.size() + willPromote.size())
    + '  (currently ' + activeList.size() + ' active + ' + willPromote.size() + ' promoted)');
System.debug('DRY RUN complete — no DML executed.');
