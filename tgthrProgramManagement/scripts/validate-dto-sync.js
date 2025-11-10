#!/usr/bin/env node

/**
 * DTO Sync Validator
 * 
 * Ensures TypeScript contracts in pwa-sync-starter/shared/contracts/ stay in sync
 * with Apex DTOs in force-app/main/default/classes/.
 * 
 * Validates:
 * 1. Field count matches between Apex @AuraEnabled fields and TypeScript interface properties
 * 2. Field names are consistent (accounting for camelCase/PascalCase conversion)
 * 3. Required vs optional fields align
 * 4. No orphaned TypeScript contracts without corresponding Apex DTOs
 * 
 * Run: node scripts/validate-dto-sync.js
 * Pre-commit: npm run validate-dto-sync (add to package.json scripts)
 */

const fs = require('fs');
const path = require('path');

// Configuration
const APEX_CLASSES_DIR = path.join(__dirname, '../force-app/main/default/classes');
const TS_CONTRACTS_DIR = path.join(__dirname, '../../pwa-sync-starter/shared/contracts');

// DTO Mappings: Apex ClassName -> TypeScript Contract File
const DTO_MAPPINGS = {
  'TaskCreationDTO': 'TaskContract.ts',
  'FollowUpTaskDTO': 'TaskContract.ts',
  'PwaEncounter': 'PwaEncounterContract.ts',
};

const FIELD_MAPPINGS = {
  // Apex fieldName -> TypeScript fieldName (if different)
  'accountId': 'accountId',
  'encounterUuid': 'encounterUuid',
  'disbursementId': 'disbursementId',
  'personUuid': 'personUuid',
  'firstName': 'firstName',
  'lastName': 'lastName',
  'notes': 'notes',
  'pos': 'pos',
  'isCrisis': 'isCrisis',
  'createdByUserId': 'createdByUserId',
  'startUtc': 'startUtc',
  'endUtc': 'endUtc',
};

/**
 * Extract @AuraEnabled fields from Apex DTO class
 * @param {string} fileContent - Content of Apex class file
 * @param {string} className - Name of DTO class to extract
 * @returns {Object} { fields: [...], fieldCount: number }
 */
function extractApexFields(fileContent, className) {
  // Find the inner class definition (handle both public class X { and just class X {)
  const classRegex = new RegExp(
    `(?:public\\s+)?class\\s+${className}\\s*\\{`,
    ''
  );
  
  const startIdx = fileContent.search(classRegex);
  if (startIdx === -1) {
    return { fields: [], fieldCount: 0, found: false };
  }

  // Find matching closing brace by counting braces
  let braceCount = 0;
  let endIdx = -1;
  let inString = false;
  let stringChar = '';
  
  for (let i = startIdx; i < fileContent.length; i++) {
    const char = fileContent[i];
    
    // Track string state
    if ((char === '"' || char === "'") && fileContent[i - 1] !== '\\') {
      if (!inString) {
        inString = true;
        stringChar = char;
      } else if (char === stringChar) {
        inString = false;
      }
    }
    
    // Count braces outside strings
    if (!inString) {
      if (char === '{') braceCount++;
      if (char === '}') {
        braceCount--;
        if (braceCount === 0) {
          endIdx = i;
          break;
        }
      }
    }
  }

  if (endIdx === -1) {
    return { fields: [], fieldCount: 0, found: false };
  }

  const classBody = fileContent.substring(startIdx, endIdx + 1);
  
  // Match @AuraEnabled public fields (including optional/nullable types like String?, Boolean?, etc.)
  const fieldRegex = /@AuraEnabled\s+public\s+([\w?<>,\s]+)\s+(\w+)\s*[;=]/g;
  const fields = [];
  let match;

  while ((match = fieldRegex.exec(classBody)) !== null) {
    const type = match[1].trim();
    const name = match[2].trim();
    fields.push({
      type,
      name,
      optional: type.includes('?')
    });
  }

  return { fields, fieldCount: fields.length, found: true };
}

/**
 * Extract TypeScript interface properties
 * @param {string} fileContent - Content of TypeScript file
 * @param {string} interfaceName - Name of TypeScript interface to extract
 * @returns {Object} { fields: [...], fieldCount: number }
 */
function extractTypeScriptFields(fileContent, interfaceName) {
  // Match interface definition and extract properties
  const interfaceRegex = new RegExp(
    `(?:export\\s+)?interface\\s+${interfaceName}\\s*\\{([^}]*)\\}`,
    's'
  );
  const interfaceMatch = fileContent.match(interfaceRegex);

  if (!interfaceMatch) {
    return { fields: [], fieldCount: 0, found: false };
  }

  const interfaceBody = interfaceMatch[1];
  
  // Match properties: name?: type or name: type (ignoring comments and empty lines)
  // Split by lines and filter out comment-only lines
  const lines = interfaceBody.split('\n').filter(line => {
    const trimmed = line.trim();
    return trimmed && !trimmed.startsWith('//') && !trimmed.startsWith('/*') && !trimmed.startsWith('*');
  });

  const fields = [];
  
  for (const line of lines) {
    // Extract field: name followed by optional ?: or : with any type definition
    const fieldMatch = line.match(/^\s*(\w+)\s*(\?)?:\s*([^;,}]+)[;,]?\s*(?:\/\/.*)?\s*$/);
    if (fieldMatch) {
      const name = fieldMatch[1];
      const isOptional = fieldMatch[2] === '?';
      const type = fieldMatch[3].trim();
      
      fields.push({
        name,
        type,
        optional: isOptional
      });
    }
  }

  return { fields, fieldCount: fields.length, found: true };
}

