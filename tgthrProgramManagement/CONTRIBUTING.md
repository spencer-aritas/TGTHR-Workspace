# Contributing Guide

Welcome! This guide explains how to contribute to the TGTHR Program Management system.

---

## 🚀 Quick Start

1. **Clone & setup**
   ```bash
   git clone <repo>
   cd tgthrProgramManagement
   npm install
   ```

2. **Verify setup**
   ```bash
   npm run test:unit
   npm run validate-dto-sync
   ```

3. **Make changes** in `force-app/` (Apex/LWC) or `pwa-sync-starter/` (TypeScript)

4. **Test & commit**
   ```bash
   npm run lint && npm run lint:md
   git commit -m "description"  # Pre-commit hook validates everything
   ```

5. **Push & create PR**

---

## 📋 Development Workflow

### Before You Start

1. **Check current branch**
   ```bash
   git status
   git branch -v
   ```

2. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   # or: git checkout -b fix/bug-name
   ```

3. **Keep main/develop clean** - All work in feature branches

### Making Changes

#### Apex (Server-Side Logic)
**Location**: `force-app/main/default/classes/`

**Guidelines**:
- Use DTOs for all public methods
- Document with `@AuraEnabled` annotations
- Write unit tests (use existing patterns)
- Follow SObject dynamic access patterns (see `TaskService.cls`)

**Example Pattern**:
```apex
@AuraEnabled
public static DisburseResult disburseWithParams(DisburseRequest request) {
    // Validation
    if (request == null || request.programId == null) {
        return new DisburseResult(false, 'Required field missing');
    }
    
    // Business logic
    try {
        List<Disbursement__c> disbursements = new List<Disbursement__c>();
        // ...
        Database.insert(disbursements, false);
        return new DisburseResult(true, 'Success');
    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage());
        return new DisburseResult(false, 'Processing failed');
    }
}

// DTO
public class DisburseRequest {
    @AuraEnabled public Id programId;
    @AuraEnabled public Id enrollmentId;
    @AuraEnabled public String benefitType;
    // ...
}

public class DisburseResult {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String message;
    // Constructor...
}
```

#### Lightning Web Components (LWC)
**Location**: `force-app/main/default/lwc/`

**Guidelines**:
- Use TypeScript for type safety
- Import from `pwa-sync-starter/shared/contracts/` for DTO types
- Write Jest tests (see existing component tests)
- Use SLDS classes for styling

**Example Pattern**:
```typescript
import { LightningElement, api, wire } from 'lwc';
import { TaskContract } from 'c/taskContract';

export default class MyComponent extends LightningElement {
  @api recordId;
  
  @wire(getTaskData)
  taskData;
  
  handleCreate() {
    const request: TaskContract.TaskCreationRequest = {
      caseId: this.recordId,
      title: 'New task',
      // ...
    };
    
    createTask({ request })
      .then(() => console.log('Success'))
      .catch(err => console.error(err));
  }
}
```

#### TypeScript/PWA (Frontend)
**Location**: `pwa-sync-starter/`

**Guidelines**:
- Import types from `shared/contracts/`
- Use type guards (see `TaskContract.isTaskCreationRequest()`)
- Add to `shared/contracts/index.ts` exports
- Write test coverage

**Example Pattern**:
```typescript
import { TaskContract } from '../contracts/TaskContract';

const payload: TaskContract.TaskCreationRequest = {
  caseId: 'case123',
  title: 'Meeting notes',
  // ...
};

