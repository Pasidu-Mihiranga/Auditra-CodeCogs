
import os

file_path = r'lib/screens/coordinator_dashboard.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import if not present
import_stmt = "import 'coordinator/dialogs/documents_dialog.dart';"
if import_stmt not in content:
    # Insert after status_update_dialog.dart
    target_import = "import 'coordinator/dialogs/status_update_dialog.dart';"
    if target_import in content:
        content = content.replace(target_import, target_import + '\n' + import_stmt)
    else:
        # Fallback
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_stmt)

# Helper function to remove a block of code starting with a specific signature
def remove_block(content, start_signature):
    start_index = content.find(start_signature)
    if start_index == -1:
        print(f"Signature not found: {start_signature}")
        return content

    # Find the opening brace after the signature
    open_brace_index = content.find('{', start_index)
    if open_brace_index == -1:
         print(f"Opening brace not found for: {start_signature}")
         return content

    # Count braces to find end
    open_braces = 0
    end_index = -1
    
    for i in range(open_brace_index, len(content)):
        if content[i] == '{':
            open_braces += 1
        elif content[i] == '}':
            open_braces -= 1
        
        if open_braces == 0:
            end_index = i + 1
            break
            
    if end_index != -1:
        # Check if we should preserve a replacement
        return content[:start_index] + content[end_index:]
    return content

# Helper to replace body
def replace_body(content, start_signature, new_body):
    start_index = content.find(start_signature)
    if start_index == -1:
        print(f"Signature not found: {start_signature}")
        return content

    # Find the opening brace after the signature
    open_brace_index = content.find('{', start_index)
    if open_brace_index == -1:
         print(f"Opening brace not found for: {start_signature}")
         return content
         
    # Count braces to find end
    open_braces = 0
    end_index = -1
    
    for i in range(open_brace_index, len(content)):
        if content[i] == '{':
            open_braces += 1
        elif content[i] == '}':
            open_braces -= 1
        
        if open_braces == 0:
            end_index = i + 1
            break
            
    if end_index != -1:
        # Keep everything up to and including the opening brace
        return content[:open_brace_index+1] + "\n    " + new_body + "\n  }" + content[end_index:]
    return content


# 2. Update _showDocumentsDialog
content = replace_body(content, "Future<void> _showDocumentsDialog(Project project) async", "await DocumentsDialog.show(context, project, () => _loadProjects());")


# 3. Remove other methods
content = remove_block(content, "Future<void> _uploadDocument(Project project) async")
content = remove_block(content, "Future<void> _uploadDocumentWithUserSelection(Project project, StateSetter setDialogState) async")


# 4. Remove _UploadDialogState class
content = remove_block(content, "class _UploadDialogState")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
