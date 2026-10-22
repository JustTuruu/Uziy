# Uziy viewer app — App Store / Google Play-д гаргах заавар

Код болон тохиргоо (2026-10-22) бэлэн. Доорх алхмууд нь **эзэмшигчийн бүртгэл, түлхүүр, нууц**
шаарддаг тул repo-д байхгүй — та өөрөө хийнэ. ☐ = хийх, ☑ = кодонд аль хэдийн хийгдсэн.

## 0. Кодонд хийгдсэн зүйлс (шалгах шаардлагагүй)

- ☑ App identity: iOS bundle id / Android applicationId **`mn.uziy.viewer`**; Debug нь `mn.uziy.viewer.dev`
  (хоёулаа нэг утсанд зэрэг суух боломжтой). Нэр **Uziy**. Хувилбар `pubspec.yaml`-ийн `version: 1.0.0+1`.
- ☑ Бүртгэл устгах (Apple 5.1.1(v), Google Play): Профайл → **Бүртгэл устгах** → нууц үг → `DELETE /viewer/me`.
- ☑ iOS: `PrivacyInfo.xcprivacy` (privacy manifest), `ITSAppUsesNonExemptEncryption = false`, Release-д ATS
  exception байхгүй (Debug-д `ios/scripts/allow_local_networking_in_debug.sh` нэмнэ), push: Release =
  `production`, Profile = `development`, Debug = push-гүй. Зөвхөн iPhone (`TARGETED_DEVICE_FAMILY = 1`) — iPad
  screenshot шаардлагагүй.
- ☑ Android: `targetSdk`/`compileSdk` = 36 (Flutter 3.47-ийн default; Google Play 2026-08-31-нээс хойш шинэ апп,
  шинэчлэлд API 36 шаарддаг — жил бүрийн 8-р сард шалгана), minSdk 24, R8 (minify + shrink) Flutter plugin-ээр
  асаалттай, зөвшөөрөл зөвхөн `INTERNET` + `POST_NOTIFICATIONS`, `allowBackup=false`, release-д cleartext хориотой,
  adaptive + themed (monochrome) icon.
- ☑ Release build нь `https://` биш `API_BASE_URL`-тэй бол асахгүй (`ApiService.ensureConfigured`).

## 1. Apple (App Store)

1. ☐ **Apple Developer Program** (жилд $99) — байгууллагаар бүртгүүлбэл D-U-N-S дугаар хэрэгтэй (хэдэн долоо хоног).
2. ☐ developer.apple.com → Identifiers → **App ID** `mn.uziy.viewer`, capability: **Push Notifications**.
3. ☐ Xcode → Runner target → Signing & Capabilities → **Team**-ээ сонгоно (одоо `TLT6M8G84N` — таных биш бол
   солино), "Automatically manage signing" асаалттай.
4. ☐ **App Store Connect** → My Apps → **+** → New App: platform iOS, name **Uziy**, primary language
   Mongolian (байхгүй бол English), bundle id `mn.uziy.viewer`, SKU `uziy-viewer`.
5. ☐ **APNs key**: Keys → **+** → Apple Push Notifications service → `.p8` татна (нэг л удаа татагдана!) →
   Firebase Console → Cloud Messaging → Apple app configuration → upload (Key ID, Team ID). Дэлгэрэнгүй:
   `docs/PUSH_SETUP.md`.
6. ☐ Firebase-д iOS app (`mn.uziy.viewer`) нэмээд **`GoogleService-Info.plist`**-ийг
   `ios/Runner/`-д хуулж, Xcode-оор Runner target-д нэмнэ (repo-д commit хийхгүй).
7. ☐ Build + upload:
   ```
   cd viewer_app
   flutter build ipa --release --dart-define=API_BASE_URL=https://api.<таны-домэйн>
   # build/ios/ipa/*.ipa → Transporter апп эсвэл: xcrun altool / Xcode Organizer → Distribute
   ```
8. ☐ TestFlight дээр өөрөө туршина (бүртгүүлэх, видео, судалгаа, мөнгө татах, push, бүртгэл устгах).

## 2. Google Play

1. ☐ **Play Console** бүртгэл ($25 нэг удаа). 2023-аас хойш шинэ *хувь хүний* бүртгэл бол production-д гаргахаас
   өмнө **20 tester × 14 хоног closed test** шаардлагатай; байгууллагын бүртгэлд энэ шаардлага байхгүй.
2. ☐ **Upload key** үүсгэнэ (нэг удаа, `.jks`-ээ нууц үгийн менежер + backup-д хадгална):
   ```
   keytool -genkey -v -keystore ~/uziy-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # утгуудаа бөглөнө; git-д орохгүй
   ```
   `key.properties` байхгүй бол `flutter build appbundle` зориуд алдаа өгнө (debug key-тэй bundle Play хүлээж
   авахгүй). APK-г локал туршихад debug key-ээр гарын үсэг зурж, анхааруулга бичнэ.
