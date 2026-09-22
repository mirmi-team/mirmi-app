const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.mirmi.kr',
);

/// 문의 메일이 도착하는 주소. 백엔드 `contact.service.ts` 와 같아야 한다.
/// (실제 발송은 서버가 하고, 앱은 안내 문구에만 쓴다)
const String kContactEmail = 'mirmi.dev@gmail.com';
