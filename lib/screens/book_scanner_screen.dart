import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import '../widgets/return_note_dialog.dart';

/// QR Scanner screen to scan Book ID with Issue/Return actions
class BookScannerScreen extends StatefulWidget {
  final String studentCid;

  const BookScannerScreen({super.key, required this.studentCid});

  @override
  State<BookScannerScreen> createState() => _BookScannerScreenState();
}

class _BookScannerScreenState extends State<BookScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  final ApiService _apiService = ApiService();

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  String? _scannedBookId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: true,
    );
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scannedBookId != null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final bookId = barcodes.first.rawValue;
    if (bookId == null || bookId.isEmpty) return;

    // Book QR codes do NOT contain commas
    // Skip if contains comma (this is a student QR code, not book)
    if (bookId.contains(',')) return;

    // Haptic feedback on successful scan
    HapticFeedback.mediumImpact();

    setState(() {
      _scannedBookId = bookId;
    });

    _scannerController.stop();
  }

  Future<void> _handleIssue() async {
    if (_scannedBookId == null) return;

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final prefs = await PreferencesService.getInstance();
      final uid = prefs.uid ?? '';

      final response = await _apiService.issueBook(
        cid: widget.studentCid,
        uid: uid,
        bookId: _scannedBookId!,
      );

      if (!mounted) return;

      // Show toast with response and go back to student scanner
      if (response.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(response)),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Something went wrong'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Navigate back to student scanner
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Something went wrong'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReturn() async {
    if (_scannedBookId == null) return;

    // Show return note dialog
    final returnNote = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ReturnNoteDialog(),
    );

    if (returnNote == null) {
      // User cancelled
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final prefs = await PreferencesService.getInstance();
      final uid = prefs.uid ?? '';

      final response = await _apiService.returnBook(
        cid: widget.studentCid,
        uid: uid,
        bookId: _scannedBookId!,
        returnNote: returnNote,
      );

      if (!mounted) return;

      // Show toast with response and go back to student scanner
      if (response.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(response)),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Something went wrong'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Navigate back to student scanner
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Something went wrong'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetScanner() {
    HapticFeedback.selectionClick();
    setState(() {
      _scannedBookId = null;
    });
    _scannerController.start();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Dark overlay gradient at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Back button and status
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status chips
                  Expanded(
                    child: Row(
                      children: [
                        _buildStatusChip(
                          icon: Icons.person,
                          label: 'Student Scanned',
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(width: 8),
                        if (_scannedBookId != null)
                          _buildStatusChip(
                            icon: Icons.menu_book,
                            label: 'Book Scanned',
                            color: AppTheme.secondaryTeal,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning overlay (when no book scanned yet)
          if (_scannedBookId == null)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.secondaryTeal,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.secondaryTeal,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Scan Book QR',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Scanned - show large action buttons
          if (_scannedBookId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Success message
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.secondaryTeal,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Book ID Scanned Successfully',
                                style: TextStyle(
                                  color: AppTheme.secondaryTeal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Large action buttons
                        Row(
                          children: [
                            // Issue Button
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.arrow_upward_rounded,
                                label: 'ISSUE',
                                color: AppTheme.successGreen,
                                onPressed: _isProcessing ? null : _handleIssue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Return Button
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.arrow_downward_rounded,
                                label: 'RETURN',
                                color: AppTheme.primaryCoral,
                                onPressed: _isProcessing ? null : _handleReturn,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Rescan button
                        TextButton.icon(
                          onPressed: _isProcessing ? null : _resetScanner,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Scan Different Book'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 72,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
