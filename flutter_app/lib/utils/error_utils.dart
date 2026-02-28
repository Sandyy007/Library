/// Utility functions for handling and displaying errors
library;

/// Extracts a user-friendly message from an exception.
/// Removes 'Exception:', stack traces, and technical details.
String cleanErrorMessage(dynamic error, {String fallback = 'An error occurred'}) {
  if (error == null) return fallback;
  
  String message = error.toString();
  
  // Remove "Exception: " prefix
  if (message.startsWith('Exception: ')) {
    message = message.substring(11);
  }
  
  // Remove "FormatException: " prefix
  if (message.startsWith('FormatException: ')) {
    message = message.substring(17);
  }
  
  // Truncate if too long (likely contains stack trace)
  if (message.length > 100) {
    // Find first newline or period
    final newlineIndex = message.indexOf('\n');
    final periodIndex = message.indexOf('. ');
    
    int cutoff = message.length;
    if (newlineIndex > 0 && newlineIndex < cutoff) cutoff = newlineIndex;
    if (periodIndex > 0 && periodIndex < cutoff) cutoff = periodIndex + 1;
    
    if (cutoff < message.length) {
      message = message.substring(0, cutoff);
    } else {
      message = '${message.substring(0, 80)}...';
    }
  }
  
  // Clean up common technical patterns
  message = message.trim();
  if (message.isEmpty) return fallback;
  
  return message;
}

/// Returns a short, user-friendly error message for common operations
String getOperationErrorMessage(String operation, dynamic error) {
  final cleanMsg = cleanErrorMessage(error);
  
  // Map common error patterns to friendly messages
  if (cleanMsg.contains('connect') || cleanMsg.contains('SocketException')) {
    return 'Cannot connect to server';
  }
  if (cleanMsg.contains('timed out') || cleanMsg.contains('TimeoutException')) {
    return 'Connection timed out';
  }
  if (cleanMsg.contains('not found') || cleanMsg.contains('404')) {
    return '$operation: Item not found';
  }
  if (cleanMsg.contains('unauthorized') || cleanMsg.contains('401')) {
    return 'Please log in again';
  }
  if (cleanMsg.contains('forbidden') || cleanMsg.contains('403')) {
    return 'Access denied';
  }
  
  // For other errors, return the cleaned message or a generic one
  if (cleanMsg.length > 50) {
    return '$operation failed';
  }
  
  return cleanMsg;
}
