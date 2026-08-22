import http from 'node:http';

const host = process.env.HOST?.trim() || '127.0.0.1';
const port = Number.parseInt(process.env.PORT || '8787', 10);
const arkApiKey = process.env.ARK_API_KEY?.trim() || '';
const proxyAccessToken = process.env.LIFEATLAS_PROXY_TOKEN?.trim() || '';
const model = process.env.ARK_MODEL?.trim() || 'doubao-seed-2-1-pro-260628';
const arkBaseUrl = (
  process.env.ARK_BASE_URL?.trim() ||
  'https://ark.cn-beijing.volces.com/api/v3'
).replace(/\/$/, '');

const maximumRequestBytes = 15 * 1024 * 1024;
const maximumImageBytes = 10 * 1024 * 1024;
const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

const prompt = `你是 LifeAtlas 的衣服图片参数提取器。分析用户提供的单张衣服照片、商品截图、吊牌或尺码表，只返回一个 JSON 对象，不要 Markdown，不要解释。

输出必须严格使用以下字段；看不到或不能确定时填 null，季节看不到时填空数组：
{
  "name": string|null,
  "brand": string|null,
  "category": "外套"|"内搭"|"上衣"|"长裤"|"短裤"|"裙装"|"鞋"|"包"|"饰品"|null,
  "seasonTags": ("春"|"夏"|"秋"|"冬")[],
  "color": string|null,
  "material": string|null,
  "size": string|null,
  "measurements": {
    "clothingLength": number|null,
    "shoulderWidth": number|null,
    "chestCircumference": number|null,
    "sleeveLength": number|null,
    "waistCircumference": number|null,
    "hipCircumference": number|null,
    "trouserLength": number|null
  }
}

规则：
1. 尺寸数字统一为厘米，只提取图片文字明确标注的数值。
2. 普通实物照片没有尺子或尺寸表时，禁止猜测衣长、胸围等精确数值。
3. 区分平铺宽度和围度；只有图片明确写胸围/腰围/臀围时才填对应围度。写“胸宽”时不得直接当作胸围，无法确认换算口径就填 null。
4. 品牌、材质和尺码优先读取图片文字；无法可靠判断时填 null。
5. 同一图片包含多个尺码时，只在图片明确指出所选尺码时填写尺寸，否则尺寸字段填 null。
6. seasonTags 最多三个，不要输出 JSON 以外的任何字符。`;

const server = http.createServer(async (request, response) => {
  setSecurityHeaders(response);

  if (request.method === 'GET' && request.url === '/health') {
    return sendJson(response, 200, { status: 'ok', model });
  }

  if (request.method !== 'POST' || request.url !== '/v1/wardrobe/analyze') {
    return sendJson(response, 404, { message: '接口不存在' });
  }

  if (!arkApiKey) {
    return sendJson(response, 503, { message: '代理服务器尚未配置 ARK_API_KEY' });
  }

  if (proxyAccessToken) {
    const authorization = request.headers.authorization || '';
    if (authorization !== `Bearer ${proxyAccessToken}`) {
      return sendJson(response, 401, { message: '图片识别服务鉴权失败' });
    }
  }

  try {
    const body = await readJsonBody(request);
    const mimeType = typeof body.mimeType === 'string' ? body.mimeType : '';
    const imageBase64 =
      typeof body.imageBase64 === 'string' ? body.imageBase64 : '';

    if (!allowedMimeTypes.has(mimeType) || !imageBase64) {
      return sendJson(response, 400, { message: '图片格式不受支持' });
    }
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(imageBase64)) {
      return sendJson(response, 400, { message: '图片数据无效' });
    }
    const imageBytes = Buffer.from(imageBase64, 'base64');
    if (imageBytes.length === 0 || imageBytes.length > maximumImageBytes) {
      return sendJson(response, 413, { message: '图片为空或超过 10 MB' });
    }

    const arkResult = await requestArk({ mimeType, imageBase64 });
    const normalized = normalizeResult(extractModelJson(arkResult));
    return sendJson(response, 200, {
      result: normalized,
      model: arkResult.model || model,
      usage: arkResult.usage || null,
    });
  } catch (error) {
    const status = Number.isInteger(error?.status) ? error.status : 500;
    const safeStatus = status >= 400 && status < 600 ? status : 500;
    const message =
      typeof error?.publicMessage === 'string'
        ? error.publicMessage
        : '图片识别服务暂时不可用';
    return sendJson(response, safeStatus, { message });
  }
});

