public with sharing class PSEIntakeTypes {
    public class IntakeIncomeRow {
        @AuraEnabled public String  Key;                     // stable row id for table edits (e.g., "1", "2", ...)
        @AuraEnabled public String  SourceApiName;           // machine-safe (e.g., EARNED_INCOME)
        @AuraEnabled public String  SourceLabel;             // what users see in the first column
        @AuraEnabled public Boolean HasIncome;               // checkbox (editable)
        @AuraEnabled public Decimal StatedMonthlyIncome;     // currency/decimal (editable)
        @AuraEnabled public Boolean DocumentationProvided;   // checkbox (editable)
        @AuraEnabled public String  Notes;                   // optional free text if you want it later

    
        public IntakeIncomeRow(String key, String SourceApiName, String SourceLabel, Boolean HasIncome, Decimal StatedMonthlyIncome, Boolean DocumentationProvided, String Notes) 
        {   
            this.Key = key;
            this.SourceApiName = SourceApiName;
            this.SourceLabel = SourceLabel;
            this.HasIncome = HasIncome;
            this.StatedMonthlyIncome = StatedMonthlyIncome;
            this.DocumentationProvided = DocumentationProvided;
            this.Notes = Notes;
        }
    public IntakeIncomeRow() {}
    }

}