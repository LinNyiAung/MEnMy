// widgets/file_viewer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/transaction_service.dart';

class FileViewer extends StatefulWidget {
  final List<String> filePaths;
  final int initialIndex;
  final String? authToken; // Add auth token parameter

  const FileViewer({
    Key? key,
    required this.filePaths,
    this.initialIndex = 0,
    this.authToken, // Add this parameter
  }) : super(key: key);

  @override
  State<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<FileViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getFileName(String filePath) {
    return filePath.split('_').last;
  }

  String _getFileExtension(String filename) {
    return filename.split('.').last.toLowerCase();
  }

  bool _isImageFile(String filename) {
    final extension = _getFileExtension(filename);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  bool _isPdfFile(String filename) {
    return _getFileExtension(filename) == 'pdf';
  }

  Future<void> _downloadFile(String filePath) async {
  setState(() {
    _isLoading = true;
    _message = 'Downloading...';
  });

  // Show download options dialog first
  final downloadOption = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Download Options'),
      content: const Text('Choose where to save the file:'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('app'),
          child: const Text('App Folder (Recommended)'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('downloads'),
          child: const Text('Downloads Folder'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (downloadOption == null) {
    setState(() {
      _isLoading = false;
      _message = '';
    });
    return;
  }

  Map<String, dynamic> result;
  
  if (downloadOption == 'app') {
    // Download to app-specific folder (no permission required)
    result = await TransactionService.downloadTransactionFile(
      filename: filePath,
      customFileName: _getFileName(filePath),
    );
  } else {
    // Download to public Downloads folder (requires permission)
    result = await TransactionService.downloadToPublicDownloads(
      filename: filePath,
      customFileName: _getFileName(filePath),
    );
  }

  setState(() {
    _isLoading = false;
    _message = result['message'];
  });

  if (mounted) {
    if (result['success']) {
      final directoryType = result['directory_type'] ?? 'unknown';
      String locationMessage;
      
      switch (directoryType) {
        case 'app_external':
          locationMessage = 'Downloaded to app storage folder';
          break;
        case 'app_documents':
          locationMessage = 'Downloaded to app documents folder';
          break;
        case 'public_downloads':
          locationMessage = 'Downloaded to Downloads folder';
          break;
        default:
          locationMessage = 'Downloaded successfully';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locationMessage),
              Text(
                'Path: ${result['file_path']}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open Folder',
            onPressed: () => _openFileLocation(result['file_path']),
          ),
        ),
      );
    } else {
      Color snackBarColor = Colors.red;
      String actionLabel = 'Retry';
      VoidCallback? actionCallback = () => _downloadFile(filePath);

      // Handle permission denied case
      if (result['permission_denied'] == true) {
        actionLabel = 'Try App Folder';
        actionCallback = () async {
          final appResult = await TransactionService.downloadTransactionFile(
            filename: filePath,
            customFileName: _getFileName(filePath),
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(appResult['message']),
                backgroundColor: appResult['success'] ? Colors.green : Colors.red,
              ),
            );
          }
        };
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: snackBarColor,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: actionLabel,
            onPressed: actionCallback,
          ),
        ),
      );
    }
  }
}

  Future<void> _openFileLocation(String filePath) async {
  try {
    if (Platform.isAndroid) {
      // Try to open file manager
      final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Alternative: try to open the file directly
        final fileUri = Uri.file(filePath);
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot open file location. File saved successfully.'),
              ),
            );
          }
        }
      }
    } else if (Platform.isIOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File saved to app documents directory'),
          ),
        );
      }
    }
  } catch (e) {
    print('Error opening file location: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File downloaded successfully but cannot open location'),
        ),
      );
    }
  }
}

  Future<void> _shareFile(String filePath) async {
    try {
      // Download the file first
      final result = await TransactionService.downloadTransactionFile(
        filename: filePath,
        customFileName: _getFileName(filePath),
      );

      if (result['success']) {
        // You can implement sharing functionality here using share_plus package
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File ready for sharing (implement share_plus package)'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sharing file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} of ${widget.filePaths.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: () => _downloadFile(widget.filePaths[_currentIndex]),
            icon: const Icon(Icons.download),
            tooltip: 'Download file',
          ),
          IconButton(
            onPressed: () => _shareFile(widget.filePaths[_currentIndex]),
            icon: const Icon(Icons.share),
            tooltip: 'Share file',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'info') {
                _showFileInfo();
              } else if (value == 'open_external') {
                _openInExternalApp();
              } else if (value == 'refresh') {
                setState(() {}); // Simple refresh by rebuilding
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('File Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('Open in Browser'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.filePaths.length,
            itemBuilder: (context, index) {
              final filePath = widget.filePaths[index];
              final fileName = _getFileName(filePath);

              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isImageFile(fileName))
                      _buildImageViewer(filePath)
                    else if (_isPdfFile(fileName))
                      _buildPdfViewer(filePath)
                    else
                      _buildGenericFileViewer(fileName),
                    const SizedBox(height: 20),
                    Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.filePaths.length > 1
          ? Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      _getFileName(widget.filePaths[_currentIndex]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _currentIndex < widget.filePaths.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildImageViewer(String filePath) {
    final imageUrl = TransactionService.getFileUrl(filePath);
    
    return Expanded(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        child: Image.network(
          imageUrl,
          headers: widget.authToken != null ? {
            'Authorization': 'Bearer ${widget.authToken}',
          } : {},
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${error.toString()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}), // Retry loading
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfViewer(String filePath) {
    final fileName = _getFileName(filePath);
    
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.picture_as_pdf,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'PDF Document',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _downloadFile(filePath),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openInExternalApp(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in Browser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericFileViewer(String fileName) {
    final extension = _getFileExtension(fileName);
    IconData icon;
    Color color;

    switch (extension) {
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'zip':
      case 'rar':
        icon = Icons.archive;
        color = Colors.orange;
        break;
      case 'mp3':
      case 'wav':
        icon = Icons.audiotrack;
        color = Colors.purple;
        break;
      case 'mp4':
      case 'avi':
        icon = Icons.videocam;
        color = Colors.red;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: color,
            ),
            const SizedBox(height: 20),
            Text(
              extension.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _downloadFile(widget.filePaths[_currentIndex]),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openInExternalApp(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo() async {
    final filePath = widget.filePaths[_currentIndex];
    final result = await TransactionService.getFileInfo(filename: filePath);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('File Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Name', result['filename'] ?? 'Unknown'),
              _buildInfoRow('Type', result['content_type'] ?? 'Unknown'),
              _buildInfoRow('Size', result['size_kb'] != null ? '${result['size_kb']} KB' : 'Unknown'),
              _buildInfoRow('Extension', _getFileExtension(_getFileName(filePath)).toUpperCase()),
              _buildInfoRow('Path', filePath),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _openInExternalApp() async {
    final filePath = widget.filePaths[_currentIndex];
    final fileUrl = TransactionService.getFileUrl(filePath);
    
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open file in external app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}