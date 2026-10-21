-- Run after demo_feed.sql twice in an isolated database (see ../README.md).
DO $$
DECLARE n int;
BEGIN
 SELECT count(*) INTO n FROM campaign_payments WHERE reference LIKE 'DEV-FEED-20261021-%';
 ASSERT n=24, 'Expected exactly 24 payments after repeated seed runs';
 SELECT count(*) INTO n FROM campaigns c JOIN campaign_payments p ON p.campaign_id=c.id
 WHERE p.reference LIKE 'DEV-FEED-20261021-%' AND c.has_video;
 ASSERT n=12, 'Expected 12 video campaigns';
 SELECT count(*) INTO n FROM survey_questions q JOIN campaign_payments p ON p.campaign_id=q.campaign_id
 WHERE p.reference LIKE 'DEV-FEED-20261021-%';
 ASSERT n=120, 'Expected 120 questions';
 ASSERT NOT EXISTS (
 SELECT c.id FROM campaigns c JOIN campaign_payments p ON p.campaign_id=c.id
 JOIN survey_questions q ON q.campaign_id=c.id
 WHERE p.reference LIKE 'DEV-FEED-20261021-%'
 GROUP BY c.id HAVING count(q.id)<>5 OR count(DISTINCT q.q_type)<>4
 OR min(q.position)<>1 OR max(q.position)<>5), 'Each campaign needs five ordered questions of four types';
 ASSERT NOT EXISTS (
 SELECT 1 FROM campaigns c JOIN campaign_payments p ON p.campaign_id=c.id
 WHERE p.reference LIKE 'DEV-FEED-20261021-%' AND
 (c.status<>'ACTIVE' OR c.target_gender<>'ALL' OR c.target_city<>'ALL' OR c.min_age<>0 OR c.max_age<>120
 OR c.remaining_budget<>c.total_budget OR c.cost_per_view<c.reward_per_user
 OR c.cost_per_view<>ceil(c.reward_per_user*100.0/(100-c.commission_percent))
 OR c.paid_at IS NULL OR p.provider<>'SIMULATED'
 OR (c.has_video AND (c.video_url='' OR c.duration_seconds<>33))
 OR (NOT c.has_video AND (c.video_url<>'' OR c.duration_seconds<>0)))), 'Visibility, pricing or media mismatch';
 ASSERT NOT EXISTS (
 SELECT 1 FROM survey_questions q JOIN campaign_payments p ON p.campaign_id=q.campaign_id
 WHERE p.reference LIKE 'DEV-FEED-20261021-%' AND
 (length(trim(q.prompt))=0 OR NOT q.required
 OR (q.q_type='RATING' AND q.options_json<>'["Муу","Дунд","Сайн"]'::jsonb)
 OR (q.q_type IN ('SINGLE_CHOICE','MULTI_CHOICE') AND jsonb_array_length(q.options_json)<3)
 OR (q.q_type='TEXT' AND q.options_json<>'[]'::jsonb))), 'Invalid question options';
END $$;
