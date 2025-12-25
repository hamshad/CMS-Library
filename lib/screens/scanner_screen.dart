import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/exceptions.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import '../widgets/return_note_dialog.dart';
import 'login_screen.dart';

/// Unified QR Scanner screen for both Student and Book scanning
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum ScanStep { student, book, action }

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  late MobileScannerController _scannerController;
  final ApiService _apiService = ApiService();

  late AnimationController _pulseController;
  late AnimationController _stepController;
  late Animation<double> _pulseAnimation;

  String? _userName;
  String? _scannedStudentId;
  String? _scannedBookId;
  bool _isProcessing = false;
  bool _isCameraReady = false;

  ScanStep get _currentStep {
    if (_scannedStudentId == null) return ScanStep.student;
    if (_scannedBookId == null) return ScanStep.book;
    return ScanStep.action;
  }

  @override
  void initState() {
    super.initState();
    _initScanner();
    _setupAnimations();
    _loadUserName();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: true,
    );
    _isCameraReady = true;
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadUserName() async {
    final prefs = await PreferencesService.getInstance();
    setState(() => _userName = prefs.fullName);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await PreferencesService.getInstance();
      await prefs.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final hasComma = rawValue.contains(',');

    if (_currentStep == ScanStep.student) {
      // Expect student QR with comma: <studentid>,<somevalue>
      if (!hasComma) return;

      final studentId = rawValue.split(',').first.trim();
      if (studentId.isEmpty) return;

      HapticFeedback.mediumImpact();
      _stepController.forward(from: 0);

      setState(() {
        _scannedStudentId = studentId;
      });
    } else if (_currentStep == ScanStep.book) {
      // Expect book QR without comma: <bookid>
      if (hasComma) return;

      HapticFeedback.mediumImpact();
      _stepController.forward(from: 0);

      setState(() {
        _scannedBookId = rawValue.trim();
      });

      // Show action dialog
      _showActionDialog();
    }
  }

  void _showActionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _ActionBottomSheet(
        onIssue: () {
          Navigator.pop(context);
          _handleIssue();
        },
        onReturn: () {
          Navigator.pop(context);
          _handleReturn();
        },
        onCancel: () {
          Navigator.pop(context);
          _resetToBookScan();
        },
      ),
    );
  }

  Future<void> _handleIssue() async {
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final prefs = await PreferencesService.getInstance();
      final uid = prefs.uid ?? '';

      final response = await _apiService.issueBook(
        cid: _scannedStudentId!,
        uid: uid,
        bookId: _scannedBookId!,
      );

      if (!mounted) return;

      _showResultToast(response, isSuccess: true);
      _resetAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showResultToast(e.message, isSuccess: false);
      _resetAll();
    } catch (e) {
      if (!mounted) return;
      _showResultToast(null, isSuccess: false);
      _resetAll();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReturn() async {
    // Show return note dialog
    final returnNote = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ReturnNoteDialog(),
    );

    if (returnNote == null) {
      // User cancelled, go back to action dialog
      _showActionDialog();
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final prefs = await PreferencesService.getInstance();
      final uid = prefs.uid ?? '';

      final response = await _apiService.returnBook(
        cid: _scannedStudentId!,
        uid: uid,
        bookId: _scannedBookId!,
        returnNote: returnNote,
      );

      if (!mounted) return;

      _showResultToast(response, isSuccess: true);
      _resetAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showResultToast(e.message, isSuccess: false);
      _resetAll();
    } catch (e) {
      if (!mounted) return;
      _showResultToast(null, isSuccess: false);
      _resetAll();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultToast(String? message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message ?? 'Something went wrong'),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetToBookScan() {
    setState(() {
      _scannedBookId = null;
    });
  }

  void _resetAll() {
    _stepController.reverse();
    setState(() {
      _scannedStudentId = null;
      _scannedBookId = null;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepController.dispose();
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
          if (_isCameraReady)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Dark overlay gradient at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Header with user info and logout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // User avatar and name
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryCoral,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        if (_userName != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _userName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Reset button (visible when scanning started)
                  if (_scannedStudentId != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _resetAll,
                        tooltip: 'Start Over',
                      ),
                    ),
                  // Logout button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _handleLogout,
                      tooltip: 'Logout',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning overlay with dynamic content
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentStep == ScanStep.student
                            ? AppTheme.primaryCoral
                            : AppTheme.secondaryTeal,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildScanContent(),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom workflow indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated workflow steps
                    _buildAnimatedWorkflowSteps(),
                    const SizedBox(height: 16),
                    // Current step instruction
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _getStepInstruction(),
                        key: ValueKey(_currentStep),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanContent() {
    if (_currentStep == ScanStep.student) {
      return Column(
        key: const ValueKey('student'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            color: AppTheme.primaryCoral,
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan Student ID',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Point camera at QR code',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('book'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Student scanned indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Student Scanned',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.menu_book_rounded,
            color: AppTheme.secondaryTeal,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan Book QR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildAnimatedWorkflowSteps() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildWorkflowStep(
          number: '1',
          label: 'Student',
          step: ScanStep.student,
        ),
        _buildAnimatedConnector(fromStep: ScanStep.student),
        _buildWorkflowStep(
          number: '2',
          label: 'Book',
          step: ScanStep.book,
        ),
        _buildAnimatedConnector(fromStep: ScanStep.book),
        _buildWorkflowStep(
          number: '3',
          label: 'Action',
          step: ScanStep.action,
        ),
      ],
    );
  }

  Widget _buildWorkflowStep({
    required String number,
    required String label,
    required ScanStep step,
  }) {
    final isCompleted = _currentStep.index > step.index;
    final isActive = _currentStep == step;
    final color = isCompleted
        ? AppTheme.successGreen
        : isActive
            ? (step == ScanStep.student ? AppTheme.primaryCoral : AppTheme.secondaryTeal)
            : Colors.white.withOpacity(0.3);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: isActive ? 48 : 40,
          height: isActive ? 48 : 40,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    number,
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isCompleted || isActive ? Colors.white : Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildAnimatedConnector({required ScanStep fromStep}) {
    final isCompleted = _currentStep.index > fromStep.index;

    return Container(
      width: 50,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      child: Stack(
        children: [
          // Background line
          Container(
            color: Colors.white.withOpacity(0.2),
          ),
          // Animated fill
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: isCompleted ? 50 : 0,
            color: AppTheme.successGreen,
          ),
        ],
      ),
    );
  }

  String _getStepInstruction() {
    switch (_currentStep) {
      case ScanStep.student:
        return 'Step 1: Scan student ID card';
      case ScanStep.book:
        return 'Step 2: Now scan book QR code';
      case ScanStep.action:
        return 'Step 3: Choose Issue or Return';
    }
  }
}

/// Bottom sheet for Issue/Return action selection
class _ActionBottomSheet extends StatelessWidget {
  final VoidCallback onIssue;
  final VoidCallback onReturn;
  final VoidCallback onCancel;

  const _ActionBottomSheet({
    required this.onIssue,
    required this.onReturn,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
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

              // Success indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ready for Action',
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Student & Book scanned successfully',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // Large action buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'ISSUE',
                      color: AppTheme.successGreen,
                      onPressed: onIssue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.arrow_downward_rounded,
                      label: 'RETURN',
                      color: AppTheme.primaryCoral,
                      onPressed: onReturn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cancel button
              TextButton(
                onPressed: onCancel,
                child: Text(
                  'Scan Different Book',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
