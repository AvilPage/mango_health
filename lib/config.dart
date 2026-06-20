/// PocketBase URL.
/// Override at build time: --dart-define=PB_URL=http://192.168.x.x:8090
const String kPocketBaseUrl = String.fromEnvironment(
  'PB_URL',
  defaultValue: 'https://mango-health-api.avilpage.com',
);
