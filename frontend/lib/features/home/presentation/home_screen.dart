/// Home / landing screen — full marketing homepage for IMS.
library;

import 'package:flutter/material.dart';

import 'widgets/benefits_section.dart';
import 'widgets/cta_section.dart';
import 'widgets/features_section.dart';
import 'widgets/footer_section.dart';
import 'widgets/hero_section.dart';
import 'widgets/how_it_works_section.dart';
import 'widgets/testimonials_section.dart';

/// Marketing landing page shown to unauthenticated visitors.
///
/// Assembles all homepage sections into a [CustomScrollView] using
/// [SliverToBoxAdapter] wrappers. Hero and CTA sections use full-width
/// gradient containers; all other sections use the shared [_SectionWrapper].
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: HeroSection()),
          SliverToBoxAdapter(child: FeaturesSection()),
          SliverToBoxAdapter(child: HowItWorksSection()),
          SliverToBoxAdapter(child: BenefitsSection()),
          SliverToBoxAdapter(child: TestimonialsSection()),
          SliverToBoxAdapter(child: CtaSection()),
          SliverToBoxAdapter(child: FooterSection()),
        ],
      ),
    );
  }
}
