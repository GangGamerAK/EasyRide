import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/firebase_service.dart';
import '../services/session_service.dart';
import '../main.dart';
import 'package:flutter/foundation.dart';

class ProfileCreationView extends StatefulWidget {
  final String userId; // email or number
  const ProfileCreationView({super.key, required this.userId});

  @override
  State<ProfileCreationView> createState() => _ProfileCreationViewState();
}

class _ProfileCreationViewState extends State<ProfileCreationView> with TickerProviderStateMixin {
  String? role; // 'driver' or 'passenger'
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  dynamic _profileImage; // File (mobile) or Uint8List (web)
  dynamic _cnicImage;
  dynamic _licenseImage;
  bool _loading = false;
  String? _error;
  
  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _formController;
  late Animation<double> _headerAnimation;
  late Animation<double> _formAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.elasticOut,
    );
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    );
    
    // Start animations
    _headerController.forward();
    _formController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(dynamic) setter) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setter(File(picked.path)); // File for Android
    setState(() {});
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _profileImage == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      String? profileUrl, cnicUrl, licenseUrl;
      profileUrl = await FirebaseService.uploadImageToImgbb(_profileImage);
      if (_cnicImage != null) {
        cnicUrl = await FirebaseService.uploadImageToImgbb(_cnicImage);
      }
      if (_licenseImage != null) {
        licenseUrl = await FirebaseService.uploadImageToImgbb(_licenseImage);
      }
      await FirebaseService.saveUserProfile(
        userId: widget.userId,
        role: role!,
        name: _nameController.text.trim(),
        cnic: _cnicController.text.trim(),
        profileImageUrl: profileUrl!,
        cnicImageUrl: cnicUrl,
        licenseNumber: role == 'driver' ? _licenseController.text.trim() : null,
        licenseImageUrl: licenseUrl,
      );
      
      // Create user data map to pass to HomeView
      final userData = {
        'email': widget.userId.contains('@') ? widget.userId : null,
        'number': widget.userId.contains('@') ? null : widget.userId,
        'role': role,
        'name': _nameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'profileImageUrl': profileUrl,
        'cnicImageUrl': cnicUrl,
        'licenseNumber': role == 'driver' ? _licenseController.text.trim() : null,
        'licenseImageUrl': licenseUrl,
      };
      
      // Save updated session with profile data
      await SessionService.saveSession(
        userId: widget.userId,
        userData: userData,
      );
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeView(userData: userData)),
      );
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF181818),
              Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
                
              // Top logo and welcome text
                FadeTransition(
                  opacity: _headerAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_headerAnimation),
                    child: Column(
                      children: [
              Container(
                          width: 120,
                          height: 120,
                decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2A2A2A),
                                Color(0xFF1A1A1A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                ),
                child: const Icon(
                  Icons.person,
                            size: 60,
                  color: Colors.white,
                ),
              ),
                        const SizedBox(height: 32),
              Text(
                'Profile Creation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                            fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
                        const SizedBox(height: 12),
              Text(
                'Complete your profile to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                            fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Main form container
                FadeTransition(
                  opacity: _formAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_formAnimation),
                    child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF232323),
                            Color(0xFF1A1A1A),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                    BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: role == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                                Text(
                                  'Are you a driver or passenger?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                _buildRoleButton(
                                  title: 'Driver',
                                  icon: Icons.directions_car,
                              onPressed: () => setState(() => role = 'driver'),
                                ),
                                const SizedBox(height: 16),
                                _buildRoleButton(
                                  title: 'Passenger',
                                  icon: Icons.person,
                              onPressed: () => setState(() => role = 'passenger'),
                            ),
                                const SizedBox(height: 16),
                          // Admin option - only show for specific emails or add a secret code
                          if (widget.userId.contains('admin') || widget.userId == 'admin@easyride.com')
                                  _buildRoleButton(
                                    title: 'Admin',
                                    icon: Icons.admin_panel_settings,
                                    onPressed: () => setState(() => role = 'admin'),
                                    isAdmin: true,
                            ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                                  // Profile Image Section
                                  _buildImageUploadSection(
                                    title: 'Profile Image',
                                    subtitle: 'Tap to upload your profile photo',
                                    isRequired: true,
                                    image: _profileImage,
                                    onTap: () => _pickImage((f) => _profileImage = f),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Name Field
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Name on CNIC',
                                    icon: Icons.person_outline,
                                    validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                            ),
                            const SizedBox(height: 16),
                                  
                                  // CNIC Field
                                  _buildTextField(
                              controller: _cnicController,
                                    label: 'CNIC (13 digits)',
                                    icon: Icons.credit_card,
                              keyboardType: TextInputType.number,
                              maxLength: 13,
                              validator: (v) => v == null || v.length != 13 ? 'Enter 13 digit CNIC' : null,
                            ),
                                  const SizedBox(height: 20),
                                  
                                  // CNIC Image Upload
                                  _buildImageUploadSection(
                                    title: 'CNIC Image',
                                    subtitle: 'Upload CNIC image (optional)',
                                    isRequired: false,
                                    image: _cnicImage,
                                    onTap: () => _pickImage((f) => _cnicImage = f),
                                  ),
                                  
                            // Only show license fields for drivers
                            if (role == 'driver') ...[
                                    const SizedBox(height: 20),
                                    _buildTextField(
                                controller: _licenseController,
                                      label: 'Driver License Number',
                                      icon: Icons.drive_eta,
                                validator: (v) => v == null || v.isEmpty ? 'Enter license number' : null,
                              ),
                                    const SizedBox(height: 20),
                                    _buildImageUploadSection(
                                      title: 'License Image',
                                      subtitle: 'Upload license image (optional)',
                                      isRequired: false,
                                      image: _licenseImage,
                                      onTap: () => _pickImage((f) => _licenseImage = f),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Error Message
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.shade900.withOpacity(0.8),
                                            Colors.red.shade800.withOpacity(0.6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade700),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red.shade300,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(
                                                color: Colors.red.shade100,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  // Validation status
                                  if (_profileImage == null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.withOpacity(0.2),
                                            Colors.orange.withOpacity(0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: Row(
                                          children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Please upload a profile image to continue',
                                              style: TextStyle(
                                                color: Colors.orange.shade100,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              ),
                                            ),
                                          ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  // Submit Button
                                  Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: _profileImage != null
                                          ? const LinearGradient(
                                              colors: [Colors.white, Color(0xFFF0F0F0)],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                Colors.grey.shade600,
                                                Colors.grey.shade700,
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _profileImage != null
                                          ? [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.2),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: _profileImage != null ? Colors.black : Colors.white70,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: _profileImage != null ? _handleSubmit : null,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                        _profileImage == null 
                                          ? 'Upload Profile Image First' 
                                          : 'Confirm & Continue',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                      ),
                                    ),
                                  ),
                          ],
                              ),
                            ),
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    bool isAdmin = false,
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAdmin
              ? [Colors.red.shade600, Colors.red.shade700]
              : [Colors.white, Color(0xFFF0F0F0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isAdmin ? Colors.red : Colors.white).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: isAdmin ? Colors.white : Colors.black,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection({
    required String title,
    required String subtitle,
    required bool isRequired,
    required dynamic image,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F0F0F),
            Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: image == null
              ? (isRequired ? Colors.orange : Colors.white24)
              : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: image != null
                    ? LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade700, Colors.grey.shade800],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: image != null
                  ? ClipOval(
                      child: Image(
                        image: kIsWeb && image is Uint8List
                            ? MemoryImage(image)
                            : FileImage(image) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo,
                      size: 32,
                      color: isRequired ? Colors.orange : Colors.white70,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$title${isRequired ? ' (REQUIRED)' : ''}',
            style: TextStyle(
              color: image == null
                  ? (isRequired ? Colors.orange : Colors.white70)
                  : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            image == null ? subtitle : 'Image uploaded successfully ✓',
            style: TextStyle(
              color: image == null ? Colors.white54 : Colors.green.shade300,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        obscureText: isPassword,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          filled: true,
          fillColor: const Color(0xFF0F0F0F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white54, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white54,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }
} 