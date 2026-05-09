import 'dart:math' as math;
import 'package:flutter/material.dart';

class AboutContent extends StatefulWidget {
  const AboutContent({super.key});

  @override
  State<AboutContent> createState() => _AboutContentState();
}

class _AboutContentState extends State<AboutContent>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _revealController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1100;
    final horizontalPadding = isWide ? 40.0 : 20.0;

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = _floatController.value;
        final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t);
        final topColor = Color.lerp(
          cs.surface,
          cs.primary.withValues(alpha: 0.08),
          pulse,
        )!;
        final bottomColor = Color.lerp(
          cs.surface,
          cs.secondary.withValues(alpha: 0.14),
          1 - pulse,
        )!;
        final floatOffset = 10 * math.sin(2 * math.pi * t);

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topColor, bottomColor],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DotGridPainter(
                    color: cs.primary.withValues(alpha: 0.04),
                    spacing: 28,
                    radius: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -140,
              left: -120,
              child: Transform.translate(
                offset: Offset(20 * math.cos(2 * math.pi * t), 0),
                child: _GlowOrb(
                  size: 280,
                  colors: [
                    cs.primary.withValues(alpha: 0.25),
                    cs.secondary.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -160,
              right: -140,
              child: Transform.translate(
                offset: Offset(0, 18 * math.sin(2 * math.pi * t)),
                child: _GlowOrb(
                  size: 320,
                  colors: [
                    cs.secondary.withValues(alpha: 0.22),
                    cs.primary.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReveal(
                        order: 0,
                        child: _buildHero(context, isWide, floatOffset),
                      ),
                      const SizedBox(height: 20),
                      _buildReveal(order: 1, child: _buildAboutCard(context)),
                      const SizedBox(height: 20),
                      _buildReveal(
                        order: 2,
                        child: _buildObjectiveImpactSection(context),
                      ),
                      const SizedBox(height: 20),
                      _buildReveal(
                        order: 3,
                        child: _buildFocusSection(context),
                      ),
                      const SizedBox(height: 20),
                      _buildReveal(
                        order: 4,
                        child: _buildOperationalExcellence(context),
                      ),
                      const SizedBox(height: 20),
                      _buildReveal(
                        order: 5,
                        child: _buildGallery(context),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, bool isWide, double floatOffset) {
    final cs = Theme.of(context).colorScheme;
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT US',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.2,
              ),
        ),
        const SizedBox(height: 10),
        _buildGradientTitle(
          context,
          'Uttar Pradesh State Tax Training and Research Institute',
        ),
        const SizedBox(height: 12),
        Text(
          'A dedicated environment for the professional development of tax officials, supported by a structured and resource-rich Library Management System.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPill(context, 'Structured Learning'),
            _buildPill(context, 'Operational Transparency'),
            _buildPill(context, 'Resource Accountability'),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );

    final heroImage = Transform.translate(
      offset: Offset(0, floatOffset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                'assets/images/Lib1.jpeg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );

    final heroCard = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surface.withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: textBlock),
                const SizedBox(width: 20),
                Expanded(child: heroImage),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textBlock,
                const SizedBox(height: 16),
                heroImage,
              ],
            ),
    );

    return heroCard;
  }

  Widget _buildAboutCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the UPSTTRI Library Management System',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'The Uttar Pradesh State Tax Training and Research Institute (UPSTTRI) is committed to providing a structured and resource-rich environment for the professional development of tax officials. To support this, our specialized Library Management System (LMS) serves as the central administrative backbone for our physical book collection.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'This system is designed to bridge the gap between traditional archival management and modern administrative efficiency, ensuring that every volume in our library is accounted for and accessible.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.12),
                  cs.secondary.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Developed under guidance of Mr. Vinod Yadav (Joint Commissioner).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Core System Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 1200
                ? (constraints.maxWidth - 42) / 4
                : constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth;

            final cards = [
              _buildFocusCard(
                context,
                width: cardWidth,
                title: 'Real-Time Physical Monitoring',
                description:
                    'A comprehensive registry of every physical book, journal, and manual with instant stock visibility.',
                icon: Icons.track_changes_rounded,
              ),
              _buildFocusCard(
                context,
                width: cardWidth,
                title: 'Seamless Issue & Return Workflow',
                description:
                    'Streamlined circulation that automates issue and return tracking for clear custody.',
                icon: Icons.swap_horiz_rounded,
              ),
              _buildFocusCard(
                context,
                width: cardWidth,
                title: 'Automated Member Management',
                description:
                    'Centralized member profiles with borrowing history and status tracking.',
                icon: Icons.people_alt_rounded,
              ),
              _buildFocusCard(
                context,
                width: cardWidth,
                title: 'Administrative Reporting',
                description:
                    'Detailed analytics on usage, circulation trends, and pending returns.',
                icon: Icons.analytics_rounded,
              ),
            ];

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  Widget _buildObjectiveImpactSection(BuildContext context) {
    final left = _buildSectionCard(
      context,
      title: 'Our Objective',
      body:
          'Provide a robust, transparent, and automated framework for the circulation of physical literature by digitizing inventory and member records with precision and accountability.',
    );
    final right = _buildSectionCard(
      context,
      title: 'Institutional Impact',
      body:
          'Supports a culture of discipline and continuous learning by ensuring the right reference materials reach officers who need them most.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purpose and Impact',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 860;
            if (isStacked) {
              return Column(
                children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOperationalExcellence(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational Excellence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'At UPSTTRI, we believe that organized knowledge is the foundation of effective administration. This LMS reflects our move toward paperless administration and enhanced operational transparency in academic facilities.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.primary.withValues(alpha: 0.08),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Uttar Pradesh State Tax Training and Research Institute\nLucknow, Uttar Pradesh',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1200
        ? 4
        : screenWidth >= 900
            ? 3
            : screenWidth >= 600
                ? 2
                : 1;

    final items = [
      _GalleryItem('assets/images/Lib1.jpeg', 'Library view'),
      _GalleryItem('assets/images/Lib2.jpeg', 'Reading hall'),
      _GalleryItem('assets/images/Lib3.jpeg', 'Training workspace'),
      _GalleryItem('assets/images/Lib4.jpeg', 'Seminar session'),
      _GalleryItem('assets/images/Lib5.jpeg', 'Knowledge resources'),
      _GalleryItem('assets/images/Lib6.jpeg', 'Reference section'),
      _GalleryItem('assets/images/Lib7.jpeg', 'Campus snapshot'),
      _GalleryItem('assets/images/Lib8.jpeg', 'Learning environment'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Library and Campus Gallery',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 1.6 : 1.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final animation = CurvedAnimation(
              parent: _revealController,
              curve: Interval(0.3 + index * 0.05, 1, curve: Curves.easeOut),
            );

            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(item.assetPath, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFocusCard(
    BuildContext context, {
    required double width,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildGradientTitle(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [cs.primary, cs.secondary],
      ).createShader(bounds),
      child: Text(
        text,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
      ),
    );
  }

  Widget _buildStatStrip(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatChip(
          icon: Icons.event_available_rounded,
          label: 'Year-round training calendar',
        ),
        _StatChip(
          icon: Icons.insights_rounded,
          label: 'Policy notes and research briefs',
        ),
        _StatChip(
          icon: Icons.laptop_chromebook_rounded,
          label: 'Classroom and hybrid delivery',
        ),
      ],
    );
  }

  Widget _buildReveal({required int order, required Widget child}) {
    final animation = CurvedAnimation(
      parent: _revealController,
      curve: Interval(0.08 * order, 1, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _GalleryItem {
  const _GalleryItem(this.assetPath, this.label);

  final String assetPath;
  final String label;
}
