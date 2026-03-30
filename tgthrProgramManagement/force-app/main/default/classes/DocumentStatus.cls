/**
 * DocumentStatus — canonical status constants for all document types.
 *
 * Use these constants everywhere instead of inline string literals.
 * This eliminates the class of bug where a status check and a status write
 * use different strings for the same semantic state.
 *
 * InteractionSummary.Status  — standard Salesforce field; values must exist
 *                               in the org's InteractionSummary.Status picklist.
 * Interview__c.Status__c     — custom picklist defined in
 *                               objects/Interview__c/fields/Status__c.field-meta.xml.
 */
public class DocumentStatus {

    // ── InteractionSummary (Clinical / Case / Peer Notes) ─────────────────
    /** Signed by author; waiting for manager co-sign. */
    public static final String NOTE_PENDING   = 'Published';
    /** Recalled within the 72-hour window; returned to author for revision. */
    public static final String NOTE_RECALLED  = 'Recalled';
    /** All required signatures obtained; document is final. */
    public static final String NOTE_COMPLETED = 'Completed';

    // ── Interview__c ──────────────────────────────────────────────────────
    /** Being authored or edited; no signatures yet collected. */
    public static final String INTERVIEW_IN_PROGRESS = 'In Progress';
    /** All co-signers (CM, PS, Clinician) have signed; awaiting manager co-sign. */
    public static final String INTERVIEW_SUBMITTED   = 'Submitted';
    /** Recalled within the 72-hour window; returned to author for revision. */
    public static final String INTERVIEW_RECALLED    = 'Recalled';
    /** All signatures obtained (including manager where required); document is final. */
    public static final String INTERVIEW_SIGNED      = 'Signed';
    /** Voided / invalidated. */
    public static final String INTERVIEW_VOIDED      = 'Voided';
    /** Amendment to a previously active Treatment Plan. */
    public static final String INTERVIEW_AMENDED     = 'Amended';
}
