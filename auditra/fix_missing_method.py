
import os

file_path = r'lib/screens/coordinator_dashboard.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the last closing brace
last_brace_index = -1
for i in range(len(lines) - 1, -1, -1):
    if '}' in lines[i]:
        last_brace_index = i
        break

if last_brace_index != -1:
    lines.insert(last_brace_index, "\n  Future<void> _showDocumentsDialog(Project project) async {\n    await DocumentsDialog.show(context, project, () => _loadProjects());\n  }\n")

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
