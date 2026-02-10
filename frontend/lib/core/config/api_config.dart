class ApiConfig {
  static String _baseUrl =
      'https://qjhcp0ph-3000.inc1.devtunnels.ms'; // Local Network IP (Dynamic)

  static String get baseUrl => _baseUrl;

  static String get sttUrl {
    // Handle DevTunnels: Replace port 3000 in subdomain with 8000
    if (_baseUrl.contains('devtunnels.ms')) {
      // e.g. https://xyz-3000.devtunnels.ms -> wss://xyz-8000.devtunnels.ms/listen
      return _baseUrl
              .replaceFirst('3000', '8000')
              .replaceFirst('https', 'wss')
              .replaceFirst('http', 'ws') +
          '/listen';
    }

    // Handle Localhost/IP: Replace port 3000 with 8000
    if (_baseUrl.contains(':3000')) {
      return _baseUrl.replaceFirst('3000', '8000').replaceFirst('http', 'ws') +
          '/listen';
    }

    // Fallback
    return 'ws://10.0.2.2:8000/listen';
  }

  static String get sttHealthUrl {
    // For DevTunnels: use https, for local use http
    if (_baseUrl.contains('devtunnels.ms')) {
      // https://xyz-3000.devtunnels.ms -> https://xyz-8000.devtunnels.ms/health
      return _baseUrl.replaceFirst('3000', '8000') + '/health';
    }
    // For local: derive from sttUrl
    final url = sttUrl;
    return url
        .replaceFirst('wss', 'https')
        .replaceFirst('ws', 'http')
        .replaceFirst('/listen', '/health');
  }

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }
}
