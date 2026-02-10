
import 'package:flutter/material.dart';
import '../../../../models/valuation_model.dart';

class FieldOfficerUiHelpers {
  /// Get color for valuation status
  static Color getValuationStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'submitted':
      case 'pending':
        return Colors.orange;
      case 'draft':
      default:
        return Colors.blue;
    }
  }

  /// Check if a valuation can be edited (created within 2 hours)
  static bool canEditValuation(Valuation valuation) {
    if (valuation.status == 'draft' || valuation.status == 'rejected') {
      return true;
    }
    
    if (valuation.status == 'submitted') {
      final now = DateTime.now();
      final difference = now.difference(valuation.submittedAt ?? valuation.createdAt);
      
      // Allow editing if submitted within 2 hours
      return difference.inHours < 2;
    }
    
    return false;
  }

  /// Check if a valuation can be deleted (draft or rejected)
  static bool canDeleteValuation(Valuation valuation) {
    // Only allow deleting drafts or rejected reports
    return valuation.status == 'draft' || valuation.status == 'rejected';
  }
}
