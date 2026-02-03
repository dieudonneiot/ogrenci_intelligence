import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

const appLocaleStorageKey = 'app_locale';

Locale? parseStoredLocale(String raw) {
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) return Locale(parts[0], parts[1]);
  }
  if (raw.contains('_')) {
    final parts = raw.split('_');
    if (parts.length >= 2) return Locale(parts[0], parts[1]);
  }
  if (raw.trim().isEmpty) return null;
  return Locale(raw);
}

String serializeLocale(Locale locale) {
  final country = locale.countryCode;
  if (country == null || country.isEmpty) return locale.languageCode;
  return '${locale.languageCode}-$country';
}

Future<Locale?> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(appLocaleStorageKey);
  if (raw == null) return null;
  return parseStoredLocale(raw.trim());
}

final initialLocaleProvider = Provider<Locale?>((ref) => null);

class LocaleController extends StateNotifier<Locale> {
  LocaleController({required Locale? initialLocale})
      : super(_supportedOrFallback(initialLocale ?? _deviceLocale())) {
    // If main() provided an initial locale, we skip async load to avoid flicker.
    if (initialLocale == null) {
      _loadSavedLocale();
    }
  }

  static Locale _deviceLocale() => WidgetsBinding.instance.platformDispatcher.locale;

  static Locale _supportedOrFallback(Locale locale) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode &&
          (supported.countryCode == null || supported.countryCode == locale.countryCode)) {
        return supported;
      }
    }
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return AppLocalizations.supportedLocales.first;
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(appLocaleStorageKey);
    if (raw == null || raw.trim().isEmpty) return;
    final parsed = parseStoredLocale(raw.trim());
    if (parsed != null) {
      state = _supportedOrFallback(parsed);
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = _supportedOrFallback(locale);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appLocaleStorageKey, serializeLocale(next));
  }

  Future<void> setLocaleByCode(String code) async {
    await setLocale(Locale(code));
  }
}

final appLocaleProvider = StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(initialLocale: ref.watch(initialLocaleProvider)),
);
