import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';

class MemberDialog extends StatefulWidget {
  final Member? member;

  const MemberDialog({super.key, this.member});

  @override
  State<MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<MemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _membershipDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  String? _selectedType;
  String? _profilePhotoUrl;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  bool _isActive = true;
  bool _isUploading = false;

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  static const List<Map<String, dynamic>> _memberTypes = [
    // Keep value as 'guest' for new entries; backend will accept both guest/student.
    {
      'value': 'guest',
      'label': 'Guest',
      'maxBooks': 3,
      'loanDays': 14,
      'icon': Icons.person_outline,
    },
    {
      'value': 'faculty',
      'label': 'Faculty',
      'maxBooks': 10,
      'loanDays': 30,
      'icon': Icons.person,
    },
    {
      'value': 'staff',
      'label': 'Staff',
      'maxBooks': 5,
      'loanDays': 21,
      'icon': Icons.work,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      _nameController.text = normalizeHindiForDisplay(widget.member!.name);
      _emailController.text = widget.member!.email ?? '';
      _phoneController.text = widget.member!.phone ?? '';
      _addressController.text = normalizeHindiForDisplay(
        widget.member!.address ?? '',
      );
      try {
        final date = DateTime.parse(widget.member!.membershipDate);
        _membershipDateController.text = date.toIso8601String().split('T')[0];
      } catch (e) {
        _membershipDateController.text = widget.member!.membershipDate;
      }
      if (widget.member!.expiryDate != null) {
        try {
          final expiry = DateTime.parse(widget.member!.expiryDate!);
          _expiryDateController.text = expiry.toIso8601String().split('T')[0];
        } catch (e) {
          _expiryDateController.text = widget.member!.expiryDate!;
        }
      }
      final raw = widget.member!.memberType.toLowerCase();
      // Backward compatibility: treat 'student' as 'guest'.
      _selectedType = raw == 'student' ? 'guest' : raw;
      _profilePhotoUrl = widget.member!.profilePhoto;
      _isActive = widget.member!.isActive;
    } else {
      _selectedType = 'guest';
      _membershipDateController.text = DateTime.now().toIso8601String().split(
        'T',
      )[0];
      _expiryDateController.text = DateTime.now()
          .add(const Duration(days: 365))
          .toIso8601String()
          .split('T')[0];
    }
    _nameController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 850;
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 900).toDouble();
    final maxHeight = (isSmallScreen ? screenSize.height * 0.95 : 800)
        .toDouble();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Member' : 'Add Member',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (isEditing) ...[
                      Switch(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: _isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: isSmallScreen
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfilePhotoPicker(),
                                const SizedBox(height: 20),
                                if (_selectedType != null)
                                  _buildMemberTypeInfo(),
                                const SizedBox(height: 24),
                                _buildFormFields(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    _buildProfilePhotoPicker(),
                                    const SizedBox(height: 20),
                                    if (_selectedType != null)
                                      _buildMemberTypeInfo(),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Expanded(child: _buildFormFields()),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _saveMember,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              widget.member != null ? Icons.save : Icons.add,
                            ),
                      label: Text(widget.member != null ? 'Update' : 'Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    final baseFieldStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _nameController,
          style: hindiAwareTextStyle(
            context,
            text: _nameController.text,
            base: baseFieldStyle,
          ),
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Name is required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return null;
            final emailRegex = RegExp(r"^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}");
            if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Phone is required';
            final phoneRegex = RegExp(r'^\d{10}$');
            if (!phoneRegex.hasMatch(value)) {
              return 'Enter a valid 10-digit phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Member Type',
            prefixIcon: Icon(Icons.badge),
          ),
          items: _memberTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type['value'] as String,
                  child: Row(
                    children: [
                      Icon(type['icon'] as IconData, size: 20),
                      const SizedBox(width: 8),
                      Text(type['label'] as String),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedType = value),
          validator: (value) {
            if (value == null) return 'Member type is required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on),
            alignLabelWithHint: true,
          ),
          maxLines: 2,
          style: hindiAwareTextStyle(
            context,
            text: _addressController.text,
            base: baseFieldStyle,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _membershipDateController,
                decoration: const InputDecoration(
                  labelText: 'Membership Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_membershipDateController),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: Icon(Icons.event_busy),
                ),
                readOnly: true,
                onTap: () => _selectDate(_expiryDateController),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfilePhotoPicker() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: ClipOval(child: _buildPhotoPreview()),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickPhoto,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _profilePhotoUrl != null || _selectedPhotoBytes != null
                        ? Icons.edit
                        : Icons.add_photo_alternate,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          if (_profilePhotoUrl != null || _selectedPhotoBytes != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _profilePhotoUrl = null;
                      _selectedPhotoBytes = null;
                      _selectedPhotoName = null;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    if (_selectedPhotoBytes != null) {
      return Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover);
    } else if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return Image.network(
        ApiService.resolvePublicUrl(_profilePhotoUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: 60,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildMemberTypeInfo() {
    final typeInfo = _memberTypes.firstWhere(
      (t) => t['value'] == _selectedType,
      orElse: () => _memberTypes[0],
    );
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                typeInfo['icon'] as IconData,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  typeInfo['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      controller.text = date.toIso8601String().split('T')[0];
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPhotoBytes = result.files.first.bytes;
          _selectedPhotoName = result.files.first.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick photo: $e')));
      }
    }
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String? photoPath = _profilePhotoUrl;

      if (_selectedPhotoBytes != null && _selectedPhotoName != null) {
        photoPath = await ApiService.uploadMemberPhoto(
          _selectedPhotoBytes!,
          _selectedPhotoName!,
        );
      }

      final name = normalizeHindiForDisplay(_nameController.text);
      final address = normalizeHindiForDisplay(_addressController.text);

      final member = Member(
        id: widget.member?.id ?? 0,
        name: name,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        phone: _phoneController.text,
        address: address.isEmpty ? null : address,
        memberType: _selectedType!,
        membershipDate: _membershipDateController.text,
        expiryDate: _expiryDateController.text.isEmpty ? null : _expiryDateController.text,
        profilePhoto: photoPath,
        isActive: _isActive,
      );

      if (widget.member != null) {
        await ApiService.updateMember(member.id, member);
      } else {
        await ApiService.addMember(member);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Member ${widget.member != null ? 'updated' : 'added'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save member: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _addressController.removeListener(_onTextChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _membershipDateController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }
}
