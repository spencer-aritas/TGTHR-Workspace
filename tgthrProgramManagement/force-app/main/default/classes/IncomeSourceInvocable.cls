public class IncomeSourceInvocable {
    
    public class Result {
        @InvocableVariable public List<IntakeIncomeRow> rows;
    }
    
    @InvocableMethod(label='Get Income Source Rows')
    public static List<Result> getIncomeSourceRows() {
        Result result = new Result();
        result.rows = IntakeIncomeRow.getRows();
        return new List<Result>{result};
    }
}