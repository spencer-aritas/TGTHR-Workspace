/**
 * Schedule the 6-month Psycho-Social Renewal job
 * 
 * Run this script once to schedule the daily job that:
 * 1. Checks for completed 1440 Pine Psycho-Social Intakes that are 6 months old
 * 2. Creates a new "In Progress" interview for the same Case/Client
 * 3. Sends a notification bell to the Case Manager
 * 
 * Usage: Execute this script in Anonymous Apex (Developer Console)
 */

// Schedule the job to run daily at 8 AM
String jobId = PsychoSocialRenewalScheduler.scheduleDaily();
System.debug('Scheduled job ID: ' + jobId);

// Alternatively, to run immediately for testing:
// Integer renewals = PsychoSocialRenewalScheduler.runNow();
// System.debug('Created ' + renewals + ' renewal interviews');

// To abort all scheduled jobs:
// PsychoSocialRenewalScheduler.abortAllJobs();
