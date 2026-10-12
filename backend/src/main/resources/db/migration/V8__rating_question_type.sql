-- A 3-point mood scale (Муу / Дунд / Сайн) is a question type of its own.
ALTER TABLE survey_questions DROP CONSTRAINT survey_questions_q_type_check;
ALTER TABLE survey_questions
    ADD CONSTRAINT survey_questions_q_type_check
    CHECK (q_type IN ('SINGLE_CHOICE', 'MULTI_CHOICE', 'TEXT', 'RATING'));
