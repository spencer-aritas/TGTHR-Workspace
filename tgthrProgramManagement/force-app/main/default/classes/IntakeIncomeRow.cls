public with sharing class IntakeIncomeRow {
    @AuraEnabled public String Key;
    @AuraEnabled public String SourceApiName;
    @AuraEnabled public String SourceLabel;
    @AuraEnabled public Boolean HasIncome;
    @AuraEnabled public Decimal StatedMonthlyIncome;
    @AuraEnabled public Boolean DocumentationProvided;
    @AuraEnabled public String Notes;

    public IntakeIncomeRow() {
    }

    public IntakeIncomeRow(
        String key,
        String sourceApiName,
        String sourceLabel,
        Boolean hasIncome,
        Decimal statedMonthlyIncome,
        Boolean documentationProvided,
        String notes
    ) {
        this.Key = key;
        this.SourceApiName = sourceApiName;
        this.SourceLabel = sourceLabel;
        this.HasIncome = hasIncome;
        this.StatedMonthlyIncome = statedMonthlyIncome;
        this.DocumentationProvided = documentationProvided;
        this.Notes = notes;
    }

    public static List<IntakeIncomeRow> getRows() {
        List<IntakeIncomeRow> rows = new List<IntakeIncomeRow>();
        List<Income_Source__mdt> defs = [
            SELECT MasterLabel, DeveloperName, Sort_Order__c
            FROM Income_Source__mdt
            ORDER BY Sort_Order__c NULLS LAST, MasterLabel
        ];

        Integer idx = 0;
        for (Income_Source__mdt def : defs) {
            idx++;
            String developerName = def.DeveloperName;
            String masterLabel = def.MasterLabel;
            String api = String.isBlank(developerName)
                ? 'ROW_' + String.valueOf(idx)
                : developerName;
            rows.add(new IntakeIncomeRow(
                String.valueOf(idx),
                api,
                masterLabel,
                false,
                0,
                false,
                null
            ));
        }
        return rows;
    }
}