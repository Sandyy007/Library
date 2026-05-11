import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AboutContent extends StatefulWidget {
  const AboutContent({super.key});

  @override
  State<AboutContent> createState() => _AboutContentState();
}

class _AboutContentState extends State<AboutContent> with TickerProviderStateMixin {
  // Fixed color palette
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _sidebarDark = Color(0xFF0D2137);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _lightBlueAccent = Color(0xFFDEEAFB);
  static const Color _iconTeal = Color(0xFFE0F2F1);
  static const Color _iconOrange = Color(0xFFFBE9E7);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _secondaryBlue = Color(0xFF42A5F5);

  int? _hoveredFeatureIndex;
  int? _hoveredGalleryIndex;

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1100;
    final horizontalPadding = isWide ? 40.0 : 20.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Theme-aware colors
    final cardBg = isDark ? const Color(0xFF111C2D) : _cardBg;
    final textColor = isDark ? colorScheme.onSurface : _textDark;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : _textGrey;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(const Color(0xFF060D17), const Color(0xFF0A1628), _gradientAnimation.value)!,
                        Color.lerp(const Color(0xFF0A1628), const Color(0xFF0D2137), _gradientAnimation.value)!,
                        Color.lerp(const Color(0xFF060D17), const Color(0xFF0F2847), _gradientAnimation.value)!,
                      ]
                    : [
                        Color.lerp(const Color(0xFFEBF2F7), const Color(0xFFF5F9FC), _gradientAnimation.value)!,
                        Color.lerp(const Color(0xFFF5F9FC), const Color(0xFFE8F0F8), _gradientAnimation.value)!,
                        Color.lerp(const Color(0xFFE8F0F8), const Color(0xFFDEEAFB), _gradientAnimation.value)!,
                      ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Column(
        children: [
          // Top bar placeholder - keep existing
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: cardBg,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 20,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.library_books_rounded, color: _primaryBlue, size: 24),
                const SizedBox(width: 12),
                Text(
                  'About Us',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Developed under guidance highlight
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1E3A5F), const Color(0xFF0D2137)]
                                : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF1565C0) : const Color(0xFF1565C0)).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Developed under guidance of Mr. Vinod Kumar Yadav (Joint Director)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildHeroCard(context),
                      const SizedBox(height: 32),
                      _buildAboutTextCard(context),
                      const SizedBox(height: 32),
                      _buildCoreFeaturesSection(context),
                      const SizedBox(height: 32),
                      _buildOperationalExcellenceCard(context),
                      const SizedBox(height: 32),
                      _buildGallerySection(context),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HERO SECTION - 55/45 split layout
  // ═══════════════════════════════════════════
  Widget _buildHeroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111C2D) : _cardBg;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Gradient top border
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                    ? [const Color(0xFF5B8DEF), const Color(0xFF4ECDC4)]
                    : [_primaryBlue, _secondaryBlue],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isStacked = constraints.maxWidth < 700;
                  if (isStacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroText(context),
                        const SizedBox(height: 24),
                        _buildHeroImage(context),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 55, child: _buildHeroText(context)),
                      const SizedBox(width: 24),
                      Expanded(flex: 45, child: _buildHeroImage(context)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = isDark ? const Color(0xFF5B8DEF) : _primaryBlue;
    final lightAccent = isDark ? const Color(0xFF1E3A5F) : _lightBlueAccent;
    final textColor = isDark ? const Color(0xFFE2E8F0) : _sidebarDark;
    final textGrey = isDark ? const Color(0xFF94A3B8) : _textGrey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // UPSTTRI Badge - pill shape
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: lightAccent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryBlue, width: 1.5),
          ),
          child: Text(
            'UPSTTRI',
            style: TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Title - 32px, weight 800
        Text(
          'Uttar Pradesh State Tax Training and Research Institute',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        // Description - 15px
        SizedBox(
          width: 480,
          child: Text(
            'A dedicated environment for the professional development of tax officials, supported by a structured and resource-rich Library Management System.',
            style: TextStyle(
              fontSize: 15,
              color: textGrey,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Tags - styled chips with colored dot
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildTagChip(context, 'Structured Learning', _primaryBlue),
            _buildTagChip(context, 'Operational Transparency', const Color(0xFF059669)),
            _buildTagChip(context, 'Resource Accountability', const Color(0xFFD97706)),
          ],
        ),
      ],
    );
  }

  Widget _buildTagChip(BuildContext context, String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _lightBlueAccent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _sidebarDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return AnimatedScale(
      scale: _hoveredFeatureIndex == 0 ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/Lib1.jpeg',
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(seconds: 1),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Image load error: $error');
              debugPrint('Stack trace: $stackTrace');
              return Container(
                color: _lightBlueAccent,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: _primaryBlue.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image not loading',
                        style: TextStyle(color: _textGrey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'assets/images/Lib1.jpeg',
                        style: TextStyle(color: _textGrey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ABOUT TEXT SECTION - with left accent bar
  // ═══════════════════════════════════════════
  Widget _buildAboutTextCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111C2D) : _cardBg;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Gradient top border
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                    ? [const Color(0xFF5B8DEF), const Color(0xFF4ECDC4)]
                    : [_primaryBlue, _secondaryBlue],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading with left accent bar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'About the UPSTTRI Library Management System',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Body paragraphs - 14px, line-height 1.8
                  Text(
                    'The Uttar Pradesh State Tax Training and Research Institute (UPSTTRI) is committed to providing a structured and resource-rich environment for the professional development of tax officials. To support this, our specialized Library Management System (LMS) serves as the central administrative backbone for our physical book collection.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textGrey,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This system is designed to bridge the gap between traditional archival management and modern administrative efficiency, ensuring that every volume in our library is accounted for and accessible.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textGrey,
                      height: 1.8,
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

  // ═══════════════════════════════════════════
  // CORE FEATURES SECTION - 2x2 grid
  // ═══════════════════════════════════════════
  Widget _buildCoreFeaturesSection(BuildContext context) {
    final features = [
      {
        'icon': Icons.wifi_tethering,
        'title': 'Real-Time Physical Monitoring',
        'description': 'A comprehensive registry of every physical book, journal, and manual with instant stock visibility.',
        'bgColor': _lightBlueAccent,
        'iconColor': _primaryBlue,
      },
      {
        'icon': Icons.swap_horiz,
        'title': 'Seamless Issue & Return Workflow',
        'description': 'Streamlined circulation that automates issue and return tracking for clear custody.',
        'bgColor': _iconTeal,
        'iconColor': const Color(0xFF00897B),
      },
      {
        'icon': Icons.group,
        'title': 'Automated Member Management',
        'description': 'Centralized member profiles with borrowing history and status tracking.',
        'bgColor': _iconOrange,
        'iconColor': const Color(0xFFEF6C00),
      },
      {
        'icon': Icons.bar_chart,
        'title': 'Administrative Reporting',
        'description': 'Detailed analytics on usage, circulation trends, and pending returns.',
        'bgColor': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF7B1FA2),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading with blue underline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Core System Features',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 2x2 Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(features.length, (index) {
                final feature = features[index];
                return SizedBox(
                  width: cardWidth,
                  child: _buildFeatureCard(context, index, feature),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, int index, Map<String, dynamic> feature) {
    final isHovered = _hoveredFeatureIndex == index;
    final iconData = feature['icon'] as IconData;
    final title = feature['title'] as String;
    final description = feature['description'] as String;
    final bgColor = feature['bgColor'] as Color;
    final iconColor = feature['iconColor'] as Color;

    return MouseRegion(
      onEnter: (_) => _scheduleHover(index),
      onExit: (_) => _scheduleHover(null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isHovered ? _primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(isHovered ? 0x19000000 : 0x0D000000),
              blurRadius: isHovered ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Gradient top line
              Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryBlue, _secondaryBlue],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon in colored square
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconData, color: iconColor, size: 24),
                    ),
                    const SizedBox(height: 16),
                    // Title - 16px bold
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description - 13px
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textGrey,
                        height: 1.7,
                      ),
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

  // ═══════════════════════════════════════════
  // OPERATIONAL EXCELLENCE - left gradient bar
  // ═══════════════════════════════════════════
  Widget _buildOperationalExcellenceCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Left gradient bar
            Container(
              width: 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_sidebarDark, _primaryBlue],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading - 20px bold
                    const Text(
                      'Operational Excellence',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Body text - 14px
                    SizedBox(
                      width: 800,
                      child: Text(
                        'At UPSTTRI, we believe that organized knowledge is the foundation of effective administration. This LMS reflects our move toward paperless administration and enhanced operational transparency in academic facilities.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textGrey,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Address chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _lightBlueAccent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: _primaryBlue),
                          const SizedBox(width: 8),
                          const Text(
                            'Uttar Pradesh State Tax Training and Research Institute, Lucknow, Uttar Pradesh',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // GALLERY SECTION - 4x2 grid
  // ═══════════════════════════════════════════
  Widget _buildGallerySection(BuildContext context) {
    final galleryItems = [
      'assets/images/Lib1.jpeg',
      'assets/images/Lib2.jpeg',
      'assets/images/Lib3.jpeg',
      'assets/images/Lib4.jpeg',
      'assets/images/Lib5.jpeg',
      'assets/images/Lib6.jpeg',
      'assets/images/Lib7.jpeg',
      'assets/images/Lib8.jpeg',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading with blue underline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Library and Campus Gallery',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Gallery card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);
              final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(galleryItems.length, (index) {
                  return SizedBox(
                    width: itemWidth,
                    height: itemWidth * 0.75,
                    child: _buildGalleryItem(context, index, galleryItems[index]),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryItem(BuildContext context, int index, String assetPath) {
    final isHovered = _hoveredGalleryIndex == index;

    return AnimatedScale(
      scale: isHovered ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: MouseRegion(
        onEnter: (_) => _scheduleGalleryHover(index),
        onExit: (_) => _scheduleGalleryHover(null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Color(isHovered ? 0x2D000000 : 0x0D000000),
                blurRadius: isHovered ? 12 : 8,
                offset: Offset(0, isHovered ? 6 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Gallery image error: $error - $assetPath');
                return Container(
                  color: _lightBlueAccent,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_rounded,
                          color: _primaryBlue.withValues(alpha: 0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Image ${index + 1}',
                          style: TextStyle(
                            color: _textGrey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleHover(int? index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hoveredFeatureIndex = index);
    });
  }

  void _scheduleGalleryHover(int? index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hoveredGalleryIndex = index);
    });
  }
}