3. ☐ Play Console → Create app → **Play App Signing** (Google signing key-г хадгална; та upload key-ээр илгээнэ).
4. ☐ Firebase-д Android app (`mn.uziy.viewer`) нэмээд **`google-services.json`**-ийг `android/app/`-д хуулна.
5. ☐ Build + upload:
   ```
   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.<таны-домэйн>
   # build/app/outputs/bundle/release/app-release.aab → Play Console → Testing → Internal testing
   ```
6. ☐ Store listing: 512×512 icon (`sips -Z 512 assets/logo.png --out play-icon-512.png` эсвэл дизайнераас),
   1024×500 feature graphic, утасны screenshot 2–8 ширхэг.

## 3. Хувилбар (versioning)

`pubspec.yaml`: `version: 1.0.0+1` → `<хэрэглэгчид харагдах>+<build дугаар>`. Store-д илгээх бүрт **build
дугаарыг заавал нэмнэ** (`1.0.0+2`, …); шинэ боломжтой бол хувилбарыг ч (`1.1.0+3`). Эсвэл build командад
`--build-name=1.0.1 --build-number=4`.

## 4. Нууцлалын бодлого ба бүртгэл устгах холбоос (нийтийн URL хэрэгтэй)

- ☐ **Privacy policy URL** — хоёр store хоёулаа шаардана. `landing/` сайтад `/privacy` хуудас нэмэх
  (апп доторх `lib/screens/profile/privacy_content.dart`-ийн текстийг ашиглаж болно). **Хуульчаар хянуулна.**
- ☐ **Account deletion URL** (Google Play, Data safety → "Delete account URL") — апп-д нэвтэрч чадахгүй хүн ч
  устгах хүсэлт гаргах боломжтой байх ёстой. Санал: `landing/`-д `/delete-account` хуудас — апп доторх алхмыг
  тайлбарлаж, мөн "утасны дугаараа бичээд privacy@<домэйн> руу имэйл илгээ" гэсэн замтай. Имэйлээр ирсэн
  хүсэлтийг эрх бүхий ажилтан шалгаад (тухайн дугаараас SMS-ээр баталгаажуулж) устгана.
- Бүртгэл устгахад юу болох (backend `AccountDeletionServiceImpl`, апп болон privacy хуудсанд ижил текст):
  утас, овог нэр, хүйс, төрсөн огноо, хот/дүүрэг, статистикийн зөвшөөрөл, push token, чөлөөт хариулт устана;
  хэтэвчийн үлдэгдэл буцаагдахгүй; сонголттой хариулт ба үзсэн түүх хүнтэй холбогдохгүйгээр нийлбэрт үлдэнэ;
  шийдвэрлэгдсэн мөнгө татах бүртгэл дүн/банк/огноотой, нэргүй, дансны сүүлийн 4 оронтойгоор үлдэнэ (нягтлан
  бодох бүртгэл — нягтланчаараа хугацааг тогтоолгоно); PENDING хүсэлттэй үед устгах боломжгүй (409).

## 5. App Store "App Privacy" асуулга (`ios/Runner/PrivacyInfo.xcprivacy`-тэй таарах ёстой)

Бүгд: **Linked to the user = Yes**, **Used for tracking = No**.

| Apple data type | Юу | Purpose |
|---|---|---|
| Contact Info → Phone Number | нэвтрэх, SMS баталгаажуулалт | App Functionality |
| Contact Info → Name | овог/нэр (мөнгө татахад тулгах) | App Functionality |
| Location → Coarse Location | хот/аймаг, дүүрэг/сум (GPS биш, хэрэглэгч сонгоно) | App Functionality, Analytics |
| Other Data → Other Data Types | хүйс, төрсөн огноо (targeting, 13+ нас) | App Functionality, Analytics |
| Financial Info → Other Financial Info | банк, дансны дугаар/нэр, хэтэвчийн үлдэгдэл | App Functionality |
| User Content → Other User Content | судалгааны хариулт | App Functionality, Analytics |
| Usage Data → Product Interaction | ямар видео/судалгаа бөглөсөн | App Functionality, Analytics |
| Identifiers → User ID | бүртгэлийн дугаар | App Functionality |
| Identifiers → Device ID | push token (FCM) | App Functionality |

