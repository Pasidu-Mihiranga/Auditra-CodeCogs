
import os

file_path = r'lib/screens/coordinator_dashboard.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports
imports = """
import 'coordinator/dialogs/status_update_dialog.dart';
import 'coordinator/dialogs/assign_users_dialog.dart';
"""
if "import 'coordinator/dialogs/status_update_dialog.dart';" not in content:
    idx = content.find("import '../models/project_model.dart';")
    content = content[:idx] + imports + content[idx:]

# 2. Helper to remove methods
def remove_method(s, sig):
    start = s.find(sig)
    if start != -1:
        open_brace = s.find('{', start)
        if open_brace != -1:
            brace_count = 1
            i = open_brace + 1
            while brace_count > 0 and i < len(s):
                if s[i] == '{':
                    brace_count += 1
                elif s[i] == '}':
                    brace_count -= 1
                i += 1
            return s[:start] + s[i:]
    return s

# Remove the large helper methods first (bottom up logic roughly)
content = remove_method(content, "Widget _buildWorkflowStage(")
content = remove_method(content, "Widget _buildStatusOption(")
content = remove_method(content, "Future<void> _updateWorkflowStage(")

content = remove_method(content, "Widget _buildUserTypeTab<T>(")
content = remove_method(content, "Widget _buildClientAgentTab(")
content = remove_method(content, "Future<void> _showUserAssignedProjects(")

# Now replace _showStatusDialog and _showAssignUsersDialog
# Instead of removing, we replace their bodies with the new calls.

sig_status = "Future<void> _showStatusDialog(Project project) async {"
idx_status = content.find(sig_status)
if idx_status != -1:
    # remove old body
    content = remove_method(content, sig_status)
    # append new simple method
    # We can just put it back in.
    new_method = """
  Future<void> _showStatusDialog(Project project) async {
    await StatusUpdateDialog.show(context, project, () {
      _loadProjects();
    });
  }
"""
    # Insert before last }
    last_brace = content.rfind('}')
    content = content[:last_brace] + new_method + "\n}"

sig_assign = "Future<void> _showAssignUsersDialog(Project project) async {"
idx_assign = content.find(sig_assign)
if idx_assign != -1:
    content = remove_method(content, sig_assign)
    new_method = """
  Future<void> _showAssignUsersDialog(Project project) async {
    await AssignUsersDialog.show(context, project, () {
      _loadProjects();
    });
  }
"""
    last_brace = content.rfind('}')
    content = content[:last_brace] + new_method + "\n}"

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
