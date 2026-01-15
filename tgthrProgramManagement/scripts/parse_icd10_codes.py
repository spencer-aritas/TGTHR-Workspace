#!/usr/bin/env python3
"""
Parse ICD10Codes.csv and generate Salesforce Custom Metadata Type records.
Handles both quoted and unquoted entries.
"""

import os
import re
import csv

INPUT_FILE = r"D:\Projects\TGTHR-Workspace\ICD-Dev\ICD10Codes.csv"
OUTPUT_DIR = r"D:\Projects\TGTHR-Workspace\tgthrProgramManagement\force-app\main\default\customMetadata"

# Template for MDT record
MDT_TEMPLATE = '''<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>{label}</label>
    <protected>false</protected>
    <values>
        <field>Category__c</field>
        <value xsi:type="xsd:string">{category}</value>
    </values>
    <values>
        <field>Code__c</field>
        <value xsi:type="xsd:string">{code}</value>
    </values>
    <values>
        <field>Description__c</field>
        <value xsi:type="xsd:string">{description}</value>
    </values>
    <values>
        <field>Is_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Is_Billable__c</field>
        <value xsi:type="xsd:boolean">{is_billable}</value>
    </values>
    <values>
        <field>Parent_Code__c</field>
        <value xsi:type="xsd:string">{parent_code}</value>
    </values>
    <values>
        <field>Sort_Order__c</field>
        <value xsi:type="xsd:double">{sort_order}</value>
    </values>
</CustomMetadata>
'''

def get_parent_code(code):
    """Determine parent code based on code structure."""
    # F33.42 -> F33.4, F33.4 -> F33, F33 -> None
    if '.' in code:
        parts = code.split('.')
        decimal_part = parts[1]
        if len(decimal_part) > 1:
            # F33.42 -> F33.4
            return f"{parts[0]}.{decimal_part[:-1]}"
        else:
            # F33.4 -> F33
            return parts[0]
    return None  # Top-level code

def get_category(code):
    """Determine category based on ICD-10 code range."""
    prefix = code.split('.')[0] if '.' in code else code
    num = int(re.sub(r'[^0-9]', '', prefix)) if re.search(r'\d', prefix) else 0
    
    # F codes are mental/behavioral
    if prefix.startswith('F'):
        if num <= 9:
            return "Organic Mental Disorders"
        elif num <= 19:
            return "Substance Use Disorders"
        elif num <= 29:
            return "Schizophrenia & Psychotic Disorders"
        elif num <= 39:
            return "Mood Disorders"
        elif num <= 48:
            return "Anxiety & Stress Disorders"
        elif num <= 59:
            return "Behavioral Syndromes"
        elif num <= 69:
            return "Personality Disorders"
        elif num <= 79:
            return "Intellectual Disabilities"
        elif num <= 89:
            return "Developmental Disorders"
        else:
            return "Childhood Disorders"
    return "Other"

def is_billable(code, all_codes):
    """
    A code is billable if it has no children (most specific level).
    Check if any other code has this as a parent.
    """
    for other_code in all_codes:
        parent = get_parent_code(other_code)
        if parent == code:
            return False
    return True

def sanitize_developer_name(code):
    """Convert code to valid Salesforce DeveloperName (alphanumeric + underscore)."""
    # F33.42 -> F33_42
    return code.replace('.', '_').replace('-', '_')

def escape_xml(text):
    """Escape special XML characters."""
    if not text:
        return ""
    return (text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace("'", '&apos;'))

def parse_csv():
    """Parse the CSV file and return list of (code, description) tuples."""
    codes = []
    
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Skip header
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        
        # Handle quoted entries: "F33 Major depressive disorder, recurrent"
        if line.startswith('"'):
            # Remove surrounding quotes
            line = line.strip('"')
        
        # Split on first space to get code and description
        parts = line.split(' ', 1)
        if len(parts) >= 2:
            code = parts[0].strip()
            description = parts[1].strip()
            
            # Validate code format: should start with F and be a proper ICD-10 code
            # Skip malformed entries like "F14.982," or lines with multiple codes
            if not re.match(r'^F\d+(\.\d+)?$', code):
                print(f"Skipping malformed code: {code}")
                continue
            
            codes.append((code, description))
        elif len(parts) == 1:
            code = parts[0].strip()
            if re.match(r'^F\d+(\.\d+)?$', code):
                codes.append((code, code))
    
    return codes

def main():
    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Parse CSV
    codes = parse_csv()
    print(f"Parsed {len(codes)} codes from CSV")
    
    # Get all code values for billable check
    all_code_values = [c[0] for c in codes]
    
    # Generate MDT records
    generated = 0
    skipped = 0
    
    for i, (code, description) in enumerate(codes):
        dev_name = sanitize_developer_name(code)
        filename = f"ICD10_Code.{dev_name}.md-meta.xml"
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        # Skip if already exists (preserve manual edits)
        # Actually, let's regenerate all to ensure consistency
        # if os.path.exists(filepath):
        #     skipped += 1
        #     continue
        
        parent_code = get_parent_code(code)
        category = get_category(code)
        billable = is_billable(code, all_code_values)
        
        # MasterLabel max is 40 chars - truncate cleanly
        label = description[:37] + '...' if len(description) > 40 else description
        
        content = MDT_TEMPLATE.format(
            label=escape_xml(label),
            code=escape_xml(code),
            description=escape_xml(description),
            category=escape_xml(category),
            parent_code=escape_xml(parent_code) if parent_code else '',
            is_billable='true' if billable else 'false',
            sort_order=i + 1
        )
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        generated += 1
    
    print(f"Generated {generated} MDT records")
    print(f"Skipped {skipped} existing records")
    print(f"Output directory: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
