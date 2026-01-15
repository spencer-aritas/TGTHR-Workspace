/**
 * PendingDocNotificationScheduler - Scheduled job to send daily pending documentation reminders
 * 
 * Schedule from Developer Console or Apex:
 * 
 * // Run daily at 8 AM
 * String cronExp = '0 0 8 * * ?';
 * System.schedule('Daily Pending Doc Reminder', cronExp, new PendingDocNotificationScheduler());
 * 
 * @author TGTHR Development Team
 * @date 2025-12-22
 */
public class PendingDocNotificationScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        // Send notifications to all users with pending items
        PendingDocNotificationService.sendPendingDocNotificationsToAllUsers();
    }
}
