import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import 'neu.dart';
import 'tokens.dart';

/// Shared frame for a module's root page: large title, profile shortcut and,
/// optionally, the module's own add button.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.module,
    required this.title,
    required this.body,
    this.subtitle,
    this.addLabel,
    this.addPageBuilder,
  });

  final LbModule module;
  final String title;
  final String? subtitle;
  final Widget body;

  /// When set, a floating add button opens this module's own add page.
  final String? addLabel;
  final WidgetBuilder? addPageBuilder;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: t.onBase,
                          ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: t.muted, fontWeight: FontWeight.w600)),
                ]),
              ),
              const ProfileButton(),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
      floatingActionButton: addPageBuilder == null
          ? null
          : Padding(
              // Scaffold places the FAB by viewPadding, which ignores the
              // floating nav bar the shell reports through padding.
              padding: EdgeInsets.only(
                bottom: (MediaQuery.paddingOf(context).bottom - MediaQuery.viewPaddingOf(context).bottom)
                    .clamp(0, double.infinity),
              ),
              child: _AddButton(module: module, label: addLabel ?? 'Ekle', builder: addPageBuilder!),
            ),
    );
  }
}

/// List padding that clears the floating nav bar and the add button.
EdgeInsets moduleListPadding(BuildContext context, {bool hasAddButton = false}) => EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.paddingOf(context).bottom + (hasAddButton ? 96 : 24),
    );

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) => NeuButton(
        semanticLabel: 'Hesap ve ayarlar',
        radius: 24,
        padding: const EdgeInsets.all(12),
        onPressed: () => context.push(AppRoutes.account),
        child: const Icon(Icons.person_rounded, size: 22),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.module, required this.label, required this.builder});

  final LbModule module;
  final String label;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final color = t.module(module);
    final reduce = t.reduceMotion || MediaQuery.disableAnimationsOf(context);
    return OpenContainer(
      key: ValueKey('add-${module.name}'),
      // Stay inside this tab's navigator so back returns to the module.
      useRootNavigator: false,
      transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 380),
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      openElevation: 0,
      closedColor: color,
      openColor: t.base,
      middleColor: t.base,
      closedShape: const StadiumBorder(),
      tappable: false,
      closedBuilder: (context, open) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: open,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: t.onAccent),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: t.onAccent, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
      openBuilder: (context, _) => builder(context),
    );
  }
}
