import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import '../utils/responsive.dart';
import 'premium_dialog.dart';
import 'app_toast.dart';

class MemberDialog extends StatefulWidget {
  final Member? member;

  const MemberDialog({super.key, this.member});

  @override
  State<MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<MemberDialog> {
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
    {'value': 'guest', 'label': 'Guest', 'maxBooks': 3, 'loanDays': 14, 'icon': Icons.person_outline, 'color': Color(0xFF6366F1)},
    {'value': 'additional_director', 'label': 'Additional Director', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.apartment, 'color': Color(0xFF8B5CF6)},
    {'value': 'joint_director', 'label': 'Joint Director', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.apartment_outlined, 'color': Color(0xFFA855F7)},
    {'value': 'deputy_director', 'label': 'Deputy Director', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.badge, 'color': Color(0xFFEC4899)},
    {'value': 'assistant_commissioner', 'label': 'Asst. Commissioner', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.account_balance, 'color': Color(0xFF14B8A6)},
    {'value': 'state_tax_officer', 'label': 'State Tax Officer', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.account_balance_wallet, 'color': Color(0xFF22C55E)},
    {'value': 'assistant', 'label': 'Assistant', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.person, 'color': Color(0xFFF59E0B)},
    {'value': 'faculty', 'label': 'Faculty', 'maxBooks': 10, 'loanDays': 30, 'icon': Icons.school, 'color': Color(0xFF3B82F6)},
    {'value': 'staff', 'label': 'Staff', 'maxBooks': 5, 'loanDays': 21, 'icon': Icons.work, 'color': Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
    _initializeData();
  }

  void _initializeData() {
    if (widget.member != null) {
      _nameController.text = normalizeHindiForDisplay(widget.member!.name);
      _emailController.text = widget.member!.email ?? '';
      _phoneController.text = widget.member!.phone ?? '';
      _addressController.text = normalizeHindiForDisplay(widget.member!.address ?? '');
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
      _selectedType = raw == 'student' ? 'guest' : raw;
      _profilePhotoUrl = widget.member!.profilePhoto;
      _isActive = widget.member!.isActive;
    } else {
      _selectedType = 'guest';
      _membershipDateController.text = DateTime.now().toIso8601String().split('T')[0];
      _expiryDateController.text = DateTime.now().add(const Duration(days: 365)).toIso8601String().split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;
    final colorScheme = Theme.of(context).colorScheme;
    final responsive = Responsive(context);
    final isVerySmallScreen = responsive.isCompact;
    final isSmallScreen = responsive.isMedium;

    return PremiumDialogShell(
      icon: isEditing ? Icons.manage_accounts_rounded : Icons.person_add_rounded,
      title: isEditing ? 'Edit Member' : 'Add New Member',
      subtitle: isEditing
          ? 'Update member information and privileges'
          : 'Fill in the details to register a new member',
      headerTrailing: isEditing ? _buildActiveStatusControl(colorScheme) : null,
      body: isVerySmallScreen
          ? _buildCompactLayout(colorScheme, responsive, veryCompact: true)
          : (isSmallScreen
              ? _buildCompactLayout(colorScheme, responsive)
              : _buildWideLayout(colorScheme, responsive)),
      actions: [
        PremiumDialogButton.secondary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PremiumDialogButton.primary(
          label: isEditing ? 'Update Member' : 'Add Member',
          icon: isEditing ? Icons.save_rounded : Icons.add_rounded,
          loading: _isUploading,
          onPressed: _isUploading ? null : _saveMember,
        ),
      ],
    );
  }

  /// Active/inactive status control shown in the header when editing.
  Widget _buildActiveStatusControl(ColorScheme colorScheme) {
    final isVerySmallScreen = MediaQuery.of(context).size.width < 480;
    if (isVerySmallScreen) {
      return Transform.scale(
        scale: 0.75,
        child: Switch(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isActive
                ? Colors.green.withValues(alpha: 0.15)
                : colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isActive
                  ? Colors.green.withValues(alpha: 0.4)
                  : colorScheme.error.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isActive ? Colors.green : colorScheme.error,
                  boxShadow: [
                    BoxShadow(
                      color: (_isActive ? Colors.green : colorScheme.error)
                          .withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isActive ? Colors.green : colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
      ],
    );
  }

  Widget _buildWideLayout(ColorScheme colorScheme, Responsive responsive) {
    final profileWidth = (responsive.width * 0.25).clamp(180.0, 260.0);
    final spacing = responsive.pagePadding;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: profileWidth, child: Column(children: [
          _buildProfileCard(colorScheme, responsive),
          SizedBox(height: spacing),
          if (_selectedType != null) _buildMemberTypeCard(colorScheme),
        ])),
        SizedBox(width: spacing * 1.5),
        Expanded(child: _buildFormSection(colorScheme)),
      ],
    );
  }

  Widget _buildCompactLayout(ColorScheme colorScheme, Responsive responsive, {bool veryCompact = false}) {
    return Column(
      children: [
        if (veryCompact)
          Column(
            children: [
              Center(child: _buildProfileCard(colorScheme, responsive, compact: true)),
              SizedBox(height: responsive.pagePadding),
              if (_selectedType != null) _buildMemberTypeCard(colorScheme),
              SizedBox(height: responsive.pagePadding),
              _buildFormSection(colorScheme, compact: true),
            ],
          )
        else
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(colorScheme, responsive, compact: true),
                  SizedBox(width: responsive.pagePadding * 1.2),
                  Expanded(child: _buildFormSection(colorScheme, compact: true)),
                ],
              ),
              SizedBox(height: responsive.pagePadding * 1.5),
              if (_selectedType != null) _buildMemberTypeCard(colorScheme),
            ],
          ),
      ],
    );
  }

  Widget _buildProfileCard(ColorScheme colorScheme, Responsive responsive, {bool compact = false}) {
    final photoSize = compact 
        ? (responsive.isCompact ? 80 : 100)
        : (responsive.isCompact ? 100 : 130);
    final cardPadding = responsive.pagePadding;
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: photoSize.toDouble(),
                height: photoSize.toDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colorScheme.primary.withValues(alpha: 0.12), colorScheme.tertiary.withValues(alpha: 0.12)]),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35), width: 3),
                  boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: ClipOval(child: _buildPhotoPreview()),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: EdgeInsets.all(responsive.pagePadding / 2),
                    decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))]),
                    child: Icon(_profilePhotoUrl != null || _selectedPhotoBytes != null ? Icons.edit : Icons.add_a_photo, color: colorScheme.onPrimary, size: compact ? 18 : 22),
                  ),
                ),
              ),
            ],
          ),
          if ((_profilePhotoUrl != null || _selectedPhotoBytes != null) && !compact) ...[
            SizedBox(height: responsive.pagePadding),
            TextButton.icon(
              onPressed: () => setState(() { _profilePhotoUrl = null; _selectedPhotoBytes = null; _selectedPhotoName = null; }),
              icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
              label: Text('Remove', style: TextStyle(color: colorScheme.error, fontSize: 12)),
              style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: responsive.pagePadding / 2)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberTypeCard(ColorScheme colorScheme) {
    if (_selectedType == null) return const SizedBox(width: 200, height: 80);
    final typeInfo = _memberTypes.firstWhere((t) => t['value'] == _selectedType, orElse: () => _memberTypes.first);
    final color = typeInfo['color'] as Color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(typeInfo['icon'] as IconData, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeInfo['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text('Max ${typeInfo['maxBooks']} books • ${typeInfo['loanDays']} days loan', style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(ColorScheme colorScheme, {bool compact = false}) {
    final baseFieldStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final sp = compact ? 12.0 : 16.0;
    final sectionSp = compact ? 16.0 : 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionTitle(title: 'Personal Information', icon: Icons.person_outline),
              SizedBox(height: sp),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: compact ? 2 : 3, child: _buildTextField(controller: _nameController, label: 'Full Name', hint: 'Enter member name', icon: Icons.person_outline, validator: (v) => (v?.isEmpty ?? true) ? 'Name is required' : null, style: hindiAwareTextStyle(context, text: _nameController.text, base: baseFieldStyle))),
                  if (!compact) ...[
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildTextField(controller: _phoneController, label: 'Phone Number', hint: 'Enter phone number', icon: Icons.phone_outlined, validator: (v) => (v?.isEmpty ?? true) ? 'Phone is required' : null)),
                  ],
                ],
              ),
              if (compact) ...[
                SizedBox(height: sp),
                _buildTextField(controller: _phoneController, label: 'Phone Number', hint: 'Enter phone number', icon: Icons.phone_outlined, validator: (v) => (v?.isEmpty ?? true) ? 'Phone is required' : null),
              ],
              SizedBox(height: sp),
              _buildTextField(controller: _emailController, label: 'Email Address', hint: 'Enter email address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              SizedBox(height: sp),
              _buildTextField(controller: _addressController, label: 'Address', hint: 'Enter address', icon: Icons.location_on_outlined, maxLines: 2, style: hindiAwareTextStyle(context, text: _addressController.text, base: baseFieldStyle)),
            ],
          ),
        ),
        SizedBox(height: sectionSp),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionTitle(title: 'Membership Details', icon: Icons.badge_outlined),
              SizedBox(height: sp),
              _buildMemberTypeSelector(colorScheme),
              SizedBox(height: sp),
              Row(
                children: [
                  Expanded(child: _buildDateField(_membershipDateController, 'Membership Date', Icons.calendar_today)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDateField(_expiryDateController, 'Expiry Date', Icons.event_busy)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, TextStyle? style, int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      style: style,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: premiumInputDecoration(context, label: label, hint: hint, icon: icon),
      validator: validator,
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDate(controller),
      decoration: premiumInputDecoration(context, label: label, icon: icon),
    );
  }

  Widget _buildMemberTypeSelector(ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedType ?? 'guest',
      decoration: premiumInputDecoration(
        context,
        label: 'Member Type',
        prefixIcon: Icon(_memberTypes.first['icon'] as IconData, size: 20, color: _memberTypes.first['color'] as Color),
      ),
      items: _memberTypes.map((type) {
        return DropdownMenuItem(
          value: type['value'] as String,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type['icon'] as IconData, size: 18, color: type['color'] as Color),
              const SizedBox(width: 8),
              Text(type['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: type['color'] as Color)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedType = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Member type is required';
        return null;
      },
    );
  }

  Widget _buildPhotoPreview() {
    if (_selectedPhotoBytes != null) return Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover);
    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ApiService.resolvePublicUrl(_profilePhotoUrl!),
        fit: BoxFit.cover,
        placeholder: (context, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, _, _) => _buildPhotoPlaceholder(),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Center(child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.outline));
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date != null) controller.text = date.toIso8601String().split('T')[0];
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() { _selectedPhotoBytes = result.files.first.bytes; _selectedPhotoName = result.files.first.name; });
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed to pick photo');
    }
  }

  Future<void> _saveMember() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) AppToast.warning(context, 'Name is required');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      if (mounted) AppToast.warning(context, 'Phone is required');
      return;
    }
    if (_selectedType == null || _selectedType!.isEmpty) {
      if (mounted) AppToast.warning(context, 'Member type is required');
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? photoPath = _profilePhotoUrl;
      if (_selectedPhotoBytes != null && _selectedPhotoName != null) {
        photoPath = await ApiService.uploadMemberPhoto(_selectedPhotoBytes!, _selectedPhotoName!);
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
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        AppToast.showOnMessenger(
          messenger,
          message: 'Member ${widget.member != null ? 'updated' : 'added'} successfully',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, getOperationErrorMessage('Save member', e));
    } finally {
      if (mounted) setState(() => _isUploading = false);
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