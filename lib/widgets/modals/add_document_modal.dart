import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddDocumentModal extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  final Function(Map<String, dynamic>) onSubmit;

  const AddDocumentModal({
    super.key,
    required this.profiles,
    required this.onSubmit,
  });

  @override
  State<AddDocumentModal> createState() => _AddDocumentModalState();
}

class _AddDocumentModalState extends State<AddDocumentModal> {
  final _formKey = GlobalKey<FormState>();
  final _documentNameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _documentType = 'Passport';
  String? _selectedProfileId;
  File? _documentFile;
  String? _fileName;
  
  final List<String> _documentTypes = [
    'Passport',
    'Visa',
    'National ID',
    'Driver\'s License',
    'Birth Certificate',
    'Marriage Certificate',
    'Other'
  ];

  @override
  void dispose() {
    _documentNameController.dispose();
    _documentNumberController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        
        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size must be less than 10MB')),
            );
          }
          return;
        }
        
        setState(() {
          _documentFile = file;
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _takeCameraPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        final file = File(photo.path);
        final fileSize = await file.length();

        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo size must be less than 10MB')),
            );
          }
          return;
        }

        setState(() {
          _documentFile = file;
          _fileName = 'camera_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
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
      if (_documentFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a document file')),
        );
        return;
      }

      if (_selectedProfileId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a profile')),
        );
        return;
      }
      
      final data = {
        'documentFile': _documentFile,
        'document_name': _documentNameController.text.trim(),
        'documentName': _documentNameController.text.trim(),
        'document_type': _documentType,
        'documentType': _documentType,
        'profile_id': _selectedProfileId,
        'profile': _selectedProfileId,
        'document_number': _documentNumberController.text.trim(),
        'documentNumber': _documentNumberController.text.trim(),
        'issue_date': _issueDateController.text.trim(),
        'dateOfIssue': _issueDateController.text.trim(),
        'expiry_date': _expiryDateController.text.trim(),
        'dateOfExpiry': _expiryDateController.text.trim(),
        'description': _notesController.text.trim(),
        'notes': _notesController.text.trim(),
      };
      
      widget.onSubmit(data);
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
                    'Add Document',
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
                      // File Picker & Camera Capture
                      Text(
                        'Document File *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Pick File', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _takeCameraPhoto,
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Take Photo', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_fileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fileName!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      
                      // Document Name
                      _buildTextField(
                        'Document Name *',
                        _documentNameController,
                        required: true,
                        hint: 'e.g. My Passport',
                        textColor: textColor,
                      ),
                      
                      // Document Type
                      _buildDropdown(
                        'Document Type *',
                        _documentType,
                        _documentTypes,
                        (value) {
                          setState(() => _documentType = value!);
                        },
                        textColor: textColor,
                      ),
                      
                      // Profile Association
                      _buildProfileDropdown(textColor: textColor),
                      
                      // Document Number
                      _buildTextField(
                        'Document Number',
                        _documentNumberController,
                        hint: 'e.g. G0123456',
                        textColor: textColor,
                      ),
                      
                      // Issue Date
                      _buildDateField('Issue Date', _issueDateController, textColor: textColor),
                      
                      // Expiry Date
                      _buildDateField('Expiry Date', _expiryDateController, textColor: textColor),
                      
                      // Notes
                      _buildTextField(
                        'Notes',
                        _notesController,
                        maxLines: 3,
                        hint: 'Add any additional notes',
                        textColor: textColor,
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
                              child: const Text('Add Document'),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    int maxLines = 1,
    String hint = '',
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            maxLines: maxLines,
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    Color? textColor,
  }) {
    final safeItems = Set<String>.from(items);
    if (value.isNotEmpty && !safeItems.contains(value)) {
      safeItems.add(value);
    }
    final itemList = safeItems.toList();
    final safeValue = itemList.contains(value) ? value : (itemList.isNotEmpty ? itemList.first : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: safeValue,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: itemList.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDropdown({Color? textColor}) {
    final validProfileIds = widget.profiles
        .map((profile) => profile['id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
    final safeProfileId = validProfileIds.contains(_selectedProfileId) ? _selectedProfileId : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: safeProfileId,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: const Text('Select a profile'),
            items: widget.profiles.map((profile) {
              final id = profile['id']?.toString();
              if (id == null || id.isEmpty) return null;
              final name = profile['full_name'] ?? profile['name'] ?? 'Unnamed Profile';
              return DropdownMenuItem<String>(
                value: id,
                child: Text(name),
              );
            }).whereType<DropdownMenuItem<String>>().toList(),
            onChanged: (value) {
              setState(() {
                _selectedProfileId = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a profile';
              }
              return null;
            },
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
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
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
