
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../../models/project_model.dart';
import '../../../../services/network_service.dart';

class FieldOfficerDocumentManager {
  final BuildContext context;
  final Function(void Function()) setState;
  final Set<int> downloadedDocuments = {};

  FieldOfficerDocumentManager({
    required this.context,
    required this.setState,
  });

  Future<bool> isDocumentDownloaded(int docId) async {
    if (downloadedDocuments.contains(docId)) return true;
    
    final filePath = await getLocalFilePath(docId);
    if (filePath != null && File(filePath).existsSync()) {
      setState(() {
        downloadedDocuments.add(docId);
      });
      return true;
    }
    return false;
  }

  Future<String?> getLocalFilePath(int docId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${directory.path}/project_docs');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      
      // Find file with this ID prefix
      if (await docsDir.exists()) {
        await for (final entity in docsDir.list()) {
          if (entity is File) {
            final filename = entity.path.split(Platform.pathSeparator).last;
            if (filename.startsWith('${docId}_')) {
              return entity.path;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting local file path: $e');
      return null;
    }
  }

  Future<void> viewDownloadedDocument(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> downloadDocument(ProjectDocument doc) async {
    // Check network
    if (!await NetworkService.checkConnectivity()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot download document.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${doc.name}...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final response = await http.get(Uri.parse(doc.fileUrl!));
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final docsDir = Directory('${directory.path}/project_docs');
        if (!await docsDir.exists()) {
          await docsDir.create(recursive: true);
        }
        
        // Clean filename logic could go here, for now using simple replacement
        final safeName = doc.name.replaceAll(RegExp(r'[^\w\s\.-]'), '');
        final filePath = '${docsDir.path}/${doc.id}_$safeName';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          downloadedDocuments.add(doc.id);
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download complete'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Ask to open
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Document downloaded'),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => viewDownloadedDocument(filePath),
              ),
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
