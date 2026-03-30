public with sharing class PSEIntakeSeedAction {
    public class Request {
        @InvocableVariable(label='Prefer CMDT')
        public Boolean PreferCmdt;
        @InvocableVariable(label='Max Rows')
        public Integer MaxRows;
    }

    public class Response {
        @InvocableVariable(label='Rows')
    public List<IntakeIncomeRow> Rows;
    }

    @InvocableMethod(label='Seed Income/Benefit Rows for PSE Intake'
                     description='Returns Apex-defined rows for the OOB Data Table (Income Source, HasIncome, StatedMonthlyIncome, DocumentationProvided).')
    public static List<Response> seed(List<Request> reqList) {
        Integer maxRows = (reqList != null && !reqList.isEmpty() && reqList[0].MaxRows != null && reqList[0].MaxRows > 0)
            ? reqList[0].MaxRows : 1000;

        List<IntakeIncomeRow> rows = new List<IntakeIncomeRow>();
        List<Income_Source__mdt> defs = [
            SELECT MasterLabel, DeveloperName, Sort_Order__c
            FROM Income_Source__mdt
            ORDER BY Sort_Order__c NULLS LAST, MasterLabel
        ];
        Integer rowIdx = 0;
        for (Income_Source__mdt def : defs) {
            rowIdx++;
            String developerName = def.DeveloperName;
            String masterLabel = def.MasterLabel;
            String api = (developerName != null && developerName != '')
                ? developerName
                : 'ROW_' + rowIdx;
            rows.add(new IntakeIncomeRow(
                String.valueOf(rowIdx),
                api,
                masterLabel,
                false, // HasIncome default
                0,     // StatedMonthlyIncome default
                false, // DocumentationProvided default
                null   // Notes default
            ));
        }

        // Cap if requested
        if (rows.size() > maxRows) {
            List<IntakeIncomeRow> cappedRows = new List<IntakeIncomeRow>();
            for (Integer rowNum = 0; rowNum < maxRows; rowNum++) {
                cappedRows.add(rows[rowNum]);
            }
            rows = cappedRows;
        }

        Response out = new Response();
        out.Rows = rows;
        return new List<Response>{ out };
    }
}