import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق تسجيل الوقت والأجور',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const HistoryScreen(),
        '/monthly': (context) => const MonthlyReportScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class TimeRecord {
  final DateTime date;
  DateTime? clockIn;
  DateTime? clockOut;
  double hoursWorked;
  double overtimeHours;
  double dailyWage;

  TimeRecord({
    required this.date,
    this.clockIn,
    this.clockOut,
    this.hoursWorked = 0,
    this.overtimeHours = 0,
    this.dailyWage = 0,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'clockIn': clockIn?.toIso8601String(),
    'clockOut': clockOut?.toIso8601String(),
    'hoursWorked': hoursWorked,
    'overtimeHours': overtimeHours,
    'dailyWage': dailyWage,
  };

  factory TimeRecord.fromJson(Map<String, dynamic> json) => TimeRecord(
    date: DateTime.parse(json['date']),
    clockIn: json['clockIn'] != null ? DateTime.parse(json['clockIn']) : null,
    clockOut: json['clockOut'] != null ? DateTime.parse(json['clockOut']) : null,
    hoursWorked: json['hoursWorked'] ?? 0,
    overtimeHours: json['overtimeHours'] ?? 0,
    dailyWage: json['dailyWage'] ?? 0,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isClockedIn = false;
  DateTime? clockInTime;
  Timer? timer;
  Duration workedTime = Duration.zero;
  double hourlyRate = 10.0;
  double overtimeRate = 15.0;
  List<TimeRecord> records = [];

  @override
  void initState() {
    super.initState();
    loadSettings();
    loadRecords();
    checkCurrentDayStatus();
  }

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hourlyRate = prefs.getDouble('hourlyRate') ?? 10.0;
      overtimeRate = prefs.getDouble('overtimeRate') ?? 15.0;
    });
  }

  void loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('records') ?? [];
    setState(() {
      records = recordsJson.map((json) => TimeRecord.fromJson(jsonDecode(json))).toList();
    });
  }

  void saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList('records', recordsJson);
  }

  void checkCurrentDayStatus() {
    final today = DateTime.now();
    final todayRecord = records.where((r) => 
      r.date.year == today.year && 
      r.date.month == today.month && 
      r.date.day == today.day
    ).toList();
    
    if (todayRecord.isNotEmpty) {
      final record = todayRecord.first;
      if (record.clockIn != null && record.clockOut == null) {
        setState(() {
          isClockedIn = true;
          clockInTime = record.clockIn;
        });
        startTimer();
      }
    }
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (clockInTime != null) {
        setState(() {
          workedTime = DateTime.now().difference(clockInTime!);
        });
      }
    });
  }

  void clockIn() {
    final now = DateTime.now();
    setState(() {
      isClockedIn = true;
      clockInTime = now;
      workedTime = Duration.zero;
    });
    
    final today = DateTime(now.year, now.month, now.day);
    final existingRecord = records.where((r) => 
      r.date.year == today.year && 
      r.date.month == today.month && 
      r.date.day == today.day
    ).toList();
    
    if (existingRecord.isEmpty) {
      records.add(TimeRecord(date: today, clockIn: now));
    } else {
      existingRecord.first.clockIn = now;
    }
    
    saveRecords();
    startTimer();
  }

  void clockOut() {
    final now = DateTime.now();
    setState(() {
      isClockedIn = false;
    });
    
    final today = DateTime(now.year, now.month, now.day);
    final record = records.where((r) => 
      r.date.year == today.year && 
      r.date.month == today.month && 
      r.date.day == today.day
    ).first;
    
    record.clockOut = now;
    final hours = now.difference(record.clockIn!).inMinutes / 60.0;
    record.hoursWorked = hours;
    
    if (hours > 8) {
      record.overtimeHours = hours - 8;
    }
    
    record.dailyWage = (record.hoursWorked - record.overtimeHours) * hourlyRate + 
                       record.overtimeHours * overtimeRate;
    
    saveRecords();
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الوقت'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isClockedIn ? 'مسجل دخول' : 'غير مسجل',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),n            const SizedBox(height: 20),
            if (isClockedIn)
              Text(
                'الوقت المعمل: ${workedTime.inHours}:${(workedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(workedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: isClockedIn ? clockOut : clockIn,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: const TextStyle(fontSize: 20),
              ),
              child: Text(isClockedIn ? 'تسجيل خروج' : 'تسجيل دخول'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'التاريخ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'التقرير الشهري',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              Navigator.pushNamed(context, '/history');
              break;
            case 2:
              Navigator.pushNamed(context, '/monthly');
              break;
          }
        },
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تاريخ التسجيلات'),
      ),
      body: FutureBuilder<List<TimeRecord>>(
        future: loadRecords(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final records = snapshot.data!;
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                title: Text('${record.date.day}/${record.date.month}/${record.date.year}'),
                subtitle: Text(
                  'دخول: ${record.clockIn?.hour ?? '--'}:${record.clockIn?.minute.toString().padLeft(2, '0') ?? '--'} | '
                  'خروج: ${record.clockOut?.hour ?? '--'}:${record.clockOut?.minute.toString().padLeft(2, '0') ?? '--'} | '
                  'الأجر اليومي: ${record.dailyWage.toStringAsFixed(2)}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<TimeRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('records') ?? [];
    return recordsJson.map((json) => TimeRecord.fromJson(jsonDecode(json))).toList();
  }
}

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير الشهري'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: calculateMonthlyReport(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final report = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي الساعات: ${report['totalHours'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
                Text('ساعات إضافية: ${report['totalOvertime'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
                Text('إجمالي الأجر: ${report['totalWage'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> calculateMonthlyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('records') ?? [];
    final records = recordsJson.map((json) => TimeRecord.fromJson(jsonDecode(json))).toList();
    
    final now = DateTime.now();
    final monthRecords = records.where((r) => r.date.month == now.month && r.date.year == now.year);
    
    double totalHours = 0;
    double totalOvertime = 0;
    double totalWage = 0;
    
    for (final record in monthRecords) {
      totalHours += record.hoursWorked;
      totalOvertime += record.overtimeHours;
      totalWage += record.dailyWage;
    }
    
    return {
      'totalHours': totalHours,
      'totalOvertime': totalOvertime,
      'totalWage': totalWage,
    };
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double hourlyRate = 10.0;
  double overtimeRate = 15.0;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hourlyRate = prefs.getDouble('hourlyRate') ?? 10.0;
      overtimeRate = prefs.getDouble('overtimeRate') ?? 15.0;
    });
  }

  void saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hourlyRate', hourlyRate);
    await prefs.setDouble('overtimeRate', overtimeRate);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'الأجر بالساعة'),
              keyboardType: TextInputType.number,
              onChanged: (value) => hourlyRate = double.tryParse(value) ?? 10.0,
              controller: TextEditingController(text: hourlyRate.toString()),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'الأجر للساعات الإضافية'),
              keyboardType: TextInputType.number,
              onChanged: (value) => overtimeRate = double.tryParse(value) ?? 15.0,
              controller: TextEditingController(text: overtimeRate.toString()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveSettings,
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}