import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_ext.dart';
import '../theme/cafe_theme.dart';

/// What one version added and fixed, in the words the cafe reads.
class ReleaseNotes {
  const ReleaseNotes({this.added = const [], this.fixed = const []});

  final List<String> added;
  final List<String> fixed;
}

/// The notes of each version that has any, by version and then language. Add the next version's
/// notes here before its release; a version without notes shows no popup.
const Map<String, Map<String, ReleaseNotes>> releaseNotes = {
  '2.8.6': {
    'en': ReleaseNotes(
      added: [
        'Running the setup again lets you reset the offline admin PIN',
      ],
      fixed: [
        'A wrong offline PIN now says "Wrong PIN"',
        'The settings card is now called "Ordering online"',
      ],
    ),
    'ar': ReleaseNotes(
      added: [
        'إعادة تشغيل الإعداد تتيح إعادة تعيين رمز المدير دون إنترنت',
      ],
      fixed: [
        'الرمز الخاطئ دون إنترنت يظهر الآن "الرمز غير صحيح"',
        'أصبح اسم بطاقة الإعدادات "الطلب عبر الإنترنت"',
      ],
    ),
  },
  '2.8.5': {
    'en': ReleaseNotes(
      added: [
        'Offline, the admin signs in with a PIN of any length',
        'Offline, waiters use the phone app with no sign-in',
        'Settings shows only the features this cafe uses',
      ],
      fixed: [
        'The guest menu address no longer shows in cafe info',
      ],
    ),
    'ar': ReleaseNotes(
      added: [
        'دون إنترنت، يدخل المدير برمز من أي طول',
        'دون إنترنت، يستخدم النُدُل تطبيق الهاتف دون تسجيل دخول',
        'تعرض الإعدادات الميزات التي يستخدمها المقهى فقط',
      ],
      fixed: [
        'لم يعد عنوان قائمة الزبائن يظهر في معلومات المقهى',
      ],
    ),
  },
};

/// The notes for [version] in [locale] (English when there are none in it), or null.
ReleaseNotes? releaseNotesFor(String version, String locale) {
  final byLanguage = releaseNotes[version];
  if (byLanguage == null) return null;
  return byLanguage[locale] ?? byLanguage['en'];
}

/// Who the popup is for: the till after it starts, and the admin when they reach the console.
/// Each sees each version's notes once, on this device.
enum WhatsNewAudience { till, admin }

/// Shows this version's notes once for [audience]. Nothing shows on a fresh install
/// ([updated] false: there is no earlier version to compare with), for a version without notes,
/// or where the version can't be read.
Future<void> showWhatsNewOnce(BuildContext context, WhatsNewAudience audience, {required bool updated}) async {
  final String version;
  final SharedPreferences prefs;
  try {
    version = (await PackageInfo.fromPlatform()).version;
    prefs = await SharedPreferences.getInstance();
  } on PlatformException {
    return;
  } on MissingPluginException {
    return;
  }
  final key = 'whatsNewSeen.${audience.name}';
  if (prefs.getString(key) == version) return;
  await prefs.setString(key, version);
  if (!updated || !context.mounted) return;
  final notes = releaseNotesFor(version, Localizations.localeOf(context).languageCode);
  if (notes == null) return;
  await showDialog<void>(context: context, builder: (_) => WhatsNewDialog(version: version, notes: notes));
}

/// The popup: what the update added, what it fixed, and one button to close it.
class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key, required this.version, required this.notes});

  final String version;
  final ReleaseNotes notes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget section(String title, Color color, IconData icon, List<String> lines) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: const TextStyle(fontSize: 14, height: 1.4, color: CafeColors.ink))),
                  ],
                ),
              ),
          ],
        );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: CafeColors.peach, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome_outlined, color: CafeColors.terracottaDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.whatsNewTitle(version), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CafeColors.ink)),
                  ),
                ],
              ),
              if (notes.added.isNotEmpty) section(l10n.whatsNewAdded, CafeColors.success, Icons.add, notes.added),
              if (notes.fixed.isNotEmpty) section(l10n.whatsNewFixed, CafeColors.terracottaDark, Icons.check, notes.fixed),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text(l10n.whatsNewGotIt, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts [child] on screen and, once it is up, shows the update notes for [audience] if due.
class WhatsNewGate extends StatefulWidget {
  const WhatsNewGate({super.key, required this.audience, required this.updated, required this.child});

  final WhatsNewAudience audience;

  /// Whether this install existed before this start (a fresh install has nothing new to show).
  final bool updated;
  final Widget child;

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWhatsNewOnce(context, widget.audience, updated: widget.updated);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
