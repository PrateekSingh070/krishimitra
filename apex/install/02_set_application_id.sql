-- =============================================================================
-- KrishiMitra :: APEX import wrapper
-- Forces the imported application to install as Application ID 100 into the
-- target workspace. Run this immediately before importing the exported f100.sql
-- (generated via SQL Developer / APEXExport, see apex/README.md).
-- =============================================================================
BEGIN
    apex_application_install.set_workspace('KRISHIMITRA');
    apex_application_install.set_application_id(100);
    apex_application_install.generate_offset;
    apex_application_install.set_application_alias('KRISHIMITRA');
END;
/

-- Then:  @f100.sql
