#!/usr/bin/env python3
"""
ICD-10 Code CSV to Salesforce Custom Metadata Type Converter

This script parses a CSV file containing ICD-10 codes and generates
Salesforce Custom Metadata Type records (.md-meta.xml files).

Usage:
    python convert_icd10_csv.py <input_csv> [output_dir]

CSV Format Expected:
    Code with Description
    F01,Vascular dementia
    F01.5,Vascular dementia
    ...

The script automatically:
- Parses hierarchical parent-child relationships from code structure
- Determines billability (leaf nodes with most specific codes)
- Assigns categories based on ICD-10 code ranges
- Generates valid Salesforce metadata XML files
"""

import csv
import os
import re
import sys
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

# ICD-10 Category mapping based on code prefixes
ICD10_CATEGORIES = {
    'F01-F09': 'Organic Mental Disorders',
    'F10-F19': 'Substance Use Disorders',
    'F20-F29': 'Schizophrenia and Psychotic Disorders',
    'F30-F39': 'Mood Disorders',
    'F40-F48': 'Anxiety and Stress Disorders',
    'F50-F59': 'Behavioral Syndromes',
    'F60-F69': 'Personality Disorders',
    'F70-F79': 'Intellectual Disabilities',
    'F80-F89': 'Developmental Disorders',
    'F90-F98': 'Childhood Disorders',
    'F99': 'Unspecified Mental Disorder',
    'J00-J99': 'Respiratory Diseases',
    'Z00-Z99': 'Health Status Factors',
}

def get_category(code: str) -> str:
    """Determine category based on ICD-10 code prefix."""
    if not code:
        return 'Other'
    
    # Extract the letter and first two digits
    match = re.match(r'^([A-Z])(\d{2})', code.upper())
    if not match:
        return 'Other'
    
    letter = match.group(1)
    num = int(match.group(2))
    
    # Map common mental health codes
    if letter == 'F':
        if 1 <= num <= 9:
            return 'Organic Mental Disorders'
        elif 10 <= num <= 19:
            return 'Substance Use Disorders'
        elif 20 <= num <= 29:
            return 'Schizophrenia and Psychotic Disorders'
        elif 30 <= num <= 39:
            return 'Mood Disorders'
        elif 40 <= num <= 48:
            return 'Anxiety and Stress Disorders'
        elif 50 <= num <= 59:
            return 'Behavioral Syndromes'
        elif 60 <= num <= 69:
            return 'Personality Disorders'
        elif 70 <= num <= 79:
            return 'Intellectual Disabilities'
        elif 80 <= num <= 89:
            return 'Developmental Disorders'
        elif 90 <= num <= 98:
            return 'Childhood Disorders'
        else:
            return 'Mental Disorders - Other'
    elif letter == 'J':
        return 'Respiratory Diseases'
    elif letter == 'Z':
        return 'Health Status Factors'
    elif letter == 'E':
        return 'Endocrine and Metabolic'
    elif letter == 'I':
        return 'Circulatory System'
    elif letter == 'K':
        return 'Digestive System'
    elif letter == 'M':
        return 'Musculoskeletal'
    elif letter == 'N':
        return 'Genitourinary System'
    elif letter == 'R':
        return 'Symptoms and Signs'
    
    return 'Other'


def get_parent_code(code: str) -> str:
    """
    Determine parent code from ICD-10 code structure.
    
    Examples:
    - F10.121 -> F10.12
    - F03.91 -> F03.9
    - F03.9 -> F03
    - F03 -> None (top-level)
    """
    if not code:
        return None
    
    if '.' not in code:
        # Top-level code like "F03" - no parent
        return None
    
    parts = code.split('.')
    base = parts[0]
    suffix = parts[1] if len(parts) > 1 else ''
    
    if len(suffix) > 1:
        # F10.121 -> F10.12, F03.91 -> F03.9
        return f"{base}.{suffix[:-1]}"
    elif len(suffix) == 1:
        # F03.9 -> F03
        return base
    
    return None


