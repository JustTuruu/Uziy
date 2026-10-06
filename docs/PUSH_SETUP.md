# Push мэдэгдлийн тохиргоо (Firebase Cloud Messaging)

Шинэ видео эсвэл судалгаа идэвхжихэд backend тохирох үзэгчид FCM push илгээнэ.
Firebase тохиргооны файлгүйгээр апп хэвийн ажиллана (push унтарсан байна).
Доорх алхмуудыг дуусгасны дараа push автоматаар асна.

## 1. Firebase төсөл үүсгэх

1. https://console.firebase.google.com → **Add project** → нэр: `uziy`.
2. Analytics заавал биш.

## 2. Android апп нэмэх

1. Project settings → **Add app** → Android.
2. Package name: `com.example.viewer_app`
   (`viewer_app/android/app/build.gradle.kts` дахь `applicationId`; бодит id-аа
   сольсон бол тэрийг ашиглана).
3. `google-services.json` татаад дараах замд хуулна:

   ```
   viewer_app/android/app/google-services.json
   ```

   Файл байвал Gradle `google-services` plugin автоматаар идэвхжинэ.

## 3. iOS апп нэмэх

1. Project settings → **Add app** → iOS.
2. Bundle ID: `com.example.viewerApp`
   (`PRODUCT_BUNDLE_IDENTIFIER`, Xcode дэх Runner target).
3. `GoogleService-Info.plist` татаад дараах замд хуулна:

   ```
   viewer_app/ios/Runner/GoogleService-Info.plist
   ```

4. Xcode-д `ios/Runner.xcworkspace` нээгээд Runner хавтас дээр хулганы баруун
   товч → **Add Files to "Runner"** → `GoogleService-Info.plist`-ийг сонгож,
   "Copy items if needed" болон Runner target-ийг чагтална.
5. Runner target → **Signing & Capabilities**: **Push Notifications** ба
   **Background Modes → Remote notifications** байгаа эсэхийг шалгана
   (`Runner.entitlements`, `Info.plist` дээр аль хэдийн нэмэгдсэн).
   Push нь **Apple Developer Program** (төлбөртэй) team шаардана; үнэгүй
   "Personal Team"-ээр бол device-д build хийхэд Push entitlement алдаа өгнө.
6. App Store / TestFlight build-ийн өмнө `Runner.entitlements` дахь
   `aps-environment`-ийг `production` болгоно.

## 4. APNs auth key-г Firebase-д оруулах (iOS)

1. https://developer.apple.com/account → Keys → **+** → *Apple Push
   Notifications service (APNs)* → `.p8` файл татна. Key ID, Team ID-г тэмдэглэнэ.
2. Firebase → Project settings → **Cloud Messaging** → *Apple app
   configuration* → **APNs Authentication Key → Upload** (`.p8`, Key ID, Team ID).

## 5. Backend-д зориулсан service account

1. Firebase → Project settings → **Service accounts** → **Generate new private
   key** → JSON татна.
2. Серверт аюулгүй газар хадгална (repo-д хийхгүй), жишээ нь `/etc/uziy/fcm.json`.
3. Backend-ийг дараах орчны хувьсагчтай ажиллуулна:

   ```
   PUSH_ENABLED=true
   FCM_CREDENTIALS_PATH=/etc/uziy/fcm.json
   ```

## 6. Туршиж үзэх

Апп-д нэвтэрч Нүүр хуудсанд орно: мэдэгдлийн зөвшөөрөл асууна (iOS prompt,
Android 13+ POST_NOTIFICATIONS). Зөвшөөрсний дараа FCM token backend-ийн
`POST /viewer/devices`-д бүртгэгдэнэ (DB-ийн devices хүснэгтээс харна).

**Firebase console-оос:** Engage → Messaging → **New campaign → Notifications** →
Send test message → FCM token-оо оруулна. Анхааруулга: консолын энгийн мэдэгдэл
`data` агуулдаггүй тул дарахад апп юу ч нээхгүй. Дарахад видео/судалгаа нээгдэх
эсэхийг шалгахдаа **Additional options → Custom data** дээр дараахыг нэмнэ:

```
type = CAMPAIGN
campaignId = 1
hasVideo = true      (судалгаа бол false)
```

**curl (HTTP v1 API):**

```bash
ACCESS_TOKEN=$(gcloud auth print-access-token \
  --impersonate-service-account=<service-account-email>)   # эсвэл google-auth-ийн token
curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send \
  -d '{
    "message": {
      "token": "<DEVICE_FCM_TOKEN>",
      "notification": {"title": "Шинэ видео", "body": "Үзээд 500 ₮ аваарай"},
      "data": {"type": "CAMPAIGN", "campaignId": "1", "hasVideo": "true"}
    }
  }'
```

Дарахад: `hasVideo=true` → видео, `false` → судалгааны дэлгэц. Кампанит ажил
аль хэдийн үзсэн/дууссан бол Нүүр хуудас руу очиж "Энэ видео одоо байхгүй байна"
гэж харуулна.

## 7. Анхааруулга (симулятор)

- **iOS симулятор**: Apple Silicon + Xcode 14+ дээр push хүлээн авч болох ч
  FCM/APNs token найдваргүй. Бодит iPhone дээр шалгана.
- **Android emulator**: Google Play үйлчилгээтэй (Play Store-тэй) image ашиглана,
  эс бөгөөс token авч чадахгүй.
- Android 13+ дээр зөвшөөрлөөс татгалзсан бол Settings → Apps → Uziy →
  Notifications-аас гараар асаана.
- Апп бүрэн хаагдсан (terminated) үед дарсан мэдэгдэл Нүүр хуудас ачаалж дууссаны
  дараа видео/судалгааг нээнэ.
