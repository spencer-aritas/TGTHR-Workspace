/**
 * BenefitReplacementService
 *
 * Handles the controlled lifecycle of Benefit records in Salesforce NPC, where
 * the Benefit Type on an existing record cannot be changed in-place.
 *
 * Core pattern:
 *  1. Retire the old Benefit (IsActive=false, Lifecycle_State__c=Replaced, Replaced_By_Benefit__c=newId)
 *  2. Create a replacement Benefit with the new BenefitType (and optional name/UOM changes)
 *  3. Set Supersedes_Benefit__c on the new record to point back to the old one
 *  4. Clone any ProgramBenefitConfig__c from old → new, then deactivate old config
 *
 * Historical BenefitAssignments and BenefitDisbursements are intentionally left
 * untouched — they remain associated with the original Benefit for reporting fidelity.
 * Open (Active) BenefitAssignments are surfaced in the ReplaceResult.openAssignmentCount
 * so callers can decide whether to migrate or warn.
 */
public without sharing class BenefitReplacementService {

    // Field existence check: Available_for_Program_Engagement__c is not present in all orgs
    private static final Boolean HAS_PROG_ENG_FIELD =
        Schema.getGlobalDescribe().get('Benefit') != null &&
        Schema.getGlobalDescribe().get('Benefit').getDescribe().fields.getMap()
            .containsKey('available_for_program_engagement__c');

    // Field existence check: Require_Case_Note__c — Census-channel sub-flag that
    // (a) requires Meeting Notes on disbursement and (b) flags the resulting
    // InteractionSummary as a Case Note wrapper for child Notes/Interviews.
    private static final Boolean HAS_REQUIRE_CASE_NOTE_FIELD =
        Schema.getGlobalDescribe().get('Benefit') != null &&
        Schema.getGlobalDescribe().get('Benefit').getDescribe().fields.getMap()
            .containsKey('require_case_note__c');

    // ─────────────────────────────────────────────
    // DTOs
    // ─────────────────────────────────────────────

    public class ReplaceRequest {
        @AuraEnabled public Id   oldBenefitId;
        @AuraEnabled public String newBenefitName;       // if blank, inherits old name
        @AuraEnabled public String newBenefitTypeId;     // String (not Id) to survive Aura bridge deserialization
        @AuraEnabled public String newBenefitTypeName;   // used to resolve if newBenefitTypeId blank
        @AuraEnabled public Id   newUnitId;              // optional: new Unit of Measure record
        @AuraEnabled public String newUnitName;          // used to resolve if newUnitId blank
        @AuraEnabled public Date  effectiveDate;         // defaults to today
        @AuraEnabled public Boolean migrateOpenAssignments; // default: false (warn only)
    }

    public class RetireRequest {
        @AuraEnabled public Id   benefitId;
        @AuraEnabled public Date  effectiveDate;  // defaults to today
    }

    public class CreateRequest {
        @AuraEnabled public Id      programId;
        @AuraEnabled public String  benefitName;
        @AuraEnabled public String  benefitTypeId;   // String (not Id) to survive Aura bridge deserialization
        @AuraEnabled public String  benefitTypeName;
        @AuraEnabled public Id      unitId;
        @AuraEnabled public String  unitName;
        @AuraEnabled public Boolean availableForClinical;
        @AuraEnabled public Boolean availableForPeer;
        @AuraEnabled public Boolean availableForCaseManagement;
        @AuraEnabled public Boolean availableForHousing;
        @AuraEnabled public Boolean availableForProgramEngagement;
        @AuraEnabled public Boolean requireCaseNote;
        @AuraEnabled public Decimal defaultDisbursementQty;
        @AuraEnabled public Decimal defaultDurationMinutes;
        @AuraEnabled public String  cptCode;
    }

    public class ReplaceResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id      oldBenefitId;
        @AuraEnabled public Id      newBenefitId;
        @AuraEnabled public String  message;
        @AuraEnabled public Integer openAssignmentCount;
        @AuraEnabled public Integer configsCopied;
    }

    // ─────────────────────────────────────────────
    // PUBLIC API
    // ─────────────────────────────────────────────

    /**
     * Replace an existing Benefit with a new one carrying a different BenefitType.
     * Exposed to LWC via @AuraEnabled for the Program Services workspace guided action.
     */
    @AuraEnabled
    public static ReplaceResult replaceBenefit(ReplaceRequest req) {
        ReplaceResult res = new ReplaceResult();
        res.openAssignmentCount = 0;
        res.configsCopied = 0;

        try {
            if (req == null || req.oldBenefitId == null) {
                throw new IllegalArgumentException('oldBenefitId is required');
            }

            // 1. Load the old Benefit
            SObject oldBenefit = loadBenefit(req.oldBenefitId);
            if (oldBenefit == null) {
                throw new IllegalArgumentException('Benefit not found: ' + req.oldBenefitId);
            }

            Id programId = (Id) oldBenefit.get('ProgramId');
            String oldName = (String) oldBenefit.get('Name');

            // 2. Resolve new BenefitType
            Id newBenefitTypeId = String.isNotBlank(req.newBenefitTypeId) ? (Id) req.newBenefitTypeId : null;
            if (newBenefitTypeId == null && String.isNotBlank(req.newBenefitTypeName)) {
                newBenefitTypeId = resolveBenefitTypeByName(req.newBenefitTypeName);
            }
            if (newBenefitTypeId == null) {
                throw new IllegalArgumentException(
                    'Could not resolve new BenefitType. Provide newBenefitTypeId or a valid newBenefitTypeName.'
                );
            }

            // 3. Resolve new Unit (optional — inherits existing if not provided)
            Id newUnitId = req.newUnitId;
            if (newUnitId == null && String.isNotBlank(req.newUnitName)) {
                newUnitId = resolveUnitByName(req.newUnitName);
            }
            if (newUnitId == null) {
                // Inherit from old benefit
                newUnitId = (Id) oldBenefit.get('UnitId');
            }

            Date effectiveDate = (req.effectiveDate != null) ? req.effectiveDate : Date.today();

            // 4. Count open BenefitAssignments (for caller awareness)
            res.openAssignmentCount = countOpenAssignments(req.oldBenefitId);

            // 5. Create new Benefit
            String newName = String.isNotBlank(req.newBenefitName) ? req.newBenefitName : oldName;
            Id newBenefitId = createReplacementBenefit(
                programId, newName, newBenefitTypeId, newUnitId, req.oldBenefitId, oldBenefit
            );

            // 6. Retire old Benefit and link to new
            retireBenefitInternal(req.oldBenefitId, newBenefitId, effectiveDate);

            // 7. Clone ProgramBenefitConfig__c old→new; deactivate old config
            res.configsCopied = cloneConfigs(req.oldBenefitId, newBenefitId);

            // 8. Optionally migrate open BenefitAssignments to new benefit
            if (req.migrateOpenAssignments == true && res.openAssignmentCount > 0) {
                migrateOpenAssignments(req.oldBenefitId, newBenefitId);
            }

            res.success = true;
            res.oldBenefitId = req.oldBenefitId;
            res.newBenefitId = newBenefitId;
            res.message = 'Benefit replaced successfully. ' +
                (res.openAssignmentCount > 0 && req.migrateOpenAssignments != true
                    ? res.openAssignmentCount + ' open assignment(s) were NOT migrated — review manually.'
                    : '');

        } catch (Exception e) {
            res.success = false;
            res.message = e.getMessage();
            System.debug('BenefitReplacementService.replaceBenefit error: ' + e.getMessage() +
                '\n' + e.getStackTraceString());
        }

        return res;
    }

    /**
     * LWC-facing wrapper — all parameters are flat primitives; no inner class is passed
     * from the Aura bridge to avoid deserialization issues with Id-typed fields.
     */
    @AuraEnabled
    public static ReplaceResult replaceBenefitInPlace(
        String oldBenefitId,
        String newBenefitTypeId,
        String newBenefitName,
        Boolean migrateOpenAssignments
    ) {
        ReplaceRequest req = new ReplaceRequest();
        if (String.isNotBlank(oldBenefitId))     req.oldBenefitId           = (Id) oldBenefitId;
        if (String.isNotBlank(newBenefitTypeId)) req.newBenefitTypeId        = newBenefitTypeId;
        if (String.isNotBlank(newBenefitName))   req.newBenefitName          = newBenefitName;
        req.migrateOpenAssignments = (migrateOpenAssignments == true);
        return replaceBenefit(req);
    }

    /**
     * Retire a Benefit without creating a replacement (e.g. "Not Needed" in CSV).
     */
    @AuraEnabled
    public static ReplaceResult retireBenefit(RetireRequest req) {
        ReplaceResult res = new ReplaceResult();
        res.configsCopied = 0;
        res.openAssignmentCount = 0;

        try {
            if (req == null || req.benefitId == null) {
                throw new IllegalArgumentException('benefitId is required');
            }

            Date effectiveDate = (req.effectiveDate != null) ? req.effectiveDate : Date.today();

            res.openAssignmentCount = countOpenAssignments(req.benefitId);
            retireBenefitInternal(req.benefitId, null, effectiveDate);
            deactivateConfigs(req.benefitId);

            res.success = true;
            res.oldBenefitId = req.benefitId;
            res.newBenefitId = null;
            res.message = 'Benefit retired successfully.';

        } catch (Exception e) {
            res.success = false;
            res.message = e.getMessage();
        }

        return res;
    }

    /**
     * LWC-facing wrapper — benefitId as a flat primitive; no inner class from the bridge.
     */
    @AuraEnabled
    public static ReplaceResult retireBenefitInPlace(String benefitId) {
        RetireRequest req = new RetireRequest();
        if (String.isNotBlank(benefitId)) req.benefitId = (Id) benefitId;
        return retireBenefit(req);
    }

    /**
     * Create a brand-new Benefit (no predecessor) and optionally bootstrap a ProgramBenefitConfig.
     *
     * LWC-facing: programId, benefitName, and benefitTypeId are accepted as top-level Strings
     * to avoid nested-object deserialization issues in the Aura bridge,
     * then merged into req before processing.
     */
    @AuraEnabled
    public static ReplaceResult createBenefit(String programId, String benefitName, String benefitTypeId, CreateRequest req) {
        ReplaceResult res = new ReplaceResult();
        res.configsCopied = 0;
        res.openAssignmentCount = 0;

        try {
            if (req == null) req = new CreateRequest();
            if (String.isNotBlank(programId))   req.programId   = (Id) programId;
            if (String.isNotBlank(benefitName)) req.benefitName = benefitName;

            if (req.programId == null || String.isBlank(req.benefitName)) {
                throw new IllegalArgumentException('programId and benefitName are required');
            }

            // benefitTypeId comes as a top-level String to bypass Aura inner-class deserialization.
            // Fall back to req fields for programmatic/test callers that don't use the bridge.
            Id resolvedBenefitTypeId = String.isNotBlank(benefitTypeId) ? (Id) benefitTypeId : null;
            if (resolvedBenefitTypeId == null && String.isNotBlank(req.benefitTypeId)) {
                resolvedBenefitTypeId = (Id) req.benefitTypeId;
            }
            if (resolvedBenefitTypeId == null && String.isNotBlank(req.benefitTypeName)) {
                resolvedBenefitTypeId = resolveBenefitTypeByName(req.benefitTypeName);
            }
            if (resolvedBenefitTypeId == null) {
                throw new IllegalArgumentException('A Service Type (Benefit Type) is required to create a service.');
            }
            Id unitId = req.unitId;
            if (unitId == null && String.isNotBlank(req.unitName)) {
                unitId = resolveUnitByName(req.unitName);
            }

            // Validate CPT code requirement for Clinical benefit types (in system mode
            // to avoid cross-reference access errors when BenefitType OWD is Private)
            if (resolvedBenefitTypeId != null) {
                List<SObject> btRows = Database.query(
                    'SELECT Id, Category FROM BenefitType WHERE Id = :resolvedBenefitTypeId LIMIT 1'
                );
                if (!btRows.isEmpty()) {
                    String category = (String) btRows[0].get('Category');
                    if ('Clinical'.equals(category) && String.isBlank(req.cptCode)) {
                        throw new IllegalArgumentException('CPT Code is required when Benefit Type is Clinical.');
                    }
                }
            }

            SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
            b.put('Name', req.benefitName);
            b.put('ProgramId', req.programId);
            b.put('IsActive', true);
            safePut(b, 'Lifecycle_State__c', 'Active');
            if (resolvedBenefitTypeId != null) {
                safePut(b, 'BenefitTypeId', resolvedBenefitTypeId);
            }
            if (String.isNotBlank(req.cptCode)) {
                safePut(b, 'CPT_Code__c', req.cptCode);
            }
            if (unitId != null) {
                safePut(b, 'UnitId', unitId);
            }
            if (req.availableForClinical != null) {
                safePut(b, 'Available_for_Clinical__c', req.availableForClinical);
            }
            if (req.availableForPeer != null) {
                safePut(b, 'Available_for_Peer__c', req.availableForPeer);
            }
            if (req.availableForCaseManagement != null) {
                safePut(b, 'Available_for_Case_Management__c', req.availableForCaseManagement);
            }
            if (req.availableForHousing != null) {
                safePut(b, 'Is_a_Housing_Benefit__c', req.availableForHousing);
            }
            if (req.availableForProgramEngagement != null) {
                safePut(b, 'Available_for_Program_Engagement__c', req.availableForProgramEngagement);
            }
            if (req.requireCaseNote != null) {
                safePut(b, 'Require_Case_Note__c', req.requireCaseNote);
            }
            if (req.defaultDisbursementQty != null) {
                safePut(b, 'Default_Disbursement_Quantity__c', req.defaultDisbursementQty);
            }
            if (req.defaultDurationMinutes != null) {
                safePut(b, 'Default_Duration_C__c', req.defaultDurationMinutes);
            }

            Database.insert(b, AccessLevel.SYSTEM_MODE);

            res.success = true;
            res.newBenefitId = (Id) b.get('Id');
            res.message = 'Benefit created: ' + req.benefitName;

        } catch (Exception e) {
            res.success = false;
            res.message = e.getMessage();
        }

        return res;
    }

    /**
     * Resolver: returns the active, lifecycle-aware list of Benefits for a Program.
     * This is the single source of truth that Census, Interviews, and pickers should call
     * instead of raw Benefit queries.
     *
     * Filters: IsActive = true, Lifecycle_State__c IN ('Active', null), ProgramId = programId
     * Optional: roleFilter ('Clinical' | 'Case Management' | 'Peer') to respect availability flags.
     */
    @AuraEnabled
    public static List<BenefitOption> getActiveBenefitsForProgram(
        Id programId,
        String roleFilter
    ) {
        List<BenefitOption> out = new List<BenefitOption>();
        if (programId == null) return out;

        String query =
            'SELECT Id, Name, BenefitTypeId, BenefitType.Name, BenefitType.Category, ' +
            '       UnitId, Unit.Name, IsActive, Lifecycle_State__c, ' +
            '       Available_for_Clinical__c, Available_for_Peer__c, Available_for_Case_Management__c, ' +
            '       Is_a_Housing_Benefit__c, ' + (HAS_PROG_ENG_FIELD ? 'Available_for_Program_Engagement__c, ' : '') +
            (HAS_REQUIRE_CASE_NOTE_FIELD ? '       Require_Case_Note__c, ' : '') +
            '       Default_Disbursement_Quantity__c, Default_Duration_C__c ' +
            'FROM Benefit ' +
            'WHERE ProgramId = :programId ' +
            '  AND IsActive = true ' +
            'ORDER BY Name';

        List<SObject> benefits = Database.query(query);

        for (SObject b : benefits) {
            String state = (String) b.get('Lifecycle_State__c');
            // Exclude Replaced/Retired records even if IsActive was missed on retirement
            if (state == 'Retired' || state == 'Replaced') continue;

            // Role filter
            if (String.isNotBlank(roleFilter)) {
                String role = roleFilter.trim().toLowerCase();
                if (role == 'clinical' && b.get('Available_for_Clinical__c') != true) continue;
                if (role == 'peer' && b.get('Available_for_Peer__c') != true) continue;
                if ((role == 'case management' || role == 'casemanagement') &&
                        b.get('Available_for_Case_Management__c') != true) continue;
            }

            BenefitOption opt = new BenefitOption();
            opt.benefitId   = (Id)     b.get('Id');
            opt.benefitName = (String) b.get('Name');
            opt.benefitTypeId = (Id)   b.get('BenefitTypeId');
            SObject bt = b.getSObject('BenefitType');
            opt.benefitTypeName     = bt != null ? (String) bt.get('Name')     : null;
            opt.benefitTypeCategory = bt != null ? (String) bt.get('Category') : null;
            opt.unitId              = (Id) b.get('UnitId');
            SObject un              = b.getSObject('Unit');
            opt.unitName            = un != null ? (String) un.get('Name') : null;
            opt.availableForClinical       = b.get('Available_for_Clinical__c') == true;
            opt.availableForCaseManagement = b.get('Available_for_Case_Management__c') == true;
            opt.availableForPeer           = b.get('Available_for_Peer__c') == true;
            opt.availableForHousing             = b.get('Is_a_Housing_Benefit__c') == true;
            opt.availableForProgramEngagement  = HAS_PROG_ENG_FIELD && b.get('Available_for_Program_Engagement__c') == true;
            opt.requireCaseNote                = HAS_REQUIRE_CASE_NOTE_FIELD && b.get('Require_Case_Note__c') == true;
            opt.defaultDisbursementQty         = (Decimal) b.get('Default_Disbursement_Quantity__c');
            opt.defaultDurationMinutes         = (Decimal) b.get('Default_Duration_C__c');
            opt.label = opt.benefitName;
            opt.value = String.valueOf(opt.benefitId);
            out.add(opt);
        }

        return out;
    }

    /**
     * getAllBenefitsForProgram
     *
     * Returns ALL benefits for the program (active AND inactive), for the history tab
     * in programBenefitManager. Includes Retired/Replaced records with lifecycle details.
     */
    @AuraEnabled
    public static List<BenefitOption> getAllBenefitsForProgram(Id programId) {
        List<BenefitOption> out = new List<BenefitOption>();
        if (programId == null) return out;

        String query =
            'SELECT Id, Name, BenefitTypeId, BenefitType.Name, BenefitType.Category, ' +
            '       UnitId, Unit.Name, IsActive, Lifecycle_State__c, Replaced_By_Benefit__c, ' +
            '       Replaced_By_Benefit__r.Name, ' +
            '       Available_for_Clinical__c, Available_for_Peer__c, Available_for_Case_Management__c, ' +
            '       Is_a_Housing_Benefit__c, ' + (HAS_PROG_ENG_FIELD ? 'Available_for_Program_Engagement__c, ' : '') +
            (HAS_REQUIRE_CASE_NOTE_FIELD ? '       Require_Case_Note__c, ' : '') +
            '       Default_Disbursement_Quantity__c, Default_Duration_C__c ' +
            'FROM Benefit ' +
            'WHERE ProgramId = :programId ' +
            'ORDER BY Name';

        for (SObject b : Database.query(query)) {
            BenefitOption opt = new BenefitOption();
            opt.benefitId   = (Id)     b.get('Id');
            opt.benefitName = (String) b.get('Name');
            opt.benefitTypeId = (Id)   b.get('BenefitTypeId');
            SObject bt = b.getSObject('BenefitType');
            opt.benefitTypeName     = bt != null ? (String) bt.get('Name')     : null;
            opt.benefitTypeCategory = bt != null ? (String) bt.get('Category') : null;
            opt.lifecycleState = (String) b.get('Lifecycle_State__c');
            opt.availableForClinical       = b.get('Available_for_Clinical__c') == true;
            opt.availableForCaseManagement = b.get('Available_for_Case_Management__c') == true;
            opt.availableForPeer           = b.get('Available_for_Peer__c') == true;
            opt.availableForHousing            = b.get('Is_a_Housing_Benefit__c') == true;
            opt.availableForProgramEngagement = HAS_PROG_ENG_FIELD && b.get('Available_for_Program_Engagement__c') == true;
            opt.requireCaseNote                = HAS_REQUIRE_CASE_NOTE_FIELD && b.get('Require_Case_Note__c') == true;
            opt.unitId                        = (Id) b.get('UnitId');
            SObject un2 = b.getSObject('Unit');
            opt.unitName                      = un2 != null ? (String) un2.get('Name') : null;
            opt.defaultDisbursementQty        = (Decimal) b.get('Default_Disbursement_Quantity__c');
            opt.defaultDurationMinutes        = (Decimal) b.get('Default_Duration_C__c');
            SObject replacedBy = b.getSObject('Replaced_By_Benefit__r');
            opt.replacedByName = replacedBy != null ? (String) replacedBy.get('Name') : null;
            opt.label = opt.benefitName;
            opt.value = String.valueOf(opt.benefitId);
            out.add(opt);
        }
        return out;
    }

    public class BenefitOption {
        @AuraEnabled public String  label;
        @AuraEnabled public String  value;
        @AuraEnabled public Id      benefitId;
        @AuraEnabled public String  benefitName;
        @AuraEnabled public Id      benefitTypeId;
        @AuraEnabled public String  benefitTypeName;
        @AuraEnabled public String  benefitTypeCategory;
        @AuraEnabled public String  lifecycleState;
        @AuraEnabled public Boolean availableForClinical;
        @AuraEnabled public Boolean availableForCaseManagement;
        @AuraEnabled public Boolean availableForPeer;
        @AuraEnabled public Boolean availableForHousing;
        @AuraEnabled public Boolean availableForProgramEngagement;
        @AuraEnabled public Boolean requireCaseNote;
        @AuraEnabled public String  replacedByName;
        @AuraEnabled public Id      unitId;
        @AuraEnabled public String  unitName;
        @AuraEnabled public Decimal defaultDisbursementQty;
        @AuraEnabled public Decimal defaultDurationMinutes;
    }

    // ─────────────────────────────────────────────
    // UPDATE: in-place edits (no history created)
    // ─────────────────────────────────────────────

    public class UpdateRequest {
        @AuraEnabled public String  benefitId;
        @AuraEnabled public String  newBenefitName;
        @AuraEnabled public Boolean availableForClinical;
        @AuraEnabled public Boolean availableForCaseManagement;
        @AuraEnabled public Boolean availableForPeer;
        @AuraEnabled public Boolean availableForHousing;
        @AuraEnabled public Boolean availableForProgramEngagement;
        @AuraEnabled public Boolean requireCaseNote;
        @AuraEnabled public Id      unitId;
        @AuraEnabled public String  newUnitName;
        @AuraEnabled public Decimal defaultDisbursementQty;
        @AuraEnabled public Decimal defaultDurationMinutes;
    }

    /**
     * Update non-type fields on a Benefit in place — no history record created.
     * BenefitTypeId is the only field that requires replaceBenefit instead.
     */
    @AuraEnabled
    public static ReplaceResult updateBenefit(UpdateRequest req) {
        ReplaceResult res = new ReplaceResult();
        res.configsCopied = 0;
        res.openAssignmentCount = 0;
        try {
            if (req == null || String.isBlank(req.benefitId)) {
                throw new IllegalArgumentException('benefitId is required');
            }
            Id unitId = req.unitId;
            if (unitId == null && String.isNotBlank(req.newUnitName)) {
                unitId = resolveUnitByName(req.newUnitName);
            }
            SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
            b.put('Id', (Id) req.benefitId);
            if (String.isNotBlank(req.newBenefitName)) {
                b.put('Name', req.newBenefitName);
            }
            if (req.availableForClinical != null) {
                safePut(b, 'Available_for_Clinical__c', req.availableForClinical);
            }
            if (req.availableForCaseManagement != null) {
                safePut(b, 'Available_for_Case_Management__c', req.availableForCaseManagement);
            }
            if (req.availableForPeer != null) {
                safePut(b, 'Available_for_Peer__c', req.availableForPeer);
            }
            if (req.availableForHousing != null) {
                safePut(b, 'Is_a_Housing_Benefit__c', req.availableForHousing);
            }
            if (req.availableForProgramEngagement != null) {
                safePut(b, 'Available_for_Program_Engagement__c', req.availableForProgramEngagement);
            }
            if (req.requireCaseNote != null) {
                safePut(b, 'Require_Case_Note__c', req.requireCaseNote);
            }
            if (unitId != null) {
                safePut(b, 'UnitId', unitId);
            }
            if (req.defaultDisbursementQty != null) {
                safePut(b, 'Default_Disbursement_Quantity__c', req.defaultDisbursementQty);
            }
            if (req.defaultDurationMinutes != null) {
                safePut(b, 'Default_Duration_C__c', req.defaultDurationMinutes);
            }
            Database.update(b, AccessLevel.SYSTEM_MODE);
            res.success = true;
            res.oldBenefitId = (Id) req.benefitId;
            res.message = 'Benefit updated.';
        } catch (Exception e) {
            res.success = false;
            res.message = e.getMessage();
            System.debug('updateBenefit error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        return res;
    }

    /**
     * LWC-facing wrapper — all fields accepted as top-level primitive parameters
     * to bypass Aura bridge inner-class deserialization (same pattern as createBenefit).
     * The nested UpdateRequest form was silently arriving null, producing a no-op
     * update that returned success=true without writing any data.
     */
    @AuraEnabled
    public static ReplaceResult updateBenefitInPlace(
        String  benefitId,
        String  newBenefitName,
        String  newUnitName,
        Decimal defaultDisbursementQty,
        Decimal defaultDurationMinutes,
        Boolean availableForClinical,
        Boolean availableForCaseManagement,
        Boolean availableForPeer,
        Boolean availableForHousing,
        Boolean availableForProgramEngagement,
        Boolean requireCaseNote
    ) {
        UpdateRequest req = new UpdateRequest();
        req.benefitId                  = benefitId;
        req.newBenefitName             = newBenefitName;
        req.newUnitName                = newUnitName;
        req.defaultDisbursementQty     = defaultDisbursementQty;
        req.defaultDurationMinutes     = defaultDurationMinutes;
        req.availableForClinical       = availableForClinical;
        req.availableForCaseManagement = availableForCaseManagement;
        req.availableForPeer           = availableForPeer;
        req.availableForHousing        = availableForHousing;
        req.availableForProgramEngagement = availableForProgramEngagement;
        req.requireCaseNote            = requireCaseNote;
        return updateBenefit(req);
    }

    /**
     * Returns all UnitOfMeasure records as {label, value} for comboboxes.
     * value = Name (string) so callers can pass newUnitName to updateBenefit/createBenefit.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUnitOptions() {
        List<Map<String, String>> out = new List<Map<String, String>>();
        try {
            for (SObject u : Database.query('SELECT Id, Name FROM UnitOfMeasure ORDER BY Name')) {
                out.add(new Map<String, String>{
                    'label' => (String) u.get('Name'),
                    'value' => (String) u.get('Name')
                });
            }
        } catch (Exception e) {
            System.debug('getUnitOptions error: ' + e.getMessage());
        }
        return out;
    }

    // ─────────────────────────────────────────────
    // INTERNAL HELPERS
    // ─────────────────────────────────────────────

    private static SObject loadBenefit(Id benefitId) {
        String q =
            'SELECT Id, Name, ProgramId, BenefitTypeId, UnitId, IsActive, ' +
            '       Lifecycle_State__c, Available_for_Clinical__c, ' +
            '       Available_for_Peer__c, Available_for_Case_Management__c, ' +
            '       Is_a_Housing_Benefit__c, ' + (HAS_PROG_ENG_FIELD ? 'Available_for_Program_Engagement__c, ' : '') +
            (HAS_REQUIRE_CASE_NOTE_FIELD ? '       Require_Case_Note__c, ' : '') +
            '       Default_Disbursement_Quantity__c, Default_Duration_C__c ' +
            'FROM Benefit WHERE Id = :benefitId LIMIT 1';
        List<SObject> rows = Database.query(q);
        return rows.isEmpty() ? null : rows[0];
    }

    private static Id createReplacementBenefit(
        Id programId,
        String name,
        Id benefitTypeId,
        Id unitId,
        Id supersedesId,
        SObject oldBenefit
    ) {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('Name', name);
        b.put('ProgramId', programId);
        b.put('IsActive', true);
        safePut(b, 'Lifecycle_State__c', 'Active');
        safePut(b, 'BenefitTypeId', benefitTypeId);
        if (unitId != null) {
            safePut(b, 'UnitId', unitId);
        }
        safePut(b, 'Supersedes_Benefit__c', supersedesId);
        // Carry forward availability flags and reporting defaults from old benefit
        safePut(b, 'Available_for_Clinical__c',        oldBenefit.get('Available_for_Clinical__c'));
        safePut(b, 'Available_for_Peer__c',            oldBenefit.get('Available_for_Peer__c'));
        safePut(b, 'Available_for_Case_Management__c', oldBenefit.get('Available_for_Case_Management__c'));
        safePut(b, 'Is_a_Housing_Benefit__c',              oldBenefit.get('Is_a_Housing_Benefit__c'));
        if (HAS_PROG_ENG_FIELD) {
            safePut(b, 'Available_for_Program_Engagement__c', oldBenefit.get('Available_for_Program_Engagement__c'));
        }
        if (HAS_REQUIRE_CASE_NOTE_FIELD) {
            safePut(b, 'Require_Case_Note__c', oldBenefit.get('Require_Case_Note__c'));
        }
        safePut(b, 'Default_Disbursement_Quantity__c',    oldBenefit.get('Default_Disbursement_Quantity__c'));
        safePut(b, 'Default_Duration_C__c',               oldBenefit.get('Default_Duration_C__c'));
        Database.insert(b, AccessLevel.SYSTEM_MODE);
        return (Id) b.get('Id');
    }

    private static void retireBenefitInternal(Id benefitId, Id replacedById, Date effectiveDate) {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('Id', benefitId);
        b.put('IsActive', false);
        safePut(b, 'Lifecycle_State__c', replacedById != null ? 'Replaced' : 'Retired');
        if (replacedById != null) {
            safePut(b, 'Replaced_By_Benefit__c', replacedById);
        }
        Database.update(b, AccessLevel.SYSTEM_MODE);
    }

    /**
     * Pre-flight check: how many active BenefitAssignments does this benefit have?
     * Called by the programBenefitManager LWC before the Replace modal is confirmed,
     * so the user can decide whether to migrate them.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getOpenAssignmentCount(Id benefitId) {
        return countOpenAssignments(benefitId);
    }

    private static Integer countOpenAssignments(Id benefitId) {
        try {
            AggregateResult[] ar = [
                SELECT COUNT(Id) cnt
                FROM BenefitAssignment
                WHERE BenefitId = :benefitId
                  AND Status = 'Active'
            ];
            return (Integer) ar[0].get('cnt');
        } catch (Exception e) {
            System.debug('countOpenAssignments error: ' + e.getMessage());
            return 0;
        }
    }

    private static Integer cloneConfigs(Id oldBenefitId, Id newBenefitId) {
        List<SObject> oldConfigs;
        try {
            oldConfigs = Database.query(
                'SELECT Id, Program__c, Is_Census_Eligible__c, Census_Counting_Method__c, ' +
                '       Is_Interview_Enabled__c, Interview_Auto_Disbursement__c, ' +
                '       Is_Mobile_Available__c, Requires_Enrollment__c, ' +
                '       Allow_Ad_Hoc_Disbursement__c, Requires_Signature__c, ' +
                '       Is_Billable__c, CPT_Enabled__c, Generates_Interaction_Summary__c, ' +
                '       Counts_Toward_Attendance__c, Goal_Linkage_Enabled__c, ' +
                '       Available_for_Clinical__c, Available_for_Case_Management__c, ' +
                '       Available_for_Peer__c, Display_Order__c, Notes__c ' +
                'FROM ProgramBenefitConfig__c ' +
                'WHERE Benefit__c = :oldBenefitId AND Is_Active__c = true'
            );
        } catch (Exception e) {
            System.debug('cloneConfigs query error (object may not be deployed yet): ' + e.getMessage());
            return 0;
        }

        if (oldConfigs == null || oldConfigs.isEmpty()) return 0;

        List<SObject> newConfigs = new List<SObject>();
        for (SObject old : oldConfigs) {
            SObject n = Schema.getGlobalDescribe().get('ProgramBenefitConfig__c').newSObject();
            n.put('Benefit__c', newBenefitId);
            n.put('Program__c', old.get('Program__c'));
            n.put('Is_Active__c', true);
            n.put('Is_Census_Eligible__c', old.get('Is_Census_Eligible__c'));
            n.put('Census_Counting_Method__c', old.get('Census_Counting_Method__c'));
            n.put('Is_Interview_Enabled__c', old.get('Is_Interview_Enabled__c'));
            n.put('Interview_Auto_Disbursement__c', old.get('Interview_Auto_Disbursement__c'));
            n.put('Is_Mobile_Available__c', old.get('Is_Mobile_Available__c'));
            n.put('Requires_Enrollment__c', old.get('Requires_Enrollment__c'));
            n.put('Allow_Ad_Hoc_Disbursement__c', old.get('Allow_Ad_Hoc_Disbursement__c'));
            n.put('Requires_Signature__c', old.get('Requires_Signature__c'));
            n.put('Is_Billable__c', old.get('Is_Billable__c'));
            n.put('CPT_Enabled__c', old.get('CPT_Enabled__c'));
            n.put('Generates_Interaction_Summary__c', old.get('Generates_Interaction_Summary__c'));
            n.put('Counts_Toward_Attendance__c', old.get('Counts_Toward_Attendance__c'));
            n.put('Goal_Linkage_Enabled__c', old.get('Goal_Linkage_Enabled__c'));
            n.put('Available_for_Clinical__c', old.get('Available_for_Clinical__c'));
            n.put('Available_for_Case_Management__c', old.get('Available_for_Case_Management__c'));
            n.put('Available_for_Peer__c', old.get('Available_for_Peer__c'));
            n.put('Display_Order__c', old.get('Display_Order__c'));
            n.put('Notes__c', old.get('Notes__c'));
            newConfigs.add(n);
        }
        Database.insert(newConfigs, AccessLevel.SYSTEM_MODE);

        // Deactivate old configs
        deactivateConfigs(oldBenefitId);

        return newConfigs.size();
    }

    private static void deactivateConfigs(Id benefitId) {
        try {
            List<SObject> configs = Database.query(
                'SELECT Id FROM ProgramBenefitConfig__c WHERE Benefit__c = :benefitId AND Is_Active__c = true'
            );
            for (SObject c : configs) {
                c.put('Is_Active__c', false);
            }
            if (!configs.isEmpty()) Database.update(configs, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug('deactivateConfigs error (object may not be deployed): ' + e.getMessage());
        }
    }

    private static void migrateOpenAssignments(Id oldBenefitId, Id newBenefitId) {
        List<SObject> openAssignments;
        try {
            openAssignments = Database.query(
                'SELECT Id FROM BenefitAssignment WHERE BenefitId = :oldBenefitId AND Status = \'Active\''
            );
        } catch (Exception e) {
            System.debug('migrateOpenAssignments query error: ' + e.getMessage());
            return;
        }
        for (SObject ba : openAssignments) {
            ba.put('BenefitId', newBenefitId);
        }
        if (!openAssignments.isEmpty()) Database.update(openAssignments, AccessLevel.SYSTEM_MODE);
    }

    private static Id resolveBenefitTypeByName(String name) {
        if (String.isBlank(name)) return null;
        String trimmed = name.trim();
        List<SObject> rows = Database.query(
            'SELECT Id FROM BenefitType WHERE Name = :trimmed ORDER BY CreatedDate ASC LIMIT 1'
        );
        return rows.isEmpty() ? null : (Id) rows[0].get('Id');
    }

    private static Id resolveUnitByName(String name) {
        if (String.isBlank(name)) return null;
        String trimmed = name.trim();
        try {
            List<SObject> rows = Database.query(
                'SELECT Id FROM UnitOfMeasure WHERE Name = :trimmed LIMIT 1'
            );
            return rows.isEmpty() ? null : (Id) rows[0].get('Id');
        } catch (Exception e) {
            System.debug('resolveUnitByName error: ' + e.getMessage());
            return null;
        }
    }

    private static void safePut(SObject obj, String fieldName, Object value) {
        try {
            obj.put(fieldName, value);
        } catch (Exception e) {
            System.debug('safePut(' + fieldName + ') ignored: ' + e.getMessage());
        }
    }
}