// Type guard for safety
if (TaskContract.isTaskCreationRequest(payload)) {
  await fetch('/api/tasks', {
    method: 'POST',
    body: JSON.stringify(payload)
  });
}
```

---

## ⚡ DTO Update Workflow

**IMPORTANT**: DTOs must stay in sync between Apex and TypeScript!

### When You Add a New Field

1. **Update Apex DTO**
   ```apex
   // force-app/main/default/classes/TaskService.cls
   public class TaskCreationDTO {
       @AuraEnabled public String caseId;
       @AuraEnabled public String title;
       @AuraEnabled public String newField;  // ← Add here
   }
   ```

2. **Update TypeScript Contract**
   ```typescript
   // pwa-sync-starter/shared/contracts/TaskContract.ts
   export namespace TaskContract {
       export interface TaskCreationRequest {
           caseId: string;
           title: string;
           newField: string;  // ← Add here
       }
   }
   ```

3. **Run validation**
   ```bash
   npm run validate-dto-sync
   ```
   Expected: `✅ All 3 DTOs PASS`

4. **Commit**
   ```bash
   git add .
   git commit -m "feat: add newField to TaskCreationDTO"
   ```

**Pre-commit hook will:**
- ✅ Validate Apex ↔ TypeScript sync
- ✅ Block commit if out of sync
- ✅ Lint and format code

### When You Remove/Rename a Field

1. Update both Apex + TypeScript (same process)
2. Run `npm run validate-dto-sync`
3. **Update calling code** - search for usages:
   ```bash
   grep -r "oldFieldName" force-app/
   grep -r "oldFieldName" pwa-sync-starter/
   ```
4. Test thoroughly (pre-commit helps catch issues)

---

## 🧪 Testing

### Run All Tests
```bash
npm run test:unit              # LWC Jest tests
npm run test:unit:watch       # Watch mode
npm run test:unit:coverage    # With coverage report
```

### Run Specific Test
```bash
npm run test:unit -- TaskService.test.js
```

### Add Tests for New Features
1. Create `*.test.js` in same folder as source
2. Follow existing test patterns
3. Aim for 80%+ coverage

**Example Test**:
```javascript
describe('TaskService', () => {
  it('creates task with valid DTO', () => {
    const request = {
      caseId: 'case123',
      title: 'Test task'
    };
    
    const result = createTask(request);
    expect(result.success).toBe(true);
  });
});
```

---

## ✅ Pre-Commit Checks

When you commit, the pre-commit hook automatically runs:

```bash
git commit -m "message"

# Pre-commit runs:
# 1. npm run validate-dto-sync     ← Check DTO sync
# 2. npm run lint:md               ← Check markdown
# 3. prettier --write              ← Format code
# 4. eslint                        ← Lint JavaScript/Apex
# 5. Commit proceeds if all pass ✓
```

**If validation fails:**
- Fix issues indicated in error message
- Stage fixes: `git add .`
- Re-commit: `git commit -m "message"`

---

## 📝 Commit Messages

Follow conventional commits:

```bash
# Feature
git commit -m "feat: add benefit type filter to census board"

# Fix
git commit -m "fix: correct DTO field validation logic"

# Docs
git commit -m "docs: update DTO setup guide"

# Refactor
git commit -m "refactor: consolidate benefit service methods"

# Test
git commit -m "test: add coverage for edge cases"

