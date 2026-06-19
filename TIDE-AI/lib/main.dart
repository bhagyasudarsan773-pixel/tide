import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // REQUIRED: Added Google Fonts package
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure Flutter binding is initialized for SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TideApp());
}

// ----------------------------------------------------------------------
// STATE MANAGEMENT & MODELS
// ----------------------------------------------------------------------
class Task {
  final String id;
  final String title;
  final String category;
  final String priority;
  bool isCompleted;
  final DateTime date;

  Task({
    required this.title,
    required this.category,
    required this.priority,
    this.isCompleted = false,
    String? id,
    DateTime? date,
  })  : id = id ?? UniqueKey().toString(),
        date = date ?? DateTime.now();

  // Used for priority dot
  Color get dotColor {
    if (isCompleted) return Colors.transparent;
    switch (priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return appState.primaryColor;
      default:
        return Colors.teal;
    }
  }

  // Used for Color-Coded Category Chips (+200 XP requirement)
  Color get categoryColor {
    switch (category) {
      case 'Work':
        return Colors.blueAccent;
      case 'Personal':
        return Colors.green;
      case 'Study':
        return Colors.purpleAccent;
      default:
        return appState.primaryColor;
    }
  }

  // Convert Task to JSON for Shared Preferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
    };
  }

  // Create Task from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'] ?? '',
      category: json['category'] ?? 'Work',
      priority: json['priority'] ?? 'Medium',
      isCompleted: json['isCompleted'] ?? false,
      id: json['id'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }
}

class AppState extends ChangeNotifier {
  bool isDarkMode = false;
  String userName = 'Sarah';
  String profilePicUrl =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=60';
  List<Task> tasks = [];
  bool isLoading = true;

  AppState() {
    _loadData();
  }

  // Load Tasks, Theme, Username, and Avatar from SharedPreferences
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      userName = prefs.getString('userName') ?? 'Sarah';
      profilePicUrl = prefs.getString('profilePicUrl') ??
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=60';

      final tasksString = prefs.getString('tasks');
      if (tasksString != null) {
        final List<dynamic> decoded = jsonDecode(tasksString);
        tasks = decoded.map((item) => Task.fromJson(item)).toList();
      } else {
        _loadDefaultTasks();
      }
    } catch (e) {
      _loadDefaultTasks();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _loadDefaultTasks() {
    tasks = [
      Task(
          title: 'Review Q3 Shoreline Strategy',
          category: 'Study',
          priority: 'High'),
      Task(
          title: 'Approve design system tokens',
          category: 'Work',
          priority: 'Medium',
          isCompleted: true),
      Task(
          title: 'Weekly deep focus block',
          category: 'Personal',
          priority: 'Low'),
    ];
  }

  // Save Tasks list to SharedPreferences
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
      await prefs.setString('tasks', encoded);
    } catch (e) {
      // Quietly fail
    }
  }

  // Save Username to SharedPreferences
  Future<void> updateUserName(String name) async {
    userName = name;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', userName);
    } catch (e) {
      // Quietly fail
    }
  }

  // Save Profile Picture to SharedPreferences
  Future<void> updateProfilePic(String url) async {
    profilePicUrl = url;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profilePicUrl', profilePicUrl);
    } catch (e) {
      // Quietly fail
    }
  }

  // Toggle Theme and save setting
  Future<void> toggleTheme() async {
    isDarkMode = !isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
    } catch (e) {
      // Quietly fail
    }
  }

  Color get primaryColor => isDarkMode
      ? const Color(0xFF4DB6AC)
      : const Color(0xFF006B5F); // Figma Palette (+100 XP)
  Color get textColor => isDarkMode ? Colors.white : Colors.black87;
  Color get subTextColor => isDarkMode ? Colors.white60 : Colors.black54;
  Color get cardColor => isDarkMode
      ? Colors.black.withOpacity(0.4)
      : Colors.white.withOpacity(0.4);
  String get bgImage => isDarkMode
      ? 'https://images.unsplash.com/photo-1505142468610-359e7d316be0?auto=format&fit=crop&w=800&q=80'
      : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80';

  int get ongoingCount => tasks.where((t) => !t.isCompleted).length;
  int get finishedCount => tasks.where((t) => t.isCompleted).length;
  double get completionPercentage =>
      tasks.isEmpty ? 0 : (finishedCount / tasks.length);

  void addTask(String title, String priority, String category) {
    tasks.insert(0, Task(title: title, priority: priority, category: category));
    _saveTasks();
    notifyListeners();
  }

  void insertTask(int index, Task task) {
    tasks.insert(index, task);
    _saveTasks();
    notifyListeners();
  }

  void toggleTask(String id) {
    final taskIndex = tasks.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      tasks[taskIndex].isCompleted = !tasks[taskIndex].isCompleted;
      _saveTasks();
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }
}

