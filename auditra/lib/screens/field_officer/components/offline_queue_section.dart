import 'package:flutter/material.dart';
import '../../../services/offline_storage_service.dart';
import '../../../services/network_service.dart';

class OfflineQueueSection extends StatelessWidget {
  const OfflineQueueSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: This relies on the parent widget rebuilding when sync/network events occur
    final unsyncedValuations = OfflineStorageService.getUnsyncedValuations();
    final isOnline = NetworkService.isOnline;
    
    // Don't show queue if there are no unsynced items
    if (unsyncedValuations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Offline Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  '${unsyncedValuations.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: Colors.orange[700],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isOnline 
              ? 'Syncing reports... They will be submitted automatically.'
              : 'Reports saved offline. They will be submitted when internet connects.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 12),
          ...unsyncedValuations.take(3).map((valuation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.description, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${valuation['category'] ?? 'Valuation'} - ${valuation['description'] ?? 'No description'}',
                    style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isOnline)
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange[700]),
              ],
            ),
          )),
          if (unsyncedValuations.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'And ${unsyncedValuations.length - 3} more...',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.orange[700],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
