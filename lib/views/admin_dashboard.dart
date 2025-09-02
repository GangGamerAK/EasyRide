import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/session_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _verifiedDrivers = [];
  bool _loading = true;
  String? _error;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = FirebaseService.firestore.collection('users');
      final snapshot = await users.where('role', isEqualTo: 'driver').get();
      
      final drivers = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        drivers.add({
          'id': doc.id,
          ...data,
        });
      }

      // Separate drivers into pending and verified
      final pendingDrivers = <Map<String, dynamic>>[];
      final verifiedDrivers = <Map<String, dynamic>>[];
      
      for (final driver in drivers) {
        if (driver['isVerified'] == true) {
          verifiedDrivers.add(driver);
        } else {
          pendingDrivers.add(driver);
        }
      }

      setState(() {
        _drivers = drivers;
        _pendingDrivers = pendingDrivers;
        _verifiedDrivers = verifiedDrivers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await SessionService.clearSession();
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Driver Details: ${driver['name'] ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Name', driver['name'] ?? 'N/A'),
              _buildInfoRow('Email', driver['email'] ?? 'N/A'),
              _buildInfoRow('Phone', driver['number'] ?? 'N/A'),
              _buildInfoRow('CNIC', driver['cnic'] ?? 'N/A'),
              if (driver['licenseNumber'] != null)
                _buildInfoRow('License Number', driver['licenseNumber']),
              const SizedBox(height: 16),
              // Verification Status
              Row(
                children: [
                  const Text('Verification Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: driver['isVerified'] == true ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      driver['isVerified'] == true ? 'Verified' : 'Pending',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (driver['profileImageUrl'] != null) ...[
                const Text('Profile Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      driver['profileImageUrl'],
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        width: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (driver['cnicImageUrl'] != null) ...[
                const Text('CNIC Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: 250,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      driver['cnicImageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (driver['licenseImageUrl'] != null) ...[
                const Text('Driver License Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: 250,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      driver['licenseImageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (driver['isVerified'] != true) ...[
            ElevatedButton(
              onPressed: () => _verifyDriver(driver['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify Driver'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => _resetDriverVerification(driver['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Verification'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyDriver(String driverId) async {
    try {
      await FirebaseService.firestore
          .collection('users')
          .doc(driverId)
          .update({'isVerified': true});
      
      // Refresh the drivers list
      await _loadDrivers();
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetDriverVerification(String driverId) async {
    try {
      await FirebaseService.resetDriverVerification(driverId);
      
      // Refresh the drivers list
      await _loadDrivers();
      
      // Close the dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver verification reset successfully! Driver can now edit documents.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting driver verification: $e'),
          backgroundColor: Colors.red,
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF181818),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDrivers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Tabs
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTabIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 0 ? Colors.orange : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Pending (${_pendingDrivers.length})',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 0 ? Colors.white : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTabIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 1 ? Colors.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Verified (${_verifiedDrivers.length})',
                                    style: TextStyle(
                                      color: _selectedTabIndex == 1 ? Colors.white : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Driver List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadDrivers,
                        child: _selectedTabIndex == 0
                            ? _buildDriverList(_pendingDrivers, 'No pending drivers')
                            : _buildDriverList(_verifiedDrivers, 'No verified drivers'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDriverList(List<Map<String, dynamic>> drivers, String emptyMessage) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTabIndex == 0 ? Icons.pending : Icons.verified_user,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: driver['profileImageUrl'] != null
                  ? NetworkImage(driver['profileImageUrl'])
                  : null,
              child: driver['profileImageUrl'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    driver['name'] ?? 'Unknown Driver',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Verification Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: driver['isVerified'] == true ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    driver['isVerified'] == true ? '✓' : '⏳',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver['email'] ?? driver['number'] ?? 'No contact'),
                if (driver['cnic'] != null)
                  Text('CNIC: ${driver['cnic']}'),
                if (driver['licenseNumber'] != null)
                  Text('License: ${driver['licenseNumber']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (driver['cnicImageUrl'] != null)
                  const Icon(Icons.credit_card, color: Colors.green),
                if (driver['licenseImageUrl'] != null)
                  const Icon(Icons.drive_file_rename_outline, color: Colors.blue),
              ],
            ),
            onTap: () => _showDriverDetails(driver),
          ),
        );
      },
    );
  }
} 