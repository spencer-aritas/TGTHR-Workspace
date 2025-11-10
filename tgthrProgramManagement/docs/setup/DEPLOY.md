# Deploying this project

Quick steps to deploy the local metadata to a Salesforce org using the Salesforce CLI (sf):

1. Authenticate to the target org and note the username/alias. Example:

   sf login web --set-default

2. Deploy the project (uses alias `benefits` in examples):

   sf project deploy start -o benefits

3. To run local Apex tests during deployment:

   sf project deploy start -o benefits --test-level RunLocalTests

4. If you need to deploy a subset of files, create a `manifest/package.xml` or pass `--source-dir` to the command.

If you don't have the Salesforce CLI installed, follow: https://developer.salesforce.com/tools/sfdxcli
