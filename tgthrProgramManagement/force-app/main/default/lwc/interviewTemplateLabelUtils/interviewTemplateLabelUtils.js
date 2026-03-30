export const LEGACY_COMPREHENSIVE_LABEL = 'Comprehensive Clinical Intake Assessment';
export const LEGACY_COMPREHENSIVE_SHORT_LABEL = 'Comprehensive Intake Assessment';
export const DISPLAY_COMPREHENSIVE_LABEL = 'Comprehensive Clinical Assessment';

export function normalizeInterviewDisplayLabel(value) {
    if (!value) {
        return value;
    }

    return value
        .replaceAll(LEGACY_COMPREHENSIVE_LABEL, DISPLAY_COMPREHENSIVE_LABEL)
        .replaceAll(LEGACY_COMPREHENSIVE_SHORT_LABEL, DISPLAY_COMPREHENSIVE_LABEL);
}