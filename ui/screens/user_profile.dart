import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tech_borrow/ui/screens/utility/app_colors.dart';
import 'package:tech_borrow/ui/screens/widgets/background_widget.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, String>? item;
  final Map<String, String>? userData;
  final bool isStandalone;

  const UserProfileScreen({super.key, this.item, this.userData, this.isStandalone = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      _profileData = widget.userData;
      _isLoading = false;
    } else {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _profileData = doc.data();
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndSaveImage() async {
    final ImagePicker picker = ImagePicker();
    // AUTOMATIC COMPRESSION:
    // Resize to 200x200 and set quality to 30% to keep data size very small for Firestore
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 30,
    );

    if (image == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Convert image to Base64 String
      final bytes = await image.readAsBytes();
      
      // Safety check: Firestore documents have a 1MB limit.
      // Base64 increases size by ~33%, so we aim for < 700KB.
      if (bytes.length > 700000) {
         throw Exception("Image is too large even after compression. Please pick a smaller photo.");
      }
      
      final base64String = base64Encode(bytes);

      // 2. Save Base64 String directly to Firestore Database
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profilePic': base64String,
      });

      // 3. Update UI
      setState(() {
        _profileData?['profilePic'] = base64String;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compressed photo saved to database!')),
        );
      }
    } catch (e) {
      debugPrint("Error saving image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isStandalone) {
      return Scaffold(
        body: BackgroundWidget(
          child: SafeArea(
            child: _buildBody(context),
          ),
        ),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Column(
      children: [
        if (widget.isStandalone) _buildTopBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildBorrowingStatusBadge(),
                const SizedBox(height: 24),
                _buildCurrentBorrowingItem(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final String? base64Image = _profileData?['profilePic'];

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: base64Image != null 
                  ? MemoryImage(base64Decode(base64Image)) 
                  : null,
              child: base64Image == null
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
          ),
          InkWell(
            onTap: _isSaving ? null : _pickAndSaveImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.camera_alt, size: 20, color: Appcolors.background),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoRow(Icons.fingerprint, 'User ID', _profileData?['uid'] ?? 'N/A'),
          _divider(),
          _buildInfoRow(Icons.person_outline, 'Name', '${_profileData?['firstName'] ?? ''} ${_profileData?['lastName'] ?? ''}'.trim() == '' ? 'N/A' : '${_profileData?['firstName']} ${_profileData?['lastName']}'),
          _divider(),
          _buildInfoRow(Icons.badge_outlined, 'Student ID', _profileData?['studentId'] ?? 'N/A'),
          _divider(),
          _buildInfoRow(Icons.business_outlined, 'Dept', _profileData?['department'] ?? 'N/A'),
          _divider(),
          _buildInfoRow(Icons.email_outlined, 'Email', _profileData?['email'] ?? 'N/A'),
          _divider(),
          _buildInfoRow(Icons.phone_outlined, 'Phone', _profileData?['mobile'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(color: Colors.white.withValues(alpha: 0.1), height: 1);
  }

  Widget _buildBorrowingStatusBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Borrowing Status',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.item == null ? 0 : 1} / 2 items',
              style: TextStyle(
                color: Appcolors.background,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBorrowingItem() {
    if (widget.item == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Current Borrowing',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: (widget.item?['imagePath']?.isNotEmpty ?? false)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(widget.item!['imagePath']!), fit: BoxFit.cover),
                      )
                    : Icon(Icons.devices, size: 40, color: Appcolors.background),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item?['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item?['specs'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }
}
