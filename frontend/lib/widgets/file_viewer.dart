// widgets/file_viewer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/transaction_service.dart';

class FileViewer extends StatefulWidget {
  final List<String> filePaths;
  final int initialIndex;
  final String? authToken;

  const FileViewer({
    Key? key,
    required this.filePaths,
    this.initialIndex = 0,
    this.authToken,
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

  bool _isTextFile(String filename) {
    return _getFileExtension(filename) == 'txt';
  }

  // Helper method to get a local PDF path for viewing
  Future<String> _getLocalPdfPath(String filePath) async {
    try {
      return await TransactionService.downloadFileToCache(
        filePath,
        authToken: widget.authToken,
      );
    } catch (e) {
      throw Exception('Failed to get PDF file: $e');
    }
  }

  // Helper method to get text content
  Future<String> _getTextContent(String filePath) async {
    try {
      final localPath = await TransactionService.downloadFileToCache(
        filePath,
        authToken: widget.authToken,
      );
      final file = File(localPath);
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read text file: $e');
    }
  }

  // Your existing download and other methods remain the same...
  Future<void> _downloadFile(String filePath) async {
    setState(() {
      _isLoading = true;
      _message = 'Downloading...';
    });

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
      result = await TransactionService.downloadTransactionFile(
        filename: filePath,
        customFileName: _getFileName(filePath),
      );
    } else {
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
        final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
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
      final result = await TransactionService.downloadTransactionFile(
        filename: filePath,
        customFileName: _getFileName(filePath),
      );

      if (result['success']) {
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

  // Helper method to build filename header (NEW)
  Widget _buildFileNameHeader(String fileName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        children: [
          Icon(
            _getFileTypeIcon(fileName),
            color: _getFileTypeColor(fileName),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getFileExtension(fileName).toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get file type icon
  IconData _getFileTypeIcon(String fileName) {
    final extension = _getFileExtension(fileName);
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Helper method to get file type color
  Color _getFileTypeColor(String fileName) {
    final extension = _getFileExtension(fileName);
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Colors.blue;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
        return Colors.grey;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'zip':
      case 'rar':
        return Colors.orange;
      case 'mp3':
      case 'wav':
        return Colors.purple;
      case 'mp4':
      case 'avi':
        return Colors.red;
      default:
        return Colors.grey;
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
                setState(() {});
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

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ALWAYS show filename header at the top
                    _buildFileNameHeader(fileName),
                    
                    // File content viewer
                    Expanded(
                      child: _buildFileContent(filePath, fileName),
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

  // NEW: Centralized file content builder
  Widget _buildFileContent(String filePath, String fileName) {
    if (_isImageFile(fileName)) {
      return _buildImageViewer(filePath);
    } else if (_isPdfFile(fileName)) {
      return _buildPdfViewer(filePath);
    } else if (_isTextFile(fileName)) {
      return _buildTextViewer(filePath);
    } else {
      return _buildGenericFileViewer(fileName);
    }
  }

  Widget _buildImageViewer(String filePath) {
    final imageUrl = TransactionService.getFileUrl(filePath);
    
    return InteractiveViewer(
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
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // UPDATED: Removed duplicate filename display since it's now in the header
  Widget _buildPdfViewer(String filePath) {
    return FutureBuilder<String>(
      future: _getLocalPdfPath(filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading PDF...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
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
                  'Failed to load PDF',
                  style: TextStyle(color: Colors.white),
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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
          );
        } else {
          final localPath = snapshot.data!;
          return PDFView(
            filePath: localPath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onError: (error) {
              print('Error rendering PDF: $error');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading PDF: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            onPageError: (page, error) {
              print('Page $page Error: $error');
            },
            onRender: (pages) {
              print("Rendered $pages pages.");
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // You can store this controller if you need to control the PDF programmatically
            },
            onLinkHandler: (String? uri) {
              print('goto uri: $uri');
            },
            onPageChanged: (int? page, int? total) {
              print('page change: $page/$total');
            },
          );
        }
      },
    );
  }

  // UPDATED: Removed duplicate filename display
  Widget _buildTextViewer(String filePath) {
    return FutureBuilder<String>(
      future: _getTextContent(filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
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
                  'Failed to load text file',
                  style: TextStyle(color: Colors.white),
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        } else {
          final textContent = snapshot.data!;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                textContent,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildGenericFileViewer(String fileName) {
    final extension = _getFileExtension(fileName);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileTypeIcon(fileName),
            size: 80,
            color: _getFileTypeColor(fileName),
          ),
          const SizedBox(height: 20),
          Text(
            'Preview not available',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This ${extension.toUpperCase()} file cannot be previewed directly.',
            style: const TextStyle(
              color: Colors.white60,
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
                label: const Text('Open in Browser'),
              ),
            ],
          ),
        ],
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