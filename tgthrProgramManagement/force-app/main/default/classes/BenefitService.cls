public with sharing class BenefitService {
  // Return Active Programs for tabs (Id, Name only)
  @AuraEnabled(cacheable=true)
  public static List<SObject> getActivePrograms() {
    try {
      // Adjust the object/field names if your org uses a different API (e.g., Program__c, Status__c)
      // Current assumption based on existing code: standard/custom object 'Program' with IsActive boolean.
      String q = 'SELECT Id, Name FROM Program WHERE Status = \'Active\' ORDER BY Name';
      return Database.query(q);
    } catch (Exception e) {
      System.debug('Error in getActivePrograms: ' + e.getMessage());
      return new List<SObject>();
    }
  }

  // Get available benefit types (categories) directly from BenefitType records
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getBenefitTypes(String programId) {
    try {
        System.debug('getBenefitTypes called with programId: ' + programId);
        List<Map<String, String>> benefitTypes = new List<Map<String, String>>();
        if (String.isBlank(programId)) {
            System.debug('ProgramId is blank. Returning empty list.');
            return benefitTypes;
        }

        // Return distinct BenefitType id/name pairs for active benefits in the program
        String query = 'SELECT BenefitType__r.Id btId, BenefitType__r.Name btName FROM Benefit WHERE ProgramId = :programId AND IsActive = true GROUP BY BenefitType__r.Id, BenefitType__r.Name ORDER BY BenefitType__r.Name';
        System.debug('SOQL Query: ' + query);
        List<AggregateResult> ars = Database.query(query);
        System.debug('Query Results: ' + ars);

        for (AggregateResult ar : ars) {
            Object idObj = ar.get('btId');
            Object nameObj = ar.get('btName');
            if (nameObj == null) {
                continue;
            }
            String label = String.valueOf(nameObj);
            String value = idObj == null ? label : String.valueOf(idObj);
            benefitTypes.add(
                new Map<String, String>{ 'label' => label, 'value' => value }
            );
        }
        return benefitTypes;
    } catch (Exception e) {
        System.debug('Error getting benefit types: ' + e.getMessage());
        return new List<Map<String, String>>();
    }
  }

  // Get benefits for a specific benefit type and program - direct from Benefit records
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getBenefits(
    String benefitType,
    String programId
  ) {
    try {
      List<Map<String, String>> out = new List<Map<String, String>>();
      if (String.isBlank(programId))
        return out;

      String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = true';
      if (String.isNotBlank(benefitType)) {
        if (benefitType.length() == 15 || benefitType.length() == 18) {
          query += ' AND BenefitType__c = :benefitType';
        } else {
          String likePattern = '%' + benefitType + '%';
          query += ' AND Name LIKE :likePattern';
        }
      }
      query += ' ORDER BY Name LIMIT 200';

      List<SObject> benefitRecords = Database.query(query);
      for (SObject b : benefitRecords) {
        out.add(
          new Map<String, String>{
            'label' => String.valueOf(b.get('Name')),
            'value' => String.valueOf(b.get('Id'))
          }
        );
      }
      return out;
    } catch (Exception e) {
      System.debug('Error getting benefits: ' + e.getMessage());
      return new List<Map<String, String>>();
    }
  }

  // Get program ID by name
  @AuraEnabled(cacheable=true)
  public static String getProgramIdByName(String programName) {
    try {
      if (String.isBlank(programName)) {
        return null;
      }

      // Query only active Programs by name
      String programQuery = 'SELECT Id FROM Program WHERE Name = :programName AND Status = \'Active\' LIMIT 1';
      List<SObject> programs = Database.query(programQuery);

      if (!programs.isEmpty()) {
        return (String) programs[0].get('Id');
      } else {
        return null;
      }
    } catch (Exception e) {
      System.debug('Error getting program ID: ' + e.getMessage());
      return null;
    }
  }
}