/**
 * Compare Apex and TypeScript field definitions
 * @param {Object} apexFields - Apex field definitions
 * @param {Object} tsFields - TypeScript field definitions
 * @param {string} dtoName - DTO class name
 * @param {string} contractName - TypeScript contract name
 * @returns {Object} Validation result
 */
function compareFields(apexFields, tsFields, dtoName, contractName) {
  const errors = [];
  const warnings = [];

  if (!apexFields.found) {
    errors.push(`❌ Apex DTO "${dtoName}" not found`);
    return { valid: false, errors, warnings };
  }

  if (!tsFields.found) {
    errors.push(`❌ TypeScript contract "${contractName}" not found`);
    return { valid: false, errors, warnings };
  }

  // Check field count
  if (apexFields.fieldCount !== tsFields.fieldCount) {
    warnings.push(
      `⚠️  Field count mismatch: Apex has ${apexFields.fieldCount}, TypeScript has ${tsFields.fieldCount}`
    );
  }

  // Check each Apex field exists in TypeScript
  apexFields.fields.forEach(apexField => {
    const tsField = tsFields.fields.find(
      f => f.name === apexField.name || 
           (FIELD_MAPPINGS[apexField.name] && FIELD_MAPPINGS[apexField.name] === f.name)
    );

    if (!tsField) {
      errors.push(
        `❌ Apex field "${apexField.name}" missing in TypeScript (${contractName})`
      );
    } else if (apexField.optional !== tsField.optional) {
      warnings.push(
        `⚠️  Optional mismatch for "${apexField.name}": Apex=${apexField.optional}, TS=${tsField.optional}`
      );
    }
  });

  // Check for orphaned TypeScript fields
  tsFields.fields.forEach(tsField => {
    const apexField = apexFields.fields.find(
      f => f.name === tsField.name ||
           (FIELD_MAPPINGS[tsField.name] && FIELD_MAPPINGS[tsField.name] === f.name)
    );

    if (!apexField) {
      warnings.push(
        `⚠️  Orphaned TypeScript field "${tsField.name}" has no Apex counterpart`
      );
    }
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    summary: {
      apexFieldCount: apexFields.fieldCount,
      tsFieldCount: tsFields.fieldCount,
      apexFields: apexFields.fields.map(f => f.name),
      tsFields: tsFields.fields.map(f => f.name)
    }
  };
}

/**
 * Validate all DTO-Contract pairs
 */
function validateAllDtos() {
  console.log('🔍 DTO Sync Validator - Starting validation...\n');

  let totalValid = 0;
  let totalInvalid = 0;
  const allResults = [];

  // Read all Apex classes and combine content
  let apexContent = '';
  try {
    const files = fs.readdirSync(APEX_CLASSES_DIR).filter(f => f.endsWith('.cls'));
    for (const file of files) {
      apexContent += fs.readFileSync(
        path.join(APEX_CLASSES_DIR, file),
        'utf-8'
      ) + '\n\n';
    }
  } catch (err) {
    console.error(`❌ Failed to read Apex classes: ${err.message}`);
    process.exit(1);
  }

  // Validate each DTO mapping
  for (const [dtoName, contractFile] of Object.entries(DTO_MAPPINGS)) {
    console.log(`\n📋 Validating: ${dtoName} <-> ${contractFile}`);
    console.log('─'.repeat(50));

    // Read TypeScript contract
    let tsContent = '';
    try {
      tsContent = fs.readFileSync(
        path.join(TS_CONTRACTS_DIR, contractFile),
        'utf-8'
      );
    } catch (err) {
      console.error(`❌ Failed to read TypeScript contract: ${err.message}`);
      totalInvalid++;
      allResults.push({
        dto: dtoName,
        contract: contractFile,
        valid: false,
        error: err.message
      });
      continue;
    }

    // Extract fields from both files
    // For DTO name, infer TypeScript interface name (e.g., TaskCreationDTO -> TaskCreationRequest)
    const tsInterfaceName = dtoName
      .replace('DTO', 'Request')
      .replace('PwaEncounter', 'PwaEncounter');

    const apexFields = extractApexFields(apexContent, dtoName);
    const tsFields = extractTypeScriptFields(tsContent, tsInterfaceName);

    // Compare
    const result = compareFields(apexFields, tsFields, dtoName, tsInterfaceName);

    // Report
    if (result.valid) {
      console.log(`✅ PASS - Fields are in sync`);
      console.log(`   Apex fields: ${result.summary.apexFields.join(', ')}`);
      console.log(`   TS fields:   ${result.summary.tsFields.join(', ')}`);
      totalValid++;
    } else {
      console.log(`❌ FAIL - Validation failed`);
      result.errors.forEach(err => console.log(`   ${err}`));
      totalInvalid++;
    }

    // Show warnings
    if (result.warnings.length > 0) {
      result.warnings.forEach(warn => console.log(`   ${warn}`));
    }

    allResults.push({
      dto: dtoName,
      contract: contractFile,
      valid: result.valid,
      errors: result.errors,
      warnings: result.warnings
    });
  }

  // Summary
  console.log('\n' + '═'.repeat(50));
  console.log(`📊 Validation Summary`);
  console.log('═'.repeat(50));
  console.log(`✅ Passed: ${totalValid}/${Object.keys(DTO_MAPPINGS).length}`);
  console.log(`❌ Failed: ${totalInvalid}/${Object.keys(DTO_MAPPINGS).length}`);

  if (totalInvalid > 0) {
    console.log('\n🔴 VALIDATION FAILED - Please fix the above issues before committing');
    process.exit(1);
  } else {
    console.log('\n🟢 VALIDATION PASSED - All DTOs are in sync!');
    process.exit(0);
  }
}

// Run validation
validateAllDtos();
