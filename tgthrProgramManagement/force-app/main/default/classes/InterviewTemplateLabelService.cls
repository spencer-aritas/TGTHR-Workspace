public with sharing class InterviewTemplateLabelService {
    public static final String LEGACY_COMPREHENSIVE_LABEL = 'Comprehensive Clinical Intake Assessment';
    public static final String LEGACY_COMPREHENSIVE_SHORT_LABEL = 'Comprehensive Intake Assessment';
    public static final String DISPLAY_COMPREHENSIVE_LABEL = 'Comprehensive Clinical Assessment';

    public static String normalizeDisplayLabel(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        String normalizedValue = value.replace(LEGACY_COMPREHENSIVE_LABEL, DISPLAY_COMPREHENSIVE_LABEL);
        normalizedValue = normalizedValue.replace(LEGACY_COMPREHENSIVE_SHORT_LABEL, DISPLAY_COMPREHENSIVE_LABEL);
        return normalizedValue;
    }
}