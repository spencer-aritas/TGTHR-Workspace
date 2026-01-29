/**
 * REST service to provide decrypted Account data for document generation
 * Encrypted fields like MEDICAID_Number__pc can't be queried via SOQL from external services
 */
@RestResource(urlMapping='/account-data/*')
global with sharing class AccountDataService {
    
    @HttpGet
    global static AccountDataResponse getAccountData() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        AccountDataResponse response = new AccountDataResponse();
        
        try {
            // Query Account - Apex can read encrypted fields directly
            Account acc = [
                SELECT Id, Name, PersonBirthdate, PersonEmail, PersonMobilePhone, 
                       MEDICAID_Number__pc
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
            
            response.success = true;
            response.accountId = acc.Id;
            response.name = acc.Name;
            response.birthdate = acc.PersonBirthdate;
            response.email = acc.PersonEmail;
            response.phone = acc.PersonMobilePhone;
            response.medicaidNumber = acc.MEDICAID_Number__pc; // Decrypted by Apex
            
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
        }
        
        return response;
    }
    
    global class AccountDataResponse {
        public Boolean success;
        public String accountId;
        public String name;
        public Date birthdate;
        public String email;
        public String phone;
        public String medicaidNumber;
        public String errorMessage;
    }
}