server.listen(port, host, () => {
  console.log(`LifeAtlas Doubao proxy listening on http://${host}:${port}`);
  console.log(`Model: ${model}`);
});

async function requestArk({ mimeType, imageBase64 }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90_000);
  try {
    const response = await fetch(`${arkBaseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${arkApiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image_url',
                image_url: {
                  url: `data:${mimeType};base64,${imageBase64}`,
                  detail: 'high',
                },
              },
            ],
          },
        ],
        temperature: 0.1,
        max_tokens: 1200,
        response_format: { type: 'json_object' },
      }),
      signal: controller.signal,
    });

    const responseText = await response.text();
    let decoded;
    try {
      decoded = JSON.parse(responseText);
    } catch {
      throw publicError(502, '火山方舟返回了无法解析的响应');
    }

    if (!response.ok) {
      if (response.status === 401 || response.status === 403) {
        throw publicError(502, '火山方舟 API Key 无效或没有模型权限');
      }
      if (response.status === 429) {
        throw publicError(429, '模型请求过于频繁或额度不足，请稍后重试');
      }
      throw publicError(502, '火山方舟模型调用失败');
    }
    return decoded;
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw publicError(504, '火山方舟模型响应超时');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function extractModelJson(response) {
  const content = response?.choices?.[0]?.message?.content;
  const text = Array.isArray(content)
    ? content
        .filter((item) => item?.type === 'text' && typeof item.text === 'string')
        .map((item) => item.text)
        .join('')
    : content;

  if (typeof text !== 'string' || !text.trim()) {
    throw publicError(502, '模型没有返回识别结果');
  }

  const normalized = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  const start = normalized.indexOf('{');
  const end = normalized.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw publicError(502, '模型返回结果不是有效 JSON');
  }
  try {
    return JSON.parse(normalized.slice(start, end + 1));
  } catch {
    throw publicError(502, '模型返回结果不是有效 JSON');
  }
}

function normalizeResult(value) {
  const source = value && typeof value === 'object' ? value : {};
  const measurements =
    source.measurements && typeof source.measurements === 'object'
      ? source.measurements
      : {};
  const categories = new Set([
    '外套',
    '内搭',
    '上衣',
    '长裤',
    '短裤',
    '裙装',
    '鞋',
    '包',
    '饰品',
  ]);
  const seasons = Array.isArray(source.seasonTags)
    ? [...new Set(source.seasonTags.filter((item) => ['春', '夏', '秋', '冬'].includes(item)))].slice(0, 3)
    : [];

  return {
    name: normalizeString(source.name),
    brand: normalizeString(source.brand),
    category: categories.has(source.category) ? source.category : null,
    seasonTags: seasons,
    color: normalizeString(source.color),
    material: normalizeString(source.material),
    size: normalizeString(source.size),
    measurements: {
      clothingLength: normalizeNumber(measurements.clothingLength),
      shoulderWidth: normalizeNumber(measurements.shoulderWidth),
      chestCircumference: normalizeNumber(measurements.chestCircumference),
      sleeveLength: normalizeNumber(measurements.sleeveLength),
      waistCircumference: normalizeNumber(measurements.waistCircumference),
      hipCircumference: normalizeNumber(measurements.hipCircumference),
      trouserLength: normalizeNumber(measurements.trouserLength),
    },
  };
}

function normalizeString(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized ? normalized.slice(0, 200) : null;
}

function normalizeNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value !== 'string') return null;
  const match = value.trim().match(/^(-?\d+(?:\.\d+)?)\s*(?:cm|厘米)?$/i);
  return match ? Number.parseFloat(match[1]) : null;
}

async function readJsonBody(request) {
  const chunks = [];
  let byteLength = 0;
  for await (const chunk of request) {
    byteLength += chunk.length;
    if (byteLength > maximumRequestBytes) {
      throw publicError(413, '请求内容超过限制');
    }
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw publicError(400, '请求 JSON 无效');
  }
}

function publicError(status, publicMessage) {
  const error = new Error(publicMessage);
  error.status = status;
  error.publicMessage = publicMessage;
  return error;
}

function setSecurityHeaders(response) {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
}

function sendJson(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}
