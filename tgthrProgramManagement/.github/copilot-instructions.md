# Copilot instructions for tgthrProgramManagement

This repository is a Salesforce packaging-style source tree (Apex classes, LWC, Aura) focused on program & interaction management.
The interactionSummaryBoard LWC is a key component for viewing and managing participant interactions., eventually the goal is to have it mirror a propr EHR system's notes and interaction tracking capabilities.
The ProgramCensusBoard LWC is another important component for viewing program enrollment data, and managing the Disbursement of Benefits. Everyything is centered around these two components. and our two active Program 1440 Pine and Nest 46.

ProgramCensusBoard is used to get quick info of Participants enrolled in a Program like, their Unit Number (editable), Resident Name (should link to the ProgramEnrollemnt record), Pronouns (editable), Pets (editable), Case Manager, Out of Unit (editable), Referal Source (editable). All of these fields should write back the updates to the object/record theyy came from.
From this Board we also have Benefit Type and Benefit dropdowns with Service Date (defaulted to today) and Quantity, these should reference actual Benefits and their Types in relation to the Program context. Once these are selected we can click Disburse Benefits and it will first check the right BenefitAssignment records for are created for the Program and ProgramEnrollment. If the right Assignments arent' found the User is prompted with the correct flow to create them automatically, then goes on to create the Disbursements.
The Weekly Enagagement Calendar should reflect the Benefits Disbursed in this manner in Program context. If the Benefit Type = Clinical or Case Management the User should also be prompted to add the specific time spent and notes about the interaction, these should be tied to the most active recent Case, and thus be reflected in the Meeting Notes on the Interaction Summary Board.

Keep guidance short and actionable so AI coding agents can make safe, predictable changes.

Do this first

- Only modify code under `force-app/main/default/` and supporting `scripts/` unless the task explicitly targets other areas.
- Run unit/static checks locally before changing behavior: `npm run lint` and `npm run test:unit`.

Big-picture architecture (quick):

- Apex server-side logic lives in `force-app/main/default/classes/` (e.g. `BenefitDisbursementService.cls`). These classes use dynamic SOQL (Database.query) and generic SObject access patterns.
- Front-end components are Lightning Web Components under `force-app/main/default/lwc/` and Aura under `force-app/main/default/aura/` when present. LWC unit tests use `sfdx-lwc-jest` (see `package.json`).
- Lightweight scripts for local experimentation and debugging live in `scripts/apex/` and `scripts/soql/` (e.g. `scripts/apex/createBenefitAssignmentSimple.apex`). These are developer convenience scripts meant to be run via the Salesforce CLI.

Important patterns and conventions

- Use dynamic SOQL + SObject.get/put when the org uses Non-Profit Cloud objects (e.g. `Benefit`, `BenefitAssignment`, `ProgramEnrollment`) to avoid compile-time schema dependencies. See `BenefitDisbursementService.cls` for examples.
- DTOs used for LWC <-> Apex data exchange are simple inner classes annotated with `@AuraEnabled` (e.g. `DisburseRequest`, `DisburseResult`, `BenefitAssignmentCheckResult`). Prefer creating server-side request objects when front-end serialization has caused issues (see `createDisbursementsWithParams`).
- Partial DML insert patterns use `Database.insert(list, false)` and iterate `Database.SaveResult[]` to report per-record failures. Follow existing error-handling: log debug details and return a user-facing message rather than throwing on partial failures.
- When creating related records, code often needs ProgramId resolution fallbacks: check `programId`, then `programName`, then derive from related Benefit record. Mirror that resolution order in new code.

Developer workflows (commands)

- Run linters and formatting: `npm run lint` and `npm run prettier` (pre-commit hooks are configured via husky).
- Run LWC unit tests: `npm run test:unit` or `npm run test:unit:watch` for iterative development. Tests use `sfdx-lwc-jest`.
- Deploy to a scratch org or org with Salesforce CLI: `sf project deploy start -o benefits` (project uses SFDX source format; see `sfdx-project.json`). Use `sfdx force:source:deploy` or new `sf project deploy start` depending on CLI version.
- Use `scripts/apex/*.apex` snippet files as one-off apex execute scripts. They are not automatically run; open and paste into the CLI (`sfdx force:apex:execute -f <file>`) against a dev org for debugging.

Testing & debugging notes

- Apex exceptions are surfaced to the logs. Use debug statements already present in service classes (System.debug) and check the target org's debug logs when reproducing issues.
- For partial DML failure investigations, inspect `Database.SaveResult[].getErrors()` and prefer not to parse error messages (use status codes where possible).

Integration points & external dependencies

- This repo assumes Salesforce platform objects (Program, Benefit, BenefitAssignment, ProgramEnrollment). Tests and deployments require an org with those NPC objects or a compatible scratch org definition (NPC) (`config/project-scratch-def.json`).
- Front-end tests rely on LWC Jest tooling (`@salesforce/sfdx-lwc-jest`) configured in `package.json`.

When changing behavior

- Add/adjust small Apex unit tests where logic is critical. If adding an LWC, add a matching Jest test under the component folder and run `npm run test:unit`.
- Preserve existing public method signatures annotated with `@AuraEnabled` unless the UI is being updated at the same time; otherwise prefer adding new methods (e.g. `createDisbursementsWithParams`) to avoid breaking callers.

Files worth checking when making changes

- `force-app/main/default/classes/` — Apex services and tests (e.g. `BenefitDisbursementService.cls`, `BenefitService.cls`).
- `force-app/main/default/lwc/` — LWC components and their Jest tests.
- `scripts/apex/` — developer apex scripts for manual run/debug.
- `package.json`, `sfdx-project.json`, and `config/project-scratch-def.json` — toolchain and org configuration.

If unsure

- Ask the human reviewer to confirm target org shape (custom objects/fields) and whether the change needs a backend migration or data seed script.

Feedback request

- I added this file based on discoverable repository patterns. Please tell me which areas need more detail (test commands, CI steps, org setup) and I'll iterate.
