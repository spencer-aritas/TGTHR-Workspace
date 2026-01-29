import os

file_path = r'd:\Projects\TGTHR-Workspace\tgthrProgramManagement\force-app\main\default\permissionsets\Python_API_Access.permissionset-meta.xml'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define the block to look for - using loose matching logic
start_marker = '<object>Code__c</object>'
# We need to find the <objectPermissions> block that CONTAINS this object tag.
# Since XML is structured, we can search backwards from the object tag?
# Or we can just look for the specific string block if we get the whitespace right.

# Let's try to identify the block by splitting
lines = content.splitlines()
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    # Check if this line and subsequent lines match the pattern for Code__c permissions
    # We are looking for the block ending in <object>Code__c</object>
    # The structure is:
    # <objectPermissions>
    #    <allowCreate>false</allowCreate>
    #    <allowDelete>false</allowDelete>
    #    <allowEdit>false</allowEdit>
    #    <allowRead>true</allowRead>
    #    <modifyAllRecords>false</modifyAllRecords>
    #    <object>Code__c</object>
    
    # We want to change it to true/true/true/true/true
    
    if (i + 6 < len(lines) and 
        '<object>Code__c</object>' in lines[i+6] and
        '<objectPermissions>' in lines[i]):
        
        # We found the start of the block for Code__c? 
        # Wait, the fields between might vary in order? 
        # Standard SFDX source format is usually alphabetical?
        
        # Let's verify the lines inside
        is_target_block = True
        # We can just blindly rewrite the block if the object tag matches
        # But we need to be sure we are inside the objectPermissions for Code__c
        
        # Let's search for the index of <object>Code__c</object>
        pass

# Simpler approach: String replacement with normalization
target_block = """    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Code__c</object>
        <viewAllFields>true</viewAllFields>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>"""

replacement_block = """    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>Code__c</object>
        <viewAllFields>true</viewAllFields>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>"""

if target_block in content:
    print("Found exact block match. Replacing...")
    new_content = content.replace(target_block, replacement_block)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Success.")
else:
    print("Exact block not found. Dumping surrounding lines of Code__c...")
    # debug
    for idx, line in enumerate(lines):
        if '<object>Code__c</object>' in line:
            print(f"Found at line {idx+1}")
            print('\n'.join(lines[idx-6:idx+3]))