Тэмдэглэл: компаниуд зөвхөн нийлбэр үр дүн харна; нэргүй статистик зөвхөн хэрэглэгчийн зөвшөөрлөөр (50+ хүний
бүлэг). Энэ нь Apple-ийн "Third-Party Advertising" (бусад апп/сайтад зар цацах) биш гэж үзсэн — хуульч/зөвлөхтэйгөө
шалгана. App Store Connect-ээс **ITMS-91053 "Missing API declaration"** имэйл ирвэл заасан ангиллыг шалтгааны
кодтой нь `NSPrivacyAccessedAPITypes`-д нэмнэ (одоогоор манай Swift код ийм API ашигладаггүй; plugin-ууд өөрсдийн
manifest-тэй).

## 6. Google Play "Data safety"

- Data collected: **Personal info** (Name, Phone number, Other info = хүйс/төрсөн огноо), **Location** (Approximate),
  **Financial info** (Other financial info), **App activity** (App interactions, Other user-generated content =
  судалгааны хариулт), **Device or other IDs** (push token).
- Shared with third parties: **No** (компаниуд зөвхөн нэгтгэсэн, хүн тодорхойлохгүй тоо авна — Google-ийн
  тодорхойлолтоор "anonymous/aggregated" бол sharing биш; эргэлзвэл "Yes, Analytics" гэж хариулна).
- Encrypted in transit: **Yes** (HTTPS). Users can request deletion: **Yes** (апп + 4-р хэсгийн URL).
- Required/optional: бүртгэлийн мэдээлэл required; нэргүй статистик optional (зөвшөөрөл).
- **Financial features** асуулга: апп нь мөнгөн урамшуулал олгож банк руу шилжүүлдэг — "rewards/cash out" гэж үнэн
  зөвөөр тайлбарлана.

## 7. Content rating, нас

- Апп 13+ (`ViewerAgeRule`, бүртгэл 13-аас доош насыг хүлээж авахгүй). App Store Connect → **Age Rating**
  асуулгыг үнэн зөв бөглөнө (зар/брэндийн контент, мөнгөн урамшуулал байгааг дурдана; user-generated content
  нийтэд харагддаггүй, web browser байхгүй). Гарсан үнэлгээ 13+-аас доош бол **override to a higher rating → 13+**
  сонгоно, listing-ийн тайлбарт "13 ба түүнээс дээш насныханд" гэж бичнэ.
- Google Play: IARC асуулга (Content rating), **Target audience = 13–15, 16–17, 18+** (13-аас доош сонгохгүй —
  Families policy-д орохгүй). "Ads" асуулт: апп нь брэндийн видео (зар) харуулдаг → **Contains ads = Yes**.

## 8. Шалгагчид (reviewer) зориулсан demo бүртгэл — SMS асуудал

Бүртгүүлэхэд хэрэглэгч **Монголын дугаараас 144773 руу SMS** илгээх ёстой — Apple/Google-ийн шалгагч үүнийг хийж
чадахгүй. Тиймээс:

1. ☐ Production backend дээр **урьдчилан үүсгэсэн viewer бүртгэл** (жишээ нь дугаар `99000001`, хүчтэй нууц үг)
   — SMS алгасаж, админ шууд DB-д үүсгэнэ:
   ```
   ./gradlew hash --args="<reviewer-password>"      # BCrypt hash хэвлэнэ
   psql ... -c "INSERT INTO users (phone_number, password_hash, role, gender, birth_date, city, district,
                last_name, first_name) VALUES ('99000001', '<hash>', 'VIEWER', 'MALE', '1995-01-01',
                'Улаанбаатар', 'Сүхбаатар', 'Review', 'Apple');"
   ```
2. ☐ Тэр бүртгэлд харагдах **ACTIVE судалгаа** (жижиг төсөвтэй) байлгана, тэгэхгүй бол feed хоосон харагдана.
3. ☐ App Store Connect → App Review Information → **Sign-in required**: дугаар + нууц үг; **Notes** (англиар):
   "Registration requires sending an SMS from a Mongolian mobile number to short code 144773 (operator-billed
   phone verification), which reviewers cannot do. Please use the demo account above. Guest browsing is available
   via 'Зочноор үзэх'. Account deletion: Profile → Бүртгэл устгах." Google Play → App access → ижил.
4. ☐ Шалгалт дууссаны дараа: шалгагч бүртгэлээ устгаж магадгүй — дахин үүсгэх, нууц үгээ солих.

## 9. Илгээхээс өмнөх эцсийн шалгалт

- ☐ `flutter analyze` цэвэр, `flutter test` ногоон; backend `./gradlew test` ногоон.
- ☐ Production backend: `SPRING_PROFILES_ACTIVE=prod`, verify.mn, FCM, HTTPS домэйн (`ProductionReadinessCheck`).
- ☐ `docs/PRODUCTION_CHECKLIST.md`-ийн нээлттэй асуудлууд (жишээ нь шагналыг бодит үзэлттэй холбох).
- ☐ Store listing текст Монгол + (сонголтоор) English, support email/URL, marketing URL (landing).
