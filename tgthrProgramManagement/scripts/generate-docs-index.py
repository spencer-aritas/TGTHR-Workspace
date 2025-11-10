#!/usr/bin/env python3
"""
Auto-generate documentation index from /docs/ folder structure.
Scans all markdown files, extracts headings, and creates docs/INDEX.md
Run via: npm run docs:index
"""

import os
import re
from pathlib import Path
from collections import defaultdict

DOCS_ROOT = Path("docs")
IGNORE_DIRS = {"release-notes"}  # Don't index release notes by default
IGNORE_FILES = {"README.md", "INDEX.md"}  # Don't index self

def extract_headings(filepath):
    """Extract all headings from a markdown file."""
    headings = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                match = re.match(r'^(#{1,6})\s+(.+)$', line)
                if match:
                    level = len(match.group(1))
                    title = match.group(2).strip()
                    headings.append((level, title))
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return headings

def get_relative_path(filepath):
    """Get path relative to docs folder."""
    try:
        return filepath.relative_to(DOCS_ROOT)
    except ValueError:
        return filepath

def generate_index():
    """Generate docs/INDEX.md from folder structure."""
    
    index_content = []
    index_content.append("# Documentation Index")
    index_content.append("")
    index_content.append("**Auto-generated**. Last updated: $(date)")
    index_content.append("")
    index_content.append("---")
    index_content.append("")
    
    # Group files by directory
    files_by_dir = defaultdict(list)
    
    for root, dirs, files in os.walk(DOCS_ROOT):
        # Skip ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        
        for file in sorted(files):
            if file.endswith('.md') and file not in IGNORE_FILES:
                filepath = Path(root) / file
                rel_path = filepath.relative_to(DOCS_ROOT)
                folder = str(rel_path.parent)
                
                files_by_dir[folder].append((filepath, file))
    
    # Generate index by folder
    for folder in sorted(files_by_dir.keys()):
        # Format folder name
        folder_display = folder.replace(".", "").replace("\\", "/")
        if folder == ".":
            folder_display = "Root"
        
        folder_title = folder_display.replace("-", " ").replace("/", " > ").title()
        
        index_content.append(f"## {folder_title}")
        index_content.append("")
        
        for filepath, filename in files_by_dir[folder]:
            # Get relative link path
            link_path = filepath.relative_to(DOCS_ROOT).as_posix()
            
            # Extract first heading as description
            headings = extract_headings(filepath)
            description = ""
            if headings:
                # Skip title (usually first heading), use next meaningful one
                for level, title in headings[1:]:
                    if level == 2:  # Use first ## heading
                        description = title
                        break
            
            if not description:
                # Use filename as fallback
                description = filename.replace(".md", "").replace("-", " ").replace("_", " ")
            
            index_content.append(f"- **[{description}]({link_path})**")
            index_content.append("")
        
        index_content.append("")
    
    # Add navigation footer
    index_content.append("---")
    index_content.append("")
    index_content.append("## Quick Links")
    index_content.append("")
    index_content.append("- 📚 [Architecture](architecture/DTO_ECOSYSTEM.md)")
    index_content.append("- 🔌 [API Reference](api/DTO_REFERENCE.md)")
    index_content.append("- ⚙️ [Setup Guide](setup/DTO_VALIDATION.md)")
    index_content.append("- 📋 [Design Decisions](decisions/ADR-0001-DTO-CONSOLIDATION-STRATEGY.md)")
    index_content.append("- 👨‍💻 [Quick Reference](guides/QUICK_REFERENCE.md)")
    index_content.append("")
    
    # Write INDEX.md
    index_path = DOCS_ROOT / "INDEX.md"
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(index_content))
    
    print(f"✅ Generated {index_path}")
    print(f"📊 Indexed {sum(len(v) for v in files_by_dir.values())} markdown files")

if __name__ == "__main__":
    if not DOCS_ROOT.exists():
        print(f"❌ {DOCS_ROOT} not found")
        exit(1)
    
    generate_index()
    print("✅ Index generation complete!")
