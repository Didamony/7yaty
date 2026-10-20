import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/updates.dart';

/// "There's a new update" across the top of every screen, with a button
/// that downloads the new APK to install over this one.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Updates.instance,
      builder: (context, _) {
        final u = Updates.instance;
        final update = u.available;
        if (update == null || u.dismissed) return const SizedBox.shrink();
        final p = Theme.of(context).extension<Palette>()!;
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12,
          right: 12,
          child: Material(
            color: p.card,
            elevation: 6,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: p.gold, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.system_update, color: p.goldText),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('فيه تحديث جديد'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        Text(
                          tr(
                            'نزّله وسطّبه فوق القديم، وبياناتك هتفضل زي ما هي.',
                          ),
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => launchUrl(
                      Uri.parse(update.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(tr('حدّث')),
                  ),
                  IconButton(
                    tooltip: tr('بعدين'),
                    onPressed: u.dismiss,
                    icon: Icon(Icons.close, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
