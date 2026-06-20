-- =============================================================================
-- KrishiMitra :: Seed - GOVERNMENT_SCHEMES (bilingual + JSON eligibility)
-- Real central schemes with representative eligibility rules.
-- Idempotent: MERGE on scheme_name.
-- =============================================================================
SET DEFINE OFF;

MERGE INTO government_schemes t
USING (
    SELECT
        'PM-KISAN Samman Nidhi' scheme_name,
        'पीएम-किसान सम्मान निधि' scheme_name_hi,
        'Ministry of Agriculture & Farmers Welfare' ministry,
        6000 benefit_amount,
        '{"max_land": 5, "states": ["UP","MP","Punjab","Bihar","Rajasthan","Maharashtra"]}' eligibility_json,
        'https://pmkisan.gov.in/' apply_url,
        DATE '2026-12-31' deadline
    FROM dual UNION ALL
    SELECT
        'Pradhan Mantri Fasal Bima Yojana',
        'प्रधानमंत्री फसल बीमा योजना',
        'Ministry of Agriculture & Farmers Welfare',
        0,
        '{"crops": ["Wheat","Rice","Cotton","Soybean","Groundnut"], "min_land": 0.5}',
        'https://pmfby.gov.in/',
        DATE '2026-09-30'
    FROM dual UNION ALL
    SELECT
        'Kisan Credit Card',
        'किसान क्रेडिट कार्ड',
        'Ministry of Finance',
        300000,
        '{"min_land": 0.5, "max_land": 50}',
        'https://www.myscheme.gov.in/schemes/kcc',
        NULL
    FROM dual UNION ALL
    SELECT
        'Soil Health Card Scheme',
        'मृदा स्वास्थ्य कार्ड योजना',
        'Ministry of Agriculture & Farmers Welfare',
        0,
        '{"min_land": 0.1}',
        'https://soilhealth.dac.gov.in/',
        NULL
    FROM dual UNION ALL
    SELECT
        'PM Krishi Sinchai Yojana',
        'पीएम कृषि सिंचाई योजना',
        'Ministry of Jal Shakti',
        0,
        '{"states": ["UP","MP","Rajasthan","Maharashtra"], "min_land": 1}',
        'https://pmksy.gov.in/',
        DATE '2026-10-31'
    FROM dual UNION ALL
    SELECT
        'eNAM (National Agriculture Market)',
        'ई-नाम राष्ट्रीय कृषि बाजार',
        'Ministry of Agriculture & Farmers Welfare',
        0,
        '{"crops": ["Wheat","Rice","Maize","Mustard","Gram"]}',
        'https://enam.gov.in/',
        NULL
    FROM dual UNION ALL
    SELECT
        'Sugarcane Farmers FRP Support',
        'गन्ना किसान एफआरपी सहायता',
        'Ministry of Consumer Affairs',
        0,
        '{"crops": ["Sugarcane"], "states": ["UP","Maharashtra"]}',
        'https://www.myscheme.gov.in/',
        DATE '2026-08-31'
    FROM dual
) s
ON (t.scheme_name = s.scheme_name)
WHEN MATCHED THEN UPDATE SET
    t.scheme_name_hi   = s.scheme_name_hi,
    t.ministry         = s.ministry,
    t.benefit_amount   = s.benefit_amount,
    t.eligibility_json = s.eligibility_json,
    t.apply_url        = s.apply_url,
    t.deadline         = s.deadline,
    t.is_active        = 'Y'
WHEN NOT MATCHED THEN INSERT (
    scheme_name, scheme_name_hi, ministry, benefit_amount,
    eligibility_json, apply_url, deadline, is_active
) VALUES (
    s.scheme_name, s.scheme_name_hi, s.ministry, s.benefit_amount,
    s.eligibility_json, s.apply_url, s.deadline, 'Y'
);

COMMIT;
