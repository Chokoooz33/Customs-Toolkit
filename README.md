# Customs Toolkit — أدوات التخليص الجمركي

Oman customs clearance toolkit. This repository contains:

| Folder | What it is |
| --- | --- |
| `docs/` | **The PWA** (installable web app, works offline) — published by GitHub Pages |
| `supabase/` | Cloud database schema (users, settings, cargo board, saved calculations) + gold-price Edge Function |
| `tools/build_web_data.py` | Regenerates `docs/data/tariff.json` and `docs/js/strings.js` from the iOS sources |
| `CustomsToolkit/` | Original native iOS (SwiftUI) app |

## Features (web)

- Sign in / create account / password reset (Supabase Auth)
- HS code search over the full Oman Tariff 2026 (14,365 records, offline)
- Duty & VAT calculator (CIF / CFR / FOB / EXW, documentation guarantee, Bayan fee)
- Duty & VAT difference calculator, unit converter
- Gold price (via Supabase Edge Function)
- Air cargo tracking links (airline + Transom/OmanSATS) and a personal Cargo Board synced to the cloud
- Arabic / English, light / dark, Air / Sea workspaces

---

## الإعداد خطوة بخطوة

### 1) إنشاء قاعدة البيانات في Supabase

1. ادخل [supabase.com](https://supabase.com) وأنشئ مشروعاً جديداً (اختر منطقة قريبة مثل `Middle East (Bahrain)` أو `Europe`).
2. من **SQL Editor** → **New query**: الصق محتوى الملف `supabase/schema.sql` واضغط **Run**.
3. من **Project Settings → API** انسخ:
   - `Project URL`
   - `anon public` key
4. افتح `docs/js/config.js` وضع القيمتين مكان `YOUR_SUPABASE_URL` و `YOUR_SUPABASE_ANON_KEY`.
   > مفتاح `anon` مصمم ليكون عاماً في المتصفح، والحماية تتم عبر سياسات RLS. **لا تضع أبداً** مفتاح `service_role`.
5. من **Authentication → URL Configuration**:
   - **Site URL**: رابط الموقع على GitHub Pages، مثل `https://USERNAME.github.io/REPO/`
   - أضف نفس الرابط في **Redirect URLs** (حتى تعمل روابط تأكيد البريد واستعادة كلمة المرور).

### 2) سعر الذهب (اختياري)

المتصفح لا يستطيع قراءة موقع أسعار الذهب مباشرة، لذلك توجد دالة سحابية صغيرة:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase functions deploy gold-price
```

بدونها يعمل كل شيء آخر، وتظهر في صفحة الذهب رسالة مع رابط المصدر.

### 3) الرفع إلى GitHub والتشغيل الدائم

1. أنشئ مستودعاً جديداً فارغاً على GitHub (بدون README).
2. من مجلد المشروع:
   ```bash
   git remote add origin https://github.com/USERNAME/REPO.git
   git push -u origin main
   ```
3. في المستودع: **Settings → Pages → Build and deployment**
   - Source: **Deploy from a branch**
   - Branch: **main** — Folder: **/docs** → **Save**
4. بعد دقيقة يصبح الموقع متاحاً على `https://USERNAME.github.io/REPO/` ويعمل طوال الوقت.

### 4) التثبيت على الجوال

- **iPhone (Safari)**: مشاركة ← «إضافة إلى الشاشة الرئيسية».
- **Android (Chrome)**: يظهر زر «تثبيت التطبيق» داخل الصفحة الرئيسية.

## تحديث الموقع لاحقاً

عدّل الملفات داخل `docs/` ثم:

```bash
git add -A && git commit -m "وصف التعديل" && git push
```

إذا عدّلت التعرفة أو النصوص في تطبيق iOS، أعد توليد ملفات الويب:

```bash
python3 tools/build_web_data.py
```

## إدارة المستخدمين

- كل المستخدمين يظهرون في **Supabase → Authentication → Users**، وبياناتهم في جدول `profiles`.
- لإغلاق التسجيل العام: **Authentication → Providers → Email → Allow new users to sign up** (إيقاف)، ثم أضف المستخدمين يدوياً بزر **Invite user**.
- كل مستخدم يرى بياناته فقط (Row Level Security).

## Differences from the iOS app

- **Live air-cargo scraping** (WebKit automation of airline sites) is not possible inside a browser; the web version identifies the airline from the AWB prefix, opens the official airline and Transom trackers, and keeps a cloud-synced Cargo Board where you record each shipment's status.
- **Camera HS scanning** is iOS-only.
