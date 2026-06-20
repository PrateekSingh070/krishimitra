# KrishiMitra :: Oracle APEX

Farmer-facing portal + admin panel, **Application ID 100**, workspace
`KRISHIMITRA`. Built on the Universal Theme with a custom green/amber
agriculture theme, full Hindi/English toggle, mobile-first layout, PWA install,
and WCAG 2.1 AA targets.

## What's in this folder

```
install/01_supporting_objects.sql  Views + LOVs + ui_messages the pages bind to
install/02_set_application_id.sql  apex_application_install wrapper (forces app 100)
static/css/krishimitra.css         Theme (colors, Devanagari font, severity badges)
static/js/lang-toggle.js           Hindi/English toggle + APEX session state
PAGES.md                           Full page-by-page blueprint (9 pages)
```

> An APEX application export (`f100.sql`) is a large auto-generated file produced
> by the builder, not authored by hand. This folder contains the reproducible
> source: the supporting DB objects the app binds to, the static theme assets,
> and the page blueprint. Generate `f100.sql` from a built app with
> `apex export -applicationid 100` (SQLcl) or SQL Developer, and commit it
> alongside these files.

## Install / import

```bash
# 1. Supporting objects (as the KRISHIMITRA schema owner, after db/deploy.sql)
sql krishimitra/<pwd>@<tns> @apex/install/01_supporting_objects.sql

# 2. Upload static files in Shared Components > Static Application Files:
#    krishimitra.css, lang-toggle.js  (referenced via #APP_IMAGES#)

# 3. Import the application as ID 100
sql krishimitra/<pwd>@<tns>
SQL> @apex/install/02_set_application_id.sql
SQL> @f100.sql        -- the exported app
```

## Design requirements (met)

- **Theme:** Universal Theme, primary `#2D6A4F`, accent `#F4A261`.
- **Fonts:** Noto Sans (Latin) + Noto Sans Devanagari (Hindi).
- **Bilingual:** every label available in hi+en (`ui_messages` + `[lang]` spans);
  toggle persists in `P_LANG` session state and `localStorage`.
- **Mobile-first:** validated at 375px; 44px tap targets.
- **PWA:** installable on Android; Home page offline-capable.
- **Accessibility:** WCAG 2.1 AA (labels, contrast, keyboard nav).
- **Security:** session state protection + CSRF tokens on forms (APEX default),
  custom auth mapping `APP_USER` to `farmers.phone`.
