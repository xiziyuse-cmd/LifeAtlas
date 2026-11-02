import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/config/ai_service_config.dart';

void main() {
  test('release AI service defaults point to the HTTPS worker', () {
    expect(
      AiServiceConfig.clothingAnalysisProxyUrl,
      'https://lifeatlas-ai-proxy.xiziyuse.workers.dev/v1/wardrobe/analyze',
    );
    expect(
      AiServiceConfig.preorderAnalysisProxyUrl,
      'https://lifeatlas-ai-proxy.xiziyuse.workers.dev/v1/wardrobe/preorder-analysis',
    );
    expect(
      AiServiceConfig.authBaseUrl,
      'https://lifeatlas-ai-proxy.xiziyuse.workers.dev/v1/auth',
    );
  });
}
