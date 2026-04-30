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

  // Get available benefit types (categories) directly from BenefitType records.
  // Delegates to BenefitReplacementService.getActiveBenefitsForProgram to ensure
  // Replaced/Retired benefits are excluded regardless of how IsActive was set.
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getBenefitTypes(String programId) {
    try {
        List<Map<String, String>> benefitTypes = new List<Map<String, String>>();
        if (String.isBlank(programId)) return benefitTypes;

        // Derive distinct BenefitType pairs from the lifecycle-aware resolver
        List<BenefitReplacementService.BenefitOption> opts =
            BenefitReplacementService.getActiveBenefitsForProgram(Id.valueOf(programId), null);

        Map<String, String> seen = new Map<String, String>(); // typeName → typeId
        for (BenefitReplacementService.BenefitOption o : opts) {
            if (String.isBlank(o.benefitTypeName)) continue;
            if (!seen.containsKey(o.benefitTypeName)) {
                seen.put(o.benefitTypeName, o.benefitTypeId != null ? String.valueOf(o.benefitTypeId) : o.benefitTypeName);
            }
        }
        List<String> sortedNames = new List<String>(seen.keySet());
        sortedNames.sort();
        for (String name : sortedNames) {
            benefitTypes.add(new Map<String, String>{ 'label' => name, 'value' => seen.get(name) });
        }
        return benefitTypes;
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