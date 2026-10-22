/// Static copy of the help page: frequently asked questions. Kept apart from
/// the widgets so copy edits never touch layout code.
library;

import '../wallet/wallet_logic.dart' show kPayoutMinimumLabel;

const String kHelpTitle = 'Тусламж';
const String kHelpIntro = 'Түгээмэл асуулт, хариулт';

/// Uziy's first message at the top of the help chat.
const String kHelpGreeting =
    'Сайн байна уу! Түгээмэл асуултуудын хариултыг доор нэг дор бичлээ. '
    'Доош гүйлгээд уншаарай.';

/// Name shown over Uziy's messages.
const String kHelpSender = 'Uziy';

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

/// Answers reflect the app's real rules: full-watch gate, one reward per
/// video, the payout minimum ([kPayoutMinimumLabel]) and the first-payout
/// verification.
const List<FaqItem> kFaqItems = [
  FaqItem(
    'Урамшууллыг хэрхэн авах вэ?',
    'Видеог дуустал нь үзээд 2–3 богино асуултад хариулна. Хариултаа '
        'илгээмэгц урамшуулал таны хэтэвчинд шууд орно.',
  ),
  FaqItem(
    'Нэг видеогоор хэдэн төгрөг авах вэ?',
    'Урамшууллын дүн видео, судалгаа бүрт өөр өөр байна. Авах урамшуулал '
        'нь тухайн видео, судалгааны карт дээр бичигдсэн байдаг.',
  ),
  FaqItem(
    'Видеог дахин үзвэл урамшуулал авах уу?',
    'Үгүй. Нэг видеогоор урамшууллыг зөвхөн нэг удаа олгоно.',
  ),
  FaqItem(
    'Мөнгөө хэрхэн татах вэ?',
    'Хэтэвч хэсгээс Мөнгө татах товчийг дарж банк, дансны мэдээллээ '
        'оруулна. Доод хэмжээ $kPayoutMinimumLabel. Хүсэлтийг шалгасны дараа мөнгө '
        'таны данс руу шилжинэ.',
  ),
  FaqItem(
    'Яагаад миний бүртгэл баталгаажаагүй байна вэ?',
    'Бүртгэл анхны мөнгө таталтын үед баталгаажна. Мөнгө татах данс таны '
        'өөрийн нэр дээр байх шаардлагатай.',
  ),
  FaqItem(
    'Мэдэгдэл ирэхгүй байна',
    'Утасныхаа тохиргооноос энэ апп-д мэдэгдэл зөвшөөрсөн эсэхийг шалгана '
        'уу. Шинэ видео гарахад танд мэдэгдэл ирнэ.',
  ),
  FaqItem(
    'Видео гацаад байвал яах вэ?',
    'Интернэт холболтоо шалгаад видеог хаан дахин нээнэ үү. Wi-Fi дээр '
        'илүү тогтвортой ажиллана.',
  ),
];