def sanitize_developer_name(code: str) -> str:
    """
    Convert ICD-10 code to valid Salesforce DeveloperName.
    - Replace dots with underscores
    - Ensure it starts with a letter
    """
    if not code:
        return 'Unknown'
    
    # Replace dots and other invalid characters
    name = code.replace('.', '_').replace('-', '_').replace(' ', '_')
    
    # Ensure it starts with a letter (prepend 'ICD_' if needed)
    if name and not name[0].isalpha():
        name = 'ICD_' + name
    
    return name


def escape_xml(text: str) -> str:
    """Escape special characters for XML."""
    if text is None:
        return ''
    return (str(text)
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace("'", '&apos;'))


def create_metadata_xml(code_data: dict) -> str:
    """Generate Salesforce Custom Metadata XML for an ICD-10 code."""
    
    def value_element(field_name: str, value, field_type: str = 'Text') -> str:
        if value is None or value == '':
            return f'''    <values>
        <field>{field_name}</field>
        <value xsi:nil="true"/>
    </values>'''
        elif field_type == 'Checkbox':
            bool_val = 'true' if value else 'false'
            return f'''    <values>
        <field>{field_name}</field>
        <value xsi:type="xsd:boolean">{bool_val}</value>
    </values>'''
        elif field_type == 'Number':
            return f'''    <values>
        <field>{field_name}</field>
        <value xsi:type="xsd:double">{float(value)}</value>
    </values>'''
        else:
            return f'''    <values>
        <field>{field_name}</field>
        <value xsi:type="xsd:string">{escape_xml(value)}</value>
    </values>'''
    
    xml = f'''<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>{escape_xml(code_data['code'])}</label>
    <protected>false</protected>
{value_element('Code__c', code_data['code'])}
{value_element('Description__c', code_data['description'])}
{value_element('Parent_Code__c', code_data.get('parent_code'))}
{value_element('Category__c', code_data.get('category', 'Other'))}
{value_element('Is_Billable__c', code_data.get('is_billable', True), 'Checkbox')}
{value_element('Is_Active__c', True, 'Checkbox')}
{value_element('Sort_Order__c', code_data.get('sort_order', 0), 'Number')}
</CustomMetadata>'''
    
    return xml


def parse_csv(csv_path: str) -> list:
    """Parse CSV file and return list of code dictionaries."""
    codes = []
    seen_codes = set()
    
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()
    
    print(f"Total lines in file: {len(lines)}")
    if lines:
        print(f"First line: {lines[0].strip()}")
        if len(lines) > 1:
            print(f"Second line: {lines[1].strip()}")
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        # Skip header lines
        if line.lower().startswith('code') or line.lower().startswith('icd'):
            print(f"Skipping header: {line}")
            continue
        
        # Parse "F01.50 Vascular dementia" format
        # Code can be F01, F01.5, F01.50, F10.121, F78.A1 etc.
        match = re.match(r'^([A-Z]\d{2}(?:\.[A-Z0-9]{1,3})?)\s+(.+)$', line)
        if match:
            code = match.group(1)
            description = match.group(2)
            
            if code in seen_codes:
                continue
            seen_codes.add(code)
            
            codes.append({
                'code': code,
                'description': description,
                'parent_code': get_parent_code(code),
                'category': get_category(code),
            })
        else:
            # Try comma-separated format as fallback
            if ',' in line:
                parts = line.split(',', 1)
                if len(parts) >= 2:
                    code = parts[0].strip()
                    description = parts[1].strip()
                    
                    if re.match(r'^[A-Z]\d', code) and code not in seen_codes:
                        seen_codes.add(code)
                        codes.append({
                            'code': code,
                            'description': description,
                            'parent_code': get_parent_code(code),
                            'category': get_category(code),
                        })
                    continue
            
            print(f"  Could not parse: {line[:60]}...")
    
    return codes


