-- Development data only (NOT a Flyway migration, never runs in production): five short survey-only campaigns
-- that every viewer sees (all genders, ages 0–100, every city), paid and ACTIVE.
-- Run against the local database:
--   docker exec -i uziy-postgres psql -U uziy -d uziy < backend/dev/sample_surveys.sql
-- Idempotent: a survey whose title already exists is skipped.
-- Pricing follows the platform rule: reward 500 ₮, commission 29 % ⇒ cost per view 705 ₮, 300 viewers.

CREATE OR REPLACE FUNCTION pg_temp.add_survey(company BIGINT, survey_title TEXT, questions JSONB)
RETURNS VOID AS $$
DECLARE
    new_id BIGINT;
    q JSONB;
    pos INT := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM campaigns WHERE title = survey_title) THEN
        RETURN;
    END IF;
    INSERT INTO campaigns (company_id, title, video_url, duration_seconds, has_video, target_gender, min_age, max_age,
                           target_city, total_budget, remaining_budget, cost_per_view, reward_per_user,
                           target_viewers, commission_percent, status, paid_at)
    VALUES (company, survey_title, '', 0, FALSE, 'ALL', 0, 100, 'ALL', 211500, 211500, 705, 500, 300, 29,
            'ACTIVE', now())
    RETURNING id INTO new_id;
    INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference, paid_at)
    VALUES (new_id, company, 211500, 'SIMULATED', 'PAID', 'UZ-DEV-' || new_id, now());
    FOR q IN SELECT * FROM jsonb_array_elements(questions) LOOP
        pos := pos + 1;
        INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json, required)
        VALUES (new_id, pos, q->>'prompt', q->>'type', COALESCE(q->'options', '[]'::jsonb),
                COALESCE((q->>'required')::boolean, TRUE));
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Golomt Bank (id 3)
SELECT pg_temp.add_survey(3, 'Санхүүгийн өдөр тутмын зуршил', '[
  {"prompt": "Та сар бүр мөнгөө төлөвлөдөг үү?", "type": "SINGLE_CHOICE",
   "options": ["Тийм, тогтмол", "Заримдаа", "Үгүй"]},
  {"prompt": "Та ихэвчлэн юугаар төлбөр төлдөг вэ?", "type": "SINGLE_CHOICE",
   "options": ["Карт", "QR код", "Бэлэн мөнгө", "Банкны апп-аар шилжүүлэх"]},
  {"prompt": "Хуримтлал үүсгэдэг үү?", "type": "SINGLE_CHOICE",
   "options": ["Тийм, сар бүр", "Боломж гарвал", "Одоогоор үгүй"]},
  {"prompt": "Санхүүгийн мэдлэгээ хэрхэн үнэлэх вэ?", "type": "RATING",
   "options": ["Муу", "Дунд", "Сайн"]}
]'::jsonb);

SELECT pg_temp.add_survey(3, 'Онлайн худалдан авалт', '[
  {"prompt": "Та сүүлийн сард онлайнаар юм авсан уу?", "type": "SINGLE_CHOICE",
   "options": ["Тийм, олон удаа", "Нэг хоёр удаа", "Үгүй"]},
  {"prompt": "Онлайнаар юу хамгийн их авдаг вэ?", "type": "MULTI_CHOICE",
   "options": ["Хувцас", "Хоол хүнс", "Электроник", "Гоо сайхан", "Ном"]},
  {"prompt": "Онлайн худалдааны хүргэлтэд хэр сэтгэл хангалуун байдаг вэ?", "type": "RATING",
   "options": ["Муу", "Дунд", "Сайн"]}
]'::jsonb);

-- MobiCom (id 2)
SELECT pg_temp.add_survey(2, 'Интернэт хэрэглээ', '[
  {"prompt": "Та өдөрт интернэтэд хэдэн цаг зарцуулдаг вэ?", "type": "SINGLE_CHOICE",
   "options": ["1 цагаас бага", "1–3 цаг", "3–6 цаг", "6 цагаас дээш"]},
  {"prompt": "Гэртээ ямар интернэт ашигладаг вэ?", "type": "SINGLE_CHOICE",
   "options": ["Утасны дата", "Гэрийн Wi-Fi", "Хоёуланг нь"]},
  {"prompt": "Интернэтийнхээ хурдыг хэрхэн үнэлэх вэ?", "type": "RATING",
   "options": ["Муу", "Дунд", "Сайн"]}
]'::jsonb);

SELECT pg_temp.add_survey(2, 'Сошиал сүлжээний хэрэглээ', '[
  {"prompt": "Аль сошиал сүлжээг хамгийн их ашигладаг вэ?", "type": "SINGLE_CHOICE",
   "options": ["Facebook", "Instagram", "TikTok", "YouTube", "X (Twitter)"]},
  {"prompt": "Мэдээ, мэдээллээ голдуу хаанаас авдаг вэ?", "type": "MULTI_CHOICE",
   "options": ["Сошиал сүлжээ", "Мэдээний сайт", "Телевиз", "Найз нөхөд"]},
  {"prompt": "Сошиал сүлжээн дээрх зарыг хэр анхаардаг вэ?", "type": "RATING",
   "options": ["Муу", "Дунд", "Сайн"]},
  {"prompt": "Ямар төрлийн контент таалагддаг вэ?", "type": "TEXT", "required": false}
]'::jsonb);

SELECT pg_temp.add_survey(2, 'Хөгжим, подкаст сонсох зуршил', '[
  {"prompt": "Та өдөр бүр хөгжим сонсдог уу?", "type": "SINGLE_CHOICE",
   "options": ["Тийм", "Заримдаа", "Бараг үгүй"]},
  {"prompt": "Юугаар голдуу сонсдог вэ?", "type": "SINGLE_CHOICE",
   "options": ["YouTube", "Spotify", "Радио", "Бусад апп"]},
  {"prompt": "Подкаст сонсдог уу?", "type": "SINGLE_CHOICE",
   "options": ["Тогтмол", "Хааяа", "Үгүй"]}
]'::jsonb);
