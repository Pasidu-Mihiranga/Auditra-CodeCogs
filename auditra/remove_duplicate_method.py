
import os

file_path = r'lib/screens/coordinator_dashboard.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# We need to find "Future<void> _showDocumentsDialog(Project project) async {" occurrences
sub = "Future<void> _showDocumentsDialog(Project project) async {"
count = content.count(sub)

print(f"Found {count} occurrences of {sub}")

if count > 1:
    # Remove the LAST one I added
    last_index = content.rfind(sub)
    if last_index != -1:
        # Find closing brace
        brace_index = content.find('}', last_index)
        if brace_index != -1:
             # Remove from last_index to brace_index + 1
             new_content = content[:last_index] + content[brace_index+1:]
             with open(file_path, 'w', encoding='utf-8') as f:
                 f.write(new_content)
             print("Removed last occurrence.")
else:
    print("Not duplicate or not found.")
