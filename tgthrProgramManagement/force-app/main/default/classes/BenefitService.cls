public without sharing class BenefitService {
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

  // Get available benefit types from the BenefitType object directly.
  // Queries BenefitType records at the org level (not filtered by program) so the
  // list is stable static data. value = BenefitType Id (18-char) so callers can
  // pass it as benefitTypeId in CreateRequest / ReplaceRequest. The Id is typed
  // as String in those DTOs to survive the Aura bridge deserialization.
  // programId param is retained for wire-call compatibility but is no longer used.
  @AuraEnabled
  public static List<Map<String, String>> getBenefitTypes(String programId) {
    try {
        List<Map<String, String>> out = new List<Map<String, String>>();
        Set<String> seen = new Set<String>();
        for (SObject bt : Database.query(
            'SELECT Id, Name, Category FROM BenefitType ORDER BY Name, CreatedDate ASC'
        )) {
            String btName = (String) bt.get('Name');
            if (seen.contains(btName)) continue;
            seen.add(btName);
            out.add(new Map<String, String>{
                'label'    => btName,
                'value'    => (String) bt.get('Id'),
                'category' => (String) bt.get('Category')
            });
        }
        return out;
    } catch (Exception e) {
        System.debug('Error getting benefit types: ' + e.getMessage());
        return new List<Map<String, String>>();
    }
  }

  // Get benefits for a specific benefit type and program.
  // Routes through the lifecycle-aware resolver so Replaced/Retired benefits
  // never surface in pickers regardless of prior data state.
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getBenefits(
    String benefitType,
    String programId
  ) {
    try {
      List<Map<String, String>> out = new List<Map<String, String>>();
      if (String.isBlank(programId)) return out;

      List<BenefitReplacementService.BenefitOption> opts =
          BenefitReplacementService.getActiveBenefitsForProgram(Id.valueOf(programId), null);

      for (BenefitReplacementService.BenefitOption o : opts) {
        if (String.isNotBlank(benefitType)) {
          // Filter by BenefitType Id (18-char) or name substring
          Boolean typeMatch = false;
          if ((benefitType.length() == 15 || benefitType.length() == 18) && o.benefitTypeId != null) {
            typeMatch = String.valueOf(o.benefitTypeId) == benefitType;
          } else {
            typeMatch = o.benefitTypeName != null && o.benefitTypeName.toLowerCase().contains(benefitType.toLowerCase());
          }
          if (!typeMatch) continue;
        }
        out.add(new Map<String, String>{ 'label' => o.label, 'value' => o.value });
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