final AppState appState = AppState();

// ----------------------------------------------------------------------
// APP SHELL (Google Fonts Theme)
// ----------------------------------------------------------------------
class TideApp extends StatelessWidget {
  const TideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, child) {
          // Apply Google Fonts dynamically based on theme
          final textTheme = appState.isDarkMode
              ? GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
              : GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Tide',
            theme: ThemeData(
              textTheme: textTheme, // Google Fonts package (+100 XP)
              brightness:
                  appState.isDarkMode ? Brightness.dark : Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: appState.primaryColor,
                brightness:
                    appState.isDarkMode ? Brightness.dark : Brightness.light,
              ),
            ),
            home: const SplashLoginScreen(),
          );
        });
  }
}

// ----------------------------------------------------------------------
// SHARED WIDGETS
// ----------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  final Widget child;
  final double padding;

  const GlassCard({super.key, required this.child, this.padding = 20.0});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: appState.cardColor,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: child,
              ),
            ),
          );
        });
  }
}

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) => Container(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      image: NetworkImage(appState.bgImage),
                      fit: BoxFit.cover)),
              child: child,
            ));
  }
}

class TopBar extends StatelessWidget {
  final String? title;
  const TopBar({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(appState.profilePicUrl)),
                  if (title != null) ...[
                    const SizedBox(width: 12),
                    Text(title!,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: appState.primaryColor))
                  ],
                ],
              ),
              Icon(Icons.notifications_none, color: appState.primaryColor),
            ],
          );
        });
  }
}

// Helper function to build Dismissible Task List Item (Reusable)
Widget buildDismissibleTask(BuildContext context, Task task) {
  return Dismissible(
    key: Key(task.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: const Icon(Icons.delete, color: Colors.white),
    ),
    onDismissed: (direction) {
      final removedIndex = appState.tasks.indexOf(task);
      appState.deleteTask(task.id);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${task.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              appState.insertTask(removedIndex, task);
            },
          ),
        ),
      );
    },
    child: TaskListItem(task: task),
  );
}

