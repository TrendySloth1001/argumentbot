class ApiConfig {
  static String _baseUrl = 'http://192.168.0.35:3000'; // Local Network IP

  static String get baseUrl => _baseUrl;

  static String get sttUrl {
    // Handle DevTunnels: Replace port 3000 in subdomain with 8000
    if (_baseUrl.contains('devtunnels.ms')) {
      // e.g. https://xyz-3000.devtunnels.ms -> wss://xyz-8000.devtunnels.ms
      return _baseUrl.replaceFirst('3000', '8000').replaceFirst('http', 'ws');
    }

    // Handle Localhost/IP: Replace port 3000 with 8000
    if (_baseUrl.contains(':3000')) {
      return _baseUrl.replaceFirst('3000', '8000').replaceFirst('http', 'ws');
    }

    // Fallback
    return 'ws://10.0.2.2:8000/listen';
  }

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }
}
