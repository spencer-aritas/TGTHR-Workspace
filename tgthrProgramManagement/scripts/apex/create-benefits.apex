// Create benefit records that match the mock data from BenefitService

// Get the 1440 Pine program ID
Id programId = [SELECT Id FROM Program WHERE Name = '1440 Pine' LIMIT 1].Id;

// Create Housing benefits
List<Benefit> benefitsToInsert = new List<Benefit>();

// Housing Benefits (h1-h4)
benefitsToInsert.add(new Benefit(
    Name = 'Housing Stipend',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Rent Assistance',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Security Deposit',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Utility Assistance',
    ProgramId = programId,
    IsActive = true
));

// Food Benefits (f1-f4)
benefitsToInsert.add(new Benefit(
    Name = 'Food Pantry',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Meal Vouchers',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Grocery Gift Card',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Community Meal',
    ProgramId = programId,
    IsActive = true
));

// Medical Benefits (m1-m4)
benefitsToInsert.add(new Benefit(
    Name = 'Medical Voucher',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Health Assessment',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Prescription Assistance',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Mental Health Services',
    ProgramId = programId,
    IsActive = true
));

// Transportation Benefits (t1-t3)
benefitsToInsert.add(new Benefit(
    Name = 'Bus Pass',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Ride Share Credit',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Gas Card',
    ProgramId = programId,
    IsActive = true
));

// Education Benefits (e1-e3)
benefitsToInsert.add(new Benefit(
    Name = 'Tuition Assistance',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'School Supplies',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Certification Fee',
    ProgramId = programId,
    IsActive = true
));

// Employment Benefits (emp1-emp3)
benefitsToInsert.add(new Benefit(
    Name = 'Work Clothing',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Job Training',
    ProgramId = programId,
    IsActive = true
));

benefitsToInsert.add(new Benefit(
    Name = 'Resume Assistance',
    ProgramId = programId,
    IsActive = true
));

// Program-specific benefits
benefitsToInsert.add(new Benefit(
    Name = '1440 Pine Housing Voucher',
    ProgramId = programId,
    IsActive = true
));

insert benefitsToInsert;

System.debug('Created ' + benefitsToInsert.size() + ' benefit records');

// Display the created benefits
for (Benefit b : benefitsToInsert) {
    System.debug('Created benefit: ' + b.Name + ' with ID: ' + b.Id);
}