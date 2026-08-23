/// Non-secret AI service configuration supplied at Flutter build/run time.
///
/// The Volcano Ark API key must never be provided to this client. It belongs
/// in the proxy server's `ARK_API_KEY` environment variable.
abstract final class AiServiceConfig {
  static const clothingAnalysisProxyUrl = String.fromEnvironment(
    'LIFEATLAS_AI_PROXY_URL',
  );

  static const preorderAnalysisProxyUrl = String.fromEnvironment(
    'LIFEATLAS_TEXT_AI_PROXY_URL',
  );

  static const authBaseUrl = String.fromEnvironment(
    'LIFEATLAS_AI_AUTH_BASE_URL',
  );
}
