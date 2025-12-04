/**
 * Create GoalDefinition library for TGTHR unhoused youth services.
 * 
 * These are high-level goal categories. Staff will create GoalAssignments
 * with client-specific CustomGoalName when IsCustomGoalNameRequired = true.
 * 
 * Run with: sf apex run -f scripts/apex/createGoalDefinitionLibrary.apex -o benefits
 */

List<GoalDefinition> goalDefs = new List<GoalDefinition>();

// Housing & Stability
goalDefs.add(new GoalDefinition(
    Name = 'Maintain Safe & Stable Housing',
    Description = 'Goals related to housing stability, lease compliance, and safe living environment.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Transition to Independent Living',
    Description = 'Goals for moving from transitional housing to permanent independent housing.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Employment & Income
goalDefs.add(new GoalDefinition(
    Name = 'Improve Employment Stability',
    Description = 'Goals related to obtaining and maintaining employment.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Increase Income & Financial Security',
    Description = 'Goals for improving financial literacy, budgeting, and income growth.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Obtain Benefits & Entitlements',
    Description = 'Goals for accessing Medicaid, SNAP, SSI/SSDI, or other benefits.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Education & Skills
goalDefs.add(new GoalDefinition(
    Name = 'Increase School Attendance',
    Description = 'Goals for improving school attendance and educational engagement.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Complete Educational Milestone',
    Description = 'Goals for GED, high school diploma, or post-secondary education.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Improve Daily Living Skills',
    Description = 'Goals for cooking, cleaning, budgeting, time management, and self-care.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Health & Wellness
goalDefs.add(new GoalDefinition(
    Name = 'Improve Physical Health',
    Description = 'Goals for medical care, nutrition, exercise, and health conditions.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Improve Mental Health',
    Description = 'Goals for therapy engagement, coping skills, and mental wellness.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Reduce Substance Use-Related Harm',
    Description = 'Goals for harm reduction, treatment engagement, and recovery support.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Social & Family
goalDefs.add(new GoalDefinition(
    Name = 'Strengthen Family Relationships',
    Description = 'Goals for reconnection, communication, and healthy family dynamics.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Build Healthy Support Network',
    Description = 'Goals for developing positive peer relationships and community connections.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Improve Parenting Skills',
    Description = 'Goals for parenting teens who have children of their own.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Legal & Safety
goalDefs.add(new GoalDefinition(
    Name = 'Resolve Legal Issues',
    Description = 'Goals for court compliance, legal aid, expungement, or immigration matters.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Improve Personal Safety',
    Description = 'Goals related to safety planning, DV/IPV, and crisis prevention.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Obtain Identity Documents',
    Description = 'Goals for obtaining birth certificate, ID, SSN card, or passport.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Life Skills & Independence
goalDefs.add(new GoalDefinition(
    Name = 'Develop Self-Advocacy Skills',
    Description = 'Goals for communicating needs, navigating systems, and self-empowerment.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Improve Communication Skills',
    Description = 'Goals for conflict resolution, professional communication, and healthy expression.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

goalDefs.add(new GoalDefinition(
    Name = 'Achieve Transportation Independence',
    Description = 'Goals for getting license, learning public transit, or obtaining vehicle.',
    Status = 'Active',
    Type = 'Individual',
    IsCustomGoalNameRequired = true
));

// Check for existing goals to avoid duplicates
Set<String> existingNames = new Set<String>();
for (GoalDefinition existing : [SELECT Name FROM GoalDefinition WHERE Status = 'Active']) {
    existingNames.add(existing.Name);
}

List<GoalDefinition> toInsert = new List<GoalDefinition>();
for (GoalDefinition gd : goalDefs) {
    if (!existingNames.contains(gd.Name)) {
        toInsert.add(gd);
    } else {
        System.debug('Skipping existing GoalDefinition: ' + gd.Name);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('✅ Created ' + toInsert.size() + ' new GoalDefinitions');
    for (GoalDefinition gd : toInsert) {
        System.debug('  - ' + gd.Name);
    }
} else {
    System.debug('ℹ️ No new GoalDefinitions to create - all already exist');
}
