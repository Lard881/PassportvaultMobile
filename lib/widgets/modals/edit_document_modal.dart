import 'package:flutter/material.dart';

class EditDocumentModal extends StatefulWidget {
  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> profiles;
  final Function(Map<String, dynamic>) onSubmit;

  const EditDocumentModal({
    super.key,
    required this.document,
    required this.profiles,
    required this.onSubmit,
  });

  @override
  State<EditDocumentModal> createState() => _EditDocumentModalState();
}

class _EditDocumentModalState extends State<EditDocumentModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _documentNameController;
  late TextEditingController _documentNumberController;
  late TextEditingController _issueDateController;
  late TextEditingController _expiryDateController;
  late TextEditingController _notesController;
  
  late String _documentType;
  late String? _selectedProfileId;
  
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
  void initState() {
    super.initState();
    _documentNameController = TextEditingController(text: widget.document['document_name'] ?? '');
    _documentNumberController = TextEditingController(text: widget.document['document_number'] ?? '');
    _issueDateController = TextEditingController(text: widget.document['date_of_issue'] ?? widget.document['issue_date'] ?? '');
    _expiryDateController = TextEditingController(text: widget.document['date_of_expiry'] ?? widget.document['expiry_date'] ?? '');
    _notesController = TextEditingController(text: widget.document['notes'] ?? widget.document['description'] ?? '');
    _documentType = widget.document['document_type'] ?? 'Passport';
    _selectedProfileId = widget.document['profile_id']?.toString();
  }

  @override
  void dispose() {
    _documentNameController.dispose();
    _documentNumberController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
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
      if (_selectedProfileId == null || _selectedProfileId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a profile')),
        );
        return;
      }
      
      final data = {
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
                    'Edit Document',
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
                              child: const Text('Update Document'),
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
