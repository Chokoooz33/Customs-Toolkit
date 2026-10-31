import { STRINGS } from "./strings.js";

// Strings that exist only in the web version (login, cloud sync, install).
const EXTRA = {
  en: {
    auth_sign_in: "Sign In",
    auth_sign_up: "Create Account",
    auth_email: "Email",
    auth_password: "Password",
    auth_full_name: "Full name",
    auth_forgot: "Forgot password?",
    auth_send_reset: "Send reset link",
    auth_reset_sent: "If this email is registered, a reset link has been sent.",
    auth_back_to_sign_in: "Back to sign in",
    auth_new_password: "New password",
    auth_set_password: "Save new password",
    auth_password_updated: "Password updated.",
    auth_check_email: "Account created. Check your email to confirm it, then sign in.",
    auth_welcome: "Sign in to access the customs tools.",
    auth_sign_out: "Sign Out",
    auth_signed_in_as: "Signed in as",
    auth_password_rule: "At least 8 characters.",
    auth_show_password: "Show password",
    auth_not_configured_title: "Cloud database not connected",
    auth_not_configured_desc: "Add your Supabase URL and anon key to docs/js/config.js to enable sign-in.",
    account: "Account",
    cloud_synced: "Synced to your account",
    install_app: "Install App",
    install_desc: "Add Customs Toolkit to your home screen for full-screen, offline use.",
    install_ios: "On iPhone: tap Share, then “Add to Home Screen”.",
    offline_ready: "Ready to work offline",
    loading_tariff: "Loading tariff data…",
    save_calculation: "Save",
    saved_calculation: "Calculation saved",
    delete: "Delete",
    tracking_web_note: "In the web version, the official tracking pages open in a new tab. Record the status on your Cargo Board after checking.",
    tracking_transom_source: "Transom Cargo / OmanSATS",
    tracking_set_status: "Status",
    tracking_note: "Note",
    tracking_added: "Added to Cargo Board",
    gold_needs_function: "Live prices need the gold-price function deployed on Supabase. You can still open the source.",
    camera_web_unavailable: "Camera scanning is available in the iOS app only.",
    error_generic: "Something went wrong. Please try again.",
    hs_detail: "HS Code Details",
    hierarchy: "Classification",
    subheading: "Subheading",
    open_source: "Open source",
    update_available: "A new version is available.",
    reload: "Reload",
  },
  ar: {
    auth_sign_in: "تسجيل الدخول",
    auth_sign_up: "إنشاء حساب",
    auth_email: "البريد الإلكتروني",
    auth_password: "كلمة المرور",
    auth_full_name: "الاسم الكامل",
    auth_forgot: "نسيت كلمة المرور؟",
    auth_send_reset: "إرسال رابط الاستعادة",
    auth_reset_sent: "إذا كان البريد مسجلاً، فقد تم إرسال رابط إعادة التعيين.",
    auth_back_to_sign_in: "العودة لتسجيل الدخول",
    auth_new_password: "كلمة المرور الجديدة",
    auth_set_password: "حفظ كلمة المرور",
    auth_password_updated: "تم تحديث كلمة المرور.",
    auth_check_email: "تم إنشاء الحساب. افحص بريدك لتأكيده ثم سجّل الدخول.",
    auth_welcome: "سجّل الدخول للوصول إلى الأدوات الجمركية.",
    auth_sign_out: "تسجيل الخروج",
    auth_signed_in_as: "مسجّل الدخول باسم",
    auth_password_rule: "8 أحرف على الأقل.",
    auth_show_password: "إظهار كلمة المرور",
    auth_not_configured_title: "قاعدة البيانات السحابية غير مربوطة",
    auth_not_configured_desc: "أضف رابط Supabase ومفتاح anon في الملف docs/js/config.js لتفعيل تسجيل الدخول.",
    account: "الحساب",
    cloud_synced: "محفوظ في حسابك",
    install_app: "تثبيت التطبيق",
    install_desc: "أضف أدوات التخليص الجمركي إلى الشاشة الرئيسية للعمل بملء الشاشة وبدون إنترنت.",
    install_ios: "على الآيفون: اضغط مشاركة ثم «إضافة إلى الشاشة الرئيسية».",
    offline_ready: "جاهز للعمل بدون إنترنت",
    loading_tariff: "جارٍ تحميل التعرفة…",
    save_calculation: "حفظ",
    saved_calculation: "تم حفظ الحساب",
    delete: "حذف",
    tracking_web_note: "في نسخة الويب تُفتح صفحات التتبع الرسمية في تبويب جديد. سجّل حالة الشحنة في لوحة الشحنات بعد التحقق.",
    tracking_transom_source: "ترانسوم للشحن / عمان ساتس",
    tracking_set_status: "الحالة",
    tracking_note: "ملاحظة",
    tracking_added: "تمت الإضافة إلى لوحة الشحنات",
    gold_needs_function: "الأسعار المباشرة تحتاج نشر دالة gold-price على Supabase. يمكنك فتح المصدر مباشرة.",
    camera_web_unavailable: "المسح بالكاميرا متاح في تطبيق iOS فقط.",
    error_generic: "حدث خطأ. حاول مرة أخرى.",
    hs_detail: "تفاصيل رمز HS",
    hierarchy: "التصنيف",
    subheading: "البند الفرعي",
    open_source: "فتح المصدر",
    update_available: "يتوفر إصدار جديد.",
    reload: "تحديث",
  },
};

const LANG_KEY = "customs_toolkit_selected_language";

function initialLang() {
  try {
    const saved = localStorage.getItem(LANG_KEY);
    if (saved === "en" || saved === "ar") return saved;
  } catch {}
  return (navigator.language || "en").startsWith("ar") ? "ar" : "en";
}

let lang = initialLang();

export const getLang = () => lang;
export const isRTL = () => lang === "ar";

export function setLang(next) {
  lang = next === "ar" ? "ar" : "en";
  try { localStorage.setItem(LANG_KEY, lang); } catch {}
  applyDocumentLang();
}

export function applyDocumentLang() {
  document.documentElement.lang = lang;
  document.documentElement.dir = isRTL() ? "rtl" : "ltr";
}

/** Looks up a key; supports the iOS `%d` / `%@` placeholders. */
export function t(key, ...args) {
  let s = EXTRA[lang][key] ?? STRINGS[lang][key] ?? EXTRA.en[key] ?? STRINGS.en[key] ?? key;
  for (const a of args) s = s.replace(/%(d|@|s)/, String(a));
  return s;
}
