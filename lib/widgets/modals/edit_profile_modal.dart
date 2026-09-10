import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileModal extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Function(Map<String, dynamic>, File?) onSubmit;

  const EditProfileModal({
    super.key,
    required this.profile,
    required this.onSubmit,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _documentNumberController;
  late TextEditingController _countryController;
  late TextEditingController _nationalityController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _issueDateController;
  late TextEditingController _expiryDateController;
  late TextEditingController _placeOfBirthController;
  late TextEditingController _notesController;
  
  late String _profileType;
  late String _gender;
  File? _photoFile;
  String? _existingPhotoUrl;
  
  final List<String> _profileTypes = ['Self', 'Spouse', 'Child', 'Parent', 'Sibling', 'Other'];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile['full_name'] ?? '');
    _documentNumberController = TextEditingController(text: widget.profile['document_number'] ?? '');
    _countryController = TextEditingController(text: widget.profile['country'] ?? '');
    _nationalityController = TextEditingController(text: widget.profile['nationality'] ?? '');
    _dateOfBirthController = TextEditingController(text: widget.profile['date_of_birth'] ?? '');
    _issueDateController = TextEditingController(text: widget.profile['issue_date'] ?? '');
    _expiryDateController = TextEditingController(text: widget.profile['expiry_date'] ?? '');
    _placeOfBirthController = TextEditingController(text: widget.profile['place_of_birth'] ?? '');
    _notesController = TextEditingController(text: widget.profile['notes'] ?? '');
    _profileType = widget.profile['profile_type'] ?? 'Self';
    _gender = widget.profile['gender'] ?? widget.profile['sex'] ?? '';
    _existingPhotoUrl = widget.profile['photo_url'];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _documentNumberController.dispose();
    _countryController.dispose();
    _nationalityController.dispose();
    _dateOfBirthController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _placeOfBirthController.dispose();
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
      
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo size must be less than 5MB')),
          );
        }
        return;
      }
      
      setState(() {
        _photoFile = file;
        _existingPhotoUrl = null; // Clear existing when new photo selected
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoFile = null;
      _existingPhotoUrl = null;
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().split('T')[0];
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
        'issue_date': _issueDateController.text.trim(),
        'expiry_date': _expiryDateController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'date_of_birth': _dateOfBirthController.text.trim(),
        'place_of_birth': _placeOfBirthController.text.trim(),
        'gender': _gender,
        'notes': _notesController.text.trim(),
      };
      
      widget.onSubmit(data, _photoFile);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoFile != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6C757D);
    final handleColor = isDark ? Colors.grey[700] : Colors.grey[300];
    
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Profile',
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
                            if (hasPhoto)
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFe0e0e0), width: 3),
                                ),
                                child: ClipOval(
                                  child: _photoFile != null
                                      ? Image.file(_photoFile!, fit: BoxFit.cover)
                                      : Image.network(_existingPhotoUrl!, fit: BoxFit.cover),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.camera_alt),
                                    label: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
                                  ),
                                ),
                                if (hasPhoto) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _removePhoto,
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Remove'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFdc3545),
                                        side: const BorderSide(color: Color(0xFFdc3545)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildTextField('Full Name *', _fullNameController, required: true, textColor: textColor),
                      _buildDropdown('Profile Type', _profileType, _profileTypes, (value) {
                        setState(() => _profileType = value!);
                      }, textColor: textColor),
                      _buildTextField('Nationality', _nationalityController, textColor: textColor),
                      _buildDateField('Date of Birth', _dateOfBirthController, textColor: textColor),
                      _buildDropdown('Gender', _gender.isEmpty ? null : _gender, ['Male', 'Female', 'Other'], (value) {
                        setState(() => _gender = value ?? '');
                      }, allowEmpty: true, textColor: textColor),
                      _buildTextField('Document Number *', _documentNumberController, required: true, textColor: textColor),
                      _buildTextField('Country *', _countryController, required: true, textColor: textColor),
                      _buildDateField('Issue Date', _issueDateController, textColor: textColor),
                      _buildDateField('Expiry Date', _expiryDateController, textColor: textColor),
                      _buildTextField('Place of Birth', _placeOfBirthController, textColor: textColor),
                      _buildTextField('Notes', _notesController, maxLines: 3, textColor: textColor),
                      
                      const SizedBox(height: 24),
                      
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
                              child: const Text('Update Profile'),
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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            maxLines: maxLines,
            validator: required ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, {bool allowEmpty = false, Color? textColor}) {
    final safeItems = Set<String>.from(items);
    if (value != null && value.isNotEmpty && !safeItems.contains(value)) {
      safeItems.add(value);
    }
    final itemList = safeItems.toList();
    final safeValue = (value != null && itemList.contains(value)) ? value : (allowEmpty ? null : (itemList.isNotEmpty ? itemList.first : null));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: safeValue,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: itemList.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () => _selectDate(context, controller),
          ),
        ],
      ),
    );
  }
}
