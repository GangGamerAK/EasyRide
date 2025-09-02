import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'passenger/passenger_view.dart';
import 'passenger/passenger_home_view.dart';
import 'views/welcome_view.dart';
import 'views/profile_view.dart';
import 'driver/driver_home_view.dart';
import 'services/firebase_service.dart';
import 'services/session_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'views/profile_creation_view.dart';
import 'views/admin_dashboard.dart';
import 'views/admin_creation_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('mapStore').manage.create();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Route Setup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WelcomeView(),
      routes: {
        '/main': (context) => const HomeView(userData: null),
        '/admin/create': (context) => const AdminCreationView(),
      },
    );
  }
}

class HomeView extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomeView({super.key, this.userData});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  Map<String, dynamic>? profile;
  bool loading = true;
  bool sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    // Use the passed user data or try to get from session
    String? userId;
    if (widget.userData != null) {
      userId = widget.userData!['email'] ?? widget.userData!['number'];
    }
    
    // If no user data passed, try to get from session
    if (userId == null || userId.isEmpty) {
      userId = await SessionService.getUserId();
    }
    
    // If still no userId, show error or redirect to login
    if (userId == null || userId.isEmpty) {
      setState(() { 
        loading = false; 
        profile = null;
      });
      return;
    }

    final users = FirebaseService.firestore.collection('users');
    final snap = await users.where('email', isEqualTo: userId).get();
    if (snap.docs.isEmpty) {
      // Try searching by number if email search failed
      final snap2 = await users.where('number', isEqualTo: userId).get();
      if (snap2.docs.isNotEmpty) {
        final data = snap2.docs.first.data();
        setState(() {
          profile = data;
          loading = false;
        });
      } else {
        setState(() { 
          loading = false; 
          profile = null;
        });
      }
    } else {
      final data = snap.docs.first.data();
      setState(() {
        profile = data;
        loading = false;
      });
    }
  }

  Future<void> _addOrEditImage(String type) async {
    // type: 'cnic' or 'license'
    // Use image_picker for Android
    dynamic image;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) image = File(picked.path);
    if (image != null) {
      final url = await FirebaseService.uploadImageToImgbb(image);
      final users = FirebaseService.firestore.collection('users');
      final userId = profile?['email'] ?? profile?['number'] ?? 'demo@user.com';
      final snap = await users.where('email', isEqualTo: userId).get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first.reference;
        await doc.update({
          if (type == 'cnic') 'cnicImageUrl': url,
          if (type == 'license') 'licenseImageUrl': url,
        });
        _fetchProfile();
      }
    }
  }

  void _toggleSidebar() {
    setState(() {
      sidebarCollapsed = !sidebarCollapsed;
    });
  }

  Future<void> _handleLogout() async {
    // Clear the session
    await SessionService.clearSession();
    
    // Clear the profile data
    setState(() {
      profile = null;
    });
    
    // Navigate back to welcome view
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;
        
        // If user is a driver, show driver home view
        if (profile != null && profile!['role'] == 'driver') {
          return DriverHomeView(
            driverId: profile!['email'] ?? profile!['number'] ?? '',
            driverName: profile!['name'] ?? 'Driver',
            profile: profile,
          );
        }
        
        // If user is a passenger, show passenger home view
        if (profile != null && profile!['role'] == 'passenger') {
          return PassengerHomeView(
            passengerId: profile!['email'] ?? profile!['number'] ?? '',
            passengerName: profile!['name'] ?? 'Passenger',
            profile: profile,
          );
        }
        
        // If user is an admin, show admin dashboard
        if (profile != null && profile!['role'] == 'admin') {
          return const AdminDashboard();
        }
        
        // Show loading or error state
        if (loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (profile == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Profile Not Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Please log in to access your profile', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await SessionService.clearSession();
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // Fallback: if profile exists but role is missing or invalid, redirect to profile creation
        if (profile != null && (profile!['role'] != 'driver' && profile!['role'] != 'passenger' && profile!['role'] != 'admin')) {
          // Only redirect if not already on ProfileCreationView
          Future.microtask(() {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ProfileCreationView(userId: profile!['email'] ?? profile!['number'] ?? '')),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If we reach here, something went wrong with role detection
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Invalid User Role', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Role: ${profile?['role'] ?? 'Unknown'}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}