def process_row(row: list, codes: list, seen_codes: set):
    """Process a single CSV row."""
    if not row:
        return
    
    code = None
    description = None
    
    # Try different CSV formats
    if len(row) >= 2:
        # Standard format: Code, Description
        code = row[0].strip()
        description = row[1].strip()
        
        # Some CSVs have Description first - check if first col looks like description
        if code and not re.match(r'^[A-Z]\d', code) and re.match(r'^[A-Z]\d', description):
            code, description = description, code
            
    elif len(row) == 1:
        # "Code Description" format in single column
        parts = row[0].strip().split(' ', 1)
        if len(parts) >= 2:
            code = parts[0].strip()
            description = parts[1].strip()
        else:
            return
    else:
        return
    
    # Clean up code - handle various formats like "F03." or '"F03"'
    code = code.strip('"').strip("'").strip().rstrip('.')
    description = description.strip('"').strip("'").strip()
    
    # Also try to extract code from formats like "F03 - Dementia" or "F03: Dementia"
    if not re.match(r'^[A-Z]\d', code):
        match = re.search(r'([A-Z]\d{2}(?:\.\d{1,2})?)', code)
        if match:
            code = match.group(1)
    
    # Skip if no valid code
    if not code or not re.match(r'^[A-Z]\d', code):
        print(f"  Skipping invalid code: {row}")
        return
    
    # Skip duplicates
    if code in seen_codes:
        return
    seen_codes.add(code)
    
    codes.append({
        'code': code,
        'description': description,
        'parent_code': get_parent_code(code),
        'category': get_category(code),
    })


def determine_billability(codes: list) -> None:
    """
    Determine which codes are billable (can be selected).
    Non-billable codes are those with children - user must select more specific code.
    """
    # Build set of all parent codes
    parent_codes = set()
    for code in codes:
        if code.get('parent_code'):
            parent_codes.add(code['parent_code'])
    
    # Mark codes with children as non-billable
    for code in codes:
        code['is_billable'] = code['code'] not in parent_codes


def assign_sort_order(codes: list) -> None:
    """Assign sort order based on code sequence."""
    # Sort by code
    codes.sort(key=lambda x: x['code'])
    
    for idx, code in enumerate(codes):
        code['sort_order'] = idx


def generate_metadata_files(codes: list, output_dir: str) -> None:
    """Generate metadata XML files for all codes."""
    # Create output directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    for code in codes:
        dev_name = sanitize_developer_name(code['code'])
        filename = f"ICD10_Code.{dev_name}.md-meta.xml"
        filepath = os.path.join(output_dir, filename)
        
        xml_content = create_metadata_xml(code)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
            f.write(xml_content)
    
    print(f"Generated {len(codes)} metadata files in {output_dir}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_icd10_csv.py <input_csv> [output_dir]")
        print("\nExample:")
        print("  python convert_icd10_csv.py 'ICD10 Codes.csv' force-app/main/default/customMetadata")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else 'force-app/main/default/customMetadata'
    
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found: {csv_path}")
        sys.exit(1)
    
    print(f"Parsing {csv_path}...")
    codes = parse_csv(csv_path)
    print(f"Found {len(codes)} codes")
    
    print("Determining billability...")
    determine_billability(codes)
    
    print("Assigning sort order...")
    assign_sort_order(codes)
    
    print("Generating metadata files...")
    generate_metadata_files(codes, output_dir)
    
    # Print summary
    billable_count = sum(1 for c in codes if c['is_billable'])
    print(f"\nSummary:")
    print(f"  Total codes: {len(codes)}")
    print(f"  Billable (leaf) codes: {billable_count}")
    print(f"  Parent codes: {len(codes) - billable_count}")
    
    # Print category breakdown
    categories = {}
    for code in codes:
        cat = code.get('category', 'Other')
        categories[cat] = categories.get(cat, 0) + 1
    
    print(f"\nCategories:")
    for cat, count in sorted(categories.items()):
        print(f"  {cat}: {count}")


if __name__ == '__main__':
    main()
