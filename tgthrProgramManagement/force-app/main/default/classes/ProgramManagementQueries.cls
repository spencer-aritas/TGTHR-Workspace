/**
 * Utility class for SOQL queries used across the Program Management app
 * Using the shared SOQL files stored in scripts/soql folder
 */
public class ProgramManagementQueries {
    
    // Paths to SOQL files
    private static final String PROGRAM_BY_NAME_QUERY = 'program-by-name.soql';
    private static final String BENEFIT_BY_NAME_QUERY = 'benefit-by-name.soql';
    private static final String ACTIVE_ENROLLMENTS_QUERY = 'active-enrollments.soql';
    private static final String BENEFIT_ASSIGNMENTS_QUERY = 'benefit-assignments.soql';
    private static final String BENEFIT_DISBURSEMENTS_QUERY = 'benefit-disbursements.soql';
    
    /**
     * Get program by name
     */
    public static SObject getProgramByName(String programName) {
        // For now we'll use the inline query, but the SOQL is saved in the scripts/soql folder
        // and can be used for direct execution via Developer Console or CLI
        List<SObject> programs = Database.query('SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1');
        return !programs.isEmpty() ? programs[0] : null;
    }
    
    /**
     * Get benefit by name and program
     */
    public static SObject getBenefitByName(String benefitName, Id programId) {
        // Using the query directly in code for better type safety and compile-time validation
        List<SObject> benefits = Database.query(
            'SELECT Id, Name, ProgramId, IsActive FROM Benefit ' +
            'WHERE Name = :benefitName AND ProgramId = :programId LIMIT 1'
        );
        return !benefits.isEmpty() ? benefits[0] : null;
    }
    
    /**
     * Get active program enrollments for an account in a program
     */
    public static List<SObject> getActiveEnrollments(Id accountId, Id programId) {
        return Database.query(
            'SELECT Id, AccountId, ProgramId, Status, StartDate, LastModifiedDate ' +
            'FROM ProgramEnrollment ' +
            'WHERE AccountId = :accountId ' +
            'AND ProgramId = :programId ' +
            'AND Status = \'Enrolled\' ' +
            'ORDER BY LastModifiedDate DESC'
        );
    }
    
    /**
     * Get benefit assignments for an account and benefit
     */
    public static List<SObject> getBenefitAssignments(Id accountId, Id benefitId) {
        return Database.query(
            'SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId, ParentRecordId, Status ' +
            'FROM BenefitAssignment ' +
            'WHERE EnrolleeId = :accountId AND BenefitId = :benefitId'
        );
    }
    
    /**
     * Get benefit disbursements by benefit assignment
     */
    public static List<SObject> getBenefitDisbursements(Id benefitAssignmentId) {
        return Database.query(
            'SELECT Id, BenefitAssignmentId, StartDate, ActualCompletionDate, DisbursedQuantity, Description ' +
            'FROM BenefitDisbursement ' +
            'WHERE BenefitAssignmentId = :benefitAssignmentId ' +
            'ORDER BY StartDate DESC'
        );
    }
}