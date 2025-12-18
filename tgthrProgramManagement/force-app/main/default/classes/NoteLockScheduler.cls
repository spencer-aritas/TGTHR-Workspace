/**
 * Scheduled job to lock InteractionSummary records 72 hours after completion.
 * 
 * Mirrors the InterviewLockScheduler behavior for InteractionSummary (notes).
 * Implements EHR industry standard where documentation must be finalized
 * within a certain timeframe, after which it becomes locked and requires
 * supervisor override to modify.
 * 
 * Schedule: Runs nightly at 2:15 AM (15 minutes after Interview lock job)
 * 
 * Example scheduling:
 * System.schedule('Lock Notes After 72 Hours', '0 15 2 * * ?', new NoteLockScheduler());
 * 
 * @author TGTHR Development Team
 * @date 2025-12-18
 */
public class NoteLockScheduler implements Schedulable {
    
    /**
     * Execute scheduled job
     */
    public void execute(SchedulableContext ctx) {
        // Query interaction summaries that are completed but not locked and past 72 hours
        DateTime lockThreshold = DateTime.now().addHours(-72);
        
        String query = 
            'SELECT Id, Completed_On__c, CreatedDate, Name ' +
            'FROM InteractionSummary ' +
            'WHERE Is_Locked__c = false ' +
            'AND (Completed_On__c != null AND Completed_On__c <= :lockThreshold) ' +
            'LIMIT 200'; // Process in batches for governor limits
        
        List<SObject> notesToLock = Database.query(query);
        
        System.debug('NoteLockScheduler: Found ' + notesToLock.size() + ' notes to lock');
        
        if (notesToLock.isEmpty()) {
            // Also check notes without Completed_On__c but created > 72 hours ago
            // (fallback for notes created before Completed_On__c was added)
            query = 
                'SELECT Id, CreatedDate, Name ' +
                'FROM InteractionSummary ' +
                'WHERE Is_Locked__c = false ' +
                'AND Completed_On__c = null ' +
                'AND CreatedDate <= :lockThreshold ' +
                'LIMIT 200';
            
            notesToLock = Database.query(query);
            System.debug('NoteLockScheduler: Found ' + notesToLock.size() + ' legacy notes (no Completed_On__c) to lock');
        }
        
        if (notesToLock.isEmpty()) {
            return;
        }
        
        // Lock each note
        Integer lockedCount = 0;
        Integer failedCount = 0;
        
        for (SObject note : notesToLock) {
            try {
                lockNote((Id)note.get('Id'));
                lockedCount++;
            } catch (Exception e) {
                System.debug('Failed to lock note ' + note.get('Id') + ': ' + e.getMessage());
                failedCount++;
            }
        }
        
        System.debug('NoteLockScheduler: Locked ' + lockedCount + ' notes, ' + failedCount + ' failures');
        
        // If there are more to process, schedule another run
        if (notesToLock.size() >= 200) {
            System.debug('More notes to process, scheduling immediate re-run');
            // Schedule to run again in 5 minutes
            Integer nextMinute = Math.mod(DateTime.now().addMinutes(5).minute(), 60);
            System.schedule('Lock Notes (Batch Continuation)', '0 ' + nextMinute + ' * * * ?', new NoteLockScheduler());
        }
    }
    
    /**
     * Lock an individual InteractionSummary record.
     * 
     * @param noteId The InteractionSummary Id to lock
     */
    private void lockNote(Id noteId) {
        SObject note = Database.query(
            'SELECT Id, Is_Locked__c, Locked_On__c, Locked_By__c FROM InteractionSummary WHERE Id = :noteId LIMIT 1'
        )[0];
        
        // Skip if already locked
        if ((Boolean) note.get('Is_Locked__c') == true) {
            return;
        }
        
        note.put('Is_Locked__c', true);
        note.put('Locked_On__c', System.now());
        // System lock - no specific user
        
        update note;
        
        // Log the lock action
        AuditLogService.logAction('LOCK', String.valueOf(noteId), 'Auto-locked after 72 hours', 'InteractionSummary');
    }
}
