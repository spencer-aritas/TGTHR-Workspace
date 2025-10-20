public with sharing class ProgramThemeService {
    public class ThemeDTO {
        @AuraEnabled public String programName;
        @AuraEnabled public String colorHex;      // mapped from CodeHex__c
        @AuraEnabled public String accentHex;
        @AuraEnabled public String iconName;
        @AuraEnabled public String imageResource;
        @AuraEnabled public Id     programId;     // optional, from ProgramId__c
    }

    @AuraEnabled(cacheable=true)
    public static ThemeDTO getThemeByProgramName(String programName) {
        if (String.isBlank(programName)) return null;

        List<Program_Theme__mdt> rows = [
            SELECT ProgramDeveloperName__c, CodeHex__c, AccentHex__c, IconName__c, ImageResource__c, ProgramId__c
            FROM Program_Theme__mdt
            WHERE ProgramDeveloperName__c = :programName
            LIMIT 1
        ];
        if (rows.isEmpty()) return null;

        Program_Theme__mdt t = rows[0];
        ThemeDTO dto = new ThemeDTO();
        dto.programName   = t.ProgramDeveloperName__c;
        dto.colorHex      = t.CodeHex__c;        // <-- your API name
        dto.accentHex     = t.AccentHex__c;
        dto.iconName      = t.IconName__c;
        dto.imageResource = t.ImageResource__c;
        dto.programId     = t.ProgramId__c;
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static ThemeDTO getThemeByProgramId(Id programId) {
        if (programId == null) return null;
        List<Program_Theme__mdt> rows = [
            SELECT ProgramDeveloperName__c, CodeHex__c, AccentHex__c, IconName__c, ImageResource__c, ProgramId__c
            FROM Program_Theme__mdt
            WHERE ProgramId__c = :programId
            LIMIT 1
        ];
        if (rows.isEmpty()) return null;
        Program_Theme__mdt t = rows[0];
        ThemeDTO dto = new ThemeDTO();
        dto.programName   = t.ProgramDeveloperName__c;
        dto.colorHex      = t.CodeHex__c;
        dto.accentHex     = t.AccentHex__c;
        dto.iconName      = t.IconName__c;
        dto.imageResource = t.ImageResource__c;
        dto.programId     = t.ProgramId__c;
        return dto;
    }
}
