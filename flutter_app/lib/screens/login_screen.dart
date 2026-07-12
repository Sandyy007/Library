import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../widgets/app_toast.dart';
import '../widgets/press_scale.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _capsLockOn = false;
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
    _animationController.forward();

    // Pause the perpetual decorative animations while the user is actually
    // interacting with the form. The floating 3D books look nice on an idle
    // login gate but are pure wasted CPU/GPU once someone is typing.
    _usernameFocus.addListener(_handleFieldFocusChange);
    _passwordFocus.addListener(_handleFieldFocusChange);
  }

  void _handleFieldFocusChange() {
    final interacting = _usernameFocus.hasFocus || _passwordFocus.hasFocus;
    if (interacting) {
      if (_floatingController.isAnimating) _floatingController.stop();
      if (_rotationController.isAnimating) _rotationController.stop();
    } else {
      if (!_floatingController.isAnimating) {
        _floatingController.repeat(reverse: true);
      }
      if (!_rotationController.isAnimating) _rotationController.repeat();
    }
  }

  /// Observes key events on the password field to reflect Caps Lock state,
  /// warning the user before a failed login. Returns [KeyEventResult.ignored]
  /// so the field still receives every keystroke.
  KeyEventResult _handlePasswordKeyEvent(FocusNode node, KeyEvent event) {
    final caps = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
    if (caps != _capsLockOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _capsLockOn = caps);
      });
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final screenSize = Size(r.width, r.height);
    final isSmallScreen = r.isCompact;
    final isLargeScreen = r.isExpanded;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),

          // Floating book decorations
          if (!isSmallScreen) ...[
            _buildFloatingBook(
              left: screenSize.width * 0.05,
              top: screenSize.height * 0.1,
              rotation: -0.2,
              scale: isLargeScreen ? 1.0 : 0.8,
              delay: 0,
            ),
            _buildFloatingBook(
              right: screenSize.width * 0.08,
              top: screenSize.height * 0.15,
              rotation: 0.15,
              scale: isLargeScreen ? 1.2 : 1.0,
              delay: 0.3,
            ),
            _buildFloatingBook(
              left: screenSize.width * 0.1,
              bottom: screenSize.height * 0.15,
              rotation: 0.1,
              scale: isLargeScreen ? 0.9 : 0.7,
              delay: 0.6,
            ),
            _buildFloatingBook(
              right: screenSize.width * 0.05,
              bottom: screenSize.height * 0.2,
              rotation: -0.1,
              scale: isLargeScreen ? 1.1 : 0.9,
              delay: 0.9,
            ),
            // Book stack decoration
            _buildBookStack(
              left: screenSize.width * 0.02,
              top: screenSize.height * 0.4,
            ),
            _buildBookStack(
              right: screenSize.width * 0.02,
              bottom: screenSize.height * 0.4,
              mirrored: true,
            ),
            // Extra floating books for large screens. Kept intentionally
            // small: each floating book runs matrix transforms every frame, so
            // piling on a dozen of them just to fill a login gate is wasted
            // CPU/GPU. Two extras on large screens is plenty of ambience.
            if (isLargeScreen) ...[
              _buildFloatingBook(
                left: screenSize.width * 0.15,
                top: screenSize.height * 0.25,
                rotation: 0.08,
                scale: 0.85,
                delay: 0.2,
              ),
              _buildFloatingBook(
                right: screenSize.width * 0.15,
                bottom: screenSize.height * 0.35,
                rotation: -0.12,
                scale: 0.95,
                delay: 0.5,
              ),
            ],
          ],

          // Main login card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildLoginCard(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(
                        const Color(0xFF0F1118),
                        const Color(0xFF171923),
                        _floatingController.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF171923),
                        const Color(0xFF1E202B),
                        _floatingController.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF1E202B),
                        const Color(0xFF0F1118),
                        _floatingController.value,
                      )!,
                    ]
                  : [
                      Color.lerp(
                        const Color(0xFFF8F0FC),
                        const Color(0xFFE8F4FD),
                        _floatingController.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFE8F4FD),
                        const Color(0xFFFDF2F8),
                        _floatingController.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFFDF2F8),
                        const Color(0xFFF8F0FC),
                        _floatingController.value,
                      )!,
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  // Premium cover gradient palettes for the floating 3D books.
  static const List<List<Color>> _coverPalettes = [
    [Color(0xFF7C3AED), Color(0xFF4C1D95)], // violet
    [Color(0xFF2563EB), Color(0xFF1E3A8A)], // blue
    [Color(0xFF0EA5E9), Color(0xFF0C4A6E)], // sky
    [Color(0xFF14B8A6), Color(0xFF0F766E)], // teal
    [Color(0xFFEC4899), Color(0xFF9D174D)], // pink
    [Color(0xFFF59E0B), Color(0xFF92400E)], // amber
    [Color(0xFF6366F1), Color(0xFF312E81)], // indigo
  ];

  List<Color> _coverFor(double delay) {
    final idx = (delay * 10).round().abs() % _coverPalettes.length;
    return _coverPalettes[idx];
  }

  Widget _buildFloatingBook({
    double? left,
    double? right,
    double? top,
    double? bottom,
    double rotation = 0,
    double scale = 1.0,
    double delay = 0,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatingController, _rotationController]),
      builder: (context, child) {
        // Gentle vertical bob.
        final bob = math.sin((_floatingController.value + delay) * math.pi * 2);
        // Slow, continuous oscillating spin around the Y axis for a true 3D feel.
        final spin = _rotationController.value * 2 * math.pi + delay * math.pi * 2;
        final angleY = rotation + math.sin(spin) * 0.7;
        final tiltX = -0.14 + bob * 0.06;

        return Positioned(
          left: left,
          right: right,
          top: top != null ? top + (bob * 14) : null,
          bottom: bottom != null ? bottom + (bob * 14) : null,
          child: ExcludeSemantics(
            child: Transform.scale(
              scale: scale,
              child: _Book3D(
                width: 76,
                height: 104,
                depth: 20,
                angleY: angleY,
                tiltX: tiltX,
                cover: _coverFor(delay),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookStack({
    double? left,
    double? right,
    double? top,
    double? bottom,
    bool mirrored = false,
  }) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final value = _floatingController.value;
        return Positioned(
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(mirrored ? math.pi : 0)
              ..rotateZ(value * 0.02),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Opacity(
              opacity: 0.15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSingleBook(Colors.purple, 60, 8),
                  const SizedBox(height: 2),
                  _buildSingleBook(Colors.blue, 55, 10),
                  const SizedBox(height: 2),
                  _buildSingleBook(Colors.indigo, 65, 7),
                  const SizedBox(height: 2),
                  _buildSingleBook(Colors.deepPurple, 50, 9),
                  const SizedBox(height: 2),
                  _buildSingleBook(Colors.purple.shade300, 58, 8),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleBook(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final r = Responsive(context);
    final isLargeScreen = r.isExpanded;
    final isExtraLargeScreen = r.isExtraExpanded;

    // Scale up card for larger screens
    final maxCardWidth = isExtraLargeScreen
        ? 480.0
        : (isLargeScreen ? 450.0 : 420.0);
    final cardPadding = isExtraLargeScreen
        ? 48.0
        : (isLargeScreen ? 44.0 : 40.0);
    final iconSize = isExtraLargeScreen ? 52.0 : (isLargeScreen ? 48.0 : 44.0);
    final titleFontSize = isExtraLargeScreen
        ? 32.0
        : (isLargeScreen ? 30.0 : 28.0);

    return Container(
      constraints: BoxConstraints(maxWidth: maxCardWidth),
      child: Card(
        elevation: isLargeScreen ? 28 : 24,
        shadowColor: Colors.purple.withValues(
          alpha: isLargeScreen ? 0.25 : 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 28),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.04),
                  Theme.of(context).colorScheme.surface,
                ),
                Theme.of(context).colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                blurRadius: 36,
                spreadRadius: -8,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          padding: EdgeInsets.all(cardPadding),
          child: AutofillGroup(
            child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Library Icon with animation
                Hero(
                  tag: 'app-logo',
                  child: _buildAnimatedIcon(iconSize: iconSize),
                ),
                SizedBox(height: isLargeScreen ? 32 : 28),

                // Title with book decoration
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: isLargeScreen ? 24 : 20,
                        color: Colors.purple.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                        ).createShader(bounds),
                        child: Text(
                          'Admin Login',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_stories,
                        size: isLargeScreen ? 24 : 20,
                        color: Colors.purple.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle with book icons
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 1,
                        width: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.purple.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Library Management System',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 1,
                        width: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Username Field
                _buildTextField(
                  controller: _usernameController,
                  label: 'Admin Username',
                  hint: 'Enter your username',
                  icon: Icons.person_outline_rounded,
                  focusNode: _usernameFocus,
                  autofocus: true,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter admin username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: _handlePasswordKeyEvent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Admin Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        focusNode: _passwordFocus,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter admin password';
                          }
                          return null;
                        },
                      ),
                      if (_capsLockOn)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.keyboard_capslock_rounded,
                                size: 15,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Caps Lock is on',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Login Button
                _buildLoginButton(),
                const SizedBox(height: 24),

                // Footer with book decoration
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Secure Admin Portal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon({double iconSize = 44}) {
    final containerPadding = iconSize * 0.45;
    final badgeSize = iconSize * 0.32;

    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            math.sin(_floatingController.value * math.pi * 2) * 3,
          ),
          child: Container(
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: EdgeInsets.all(badgeSize * 0.3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: badgeSize,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    bool autofocus = false,
    List<String>? autofillHints,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: const Color(0xFF7C3AED), size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: isDark
            ? colorScheme.surface.withValues(alpha: 0.5)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.5)
                : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildLoginButton() {
    return Semantics(
      button: true,
      enabled: !_isLoading,
      label: 'Sign In',
      child: MouseRegion(
        cursor: _isLoading
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: PressScale(
          onTap: _isLoading ? null : _login,
          pressedScale: 0.97,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED)
                      .withValues(alpha: _isLoading ? 0.2 : 0.4),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      // Server may have flagged the account as needing a password change
      // (e.g. the default seed password 'admin'). Force a change before
      // the user can navigate anywhere else.
      if (authProvider.mustChangePassword) {
        await _showChangePasswordDialog(context);
      }
    } catch (e) {
      if (mounted) {
        // Parse error message - show user-friendly text
        String errorMessage = 'Wrong username or password';
        final errorStr = e.toString();
        if (errorStr.contains('connect') || errorStr.contains('Connection')) {
          errorMessage = 'Cannot connect to server';
        } else if (errorStr.contains('timed out') || errorStr.contains('Timeout')) {
          errorMessage = 'Connection timed out';
        } else if (errorStr.contains('Too many')) {
          errorMessage = 'Too many attempts. Please wait.';
        }

        AppToast.error(context, errorMessage, title: 'Sign in failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Change your password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'You must set a new password before continuing.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: currentController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    TextFormField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) {
                          return 'At least 8 characters';
                        }
                        if (v == currentController.text) {
                          return 'New password must be different';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (v) => v != newController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          // Logging out is the only way out without changing.
                          await Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).logout();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('Log out'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setLocalState(() => busy = true);
                          try {
                            await ApiService.changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setLocalState(() => busy = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red.shade600,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(busy ? 'Saving…' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _rotationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.removeListener(_handleFieldFocusChange);
    _passwordFocus.removeListener(_handleFieldFocusChange);
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}


/// A premium, true-3D book rendered with a perspective transform.
///
/// The book is composed of three faces — the front cover, the bound spine
/// on the left, and a cream "pages" block along the top — assembled with
/// [Transform] rotations so it reads as a real object in space. Drive
/// [angleY] / [tiltX] from an animation controller to make it rotate and
/// float.
class _Book3D extends StatelessWidget {
  const _Book3D({
    required this.width,
    required this.height,
    required this.depth,
    required this.angleY,
    required this.tiltX,
    required this.cover,
  });

  final double width;
  final double height;
  final double depth;
  final double angleY;
  final double tiltX;
  final List<Color> cover;

  @override
  Widget build(BuildContext context) {
    final spineTop = Color.lerp(cover.first, Colors.black, 0.22)!;
    final spineBottom = Color.lerp(cover.last, Colors.black, 0.42)!;
    const pageColor = Color(0xFFF4ECD8);
    const pageShade = Color(0xFFD9CFB4);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0013) // perspective
        ..rotateX(tiltX)
        ..rotateY(angleY),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Spine (left bound edge, receding into depth) ──
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()..rotateY(-math.pi / 2),
                child: Container(
                  width: depth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [spineTop, spineBottom],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 2,
                      height: height * 0.5,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),

            // ── Page block (top edge, receding into depth) ──
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()..rotateX(math.pi / 2),
                child: Container(
                  height: depth,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [pageShade, pageColor, pageShade],
                    ),
                  ),
                ),
              ),
            ),

            // ── Front cover ──
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: cover,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3),
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(8, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Glossy diagonal highlight.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.12),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Binding accent line near the spine.
                  Positioned(
                    left: width * 0.12,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 1.5,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  // Cover artwork: title bars + emblem.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * 0.22,
                      height * 0.16,
                      width * 0.12,
                      height * 0.12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4,
                          width: width * 0.45,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 4,
                          width: width * 0.32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.auto_stories_rounded,
                          size: width * 0.34,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
