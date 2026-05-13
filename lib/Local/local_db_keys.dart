class LocalDbKeys {
  static String authToken = "authToken"; // jwt token
  static String refreshToken = "refreshToken"; // jwt refresh token
  static String firstLogin = "firstOpen";
  static String currentUser = "currentUser"; // stored as json
  static String postAuthAction = "postAuthAction";
  static String onboardingAnswers = "onboardingAnswers";
  static String onboardingPendingAuth = "onboardingPendingAuth";
  static String onboardingFunnelActive = "onboardingFunnelActive";
  static String onboardingGuestSession = "onboardingGuestSession";
  static String onboardingVideoGatePending = "onboardingVideoGatePending";
  static String dailyMessageCount = "dailyMessageCount"; // günlük mesaj sayısı
  static String dailyMessageDate = "dailyMessageDate"; // son mesaj gönderilen tarih
  static String dailyPhotoCount = "dailyPhotoCount"; // günlük fotoğraf sayısı
  static String dailyPhotoDate = "dailyPhotoDate"; // son fotoğraf gönderilen tarih
  static String dailyAudioCount = "dailyAudioCount"; // günlük sesli mesaj sayısı
  static String dailyAudioDate = "dailyAudioDate"; // son sesli mesaj gönderilen tarih
  static String characterEditCount = "characterEditCount"; // toplam düzenlenen karakter sayısı
  static String guestDeviceId = "guestDeviceId"; // misafir kullanıcı için cihaz ID
  static String notifications = "notifications"; // bildirimler listesi (JSON)
  static String selectedAgentPhotoPrefix = "selectedAgentPhoto_";
}
