class LocalProfilePhoto {
  static final LocalProfilePhoto _instance = LocalProfilePhoto._internal();
  factory LocalProfilePhoto() => _instance;
  LocalProfilePhoto._internal();

  String? path;
}