# Chore
git commit -m "chore: update dependencies"
```

---

## 📚 Documentation Updates

**Every code change may need docs update!**

### Where to Update Docs

| Change Type | Update |
|------------|--------|
| New DTO field | `docs/api/DTO_REFERENCE.md` + `docs/guides/QUICK_REFERENCE.md` |
| New REST endpoint | `docs/api/DTO_REFERENCE.md` |
| New Apex method | `docs/architecture/DTO_ECOSYSTEM.md` |
| Architectural change | `docs/decisions/ADR-XXXX.md` + update existing ADRs |
| Setup procedure change | `docs/setup/DTO_VALIDATION.md` |
| New feature guide | Create in `docs/guides/` |

### Documentation Standards

1. **Markdown format**: Use `.md` extension, follow markdownlint rules
2. **Line length**: Max 120 characters (configured in `.markdownlintrc`)
3. **Code examples**: Include working code snippets
4. **Links**: Use relative links (e.g., `[DTO Guide](../guides/QUICK_REFERENCE.md)`)
5. **Auto-index**: Run `npm run docs:index` to regenerate `docs/INDEX.md`

---

## 🔀 Pull Requests

### Before Submitting PR

1. **Sync with main**
   ```bash
   git fetch origin
   git rebase origin/main  # or merge
   ```

2. **Run full test suite**
   ```bash
   npm run test:unit
   npm run test:unit:coverage
   npm run validate-dto-sync
   npm run lint
   npm run lint:md
   ```

3. **Format code**
   ```bash
   npm run prettier
   ```

4. **Update docs** (if applicable)

5. **Push changes**
   ```bash
   git push origin feature/my-feature
   ```

### PR Checklist

- [ ] Tests pass locally (`npm run test:unit`)
- [ ] DTO sync validated (`npm run validate-dto-sync`)
- [ ] Code formatted (`npm run prettier`)
- [ ] Linting passes (`npm run lint && npm run lint:md`)
- [ ] Documentation updated (if needed)
- [ ] Commit messages follow conventions
- [ ] No merge conflicts
- [ ] PR description explains what & why

### PR Description Template

```markdown
## What
Brief description of changes

## Why
Why this change is needed

## How
How the change was implemented

## Testing
How to verify the changes work

## Related
Links to issues, ADRs, or related PRs
```

---

## 🐛 Reporting Bugs

If you find an issue:

1. **Search existing issues** - Don't create duplicates
2. **Reproduce locally** - Confirm it's real
3. **Create detailed report** including:
   - What you expected
   - What actually happened
   - Steps to reproduce
   - Relevant code/logs
   - Environment (Node version, OS, browser)

---

## 🎯 Code Standards

### Apex
- Use camelCase for variables/methods
- Prefix internal methods with `_`
- Use comments for complex logic
- Follow existing patterns in `TaskService.cls`

### TypeScript/JavaScript
- Use `const` by default, `let` if reassignment needed
- Type all function parameters and returns
- Use `isXxx()` pattern for type guards
- Export from `index.ts` for discoverability

### Markdown
- Use ATX-style headings (`#` not underlines)
- Max 120 chars per line
- Reference code with backticks
- Use relative links for internal docs

---

## 📦 Dependency Updates

### Adding Dependencies
```bash
npm install --save-dev package-name
# Then update this guide if significant
```

### Updating Dependencies
```bash
npm update
npm audit fix
```

Before committing:
```bash
npm test
npm run validate-dto-sync
```

---

## 🚀 Deployment

### To Scratch Org
```bash
sf org create scratch -f config/project-scratch-def.json
npm run prettier  # Format first
sf project deploy start
npm run test:unit
```

### To Sandbox/Prod
1. Create deployment manifest: `manifest/deployment-manifest.xml`
2. Run tests: `npm run test:unit`
3. Deploy: `sf project deploy start --manifest manifest/deployment-manifest.xml`
4. Monitor logs

---

## 📖 Resources

### Key Documentation
- [Architecture Overview](docs/architecture/DTO_ECOSYSTEM.md)
- [API Reference](docs/api/DTO_REFERENCE.md)
- [Setup Guide](docs/setup/DTO_VALIDATION.md)
- [Quick Reference](docs/guides/QUICK_REFERENCE.md)
- [ADR-0001](docs/decisions/ADR-0001-DTO-CONSOLIDATION-STRATEGY.md) - Design decisions

### Useful Links
- [Salesforce Docs](https://developer.salesforce.com/docs/)
- [LWC Guide](https://developer.salesforce.com/docs/component-library/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

---

## ❓ Questions?

1. **Check docs first** - 2000+ lines of guidance
2. **Search codebase** - Use Ctrl+Shift+F
3. **Review existing code** - Learn by example
4. **Ask in discussions** - Open an issue with `question` label

---

## 🎉 Thank You!

Your contributions help make this project better. Thank you for following these guidelines!

---

**Questions about this guide?** See: [Documentation Index](docs/INDEX.md)