// ----------------------------------------------------------------------
// 1. SPLASH / LOGIN (with Username Field & Verification)
// ----------------------------------------------------------------------
class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({super.key});

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Populate username field with stored username initially
    _nameController.text = appState.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedBuilder(
                  animation: appState,
                  builder: (context, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: appState.cardColor,
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.waves,
                              color: appState.primaryColor, size: 40),
                        ),
                        const SizedBox(height: 10),
                        Text('Tide',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: appState.primaryColor,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 40),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Welcome Back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: appState.primaryColor)),
                              const SizedBox(height: 8),
                              Text('Sign in to access your dashboard',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: appState.textColor)),
                              const SizedBox(height: 24),

                              // Username Field
                              TextField(
                                controller: _nameController,
                                style: TextStyle(color: appState.textColor),
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: appState.cardColor,
                                    hintText: 'Username',
                                    hintStyle:
                                        TextStyle(color: appState.subTextColor),
                                    prefixIcon: Icon(Icons.person_outline,
                                        color: appState.subTextColor),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none)),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _emailController,
                                style: TextStyle(color: appState.textColor),
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: appState.cardColor,
                                    hintText: 'Email Address',
                                    hintStyle:
                                        TextStyle(color: appState.subTextColor),
                                    prefixIcon: Icon(Icons.email_outlined,
                                        color: appState.subTextColor),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none)),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: TextStyle(color: appState.textColor),
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: appState.cardColor,
                                    hintText: 'Password',
                                    hintStyle:
                                        TextStyle(color: appState.subTextColor),
                                    prefixIcon: Icon(Icons.lock_outline,
                                        color: appState.subTextColor),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none)),
                              ),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: () {},
                                      child: Text('Forgot Password?',
                                          style: TextStyle(
                                              color: appState.primaryColor)))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: appState.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: () {
                                  final name = _nameController.text.trim();
                                  final email = _emailController.text.trim();
                                  final password =
                                      _passwordController.text.trim();

                                  if (name.isEmpty ||
                                      email.isEmpty ||
                                      password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Please enter all your details'),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    );
                                    return;
                                  }

                                  appState.updateUserName(name);
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const MainDashboard()));
                                },
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Sign In',
                                          style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 20)
                                    ]),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: appState.cardColor,
                                    side: const BorderSide(
                                        color: Colors.transparent),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12)),
                                onPressed: () {},
                                icon: Icon(Icons.g_mobiledata,
                                    color: appState.textColor),
                                label: Text('Continue with Google',
                                    style:
                                        TextStyle(color: appState.textColor)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. MAIN DASHBOARD
// ----------------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TaskStreamScreen(),
    const CalendarScreen(),
    const FocusScreen(),
    const ProfileScreen(),
  ];

  void _showAddTaskModal() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const AddTaskModal());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return Scaffold(
            extendBody: true,
            body: BackgroundWrapper(child: _screens[_currentIndex]),
            floatingActionButton: _currentIndex != 3
                ? FloatingActionButton(
                    backgroundColor: appState.primaryColor,
                    onPressed: _showAddTaskModal,
                    child: const Icon(Icons.add, color: Colors.white))
                : null,
            bottomNavigationBar: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                    backgroundColor: appState.isDarkMode
                        ? Colors.black.withOpacity(0.6)
                        : Colors.white.withOpacity(0.7),
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: appState.primaryColor,
                    unselectedItemColor: appState.subTextColor,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    selectedFontSize: 10,
                    unselectedFontSize: 10,
                    elevation: 0,
                    items: const [
                      BottomNavigationBarItem(
                          icon: Icon(Icons.home_filled), label: 'Home'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.list_alt), label: 'Tasks'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.calendar_today), label: 'Calendar'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.timelapse), label: 'Focus'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline), label: 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}

// ----------------------------------------------------------------------
// 3. HOME SCREEN (Shows dynamic username greeting)
// ----------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const TopBar(),
                  const SizedBox(height: 24),

                  // Dynamic greeting based on userName
                  Text('Good afternoon, ${appState.userName}',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: appState.primaryColor)),

                  Text('The tide is with you today.',
                      style:
                          TextStyle(fontSize: 14, color: appState.textColor)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: StatCard(
                              number: '${appState.ongoingCount}',
                              label: 'Ongoing')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: StatCard(
                              number: '${appState.finishedCount}',
                              label: 'Finished')),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: appState.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: appState.primaryColor, width: 3)),
                        child: Text(
                            '${(appState.completionPercentage * 100).toInt()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: appState.textColor)),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text("Today's Waves",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: appState.primaryColor)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: appState.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: appState.primaryColor))
                        : appState.tasks.isEmpty
                            ? Center(
                                child: Text("No tasks! You're caught up.",
                                    style:
                                        TextStyle(color: appState.textColor)))
                            : ListView.builder(
                                itemCount: appState.tasks.length,
                                itemBuilder: (context, index) =>
                                    buildDismissibleTask(
                                        context, appState.tasks[index])),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class StatCard extends StatelessWidget {
  final String number;
  final String label;
  const StatCard({super.key, required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: 16,
      child: Column(
        children: [
          Text(number,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appState.primaryColor)),
          Text(label, style: TextStyle(fontSize: 12, color: appState.textColor))
        ],
      ),
    );
  }
}

