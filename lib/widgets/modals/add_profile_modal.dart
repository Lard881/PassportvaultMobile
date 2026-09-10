import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddProfileModal extends StatefulWidget {
  final Function(Map<String, dynamic>, File?) onSubmit;

  const AddProfileModal({super.key, required this.onSubmit});

  @override
  State<AddProfileModal> createState() => _AddProfileModalState();
}

class _AddProfileModalState extends State<AddProfileModal> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _countryController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _profileType = 'Self';
  String _sex = '';
  File? _photoFile;
  
  final List<String> _profileTypes = [
    'Self',
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Other'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _documentNumberController.dispose();
    _countryController.dispose();
    _nationalityController.dispose();
    _dateOfBirthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      final file = File(image.path);
      final fileSize = await file.length();
      
      // Check file size (max 5MB)
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image size must be less than 5MB')),
          );
        }
        return;
      }
      
      setState(() {
        _photoFile = file;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoFile = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'full_name': _fullNameController.text.trim(),
        'profile_type': _profileType,
        'document_number': _documentNumberController.text.trim(),
        'country': _countryController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'date_of_birth': _dateOfBirthController.text.trim(),
        'sex': _sex,
        'notes': _notesController.text.trim(),
      };
      
      widget.onSubmit(data, _photoFile);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final handleColor = isDark ? Colors.grey[700] : Colors.grey[300];

    Widget buildFieldLabel(String label) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Modal Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: subtitleColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Upload
                      Center(
                        child: Column(
                          children: [
                            if (_photoFile != null)
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: FileImage(_photoFile!),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _removePhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Add Photo'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Full Name
                      buildFieldLabel('Full Name *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter full name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Profile Type
                      buildFieldLabel('Profile Type'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _profileTypes.contains(_profileType) ? _profileType : _profileTypes.first,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _profileTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _profileType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Document Number
                      buildFieldLabel('Document Number'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _documentNumberController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. G0123456',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Country
                      buildFieldLabel('Country'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Ghana',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Nationality
                      buildFieldLabel('Nationality'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nationalityController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Ghanaian',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Date of Birth
                      buildFieldLabel('Date of Birth'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dateOfBirthController,
                        decoration: const InputDecoration(
                          hintText: 'Select date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 16),
                      
                      // Sex
                      buildFieldLabel('Sex'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: const ['Male', 'Female', 'Other'].contains(_sex) ? _sex : null,
                        decoration: const InputDecoration(
                          hintText: 'Select...',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sex = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      buildFieldLabel('Notes (Optional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'Add any additional notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0d6efd),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                              child: const Text('Save Profile'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
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
