public class PSEIntakeSeedActionRequest {
    @InvocableVariable(label='Prefer CMDT')
    public Boolean PreferCmdt;      // set true to use Income_Source__mdt

    @InvocableVariable(label='Max Rows')
    public Integer MaxRows;
}