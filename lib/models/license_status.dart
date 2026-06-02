class LicenseStatus {
  final String deviceCode;
  final DateTime? trialStartDate;
  final DateTime? trialEndsAt;
  final bool isTrialActive;
  final int trialDaysRemaining;
  final bool isActivated;
  final DateTime? licenseExpiry;
  final bool isLifetime;
  final String licensePayload;

  const LicenseStatus({
    required this.deviceCode,
    this.trialStartDate,
    this.trialEndsAt,
    this.isTrialActive = false,
    this.trialDaysRemaining = 0,
    this.isActivated = false,
    this.licenseExpiry,
    this.isLifetime = false,
    this.licensePayload = '',
  });

  bool get isExpired => !isTrialActive && !isActivated;

  factory LicenseStatus.fromMap(Map<String, dynamic> map) {
    return LicenseStatus(
      deviceCode: map['device_code'] as String? ?? '',
      trialStartDate: map['trial_start_date'] != null ? DateTime.tryParse(map['trial_start_date'] as String) : null,
      trialEndsAt: map['trial_ends_at'] != null ? DateTime.tryParse(map['trial_ends_at'] as String) : null,
      isTrialActive: map['is_trial_active'] == true,
      trialDaysRemaining: map['trial_days_remaining'] as int? ?? 0,
      isActivated: map['is_activated'] == true,
      licenseExpiry: map['license_expiry'] != null ? DateTime.tryParse(map['license_expiry'] as String) : null,
      isLifetime: map['is_lifetime'] == true,
      licensePayload: map['license_payload'] as String? ?? '',
    );
  }
}