// Modified TaskListItem to show Color-Coded Category Chips
class TaskListItem extends StatelessWidget {
  final Task task;
  const TaskListItem({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              padding: 16,
              child: InkWell(
                onTap: () => appState.toggleTask(task.id),
                child: Row(
                  children: [
                    Icon(
                        task.isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: task.isCompleted
                            ? appState.primaryColor
                            : appState.subTextColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? appState.subTextColor
                                      : appState.textColor)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Color-Coded Category Chip (+200 XP requirement)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: task.categoryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: task.categoryColor
                                            .withOpacity(0.5))),
                                child: Text(task.category,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: task.categoryColor)),
                              ),
                              const SizedBox(width: 8),
                              Text('${task.priority} Priority',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: appState.subTextColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!task.isCompleted)
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: task.dotColor))
                  ],
                ),
              ),
            ),
          );
        });
  }
}

// ----------------------------------------------------------------------
// 4. TASK STREAM SCREEN (Filters by Category & Search Matching)
// ----------------------------------------------------------------------
class TaskStreamScreen extends StatefulWidget {
  const TaskStreamScreen({super.key});

  @override
  State<TaskStreamScreen> createState() => _TaskStreamScreenState();
}

class _TaskStreamScreenState extends State<TaskStreamScreen> {
  String selectedFilter = 'All Tasks';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          var filteredTasks = appState.tasks;
          if (selectedFilter != 'All Tasks') {
            filteredTasks = appState.tasks
                .where((t) => t.category == selectedFilter)
                .toList();
          }

          if (searchQuery.isNotEmpty) {
            filteredTasks = filteredTasks
                .where((t) =>
                    t.title.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const TopBar(title: 'Tasks'),
                  const SizedBox(height: 16),

                  // Real-time Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val;
                      });
                    },
                    style: TextStyle(color: appState.textColor),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: appState.subTextColor),
                      prefixIcon:
                          Icon(Icons.search, color: appState.primaryColor),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: appState.subTextColor),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: appState.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Tasks', Colors.white),
                        _buildFilterChip('Work', Colors.blueAccent),
                        _buildFilterChip('Personal', Colors.green),
                        _buildFilterChip('Study', Colors.purpleAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: appState.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: appState.primaryColor))
                        : filteredTasks.isEmpty
                            ? Center(
                                child: Text(
                                    searchQuery.isNotEmpty
                                        ? "No matching tasks found."
                                        : "No tasks in this category.",
                                    style:
                                        TextStyle(color: appState.textColor)))
                            : ListView.builder(
                                itemCount: filteredTasks.length,
                                itemBuilder: (context, index) =>
                                    buildDismissibleTask(
                                        context, filteredTasks[index])),
                  )
                ],
              ),
            ),
          );
        });
  }

  Widget _buildFilterChip(String label, Color colorTag) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorTag : appState.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? colorTag : colorTag.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : appState.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 5. CALENDAR SCREEN
