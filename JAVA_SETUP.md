# Java Kurulum ve Yapılandırma

## ✅ Yapılan Yapılandırmalar

### 1. Gradle Properties
`android/gradle.properties` dosyasına Java yolu eklendi:
```
org.gradle.java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

### 2. Local Properties
`android/local.properties` dosyasında Java yolu mevcut:
```
java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

### 3. Shell Environment (Kalıcı)
`~/.zshrc` dosyasına JAVA_HOME eklendi (yeni terminal açıldığında otomatik aktif olur).

## 🔍 Java Yolunu Kontrol Etme

Terminal'de Java'nın çalışıp çalışmadığını kontrol edin:
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
$JAVA_HOME/bin/java -version
```

## 🛠️ Sorun Giderme

### Java bulunamıyorsa:

1. **Yeni terminal açın** veya mevcut terminali yenileyin:
   ```bash
   source ~/.zshrc
   ```

2. **Java yolunu kontrol edin:**
   ```bash
   echo $JAVA_HOME
   ```

3. **Android Studio Java'sını doğrulayın:**
   ```bash
   ls -la "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java"
   ```

4. **Gradle build test edin:**
   ```bash
   cd android
   export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
   ./gradlew --version
   ```

## 📝 Notlar

- Android Studio'nun kendi JDK'sı kullanılıyor (JDK 21)
- Flutter build otomatik olarak bu Java'yı kullanacak
- Gradle properties dosyasındaki ayar önceliklidir


