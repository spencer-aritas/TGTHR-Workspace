public with sharing class LaunchTheSourceIntakeController {
    public String targetUrl { get; private set; }

    public LaunchTheSourceIntakeController() {
        String baseUrl = ApexPages.currentPage().getParameters().get('targetUrl');
        if (String.isBlank(baseUrl)) {
            baseUrl = 'http://localhost:5174';
        }

        String sep = baseUrl.contains('?') ? '&' : '?';
        targetUrl = baseUrl + sep + 'staffUserId=' + EncodingUtil.urlEncode(UserInfo.getUserId(), 'UTF-8');

        logLaunch(targetUrl);
    }

    private static void logLaunch(String launchedUrl) {
        try {
            Task t = new Task(
                Subject = 'Launch The Source Intake',
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                Description = 'Launched URL: ' + launchedUrl
            );
            insert t;
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'LaunchTheSourceIntake log failure: ' + ex.getMessage());
        }
    }
}
