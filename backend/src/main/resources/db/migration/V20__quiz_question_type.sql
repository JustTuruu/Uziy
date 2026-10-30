-- A QUIZ question asks about the video and has one correct option, which the viewer must pick before the
-- reward is paid. The correct option is stored here and never sent to the app.
ALTER TABLE survey_questions ADD COLUMN correct_answer TEXT;

ALTER TABLE survey_questions DROP CONSTRAINT survey_questions_q_type_check;
ALTER TABLE survey_questions
    ADD CONSTRAINT survey_questions_q_type_check
    CHECK (q_type IN ('SINGLE_CHOICE', 'MULTI_CHOICE', 'TEXT', 'RATING', 'QUIZ'));

ALTER TABLE survey_questions
    ADD CONSTRAINT survey_questions_quiz_has_answer
    CHECK (q_type <> 'QUIZ' OR correct_answer IS NOT NULL);