// ----------------------------------------------------------------------
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int currentDay = now.day;
    int firstDayWeekday = DateTime(now.year, now.month, 1).weekday;
    int offset = firstDayWeekday == 7 ? 0 : firstDayWeekday;

    List<String> months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    String monthName = months[now.month - 1];
    List<String> daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const TopBar(title: 'Calendar'),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: 16,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(monthName,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: appState.textColor)),
                            Row(children: [
                              Icon(Icons.chevron_left,
                                  color: appState.subTextColor),
                              Icon(Icons.chevron_right,
                                  color: appState.subTextColor)
                            ])
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: daysOfWeek
                              .map((day) => Text(day,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: appState.subTextColor)))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7, childAspectRatio: 1.2),
                          itemCount: daysInMonth + offset,
                          itemBuilder: (context, index) {
                            if (index < offset) return Container();
                            int day = index - offset + 1;
                            bool isToday = day == currentDay;
                            return Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: isToday
                                      ? appState.primaryColor
                                      : Colors.transparent,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                      color: isToday
                                          ? Colors.white
                                          : appState.textColor,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today, $currentDay",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: appState.textColor)),
                      Text("${appState.tasks.length} Tasks",
                          style: TextStyle(color: appState.subTextColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: appState.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: appState.primaryColor))
                        : appState.tasks.isEmpty
                            ? Center(
                                child: Text("No tasks for today.",
                                    style:
                                        TextStyle(color: appState.textColor)))
                            : ListView.builder(
                                itemCount: appState.tasks.length,
                                itemBuilder: (context, index) =>
                                    buildDismissibleTask(
                                        context, appState.tasks[index])),
                  )
                ],
              ),
            ),
          );
        });
  }
}

// ----------------------------------------------------------------------
// 6. FOCUS SCREEN
// ----------------------------------------------------------------------
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const int defaultTime = 25 * 60;
  int timeLeft = defaultTime;
  Timer? timer;
  bool isRunning = false;

  void startTimer() {
    setState(() => isRunning = true);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        stopTimer();
      }
    });
  }

  void stopTimer() {
    timer?.cancel();
    setState(() => isRunning = false);
  }

  void resetTimer() {
    stopTimer();
    setState(() => timeLeft = defaultTime);
  }

  String get timerText {
    int minutes = timeLeft ~/ 60;
    int seconds = timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Deep Work',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: appState.primaryColor)),
                  Text('Focus on the Tide',
                      style:
                          TextStyle(fontSize: 16, color: appState.textColor)),
                  const SizedBox(height: 60),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: appState.primaryColor.withOpacity(0.3),
                                  width: 10),
                              color: appState.cardColor)),
                      Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: appState.primaryColor, width: 6)),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(timerText,
                                  style: TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: appState.primaryColor)),
                              Text(isRunning ? 'In Flow State' : 'Paused',
                                  style: TextStyle(color: appState.textColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.refresh, size: 30),
                          color: appState.primaryColor,
                          onPressed: resetTimer),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: isRunning ? stopTimer : startTimer,
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: appState.primaryColor),
                            child: Icon(
                                isRunning ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32)),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                          icon: const Icon(Icons.stop, size: 30),
                          color: appState.primaryColor,
                          onPressed: resetTimer),
                    ],
                  )
                ],
              ),
            ),
          );
        });
  }
}

