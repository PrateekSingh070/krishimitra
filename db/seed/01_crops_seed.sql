-- =============================================================================
-- KrishiMitra :: Seed - CROPS (bilingual master data)
-- ~20 common Indian crops with agronomic parameters.
-- Idempotent: uses MERGE on crop_name.
-- =============================================================================
SET DEFINE OFF;

MERGE INTO crops t
USING (
    SELECT 'Wheat'      crop_name, 'गेहूँ'    crop_name_hindi, 'Rabi'   category, 120 avg_grow_days, 450 water_need_mm, 10 ideal_temp_min, 25 ideal_temp_max, 'Loamy,Clay'        ideal_soil_types FROM dual UNION ALL
    SELECT 'Rice',       'चावल',      'Kharif', 130, 1200, 20, 37, 'Clay,Loamy'          FROM dual UNION ALL
    SELECT 'Maize',      'मक्का',      'Kharif', 100, 500,  18, 32, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Bajra',      'बाजरा',      'Kharif', 80,  350,  25, 35, 'Sandy,Loamy'         FROM dual UNION ALL
    SELECT 'Jowar',      'ज्वार',      'Kharif', 110, 400,  25, 33, 'Loamy,Black'         FROM dual UNION ALL
    SELECT 'Sugarcane',  'गन्ना',      'Kharif', 360, 1800, 20, 38, 'Loamy,Clay'          FROM dual UNION ALL
    SELECT 'Cotton',     'कपास',       'Kharif', 180, 700,  21, 35, 'Black,Loamy'         FROM dual UNION ALL
    SELECT 'Soybean',    'सोयाबीन',    'Kharif', 100, 500,  20, 30, 'Loamy,Black'         FROM dual UNION ALL
    SELECT 'Groundnut',  'मूँगफली',    'Kharif', 120, 500,  25, 30, 'Sandy,Loamy'         FROM dual UNION ALL
    SELECT 'Mustard',    'सरसों',      'Rabi',   110, 240,  10, 25, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Gram',       'चना',        'Rabi',   100, 300,  15, 30, 'Loamy,Clay'          FROM dual UNION ALL
    SELECT 'Lentil',     'मसूर',       'Rabi',   110, 280,  18, 30, 'Loamy,Clay'          FROM dual UNION ALL
    SELECT 'Barley',     'जौ',         'Rabi',   115, 300,  12, 25, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Potato',     'आलू',        'Rabi',   90,  500,  15, 25, 'Sandy,Loamy'         FROM dual UNION ALL
    SELECT 'Onion',      'प्याज',      'Rabi',   120, 450,  13, 28, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Tomato',     'टमाटर',      'Zaid',   90,  400,  20, 27, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Watermelon', 'तरबूज',      'Zaid',   85,  400,  24, 32, 'Sandy,Loamy'         FROM dual UNION ALL
    SELECT 'Cucumber',   'खीरा',       'Zaid',   60,  350,  18, 30, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Moong',      'मूँग',       'Zaid',   70,  350,  25, 35, 'Loamy,Sandy'         FROM dual UNION ALL
    SELECT 'Turmeric',   'हल्दी',      'Kharif', 240, 1500, 20, 35, 'Loamy,Clay'          FROM dual
) s
ON (t.crop_name = s.crop_name)
WHEN MATCHED THEN UPDATE SET
    t.crop_name_hindi  = s.crop_name_hindi,
    t.category         = s.category,
    t.avg_grow_days    = s.avg_grow_days,
    t.water_need_mm    = s.water_need_mm,
    t.ideal_temp_min   = s.ideal_temp_min,
    t.ideal_temp_max   = s.ideal_temp_max,
    t.ideal_soil_types = s.ideal_soil_types
WHEN NOT MATCHED THEN INSERT (
    crop_name, crop_name_hindi, category, avg_grow_days, water_need_mm,
    ideal_temp_min, ideal_temp_max, ideal_soil_types
) VALUES (
    s.crop_name, s.crop_name_hindi, s.category, s.avg_grow_days, s.water_need_mm,
    s.ideal_temp_min, s.ideal_temp_max, s.ideal_soil_types
);

COMMIT;
