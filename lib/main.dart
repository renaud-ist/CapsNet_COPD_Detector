import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(COPDAnalysisApp());
}

class AnalysisRecord {
  final int? id;
  final String imagePath;
  final String resultType;
  final String resultText;
  final double confidence;
  final String description;
  final DateTime timestamp;

  const AnalysisRecord({
    this.id,
    required this.imagePath,
    required this.resultType,
    required this.resultText,
    required this.confidence,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'result_type': resultType,
      'result_text': resultText,
      'confidence': confidence,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory AnalysisRecord.fromMap(Map<String, dynamic> map) {
    return AnalysisRecord(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      resultType: map['result_type'] as String,
      resultText: map['result_text'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      description: map['description'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
    );
  }
}

class AnalysisHistoryDatabase {
  AnalysisHistoryDatabase._();

  static final AnalysisHistoryDatabase instance =
      AnalysisHistoryDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'analysis_history.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analysis_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            result_type TEXT NOT NULL,
            result_text TEXT NOT NULL,
            confidence REAL NOT NULL,
            description TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertRecord(AnalysisRecord record) async {
    final db = await database;
    return db.insert(
      'analysis_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AnalysisRecord>> fetchRecords() async {
    final db = await database;
    final maps = await db.query(
      'analysis_history',
      orderBy: 'timestamp DESC',
    );
    return maps.map(AnalysisRecord.fromMap).toList();
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete(
      'analysis_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class AppDrawer extends StatelessWidget {
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateHistory;
  final bool isHistorySelected;

  const AppDrawer({
    super.key,
    this.onNavigateHome,
    this.onNavigateHistory,
    this.isHistorySelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E21), Color(0xFF1D1E33)],
          ),
        ),
        child: SafeArea(
          child: ListTileTheme(
            iconColor: Colors.white,
            textColor: Colors.white,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'COPD Analysis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'AI-powered imaging insights',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Home'),
                  onTap: () {
                    Navigator.pop(context);
                    if (onNavigateHome != null) {
                      Future.microtask(onNavigateHome!);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  selected: isHistorySelected,
                  selectedTileColor: Colors.white.withOpacity(0.1),
                  onTap: () {
                    Navigator.pop(context);
                    if (!isHistorySelected && onNavigateHistory != null) {
                      Future.microtask(onNavigateHistory!);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<AnalysisRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await AnalysisHistoryDatabase.instance.fetchRecords();
    if (!mounted) {
      return;
    }
    setState(() {
      _records
        ..clear()
        ..addAll(records);
      _isLoading = false;
    });
  }

  Future<void> _refreshRecords() async {
    final records = await AnalysisHistoryDatabase.instance.fetchRecords();
    if (!mounted) {
      return;
    }
    setState(() {
      _records
        ..clear()
        ..addAll(records);
    });
  }

  Future<void> _confirmAndDelete(AnalysisRecord record) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete analysis?'),
            content: const Text(
              'This will remove the analysis from your saved history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    if (record.id != null) {
      await AnalysisHistoryDatabase.instance.deleteRecord(record.id!);
    }

    try {
      final file = File(record.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore file system errors when attempting to delete saved images.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _records.remove(record);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analysis removed from history'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onNavigateHome: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        isHistorySelected: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E21), Color(0xFF1D1E33)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Saved Analyses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.blue,
                        onRefresh: _refreshRecords,
                        child: _records.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Text(
                                        'No saved analyses yet. Save your results after running a scan to revisit them here.',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                itemCount: _records.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final record = _records[index];
                                  return _HistoryRecordCard(
                                    record: record,
                                    onDelete: () => _confirmAndDelete(record),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  final AnalysisRecord record;
  final VoidCallback onDelete;

  const _HistoryRecordCard({
    required this.record,
    required this.onDelete,
  });

  Color _colorForResult() {
    switch (record.resultType) {
      case 'copd':
        return Colors.redAccent;
      case 'normal':
        return Colors.greenAccent;
      case 'notXray':
        return Colors.orangeAccent;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _iconForResult() {
    switch (record.resultType) {
      case 'copd':
        return Icons.warning_rounded;
      case 'normal':
        return Icons.check_circle_rounded;
      case 'notXray':
        return Icons.error_outline_rounded;
      default:
        return Icons.insights_outlined;
    }
  }

  String _formatTimestamp() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[record.timestamp.month - 1];
    final day = record.timestamp.day.toString().padLeft(2, '0');
    final hour = record.timestamp.hour.toString().padLeft(2, '0');
    final minute = record.timestamp.minute.toString().padLeft(2, '0');
    return '$month $day, ${record.timestamp.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _colorForResult();
    final file = File(record.imagePath);
    final imageExists = file.existsSync();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.2),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _iconForResult(),
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.resultText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete from history',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Confidence',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(record.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              width: double.infinity,
              color: Colors.black,
              child: imageExists
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        'Saved image not found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            record.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class COPDAnalysisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COPD Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _analyzeImage() {
    if (_selectedImage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalysisScreen(image: _selectedImage!),
        ),
      );
    }
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onNavigateHistory: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const HistoryScreen(),
            ),
          );
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0A0E21), const Color(0xFF1D1E33)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.3),
                              Colors.cyan.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.medical_services_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'COPD Analysis',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Advanced AI-powered chest imaging analysis',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Image Selection Area
                  if (_selectedImage == null) ...[
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.5),
                                width: 2,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.withOpacity(0.1),
                                  Colors.purple.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 64,
                                  color: Colors.blue.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select Chest X-Ray Image',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose from camera or gallery',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Image Source Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildImageSourceButton(
                            icon: Icons.camera_alt_outlined,
                            label: 'Camera',
                            onTap: () => _selectImage(ImageSource.camera),
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildImageSourceButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Gallery',
                            onTap: () => _selectImage(ImageSource.gallery),
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Selected Image Preview
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Change Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.purple],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _analyzeImage,
                              icon: const Icon(Icons.analytics_outlined),
                              label: const Text('Analyze Image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white60,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This tool is for educational purposes only and should not replace professional medical diagnosis.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnalysisScreen extends StatefulWidget {
  final File image;

  const AnalysisScreen({Key? key, required this.image}) : super(key: key);

  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

enum AnalysisResult { copd, normal, notXray }

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  bool _isAnalyzing = true;
  AnalysisResult _result = AnalysisResult.normal;
  double _confidence = 0.0;
  late AnimationController _loadingController;
  late AnimationController _resultController;
  late Animation<double> _loadingAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _loadingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );

    _startAnalysis();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _startAnalysis() async {
    _loadingController.repeat();
    try {
      final interpreter = await Interpreter.fromAsset('model/model.tflite');
      final labelsData = await rootBundle.loadString('model/labels.txt');
      final labels = labelsData
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .map((e) => e.split(' ').last)
          .toList();

      final inputShape = interpreter.getInputTensor(0).shape;
      final inputSize = inputShape[1];

      final bytes = await widget.image.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        throw Exception('Unable to decode image');
      }
      final img.Image resized = img.copyResize(
        original,
        width: inputSize,
        height: inputSize,
      );

      final inputBuffer = Float32List(inputSize * inputSize * 3);
      int index = 0;
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          inputBuffer[index++] = pixel.r / 255.0;
          inputBuffer[index++] = pixel.g / 255.0;
          inputBuffer[index++] = pixel.b / 255.0;
        }
      }
      final input = inputBuffer.reshape([1, inputSize, inputSize, 3]);

      final outputShape = interpreter.getOutputTensor(0).shape;
      final outputBuffer = Float32List(
        outputShape.reduce((a, b) => a * b),
      ).reshape([1, outputShape[1]]);
      interpreter.run(input, outputBuffer);

      final probabilities = outputBuffer[0];
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      final label = labels[maxIndex];
      setState(() {
        switch (label) {
          case 'COPD':
            _result = AnalysisResult.copd;
            break;
          case 'NO_COPD':
            _result = AnalysisResult.normal;
            break;
          default:
            _result = AnalysisResult.notXray;
        }
        _confidence = maxProb;
        _isAnalyzing = false;
      });
      interpreter.close();
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _loadingController.stop();
    _resultController.forward();
  }

  Future<void> _saveResults() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final imagesDirectory =
          Directory(p.join(documentsDirectory.path, 'analysis_images'));
      if (!await imagesDirectory.exists()) {
        await imagesDirectory.create(recursive: true);
      }

      final extension = p.extension(widget.image.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'copd_analysis_$timestamp${extension.isNotEmpty ? extension : '.png'}';
      final targetPath = p.join(imagesDirectory.path, fileName);
      final savedImage = await widget.image.copy(targetPath);

      final record = AnalysisRecord(
        imagePath: savedImage.path,
        resultType: _result.name,
        resultText: _resultText,
        confidence: _confidence,
        description: _resultDescription,
        timestamp: DateTime.now(),
      );

      await AnalysisHistoryDatabase.instance.insertRecord(record);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results saved to history'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save results: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color get _resultColor {
    switch (_result) {
      case AnalysisResult.copd:
        return Colors.red;
      case AnalysisResult.normal:
        return Colors.green;
      case AnalysisResult.notXray:
        return Colors.orange;
    }
  }

  IconData get _resultIcon {
    switch (_result) {
      case AnalysisResult.copd:
        return Icons.warning_rounded;
      case AnalysisResult.normal:
        return Icons.check_circle_rounded;
      case AnalysisResult.notXray:
        return Icons.error_outline_rounded;
    }
  }

  String get _resultText {
    switch (_result) {
      case AnalysisResult.copd:
        return 'COPD Detected';
      case AnalysisResult.normal:
        return 'No COPD Detected';
      case AnalysisResult.notXray:
        return 'Invalid X-Ray Image';
    }
  }

  String get _resultDescription {
    switch (_result) {
      case AnalysisResult.copd:
        return 'The analysis indicates potential signs of COPD in the chest X-ray. Please consult with a healthcare professional for proper evaluation.';
      case AnalysisResult.normal:
        return 'The analysis shows no significant indicators of COPD in the chest X-ray. Continue regular check-ups for optimal respiratory health.';
      case AnalysisResult.notXray:
        return 'The uploaded image does not appear to be a valid chest X-ray. Please upload a clear chest X-ray image for accurate COPD analysis.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onNavigateHome: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        onNavigateHistory: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const HistoryScreen(),
            ),
          );
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0A0E21), const Color(0xFF1D1E33)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analysis Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Image Preview
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(widget.image, fit: BoxFit.cover),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Analysis Status
                      if (_isAnalyzing) ...[
                        AnimatedBuilder(
                          animation: _loadingAnimation,
                          builder: (context, child) {
                            return Column(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withOpacity(0.3),
                                        Colors.purple.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Analyzing Image...',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'AI is processing your chest X-ray',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        // Results
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Column(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          _resultColor.withOpacity(0.3),
                                          _resultColor.withOpacity(0.1),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _resultColor.withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _resultIcon,
                                      size: 64,
                                      color: _resultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    _resultText,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: _resultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _resultColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _resultColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _resultColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Text(
                                      _resultDescription,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      if (!_isAnalyzing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Analyze Another'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [Colors.blue, Colors.purple],
                                  ),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _saveResults,
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Save Results'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
