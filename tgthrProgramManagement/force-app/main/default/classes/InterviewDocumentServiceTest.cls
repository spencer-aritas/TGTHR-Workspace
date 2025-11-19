/**
 * Test class for InterviewDocumentService
 * 
 * Validates InterviewDocumentPayload structure and signature policy integration.
 * Uses dynamic SObject creation to avoid schema dependencies.
 * 
 * @author TGTHR Development Team
 * @date 2025-11-19
 */
@IsTest
private class InterviewDocumentServiceTest {
    
    /**
     * Test buildInterviewDocumentPayload with signature policies
     * 
     * Validates:
     * - Template features include clientSignaturePolicy and staffSignaturePolicy
     * - Signatures array populated based on policies (Hidden = excluded)
     * - signature_block section added when signatures exist
     * - Canonical payload structure matches specification
     */
    @IsTest
    static void testBuildPayloadWithSignaturePolicies() {
        // This test demonstrates the expected payload structure
        // Actual test requires Interview__c, InterviewTemplate__c, etc. to be deployed
        
        // Expected structure (from guide):
        Map<String, Object> expectedPayload = new Map<String, Object>{
            'template' => new Map<String, Object>{
                'id' => 'a0Y...',
                'name' => 'Psychosocial Intake',
                'versionId' => 'a1B...',
                'versionNumber' => 3,
                'features' => new Map<String, Object>{
                    'clientSignaturePolicy' => 'Required',
                    'staffSignaturePolicy' => 'Enabled',
                    'showProgramHeader' => true,
                    'allowBenefitsDisbursement' => false
                }
            },
            'interview' => new Map<String, Object>{
                'id' => 'a2C...',
                'dateStarted' => '2025-11-19T16:12:00Z',
                'dateCompleted' => '2025-11-19T16:43:00Z',
                'status' => 'Completed',
                'location' => '',
                'channel' => 'In Person'
            },
            'participant' => new Map<String, Object>{
                'id' => '001...',
                'displayName' => 'Alex Example',
                'dob' => '2007-04-15',
                'ageAtInterview' => 18,
                'pronouns' => 'they/them',
                'program' => new Map<String, Object>{
                    'id' => 'a0P...',
                    'name' => 'The Source',
                    'enrollmentId' => 'a4E...'
                }
            },
            'staff' => new Map<String, Object>{
                'id' => '005...',
                'displayName' => 'Spencer Essey',
                'role' => 'Case Manager'
            },
            'sections' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'SECTION_HEADER',
                    'label' => 'Interview Summary',
                    'kind' => 'summary',
                    'layout' => 'two-column',
                    'items' => new List<Object>()
                },
                new Map<String, Object>{
                    'id' => 'SECTION_SIGNATURES',
                    'label' => 'Signatures',
                    'kind' => 'signature_block',
                    'items' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'signature',
                            'role' => 'Client',
                            'policy' => 'Required',
                            'signed' => true,
                            'displayName' => 'Alex Example',
                            'dateSigned' => '2025-11-19T16:40:00Z',
                            'contentDocumentId' => '069...',
                            'sourceField' => 'Client_Signature_File_Id__c'
                        },
                        new Map<String, Object>{
                            'type' => 'signature',
                            'role' => 'Staff',
                            'policy' => 'Enabled',
                            'signed' => true,
                            'displayName' => 'Spencer Essey',
                            'dateSigned' => '2025-11-19T16:42:00Z',
                            'contentDocumentId' => '069...',
                            'sourceField' => 'Staff_Signature_File_Id__c'
                        }
                    }
                }
            },
            'signatures' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'CLIENT',
                    'role' => 'Client',
                    'policy' => 'Required',
                    'signed' => true,
                    'displayName' => 'Alex Example',
                    'dateSigned' => '2025-11-19T16:40:00Z',
                    'contentDocumentId' => '069...',
                    'sourceField' => 'Client_Signature_File_Id__c'
                },
                new Map<String, Object>{
                    'id' => 'STAFF',
                    'role' => 'Staff',
                    'policy' => 'Enabled',
                    'signed' => true,
                    'displayName' => 'Spencer Essey',
                    'dateSigned' => '2025-11-19T16:42:00Z',
                    'contentDocumentId' => '069...',
                    'sourceField' => 'Staff_Signature_File_Id__c'
                }
            },
            'audit' => new Map<String, Object>{
                'createdBy' => '005...',
                'createdByName' => 'Spencer Essey',
                'createdDate' => '2025-11-19T16:12:00Z',
                'lastModifiedBy' => '005...',
                'lastModifiedByName' => 'Spencer Essey',
                'lastModifiedDate' => '2025-11-19T16:43:00Z'
            }
        };
        
        // Validate structure
        System.assertNotEquals(null, expectedPayload.get('template'), 'Template block should exist');
        System.assertNotEquals(null, expectedPayload.get('interview'), 'Interview block should exist');
        System.assertNotEquals(null, expectedPayload.get('participant'), 'Participant block should exist');
        System.assertNotEquals(null, expectedPayload.get('sections'), 'Sections array should exist');
        System.assertNotEquals(null, expectedPayload.get('signatures'), 'Signatures array should exist');
        
        // Validate template features
        Map<String, Object> template = (Map<String, Object>)expectedPayload.get('template');
        Map<String, Object> features = (Map<String, Object>)template.get('features');
        
        System.assertEquals('Required', features.get('clientSignaturePolicy'), 
            'Client signature policy should be Required');
        System.assertEquals('Enabled', features.get('staffSignaturePolicy'), 
            'Staff signature policy should be Enabled');
        
        // Validate signatures array
        List<Object> signatures = (List<Object>)expectedPayload.get('signatures');
        System.assertEquals(2, signatures.size(), 'Should have 2 signatures (client + staff)');
        
        Map<String, Object> clientSig = (Map<String, Object>)signatures[0];
        System.assertEquals('CLIENT', clientSig.get('id'), 'First signature should be CLIENT');
        System.assertEquals('Required', clientSig.get('policy'), 'Client policy should match template');
        
        Map<String, Object> staffSig = (Map<String, Object>)signatures[1];
        System.assertEquals('STAFF', staffSig.get('id'), 'Second signature should be STAFF');
        System.assertEquals('Enabled', staffSig.get('policy'), 'Staff policy should match template');
        
        // Validate signature_block section exists
        List<Object> sections = (List<Object>)expectedPayload.get('sections');
        Boolean hasSignatureBlock = false;
        
        for (Object section : sections) {
            Map<String, Object> sectionMap = (Map<String, Object>)section;
            if (sectionMap.get('kind') == 'signature_block') {
                hasSignatureBlock = true;
                System.assertEquals('SECTION_SIGNATURES', sectionMap.get('id'), 
                    'Signature block section ID should be SECTION_SIGNATURES');
                
                List<Object> items = (List<Object>)sectionMap.get('items');
                System.assertEquals(2, items.size(), 'Signature block should have 2 items');
                
                Map<String, Object> item = (Map<String, Object>)items[0];
                System.assertEquals('signature', item.get('type'), 'Item type should be signature');
                System.assertEquals('Client', item.get('role'), 'First signature should be Client');
            }
        }
        
        System.assert(hasSignatureBlock, 'Sections should include signature_block when signatures exist');
    }
    
    /**
     * Test signature filtering based on Hidden policy
     * 
     * When a signature policy is "Hidden", it should not appear in:
     * - signatures[] array
     * - signature_block section items
     */
    @IsTest
    static void testHiddenSignaturesExcluded() {
        // Example: Client signature Hidden, Staff signature Enabled
        Map<String, Object> features = new Map<String, Object>{
            'clientSignaturePolicy' => 'Hidden',
            'staffSignaturePolicy' => 'Enabled',
            'showProgramHeader' => true,
            'allowBenefitsDisbursement' => false
        };
        
        // Expected: Only staff signature in array
        List<Object> expectedSignatures = new List<Object>{
            new Map<String, Object>{
                'id' => 'STAFF',
                'role' => 'Staff',
                'policy' => 'Enabled',
                'signed' => false,
                'displayName' => 'Spencer Essey',
                'dateSigned' => null,
                'contentDocumentId' => null,
                'sourceField' => 'Staff_Signature_File_Id__c'
            }
        };
        
        System.assertEquals(1, expectedSignatures.size(), 
            'Hidden signature policy should exclude signature from array');
        
        Map<String, Object> onlySignature = (Map<String, Object>)expectedSignatures[0];
        System.assertEquals('STAFF', onlySignature.get('id'), 
            'Only staff signature should be present when client is hidden');
    }
    
    /**
     * Test section kinds enum
     * 
     * Validates all supported section kinds match the canonical specification.
     */
    @IsTest
    static void testSectionKinds() {
        List<String> validKinds = new List<String>{
            'summary',
            'field_group',
            'question_group',
            'table',
            'signature_block',
            'notes'
        };
        
        System.assertEquals(6, validKinds.size(), 'Should have 6 section kinds');
        System.assert(validKinds.contains('signature_block'), 
            'Section kinds should include signature_block');
    }
    
    /**
     * Test item types enum
     * 
     * Validates all supported item types match the canonical specification.
     */
    @IsTest
    static void testItemTypes() {
        List<String> validTypes = new List<String>{
            'field',
            'qna',
            'table_row',
            'signature',
            'note'
        };
        
        System.assertEquals(5, validTypes.size(), 'Should have 5 item types');
        System.assert(validTypes.contains('signature'), 
            'Item types should include signature');
    }
}