// ----------------------------------------------------------------------
// 7. PROFILE SCREEN (Shows dynamic username & supports editing & avatars)
// ----------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: appState.userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appState.isDarkMode ? Colors.grey[900] : Colors.white,
        title:
            Text('Edit Username', style: TextStyle(color: appState.textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: appState.textColor),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: appState.subTextColor),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: appState.primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: TextStyle(color: appState.subTextColor)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                appState.updateUserName(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('Save',
                style: TextStyle(
                    color: appState.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAvatarSelectionDialog(BuildContext context) {
    final List<String> avatars = [
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=60',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=60',
    ];

    final customUrlController =
        TextEditingController(text: appState.profilePicUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appState.isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text('Select Profile Picture',
            style: TextStyle(color: appState.textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final url = avatars[index];
                  return GestureDetector(
                    onTap: () {
                      appState.updateProfilePic(url);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appState.profilePicUrl == url
                              ? appState.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(url),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Or paste a custom image URL:',
                  style: TextStyle(fontSize: 12, color: appState.subTextColor)),
              const SizedBox(height: 8),
              TextField(
                controller: customUrlController,
                style: TextStyle(color: appState.textColor),
                decoration: InputDecoration(
                  hintText: 'https://example.com/avatar.jpg',
                  hintStyle: TextStyle(color: appState.subTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: appState.primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: TextStyle(color: appState.subTextColor)),
          ),
          TextButton(
            onPressed: () {
              if (customUrlController.text.trim().isNotEmpty) {
                appState.updateProfilePic(customUrlController.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('Save Custom',
                style: TextStyle(
                    color: appState.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.arrow_back, color: appState.primaryColor),
                          Text('Tide',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: appState.primaryColor)),
                          Icon(Icons.more_vert, color: appState.subTextColor)
                        ]),
                    const SizedBox(height: 20),
                    GlassCard(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showAvatarSelectionDialog(context),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                    radius: 40,
                                    backgroundImage:
                                        NetworkImage(appState.profilePicUrl)),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: appState.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 14, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Dynamic Name and Edit Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(appState.userName,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: appState.primaryColor)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit,
                                    size: 18, color: appState.primaryColor),
                                onPressed: () => _showEditNameDialog(context),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: appState.cardColor,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('Tide Member',
                                  style: TextStyle(
                                      color: appState.primaryColor,
                                      fontSize: 12)))
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Settings',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: appState.primaryColor))),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: 10,
                      child: Column(
                        children: [
                          ListTile(
                              leading: Icon(
                                  appState.isDarkMode
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  color: appState.primaryColor),
                              title: Text('App Theme',
                                  style: TextStyle(color: appState.textColor)),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(appState.isDarkMode ? 'Dark' : 'Light',
                                        style: TextStyle(
                                            color: appState.subTextColor)),
                                    Icon(Icons.chevron_right,
                                        color: appState.subTextColor)
                                  ]),
                              onTap: () => appState.toggleTheme()),
                          Divider(
                              height: 1, color: Colors.white.withOpacity(0.2)),
                          ListTile(
                              leading: const Icon(Icons.logout,
                                  color: Colors.redAccent),
                              title: const Text('Sign Out',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                              onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SplashLoginScreen()))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          );
        });
  }
}

// ----------------------------------------------------------------------
// 8. ADD TASK BOTTOM SHEET (WITH CATEGORY DROPDOWN)
// ----------------------------------------------------------------------
class AddTaskModal extends StatefulWidget {
  const AddTaskModal({super.key});

  @override
  State<AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> {
  final TextEditingController _titleController = TextEditingController();
  String selectedPriority = 'Medium';
  String selectedCategory = 'Work'; // Default category

  void _submitTask() {
    if (_titleController.text.trim().isEmpty) return;
    appState.addTask(
        _titleController.text.trim(), selectedPriority, selectedCategory);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: appState.isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          top: 20,
          left: 24,
          right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: Icon(Icons.close, color: appState.textColor),
                  onPressed: () => Navigator.pop(context)),
              Text('NEW TASK',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: appState.subTextColor)),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: appState.textColor),
            decoration: InputDecoration(
                hintText: 'What are you working on?',
                border: InputBorder.none,
                hintStyle:
                    TextStyle(color: appState.subTextColor.withOpacity(0.3))),
          ),
          const SizedBox(height: 20),
          Text('PRIORITY',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appState.subTextColor)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildPriorityChip('High', Colors.redAccent)),
              const SizedBox(width: 8),
              Expanded(child: _buildPriorityChip('Medium', Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildPriorityChip('Low', appState.primaryColor)),
            ],
          ),
          const SizedBox(height: 20),
          Text('CATEGORY',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appState.subTextColor)),
          const SizedBox(height: 10),

          // Category Dropdown (+200 XP requirement)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: appState.subTextColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                dropdownColor:
                    appState.isDarkMode ? Colors.grey[850] : Colors.white,
                icon: Icon(Icons.arrow_drop_down, color: appState.primaryColor),
                items: ['Work', 'Personal', 'Study'].map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category,
                        style: TextStyle(
                            color: appState.textColor,
                            fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => selectedCategory = newValue);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: appState.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              onPressed: _submitTask,
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: const Text('Add Task',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    bool isSelected = selectedPriority == label;
    return GestureDetector(
      onTap: () => setState(() => selectedPriority = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.black12),
            borderRadius: BorderRadius.circular(12)),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12))),
      ),
    );
  }
}
