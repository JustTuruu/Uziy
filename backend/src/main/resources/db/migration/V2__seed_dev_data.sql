-- Development seed data. Only runs cleanly on an empty database; skip in prod.
-- Passwords are BCrypt hashes of "password" (cost 10) — for local dev only.

INSERT INTO users (id, phone_number, password_hash, role, company_name, is_verified)
VALUES
  (1, '99990000', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'ADMIN',   NULL,      TRUE),
  (2, '88112233', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'COMPANY', 'MobiCom', TRUE),
  (3, '99114455', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'COMPANY', 'Golomt Bank', TRUE);

INSERT INTO users (id, phone_number, password_hash, role, gender, birth_date, city, balance, is_verified)
VALUES
  (100, '88778899', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'VIEWER', 'MALE',   '2002-03-14', 'Улаанбаатар', 3400, TRUE),
  (101, '99551122', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'VIEWER', 'FEMALE', '1997-06-22', 'Улаанбаатар', 8200, TRUE),
  (102, '88221199', '$2a$10$N7SkGqYVPUcO2Xk0v9V0aOhLc9L3z0PZC3o5EL4MHtGkYyzB3bJqK', 'VIEWER', 'MALE',   '2007-01-10', 'Дархан',      1200, FALSE);

SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));

INSERT INTO campaigns
  (id, company_id, title, duration_seconds, target_gender, min_age, max_age, target_city,
   total_budget, remaining_budget, cost_per_view, reward_per_user, status)
VALUES
  (1, 2, 'Шинэ 5G багц - Танд хамгийн тохирсон', 45, 'ALL',  18, 45, 'Улаанбаатар', 5000000, 3200000, 1000, 700, 'ACTIVE'),
  (2, 3, 'Оюутны зээл 0% хүүтэй',                 60, 'ALL',  17, 24, 'Улаанбаатар', 3000000, 1450000,  800, 500, 'ACTIVE'),
  (3, 2, 'Гэр бүлийн багц - Дуудлага чөлөөтэй',   40, 'ALL',  25, 55, 'Улаанбаатар', 4000000, 4000000, 1200, 800, 'PENDING');

SELECT setval('campaigns_id_seq', (SELECT MAX(id) FROM campaigns));

INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json)
VALUES
  (1, 1, 'Энэ реклам танд сонирхолтой санагдсан уу?', 'SINGLE_CHOICE',
   '["Тийм","Дунд зэрэг","Үгүй"]'::jsonb),
  (1, 2, 'Та энэ бүтээгдэхүүнийг өмнө нь ашиглаж байсан уу?', 'SINGLE_CHOICE',
   '["Тогтмол ашигладаг","Хааяа","Үгүй"]'::jsonb),
  (2, 1, 'Оюутны зээл авах сонирхолтой юу?', 'SINGLE_CHOICE',
   '["Тийм, одоо хэрэгтэй","Ирээдүйд","Үгүй"]'::jsonb);
