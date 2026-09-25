// ============================================================
// state/app_state.dart
//
// Simple, reliable app-wide state using ValueNotifier.
//
// WHY ValueNotifier instead of InheritedWidget:
//   InheritedWidget lookups (context.dependOnInheritedWidgetOfExactType)
//   only walk UP the current route's element tree. When a screen is
//   pushed via Navigator.push, its BuildContext is a NEW subtree inside
//   MaterialApp's navigator overlay — it CANNOT see InheritedWidgets
//   that are ancestors of MaterialApp itself. This is the exact bug
//   that broke persona propagation.
//
//   ValueNotifier is a plain Dart object. It is passed explicitly to
//   every screen that needs it, so it works regardless of where those
//   screens appear in the navigator stack.
//
// Usage:
//   Read current value : appPersona.value
//   Change persona     : appPersona.value = Persona.student
//   React to changes   : ValueListenableBuilder<Persona>(
//                          valueListenable: appPersona,
//                          builder: (context, persona, _) { ... },
//                        )
// ============================================================

import 'package:flutter/material.dart';

import '../models/persona.dart';

/// Single source of truth for the selected persona.
/// Created once in main.dart and passed down explicitly.
class AppPersonaNotifier extends ValueNotifier<Persona> {
  AppPersonaNotifier() : super(Persona.farmer);
}
