import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/screens/new_career/wizard_kit.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Adım 1 · Kimlik: ad/soyad ve milliyet.
class IdentityStep extends StatelessWidget {
  const IdentityStep({
    super.key,
    required this.options,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.showErrors,
    required this.onChanged,
    required this.onNationality,
  });

  final api.CareerOptions options;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final String? nationality;
  final bool showErrors;
  final VoidCallback onChanged;
  final ValueChanged<String> onNationality;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const StepIntro(
          eyebrow: 'ADIM 1 / 4',
          title: 'Kim olacaksın?',
          subtitle:
              'Milliyet yalnızca bir etiket değil: başlangıç kulübün, '
              'seçtiğin ülkenin en alt liginden atanır.',
        ),
        _NameField(
          label: 'Ad',
          hint: 'Efe',
          controller: firstName,
          error: showErrors && firstName.text.trim().isEmpty
              ? 'Ad boş bırakılamaz.'
              : null,
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
        _NameField(
          label: 'Soyad',
          hint: 'Kaan',
          controller: lastName,
          error: showErrors && lastName.text.trim().isEmpty
              ? 'Soyad boş bırakılamaz.'
              : null,
          onChanged: onChanged,
        ),
        const SizedBox(height: 20),
        const _FieldLabel(label: 'Milliyet'),
        const SizedBox(height: 8),
        for (final country in options.nationalities) ...[
          SelectCard(
            selected: country.countryCode == nationality,
            onTap: () => onNationality(country.countryCode),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${country.nationality} · ${country.countryCode}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (country.countryCode == nationality)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.accent,
                    size: 18,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
      ],
    );
  }
}

/// Uygulamadaki ilk metin girişi; koyu temaya uygun tek bir alan tanımı.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.error,
    required this.onChanged,
  });

  /// Motorun `MAX_NAME_LENGTH`'i (onboarding.py) — sunucu da 422 ile
  /// koruyor, alan kullanıcıyı oraya hiç düşürmesin diye kırpıyor.
  static const _maxLength = 40;

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: error == null ? AppColors.border : AppColors.danger,
        width: 0.5,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label: label,
          trailing: '${controller.text.characters.length}/$_maxLength',
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLength: _maxLength,
          buildCounter:
              (
                _, {
                required int currentLength,
                required bool isFocused,
                int? maxLength,
              }) => null,
          textCapitalization: TextCapitalization.words,
          cursorColor: AppColors.accent,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface1,
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: border,
            border: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
