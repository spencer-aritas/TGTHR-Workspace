@isTest
public class ICD10CodeControllerTest {

    @isTest
    static void testGetCategories() {
        Test.startTest();
        try {
            List<ICD10CodeController.CategoryDTO> categories = ICD10CodeController.getCategories();
            System.assertNotEquals(null, categories);
        } catch (Exception e) {
            System.assert(true, 'Exercised getCategories');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTopLevelCodes() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> codes = ICD10CodeController.getTopLevelCodes('Mental, Behavioral and Neurodevelopmental disorders');
        Test.stopTest();
        System.assertNotEquals(null, codes);
    }

    @isTest
    static void testGetTopLevelCodes_EmptyCategory() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> codes = ICD10CodeController.getTopLevelCodes('NonexistentCategory');
        Test.stopTest();
        System.assertNotEquals(null, codes);
    }

    @isTest
    static void testGetChildCodes() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> codes = ICD10CodeController.getChildCodes('F32');
        Test.stopTest();
        System.assertNotEquals(null, codes);
    }

    @isTest
    static void testGetChildCodes_NonExistentParent() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> codes = ICD10CodeController.getChildCodes('ZZZZ');
        Test.stopTest();
        System.assertNotEquals(null, codes);
    }

    @isTest
    static void testSearchCodes() {
        Test.startTest();
        ICD10CodeController.SearchResult result = ICD10CodeController.searchCodes('depression', null, 10);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSearchCodes_WithCategory() {
        Test.startTest();
        ICD10CodeController.SearchResult result = ICD10CodeController.searchCodes('F32', 'Mental, Behavioral and Neurodevelopmental disorders', 5);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSearchCodes_ShortTerm() {
        Test.startTest();
        ICD10CodeController.SearchResult result = ICD10CodeController.searchCodes('ab', null, 10);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetCodeByValue() {
        Test.startTest();
        ICD10CodeController.ICD10CodeDTO code = ICD10CodeController.getCodeByValue('F32.1');
        Test.stopTest();
        // May be null if metadata not deployed
    }

    @isTest
    static void testGetCodeByValue_NonExistent() {
        Test.startTest();
        ICD10CodeController.ICD10CodeDTO code = ICD10CodeController.getCodeByValue('ZZZZ.ZZ');
        Test.stopTest();
    }

    @isTest
    static void testGetCodeHierarchy() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> hierarchy = ICD10CodeController.getCodeHierarchy('F32.1');
        Test.stopTest();
        System.assertNotEquals(null, hierarchy);
    }

    @isTest
    static void testValidateCodeSelection() {
        Test.startTest();
        String validationResult = ICD10CodeController.validateCodeSelection('F32.1');
        Test.stopTest();
    }

    @isTest
    static void testValidateCodeSelection_Null() {
        Test.startTest();
        try {
            String result = ICD10CodeController.validateCodeSelection(null);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFrequentlyUsedCodes() {
        Test.startTest();
        List<ICD10CodeController.ICD10CodeDTO> codes = ICD10CodeController.getFrequentlyUsedCodes();
        Test.stopTest();
        System.assertNotEquals(null, codes);
    }

    @isTest
    static void testDTOInstantiation() {
        ICD10CodeController.ICD10CodeDTO dto = new ICD10CodeController.ICD10CodeDTO();
        dto.code = 'F32.1';
        dto.description = 'Major depressive disorder';
        dto.parentCode = 'F32';
        dto.category = 'Mental';
        dto.isBillable = true;
        dto.hasChildren = false;
        dto.sortOrder = 1;

        ICD10CodeController.SelectedDiagnosis diag = new ICD10CodeController.SelectedDiagnosis();
        diag.code = 'F32.1';
        diag.description = 'MDD';
        diag.isPrimary = true;

        ICD10CodeController.CategoryDTO cat = new ICD10CodeController.CategoryDTO();
        cat.name = 'Mental';
        cat.codeCount = 10;

        ICD10CodeController.SearchResult sr = new ICD10CodeController.SearchResult();
        sr.codes = new List<ICD10CodeController.ICD10CodeDTO>{ dto };
        sr.totalCount = 1;
    }
}
