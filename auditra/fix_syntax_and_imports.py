
import os

# 1. Fix coordinator_dashboard.dart
file_path = r'lib/screens/coordinator_dashboard.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
brace_count = 0
in_broken_method = False

for i, line in enumerate(lines):
    # Remove workflowStages
    if "static const List<Map<String, dynamic>> workflowStages = [" in line:
        skip = True
        brace_count = 0
        # count braces to find end
        # assuming it ends with ]; on a separate line as seen
    
    if skip:
        if "];" in line and brace_count == 0: # minimal brace logic
             skip = False
             continue
        else:
            continue
            
    # Remove broken method starting with ) {
    # It seems to be around line 385 in original file. 
    # To be safe, look for exactly "  ) {" which matches the indentation
    if line.strip() == ") {" or line.rstrip() == "  ) {":
        in_broken_method = True
        brace_count = 1
        continue
    
    if in_broken_method:
        brace_count += line.count('{')
        brace_count -= line.count('}')
        if brace_count <= 0:
            in_broken_method = False
        continue

    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)


# 2. Fix imports in dialogs
dialog_files = [
    r'lib/screens/coordinator/dialogs/status_update_dialog.dart',
    r'lib/screens/coordinator/dialogs/assign_users_dialog.dart'
]

for d_file in dialog_files:
    if os.path.exists(d_file):
        with open(d_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace wrong import
        if "import '../services/api_service.dart';" in content:
            content = content.replace("import '../services/api_service.dart';", "import '../../../services/api_service.dart';")
            
        with open(d_file, 'w', encoding='utf-8') as f:
            f.write(content)
