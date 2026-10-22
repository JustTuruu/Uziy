/// Static copy of the privacy-policy page. Kept apart from the widgets so
/// copy edits never touch layout code.
library;

const String kPrivacyTitle = 'Нууцлалын бодлого';

/// Heading of the statistics section; the consent switch sits right under it.
const String kStatsSectionHeading = 'Нэргүй статистик (зөвхөн зөвшөөрвөл)';
const String kPrivacyIntroTitle = 'Таны мэдээлэл аюулгүй';
const String kPrivacyIntro =
    'Бид таны мэдээллийг зөвхөн урамшууллыг зөв олгох, залилангаас '
    'хамгаалах, үйлчилгээгээ сайжруулахад ашиглана.';

/// What deleting the account does. The deletion sheet lists these and the
/// privacy page says the same, so the two never disagree. Matches the backend
/// (`AccountDeletionServiceImpl`).
const String kDeleteFactPersonal =
    'Утасны дугаар, овог нэр, хүйс, төрсөн огноо, хот, дүүрэг устана.';
const String kDeleteFactAnswers =
    'Чөлөөт бичсэн хариултууд устана. Сонгож өгсөн хариултууд таныг '
    'тодорхойлох мэдээлэлгүйгээр нийлбэр дүнд үлдэнэ.';
const String kDeleteFactPayouts =
    'Мөнгө татсан гүйлгээний бүртгэлийг санхүүгийн тайланд зориулж таны нэр, '
    'дансны дугааргүйгээр хадгална.';
const String kDeleteFactBalance = 'Хэтэвчинд үлдсэн мөнгө буцаагдахгүй.';
const String kDeleteFactPending =
    'Мөнгө татах хүсэлт шалгагдаж байх үед бүртгэлээ устгах боломжгүй.';
const String kDeleteFactPhone = 'Энэ дугаараар дараа нь дахин бүртгүүлж болно.';
const List<String> kDeleteAccountFacts = [
  kDeleteFactPersonal,
  kDeleteFactAnswers,
  kDeleteFactPayouts,
  kDeleteFactBalance,
  kDeleteFactPending,
  kDeleteFactPhone,
];

const String kDeleteSectionHeading = 'Бүртгэлээ устгах';

class PolicySection {
  final String heading;
  final String body;
  const PolicySection(this.heading, this.body);
}

const List<PolicySection> kPrivacySections = [
  PolicySection(
    'Бидний цуглуулдаг мэдээлэл',
    'Бүртгүүлэхдээ оруулсан утасны дугаар, хүйс, төрсөн огноо, хот, дүүрэг. '
        'Мөнгө татахад банк, дансны дугаар, дансны нэр. '
        'Мэдэгдэл илгээхэд хэрэгтэй төхөөрөмжийн токен. '
        'Видео үзсэн түүх болон судалгааны хариулт.',
  ),
  PolicySection(
    'Мэдээллийг хэрхэн ашиглах вэ',
    'Урамшууллыг хэтэвчид олгож, мөнгө татах хүсэлтийг шалгана. '
        'Профайлын мэдээлэл ба дансны мэдээллийг тулгаж, хуурамч '
        'бүртгэлээс сэргийлнэ.',
  ),
  PolicySection(
    'Зар сурталчлагчид юу харах вэ',
    'Компаниуд судалгааны хариултыг нийлбэр, статистик хэлбэрээр харна. '
        'Таны утасны дугаар, дансны мэдээллийг компаниудад өгөхгүй.',
  ),
  PolicySection(
    kStatsSectionHeading,
    'Та зөвшөөрсөн тохиолдолд л таны сонголттой хариултыг нэр, утас, '
    'төрсөн огноо, дүүрэг зэрэг таныг тодорхойлох мэдээлэлгүйгээр, '
    'дор хаяж 50 хүний хариулттай нэгтгэж, зөвхөн хувь хэлбэрээр '
    'статистик гаргана. Ийм нэгтгэсэн тайланг байгууллагуудад хүргэж '
    'болно. Чөлөөт бичсэн хариулт ордоггүй, 18 наснаас доош хүний '
    'хариулт огт ордоггүй. Статистикт хандсан бүрийг бүртгэнэ.',
  ),
  PolicySection(
    'Мэдээллийг хамгаалах',
    'Нууц үг шифрлэгдэн хадгалагдана. Дансны мэдээллийг '
        'зөвхөн мөнгө татах хүсэлтийг шалгах эрх бүхий ажилтан харна.',
  ),
  PolicySection(
    'Таны эрх',
    'Профайлдаа байгаа мэдээллээ хүссэн үедээ харах боломжтой. Мэдэгдлийг '
        'утасныхаа тохиргооноос хүссэн үедээ унтрааж болно. Нэргүй статистикт '
        'оролцох зөвшөөрлөө энэ хуудасны «Нэргүй статистик» хэсгээс хүссэн '
        'үедээ цуцлах боломжтой — '
        'цуцалсан даруйд таны хариулт шинэ статистикт орохгүй.',
  ),
  PolicySection(
    kDeleteSectionHeading,
    'Профайл → «Бүртгэл устгах» хэсэгт нууц үгээ оруулаад бүртгэлээ хүссэн '
    'үедээ устгаж болно. $kDeleteFactPersonal $kDeleteFactAnswers '
    '$kDeleteFactPayouts $kDeleteFactBalance $kDeleteFactPending',
  ),
  PolicySection(
    'Нас',
    'Энэ апп-г 13 ба түүнээс дээш насныханд зориулсан.',
  ),
];
