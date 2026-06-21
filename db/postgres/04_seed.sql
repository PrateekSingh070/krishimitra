-- =============================================================================
-- KrishiMitra :: PostgreSQL :: Seed data
-- File: db/postgres/04_seed.sql   (run order: 4 of 4)
--
-- Port of db/seed/*.sql to set-based PostgreSQL:
--   * ~20 crops (bilingual)              * 7 government schemes (jsonb rules)
--   * 1,000 farmers + 1-2 crops each     * ~500 disease scans (HIGH/CRITICAL -> alerts)
--   * 365 days of Mandi prices           * an initial scheme-match pass
--
-- Re-runnable: clears prior synthetic rows (test phone prefix '90000', source
-- 'SEED') first. Uses pgcrypto for the Aadhaar hash.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --- crops (idempotent upsert) ------------------------------------------------
INSERT INTO crops (crop_name, crop_name_hindi, category, avg_grow_days, water_need_mm, ideal_temp_min, ideal_temp_max, ideal_soil_types)
VALUES
 ('Wheat','गेहूँ','Rabi',120,450,10,25,'Loamy,Clay'),
 ('Rice','चावल','Kharif',130,1200,20,37,'Clay,Loamy'),
 ('Maize','मक्का','Kharif',100,500,18,32,'Loamy,Sandy'),
 ('Bajra','बाजरा','Kharif',80,350,25,35,'Sandy,Loamy'),
 ('Jowar','ज्वार','Kharif',110,400,25,33,'Loamy,Black'),
 ('Sugarcane','गन्ना','Kharif',360,1800,20,38,'Loamy,Clay'),
 ('Cotton','कपास','Kharif',180,700,21,35,'Black,Loamy'),
 ('Soybean','सोयाबीन','Kharif',100,500,20,30,'Loamy,Black'),
 ('Groundnut','मूँगफली','Kharif',120,500,25,30,'Sandy,Loamy'),
 ('Mustard','सरसों','Rabi',110,240,10,25,'Loamy,Sandy'),
 ('Gram','चना','Rabi',100,300,15,30,'Loamy,Clay'),
 ('Lentil','मसूर','Rabi',110,280,18,30,'Loamy,Clay'),
 ('Barley','जौ','Rabi',115,300,12,25,'Loamy,Sandy'),
 ('Potato','आलू','Rabi',90,500,15,25,'Sandy,Loamy'),
 ('Onion','प्याज','Rabi',120,450,13,28,'Loamy,Sandy'),
 ('Tomato','टमाटर','Zaid',90,400,20,27,'Loamy,Sandy'),
 ('Watermelon','तरबूज','Zaid',85,400,24,32,'Sandy,Loamy'),
 ('Cucumber','खीरा','Zaid',60,350,18,30,'Loamy,Sandy'),
 ('Moong','मूँग','Zaid',70,350,25,35,'Loamy,Sandy'),
 ('Turmeric','हल्दी','Kharif',240,1500,20,35,'Loamy,Clay')
ON CONFLICT (crop_name) DO UPDATE SET
    crop_name_hindi = EXCLUDED.crop_name_hindi,
    category        = EXCLUDED.category,
    avg_grow_days   = EXCLUDED.avg_grow_days,
    water_need_mm   = EXCLUDED.water_need_mm,
    ideal_temp_min  = EXCLUDED.ideal_temp_min,
    ideal_temp_max  = EXCLUDED.ideal_temp_max,
    ideal_soil_types = EXCLUDED.ideal_soil_types;

-- --- government schemes (idempotent upsert) -----------------------------------
INSERT INTO government_schemes (scheme_name, scheme_name_hi, ministry, benefit_amount, eligibility_json, apply_url, deadline)
VALUES
 ('PM-KISAN Samman Nidhi','पीएम-किसान सम्मान निधि','Ministry of Agriculture & Farmers Welfare',6000,
  '{"max_land": 5, "states": ["UP","MP","Punjab","Bihar","Rajasthan","Maharashtra"]}'::jsonb,'https://pmkisan.gov.in/',DATE '2026-12-31'),
 ('Pradhan Mantri Fasal Bima Yojana','प्रधानमंत्री फसल बीमा योजना','Ministry of Agriculture & Farmers Welfare',0,
  '{"crops": ["Wheat","Rice","Cotton","Soybean","Groundnut"], "min_land": 0.5}'::jsonb,'https://pmfby.gov.in/',DATE '2026-09-30'),
 ('Kisan Credit Card','किसान क्रेडिट कार्ड','Ministry of Finance',300000,
  '{"min_land": 0.5, "max_land": 50}'::jsonb,'https://www.myscheme.gov.in/schemes/kcc',NULL),
 ('Soil Health Card Scheme','मृदा स्वास्थ्य कार्ड योजना','Ministry of Agriculture & Farmers Welfare',0,
  '{"min_land": 0.1}'::jsonb,'https://soilhealth.dac.gov.in/',NULL),
 ('PM Krishi Sinchai Yojana','पीएम कृषि सिंचाई योजना','Ministry of Jal Shakti',0,
  '{"states": ["UP","MP","Rajasthan","Maharashtra"], "min_land": 1}'::jsonb,'https://pmksy.gov.in/',DATE '2026-10-31'),
 ('eNAM (National Agriculture Market)','ई-नाम राष्ट्रीय कृषि बाजार','Ministry of Agriculture & Farmers Welfare',0,
  '{"crops": ["Wheat","Rice","Maize","Mustard","Gram"]}'::jsonb,'https://enam.gov.in/',NULL),
 ('Sugarcane Farmers FRP Support','गन्ना किसान एफआरपी सहायता','Ministry of Consumer Affairs',0,
  '{"crops": ["Sugarcane"], "states": ["UP","Maharashtra"]}'::jsonb,'https://www.myscheme.gov.in/',DATE '2026-08-31')
ON CONFLICT (scheme_name) DO UPDATE SET
    scheme_name_hi   = EXCLUDED.scheme_name_hi,
    ministry         = EXCLUDED.ministry,
    benefit_amount   = EXCLUDED.benefit_amount,
    eligibility_json = EXCLUDED.eligibility_json,
    apply_url        = EXCLUDED.apply_url,
    deadline         = EXCLUDED.deadline,
    is_active        = 'Y';

-- --- clear prior synthetic rows (idempotent reseed) ---------------------------
DELETE FROM alerts         WHERE farmer_id IN (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%');
DELETE FROM scheme_matches WHERE farmer_id IN (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%');
DELETE FROM disease_scans  WHERE farmer_id IN (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%');
DELETE FROM ml_predictions WHERE farmer_crop_id IN (
    SELECT farmer_crop_id FROM farmer_crops WHERE farmer_id IN
        (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%'));
DELETE FROM farmer_crops   WHERE farmer_id IN (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%');
DELETE FROM farmers        WHERE phone LIKE '90000%';
DELETE FROM mandi_prices   WHERE source = 'SEED';

-- --- 1,000 farmers ------------------------------------------------------------
WITH params AS (
    SELECT ARRAY['UP','UP','UP','UP','UP','UP','UP','MP','MP','MP','MP','MP','MP',
                 'Punjab','Punjab','Punjab','Punjab','Punjab','Punjab','Punjab'] AS states,
           ARRAY['Lucknow','Kanpur','Varanasi','Agra','Meerut','Gorakhpur','Bareilly',
                 'Bhopal','Indore','Jabalpur','Gwalior','Ujjain','Sagar',
                 'Ludhiana','Amritsar','Patiala','Jalandhar','Bathinda','Mohali','Ferozepur'] AS districts,
           ARRAY['Sandy','Loamy','Clay','Black','Silt'] AS soils,
           ARRAY['Ramesh','Suresh','Lakshmi','Anita','Vijay','Sunita','Mohan','Gita','Rajesh','Kavita',
                 'Arjun','Pooja','Dinesh','Meena','Harpreet','Gurpreet','Simran','Manjeet','Balwinder','Karan'] AS names
)
INSERT INTO farmers (name, phone, email, aadhaar_hash, state, district, village, land_acres, soil_type, preferred_lang, is_active)
SELECT
    p.names[(i % 20) + 1] || ' #' || i,
    '90000' || lpad(i::text, 5, '0'),
    'farmer' || i || '@example.com',
    encode(digest('AADHAAR-' || i, 'sha256'), 'hex'),
    p.states[(i % 20) + 1],
    p.districts[(i % 20) + 1],
    'Village-' || (i % 50),
    round((0.5 + random() * 11.5)::numeric, 2),
    p.soils[(i % 5) + 1],
    CASE WHEN i % 4 = 0 THEN 'en' ELSE 'hi' END,
    'Y'
FROM generate_series(1, 1000) AS i, params p;

-- --- 1-2 active crops per farmer ----------------------------------------------
-- crop 1 for everyone; crop 2 for even farmer rownums. Crop chosen round-robin.
WITH fc AS (
    SELECT f.farmer_id, f.land_acres,
           row_number() OVER (ORDER BY f.farmer_id) AS rn
    FROM farmers f WHERE f.phone LIKE '90000%'
), cl AS (
    SELECT crop_id, row_number() OVER (ORDER BY crop_id) - 1 AS ci, count(*) OVER () AS n
    FROM crops
), plan AS (
    SELECT fc.farmer_id, fc.land_acres, fc.rn, g AS slot
    FROM fc, generate_series(1, 2) AS g
    WHERE g = 1 OR fc.rn % 2 = 0
)
INSERT INTO farmer_crops (farmer_id, crop_id, sowing_date, expected_harvest, plot_acres, season, status)
SELECT
    plan.farmer_id,
    (SELECT crop_id FROM cl WHERE cl.ci = ((plan.rn + plan.slot) % (SELECT n FROM cl LIMIT 1))),
    current_date - ((10 + random() * 80)::int),
    current_date + ((30 + random() * 90)::int),
    round((plan.land_acres / (CASE WHEN plan.rn % 2 = 0 THEN 2 ELSE 1 END))::numeric, 2),
    (ARRAY['Kharif','Rabi','Zaid'])[(plan.rn % 3) + 1],
    'ACTIVE'
FROM plan;

-- --- ~500 disease scans (HIGH/CRITICAL fire alerts via trigger) ----------------
WITH picks AS (
    SELECT fc.farmer_id, fc.farmer_crop_id,
           row_number() OVER (ORDER BY random()) AS rn
    FROM farmer_crops fc
    JOIN farmers f ON f.farmer_id = fc.farmer_id AND f.phone LIKE '90000%'
    LIMIT 500
), d AS (
    SELECT ARRAY['Tomato Late Blight','Wheat Leaf Rust','Rice Blast','Potato Early Blight',
                 'Cotton Bacterial Blight','Maize Common Rust','Soybean Mosaic Virus','Healthy'] AS diseases,
           ARRAY['LOW','MEDIUM','HIGH','CRITICAL'] AS sev
)
INSERT INTO disease_scans (farmer_id, farmer_crop_id, image_url, disease_detected,
    confidence_score, severity, treatment_advice, treatment_hindi, scan_timestamp, oci_vision_req)
SELECT
    picks.farmer_id, picks.farmer_crop_id,
    'https://example.com/disease-scans/scan_' || picks.rn || '.jpg',
    d.diseases[(picks.rn % 8) + 1],
    round((70 + random() * 29)::numeric, 2),
    CASE WHEN d.diseases[(picks.rn % 8) + 1] = 'Healthy' THEN 'LOW' ELSE d.sev[(picks.rn % 4) + 1] END,
    'Apply recommended fungicide; remove affected leaves; ensure proper drainage.',
    'अनुशंसित फफूंदनाशक का छिड़काव करें; प्रभावित पत्तियाँ हटाएँ; जल निकासी सुनिश्चित करें.',
    now() - ((random() * 180)::int || ' days')::interval,
    'seed.' || picks.rn
FROM picks, d;

-- --- 365 days of Mandi prices for ALL crops x 7 mandis -----------------------
-- Deterministic-ish swing (sinusoid + noise) so PR-01/PR-02 rules can trigger.
WITH m AS (
    SELECT * FROM (VALUES
        (1,'Azadpur Mandi','Delhi','Delhi'),
        (2,'Indore Mandi','Indore','MP'),
        (3,'Khanna Mandi','Ludhiana','Punjab'),
        (4,'Lucknow Mandi','Lucknow','UP'),
        (5,'Pune Mandi','Pune','Maharashtra'),
        (6,'Jaipur Mandi','Jaipur','Rajasthan'),
        (7,'Patna Mandi','Patna','Bihar')
    ) AS t(mi, mandi_name, district, state)
), c AS (
    SELECT crop_id, row_number() OVER (ORDER BY crop_id) AS ci,
           1500 + random() * 4500 AS base
    FROM crops ORDER BY crop_id
)
INSERT INTO mandi_prices (crop_id, mandi_name, district, state, price_per_qtl, recorded_date, source)
SELECT
    c.crop_id, m.mandi_name, m.district, m.state,
    round(greatest(300, c.base * (1 + 0.18 * sin(day_off / 9.0 + c.ci + m.mi) + (random() - 0.5) * 0.06))::numeric, 2),
    current_date - day_off,
    'SEED'
FROM c, m, generate_series(0, 364) AS day_off;

-- --- initial scheme-match pass (simplified jsonb scoring) ---------------------
-- Mirrors the app's scoreMatch: % of present criteria the farmer satisfies.
-- (The app's matchAllFarmers can be re-run later for the authoritative pass.)
INSERT INTO scheme_matches (farmer_id, scheme_id, match_score, notified)
SELECT f.farmer_id, gs.scheme_id,
       round((100.0 * met / NULLIF(crit, 0))::numeric, 2) AS score,
       'N'
FROM farmers f
CROSS JOIN LATERAL (
    SELECT gs.scheme_id, gs.eligibility_json AS ej FROM government_schemes gs WHERE gs.is_active = 'Y'
) gs
CROSS JOIN LATERAL (
    SELECT
      -- criteria count
      (CASE WHEN gs.ej ? 'min_land'   THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'max_land'   THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'states'     THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'crops'      THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'max_income' THEN 1 ELSE 0 END) AS crit,
      -- criteria met
      (CASE WHEN gs.ej ? 'min_land' AND f.land_acres >= (gs.ej->>'min_land')::numeric THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'max_land' AND f.land_acres <= (gs.ej->>'max_land')::numeric THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'states' AND EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(gs.ej->'states') s WHERE upper(s) = upper(f.state)) THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'crops' AND EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(gs.ej->'crops') cn
           JOIN farmer_crops fc2 ON fc2.farmer_id = f.farmer_id AND fc2.status = 'ACTIVE'
           JOIN crops c2 ON c2.crop_id = fc2.crop_id
           WHERE upper(c2.crop_name) = upper(cn)) THEN 1 ELSE 0 END
     + CASE WHEN gs.ej ? 'max_income' THEN 1 ELSE 0 END) AS met
) sc
WHERE f.phone LIKE '90000%' AND sc.crit > 0 AND sc.met > 0
ON CONFLICT (farmer_id, scheme_id) DO UPDATE SET match_score = EXCLUDED.match_score;
