-- Registration now offers the capital and all 21 aimags by their official names, and a capital district from a
-- list (owner, 2026-10-14). The old picker offered towns; rename them to their aimag so existing viewers and
-- existing campaign targeting keep matching each other (targetCity = city, character for character).
UPDATE users SET city = 'Дархан-Уул' WHERE city = 'Дархан';
UPDATE users SET city = 'Орхон'      WHERE city = 'Эрдэнэт';
UPDATE users SET city = 'Дорнод'     WHERE city = 'Чойбалсан';
UPDATE users SET city = 'Хөвсгөл'    WHERE city = 'Мөрөн';
UPDATE users SET city = 'Баян-Өлгий' WHERE city = 'Өлгий';

UPDATE campaigns SET target_city = 'Дархан-Уул' WHERE target_city = 'Дархан';
UPDATE campaigns SET target_city = 'Орхон'      WHERE target_city = 'Эрдэнэт';
UPDATE campaigns SET target_city = 'Дорнод'     WHERE target_city = 'Чойбалсан';
UPDATE campaigns SET target_city = 'Хөвсгөл'    WHERE target_city = 'Мөрөн';
UPDATE campaigns SET target_city = 'Баян-Өлгий' WHERE target_city = 'Өлгий';
-- 'Ховд' is already the aimag's name. 'Бусад' ("other") has no aimag to map to and stays as it was.
