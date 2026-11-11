import 'package:flutter/material.dart';
import '../../../i18n/licenses_strings.dart';

/// Settings > About Application > View Licenses.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = LicensesStrings.of(context);
    final primary = theme.colorScheme.primary;
    final body = theme.textTheme.bodyMedium?.copyWith(color: Colors.black);
    final bold = body?.copyWith(fontWeight: FontWeight.bold);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(color: primary),
      ),
    );

    Widget bullet(Widget child, {double indent = 0}) => Padding(
      padding: EdgeInsets.only(left: indent, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: body),
          Expanded(child: child),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(s.viewLicenses),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.title,
                style: theme.textTheme.titleLarge?.copyWith(color: primary),
              ),
              const SizedBox(height: 10),
              Text(s.intro, style: body),
              heading(s.whyTitle),
              Text(s.whyIntro, style: body),
              for (final b in s.whyBullets)
                bullet(
                  Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        TextSpan(text: '${b.lead} ', style: bold),
                        TextSpan(text: b.text),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text(s.appVersion, style: bold),
              heading(s.stackTitle),
              for (final tech in s.technologies) ...[
                bullet(Text(tech.name, style: bold)),
                bullet(
                  Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        TextSpan(text: '${s.whatItIsLabel} ', style: bold),
                        TextSpan(text: tech.whatItIs),
                      ],
                    ),
                  ),
                  indent: 22,
                ),
                bullet(
                  Text.rich(
                    TextSpan(
                      style: body,
                      children: [
                        TextSpan(text: '${s.purposeLabel} ', style: bold),
                        TextSpan(text: tech.purpose),
                      ],
                    ),
                  ),
                  indent: 22,
                ),
                if (tech.keyServices.isNotEmpty) ...[
                  bullet(Text(s.keyServicesLabel, style: bold), indent: 22),
                  for (final service in tech.keyServices)
                    bullet(
                      Text.rich(
                        TextSpan(
                          style: body,
                          children: [
                            TextSpan(text: '${service.$1} ', style: bold),
                            TextSpan(text: service.$2),
                          ],
                        ),
                      ),
                      indent: 44,
                    ),
                ],
                const SizedBox(height: 8),
              ],
              heading(s.liabilityTitle),
              Text(s.liabilityBody, style: body),
            ],
          ),
        ),
      ),
    );
  }
}
