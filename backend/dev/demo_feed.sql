-- LOCAL DEVELOPMENT ONLY. 24 campaigns / 120 questions; no production migration.
-- Run: docker exec -i uziy-postgres psql -v ON_ERROR_STOP=1 -U uziy -d uziy < backend/dev/demo_feed.sql
-- Idempotent by SIMULATED payment reference. Existing campaigns/responses remain untouched.
-- Video entries share the public Big Buck Bunny sample trailer; they test different feedback angles.
BEGIN;
SELECT pg_advisory_xact_lock(20261021);
DO $seed$
DECLARE
 item jsonb; question jsonb; campaign_id bigint; owner_id bigint; idx int := 0; pos int;
 commission int; reward int; cost int; ref text;
BEGIN
 SELECT id INTO STRICT owner_id FROM users WHERE phone_number='88112233' AND role='COMPANY';
 SELECT commission_percent INTO STRICT commission FROM platform_settings WHERE id=1;
 FOR item IN SELECT value FROM jsonb_array_elements($data$
[
  {
    "title": "[ТЕСТ] Кофе ба цай",
    "video": false,
    "questions": [
      {
        "prompt": "Та аль ундааг илүү сонгодог вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Кофе",
          "Цай",
          "Какао",
          "Алийг нь ч хэрэглэдэггүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Амт",
          "Үнэ",
          "Орц",
          "Бэлтгэх хугацаа"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Хоол хүргэлт",
    "video": false,
    "questions": [
      {
        "prompt": "Та хоол хүргэлт хэр ашигладаг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Долоо хоног бүр",
          "Сард хэдэн удаа",
          "Ховор",
          "Ашигладаггүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Хүргэлтийн хурд",
          "Хоолны чанар",
          "Үнэ",
          "Савлагаа"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Нийтийн тээвэр",
    "video": false,
    "questions": [
      {
        "prompt": "Та ихэвчлэн хэрхэн зорчдог вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Автобус",
          "Хувийн машин",
          "Такси",
          "Алхаж эсвэл дугуйгаар"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Хүлээх хугацаа",
          "Аюулгүй байдал",
          "Тав тух",
          "Маршрут"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Аялал төлөвлөлт",
    "video": false,
    "questions": [
      {
        "prompt": "Та ямар аяллыг илүүд үздэг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Байгальд амрах",
          "Хот үзэх",
          "Адал явдалт аялал",
          "Гэртээ амрах"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Зардал",
          "Байршил",
          "Байрлах газар",
          "Тээвэр"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Ном ба унших зуршил",
    "video": false,
    "questions": [
      {
        "prompt": "Та ямар хэлбэрээр ном уншдаг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Цаасан ном",
          "Цахим ном",
          "Аудио ном",
          "Одоогоор уншдаггүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Сэдэв",
          "Зохиолч",
          "Үнэ",
          "Бусдын үнэлгээ"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Дасгал хөдөлгөөн",
    "video": false,
    "questions": [
      {
        "prompt": "Та хэр тогтмол дасгал хийдэг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Өдөр бүр",
          "Долоо хоногт хэдэн удаа",
          "Хааяа",
          "Одоогоор хийдэггүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Байршил",
          "Үнэ",
          "Дасгалжуулагч",
          "Тоног төхөөрөмж"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Цахим сургалт",
    "video": false,
    "questions": [
      {
        "prompt": "Та юуг онлайнаар сурах сонирхолтой вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Гадаад хэл",
          "Технологи",
          "Бүтээлч ур чадвар",
          "Бусад"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Богино хичээл",
          "Дасгал ажил",
          "Багшийн зөвлөгөө",
          "Уян хатан цаг"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Хог ангилалт",
    "video": false,
    "questions": [
      {
        "prompt": "Та гэртээ хогоо ангилдаг уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тогтмол",
          "Заримдаа",
          "Эхлэхээр төлөвлөж байгаа",
          "Үгүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Ойрхон цэг",
          "Тодорхой заавар",
          "Тусдаа сав",
          "Урамшуулал"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Хувцас сонголт",
    "video": false,
    "questions": [
      {
        "prompt": "Та хувцсаа хаанаас авдаг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Дэлгүүр",
          "Онлайн",
          "Хослуулж авдаг",
          "Ховор авдаг"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Материал",
          "Үнэ",
          "Загвар",
          "Эдэлгээ"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Гэрийн тав тух",
    "video": false,
    "questions": [
      {
        "prompt": "Та гэртээ аль орчныг илүүд үздэг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Минимал",
          "Өнгөлөг",
          "Байгалийн материалтай",
          "Тусгай сонголтгүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Гэрэлтүүлэг",
          "Тавилга",
          "Дулаан",
          "Дуу чимээ"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Амралтын өдөр",
    "video": false,
    "questions": [
      {
        "prompt": "Та амралтаа ихэвчлэн хэрхэн өнгөрөөдөг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Гэр бүлтэйгээ",
          "Найзуудтайгаа",
          "Ганцаараа амардаг",
          "Гадуур идэвхтэй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Зардал",
          "Цаг агаар",
          "Байршил",
          "Хамт оролцох хүмүүс"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Аппын мэдэгдэл",
    "video": false,
    "questions": [
      {
        "prompt": "Та аппын мэдэгдлийг хэрхэн тохируулдаг вэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Бүгдийг нээдэг",
          "Чухлыг нь үлдээдэг",
          "Ихэнхийг хаадаг",
          "Тохируулж үзээгүй"
        ]
      },
      {
        "prompt": "Таны сонголтод юу хамгийн их нөлөөлдөг вэ? Олон хариулт сонгож болно.",
        "type": "MULTI_CHOICE",
        "options": [
          "Давтамж",
          "Илгээх цаг",
          "Хамааралтай агуулга",
          "Хялбар тохиргоо"
        ]
      },
      {
        "prompt": "Энэ чиглэлийн одоогийн боломж, үйлчилгээг үнэлнэ үү.",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Та шинэ боломж, үйлчилгээг турших уу?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Нөхцөлөөс хамаарна",
          "Одоогоор үгүй"
        ]
      },
      {
        "prompt": "Юуг өөрчилбөл танд илүү тохиромжтой болох вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Анхны сэтгэгдэл",
    "video": true,
    "questions": [
      {
        "prompt": "«Анхны сэтгэгдэл» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Анхны сэтгэгдэл» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Өнгө ба дүрслэл",
    "video": true,
    "questions": [
      {
        "prompt": "«Өнгө ба дүрслэл» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Өнгө ба дүрслэл» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Дүрийн төрх",
    "video": true,
    "questions": [
      {
        "prompt": "«Дүрийн төрх» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Дүрийн төрх» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Өгүүлэмж",
    "video": true,
    "questions": [
      {
        "prompt": "«Өгүүлэмж» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Өгүүлэмж» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Хөдөлгөөн ба хэмнэл",
    "video": true,
    "questions": [
      {
        "prompt": "«Хөдөлгөөн ба хэмнэл» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Хөдөлгөөн ба хэмнэл» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Хөгжим ба дуу",
    "video": true,
    "questions": [
      {
        "prompt": "«Хөгжим ба дуу» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Хөгжим ба дуу» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Хөгжилтэй мөч",
    "video": true,
    "questions": [
      {
        "prompt": "«Хөгжилтэй мөч» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Хөгжилтэй мөч» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Агуулгын ойлгомж",
    "video": true,
    "questions": [
      {
        "prompt": "«Агуулгын ойлгомж» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Агуулгын ойлгомж» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Үзэгчийн сонирхол",
    "video": true,
    "questions": [
      {
        "prompt": "«Үзэгчийн сонирхол» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Үзэгчийн сонирхол» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Санахад үлдсэн зүйл",
    "video": true,
    "questions": [
      {
        "prompt": "«Санахад үлдсэн зүйл» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Санахад үлдсэн зүйл» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Найздаа санал болгох",
    "video": true,
    "questions": [
      {
        "prompt": "«Найздаа санал болгох» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Найздаа санал болгох» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  },
  {
    "title": "[ТЕСТ] Видео — Дараагийн контент",
    "video": true,
    "questions": [
      {
        "prompt": "«Дараагийн контент» талаас видеог хэрхэн үнэлэх вэ?",
        "type": "RATING",
        "options": [
          "Муу",
          "Дунд",
          "Сайн"
        ]
      },
      {
        "prompt": "Видео танд ямар мэдрэмж төрүүлсэн бэ?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Хөгжилтэй",
          "Тайван",
          "Сониуч",
          "Онцгой мэдрэмж төрөөгүй"
        ]
      },
      {
        "prompt": "Аль хэсгүүд таны анхаарлыг татсан бэ?",
        "type": "MULTI_CHOICE",
        "options": [
          "Дүрүүд",
          "Байгаль орчин",
          "Хөдөлгөөн",
          "Дуу хөгжим"
        ]
      },
      {
        "prompt": "Та ийм төрлийн видеог дахин үзэх үү?",
        "type": "SINGLE_CHOICE",
        "options": [
          "Тийм",
          "Магадгүй",
          "Үгүй"
        ]
      },
      {
        "prompt": "«Дараагийн контент» талаас юуг сайжруулах саналтай байна вэ?",
        "type": "TEXT",
        "options": []
      }
    ]
  }
]
$data$::jsonb) LOOP
 idx := idx+1;
 ref := 'DEV-FEED-20261021-' || lpad(idx::text,2,'0');
 IF EXISTS (SELECT 1 FROM campaign_payments WHERE reference=ref) THEN CONTINUE; END IF;
 SELECT greatest(min_reward_per_viewer, CASE WHEN (item->>'video')::boolean THEN 700 ELSE 500 END)
 INTO STRICT reward FROM platform_settings WHERE id=1;
 cost := ceil(reward * 100.0 / (100-commission));
 INSERT INTO campaigns(company_id,title,video_url,duration_seconds,has_video,target_gender,min_age,max_age,
 target_city,total_budget,remaining_budget,cost_per_view,reward_per_user,target_viewers,commission_percent,status,paid_at)
 VALUES(owner_id,item->>'title',CASE WHEN (item->>'video')::boolean THEN 'https://media.w3.org/2010/05/bunny/trailer.mp4' ELSE '' END,
 CASE WHEN (item->>'video')::boolean THEN 33 ELSE 0 END,(item->>'video')::boolean,'ALL',0,120,'ALL',
 cost*1000,cost*1000,cost,reward,1000,commission,'ACTIVE',now()) RETURNING id INTO campaign_id;
 INSERT INTO campaign_payments(campaign_id,company_id,amount,provider,status,reference,paid_at)
 VALUES(campaign_id,owner_id,cost*1000,'SIMULATED','PAID',ref,now());
 pos := 0;
 FOR question IN SELECT value FROM jsonb_array_elements(item->'questions') LOOP
 pos := pos+1;
 INSERT INTO survey_questions(campaign_id,position,prompt,q_type,options_json,required)
 VALUES(campaign_id,pos,question->>'prompt',question->>'type',question->'options',true);
 END LOOP;
 END LOOP;
END $seed$;
COMMIT;
