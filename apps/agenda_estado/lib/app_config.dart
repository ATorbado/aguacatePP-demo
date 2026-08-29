class AppConfig {
  final Uri? backendUri;
  final String apiToken;
  final bool demoMode;

  const AppConfig({
    required this.backendUri,
    required this.apiToken,
    this.demoMode = false,
  });

  factory AppConfig.fromEnvironment() {
    const backendUrl = String.fromEnvironment('AGENDA_BACKEND_URL');
    const apiToken = String.fromEnvironment('AGENDA_API_TOKEN');
    const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

    return AppConfig(
      backendUri: Uri.tryParse(backendUrl.trim()),
      apiToken: apiToken.trim(),
      demoMode: demoMode,
    );
  }

  String? get validationError {
    if (demoMode) return null;
    final uri = backendUri;
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      return 'Falta una URL HTTPS válida para el servidor.';
    }
    if (apiToken.length < 16) {
      return 'Falta la credencial de acceso al servidor.';
    }
    return null;
  }

  bool get isValid => validationError == null;
}
