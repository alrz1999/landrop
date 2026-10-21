// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'LanDrop';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsLanguageSystem => 'پیش‌فرض سیستم';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePersian => 'فارسی';

  @override
  String get commonCancel => 'انصراف';

  @override
  String sizeBytes(String value) {
    return '$value بایت';
  }

  @override
  String sizeKB(String value) {
    return '$value کیلوبایت';
  }

  @override
  String sizeMB(String value) {
    return '$value مگابایت';
  }

  @override
  String sizeGB(String value) {
    return '$value گیگابایت';
  }

  @override
  String sizeTB(String value) {
    return '$value ترابایت';
  }

  @override
  String speedPerSecond(String size) {
    return '$size بر ثانیه';
  }

  @override
  String durationSeconds(String seconds) {
    return '$seconds ثانیه';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes دقیقه';
  }

  @override
  String durationHours(String hours) {
    return '$hours ساعت';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours ساعت و $minutes دقیقه';
  }

  @override
  String get sendErrorDeclined => 'دستگاه دیگر ارسال را رد کرد.';

  @override
  String get sendErrorBusy =>
      'دستگاه دیگر مشغول انتقال دیگری است. چند لحظه بعد دوباره امتحان کنید.';

  @override
  String get sendErrorUnreachable =>
      'اتصال به دستگاه دیگر ممکن نشد. بررسی کنید هر دو دستگاه در یک شبکه باشند.';

  @override
  String get sendErrorCancelled => 'انتقال لغو شد.';

  @override
  String get sendErrorTimeout => 'پاسخی از دستگاه دیگر نرسید.';

  @override
  String get sendErrorFingerprintMismatch =>
      'کد امنیتی دستگاه دیگر تغییر کرده است. پیش از ارسال دوباره جست‌وجو کنید.';

  @override
  String get sendErrorDiskError => 'خواندن یا ذخیرهٔ یک فایل ممکن نشد.';

  @override
  String get sendErrorUnknown => 'ارسال انجام نشد.';

  @override
  String diagWhatToDo(String fix) {
    return 'راه‌حل: $fix';
  }

  @override
  String get diagServerDownTitle => 'این دستگاه الان نمی‌تواند فایل دریافت کند';

  @override
  String get diagServerDownDetail =>
      'LanDrop روی این دستگاه اتصالی نمی‌پذیرد، پس دستگاه‌های دیگر نمی‌توانند آن را ببینند یا برایش فایل بفرستند.';

  @override
  String get diagServerDownFix =>
      'در تنظیمات «راه‌اندازی دوبارهٔ سرویس» را بزنید، یا LanDrop را ببندید و دوباره باز کنید.';

  @override
  String get diagDiscoveryFailedTitle => 'جست‌وجوی خودکار خاموش است';

  @override
  String get diagDiscoveryFailedDetail =>
      'LanDrop نتوانست جست‌وجوی دستگاه‌های اطراف را شروع کند، پس آن‌ها خودبه‌خود نمایش داده نمی‌شوند. ارسال با نشانی IP همچنان کار می‌کند.';

  @override
  String get diagDiscoveryFailedFix =>
      'از «جست‌وجوی دوبارهٔ شبکه» یا «افزودن با IP» استفاده کنید. راه‌اندازی دوبارهٔ LanDrop یا اجازه دادن به دسترسی شبکهٔ محلی ممکن است مشکل را حل کند.';

  @override
  String get diagNoLanTitle => 'به وای‌فای یا شبکهٔ محلی وصل نیست';

  @override
  String get diagNoLanDetail =>
      'این دستگاه نشانی شبکهٔ محلی ندارد، پس نمی‌تواند به دستگاه‌های اطراف برسد.';

  @override
  String get diagNoLanFix =>
      'به همان وای‌فای دستگاه دیگر وصل شوید، کابل شبکه وصل کنید، یا هات‌اسپات را روی یک دستگاه روشن کنید و با دستگاه دیگر به آن وصل شوید.';

  @override
  String get diagLinkLocalOnlyTitle =>
      'اتصال مستقیم با کابل یا شبکهٔ بدون DHCP';

  @override
  String get diagLinkLocalOnlyDetail =>
      'به نظر می‌رسد دستگاه‌ها مستقیم با کابل وصل‌اند یا شبکه DHCP ندارد. LanDrop کار می‌کند، ولی هر دو دستگاه باید به هم وصل باشند؛ چند لحظه به هر دو فرصت دهید تا نشانی بگیرند.';

  @override
  String get diagVpnActiveTitle => 'یک VPN روشن است';

  @override
  String get diagVpnActiveDetail =>
      'VPN معمولاً شبکهٔ محلی را پنهان می‌کند، پس دستگاه‌های اطراف نمی‌توانند به هم برسند.';

  @override
  String get diagVpnActiveFix =>
      'VPN را خاموش کنید یا در تنظیمات آن «دسترسی به شبکهٔ محلی» را مجاز کنید، سپس دوباره امتحان کنید.';

  @override
  String get diagAnnounceBlockedTitle =>
      'دستگاه‌ها فقط بعد از جست‌وجو نمایش داده می‌شوند';

  @override
  String get diagAnnounceBlockedDetail =>
      'به نظر می‌رسد روتر (مودم) شما پیام‌هایی را که دستگاه‌ها برای پیدا کردن هم می‌فرستند (multicast و broadcast) مسدود می‌کند. انتقال با نشانی IP همچنان کار می‌کند.';

  @override
  String get diagAnnounceBlockedFix =>
      'از «جست‌وجوی دوبارهٔ شبکه» یا «افزودن با IP» استفاده کنید. برای حل همیشگی، در تنظیمات روتر multicast را روشن و «AP isolation» را خاموش کنید.';

  @override
  String get diagSomePeersSilentTitle =>
      'برخی دستگاه‌ها خودشان را اعلام نکردند';

  @override
  String get diagSomePeersSilentDetail =>
      'دستگاه‌های دیگر خودکار پیدا شدند، ولی این‌ها فقط با جست‌وجو یا نشانی IP. شاید در بخش دیگری از شبکه باشند یا پیدا شدن خودکار در آن‌ها خاموش باشد.';

  @override
  String get diagProbeRefusedTitle =>
      'دستگاه در دسترس است، ولی LanDrop پاسخ نمی‌دهد';

  @override
  String get diagProbeRefusedDetail =>
      'دستگاه دیگر پاسخ داد، ولی هیچ برنامه‌ای اتصال را نپذیرفت. احتمالاً LanDrop روی آن بسته است یا از پورت دیگری استفاده می‌کند.';

  @override
  String get diagProbeRefusedFix =>
      'LanDrop را روی دستگاه دیگر باز کنید و روی صفحه نگه دارید. نشانی و پورتی را که روی صفحهٔ آن نمایش داده می‌شود بررسی کنید.';

  @override
  String get diagProbeTimeoutTitle => 'پاسخی از این نشانی نیامد';

  @override
  String get diagProbeTimeoutDetail =>
      'هیچ پاسخی نرسید. ممکن است علت آن دیوار آتش، «AP / client isolation» در روتر، یا قرار داشتن در شبکهٔ دیگری باشد.';

  @override
  String get diagProbeTimeoutFix =>
      'بررسی کنید هر دو دستگاه به یک وای‌فای وصل باشند (نه شبکهٔ مهمان). به LanDrop در دیوار آتش اجازه دهید. اگر باز هم نشد، هات‌اسپات را روی یک دستگاه روشن کنید و با دستگاه دیگر به آن وصل شوید.';

  @override
  String get diagProbeUnreachableTitle => 'از اینجا نمی‌توان به این نشانی رسید';

  @override
  String get diagProbeUnreachableDetail =>
      'این دستگاه راهی برای رسیدن به این نشانی ندارد. احتمالاً در شبکهٔ دیگری است یا نشانی اشتباه است.';

  @override
  String get diagProbeUnreachableFix =>
      'نشانی را روی دستگاه دیگر بررسی کنید و هر دو را به یک وای‌فای یا هات‌اسپات وصل کنید.';

  @override
  String get diagProbeFingerprintMismatchTitle =>
      'دستگاه دیگری در این نشانی است';

  @override
  String get diagProbeFingerprintMismatchDetail =>
      'دستگاهِ این نشانی همان دستگاهی نیست که LanDrop قبلاً می‌شناخت. یا دستگاه دیگری این نشانی را گرفته، یا LanDrop آنجا دوباره نصب شده و کلید امنیتی تازه‌ای ساخته است.';

  @override
  String get diagProbeFingerprintMismatchFix =>
      'کد امنیتی نمایش‌داده‌شده در تنظیمات دستگاه دیگر را بررسی کنید. اگر درست است، دستگاه را حذف و دوباره اضافه کنید.';

  @override
  String get diagProbeNotLandropTitle => 'چیزی پاسخ داد، ولی LanDrop نیست';

  @override
  String get diagProbeNotLandropDetail =>
      'برنامه‌ای اتصال را روی این پورت پذیرفت، ولی مثل LanDrop یا LocalSend پاسخ نداد.';

  @override
  String get diagProbeNotLandropFix =>
      'پورتی را که LanDrop روی دستگاه دیگر نشان می‌دهد بررسی کنید.';

  @override
  String get diagProbeOkTitle => 'دستگاه پاسخ می‌دهد';

  @override
  String diagProbeOkDetail(String alias) {
    return '$alias در این نشانی در دسترس است و کار می‌کند.';
  }

  @override
  String get diagDifferentSubnetTitle =>
      'به نظر می‌رسد دستگاه‌ها در شبکه‌های مختلف هستند';

  @override
  String get diagDifferentSubnetDetail =>
      'نشانی‌ها با هم جور نیستند، پس شاید دستگاه‌ها به وای‌فای‌های مختلف وصل باشند یا یکی در شبکهٔ مهمان باشد.';

  @override
  String get diagDifferentSubnetFix =>
      'هر دو دستگاه را به یک وای‌فای وصل کنید (نه شبکهٔ مهمان).';

  @override
  String get diagHotspotLikelyFixTitle => 'هنوز دستگاه دیگری پیدا نشد';

  @override
  String get diagHotspotLikelyFixDetail =>
      'اگر LanDrop روی دستگاه دیگر باز است و باز هم نمایش داده نمی‌شود، احتمالاً این شبکه دستگاه‌ها را از هم جدا نگه می‌دارد (در وای‌فای مهمان، اداره، مدرسه و هتل رایج است). وصل کردن هر دو دستگاه به هات‌اسپات یک گوشی یا لپ‌تاپ معمولاً مشکل را حل می‌کند و به روتر نیازی ندارد.';

  @override
  String get diagHotspotLikelyFixFix =>
      'برای راهنمای قدم‌به‌قدم «اتصال با هات‌اسپات» را بزنید، یا اگر نشانی دستگاه دیگر را می‌دانید از «افزودن با IP» استفاده کنید.';

  @override
  String get diagMdnsOnlyTitle =>
      'روش استاندارد پیدا کردن دستگاه‌ها کار می‌کند';

  @override
  String get diagMdnsOnlyDetail =>
      'اعلام‌های خودِ LanDrop در این شبکه مسدود است، ولی روش استاندارد پیدا کردن دستگاه‌ها (mDNS / Bonjour) کار می‌کند. انتقال فایل انجام می‌شود.';

  @override
  String get diagMdnsVisibleUnreachableTitle =>
      'دستگاه در شبکهٔ شماست، ولی LanDrop به آن دسترسی ندارد';

  @override
  String diagMdnsVisibleUnreachableDetail(String reason) {
    return 'دستگاه در شبکهٔ شماست و خودش را اعلام می‌کند، ولی پورت LanDrop در دسترس نیست: دیوار آتشِ آن دستگاه یا این دستگاه، یا بسته شدن برنامه. $reason';
  }

  @override
  String get diagMdnsVisibleUnreachableFix =>
      'در هر دو دستگاه به LanDrop در دیوار آتش اجازه دهید، LanDrop را روی دستگاه دیگر باز نگه دارید و سپس «جست‌وجوی دوبارهٔ شبکه» را بزنید.';

  @override
  String get diagMdnsReasonTimeout =>
      'روی پورت LanDrop پاسخی نیامد (پایان مهلت)؛ معمولاً یعنی دیوار آتش آن را مسدود می‌کند.';

  @override
  String get diagMdnsReasonRefused =>
      'پورت اتصال را رد کرد؛ معمولاً یعنی LanDrop آنجا در حال بسته شدن است یا اجرا نمی‌شود.';

  @override
  String get diagMdnsReasonFingerprintMismatch =>
      'چیزی پاسخ داد، ولی با کلید امنیتی متفاوتی از آنچه دستگاه اعلام کرده بود.';

  @override
  String get diagMdnsReasonOther => 'اتصال یا بررسی هویت دستگاه ناموفق بود.';

  @override
  String get diagUdpOnlyNoMdnsTitle =>
      'روش استاندارد پیدا کردن دستگاه‌ها (mDNS) مسدود است';

  @override
  String get diagUdpOnlyNoMdnsDetail =>
      'دستگاه‌ها با اعلام‌های خودِ LanDrop پیدا شدند، ولی نه با روش استاندارد (mDNS / Bonjour). این برای LanDrop مشکلی نیست.';

  @override
  String get diagMdnsUnavailableTitle =>
      'روش استاندارد پیدا کردن دستگاه‌ها شروع نشد';

  @override
  String get diagMdnsUnavailableDetail =>
      'LanDrop نتوانست mDNS / Bonjour را روی این دستگاه راه‌اندازی کند، پس از اعلام‌های خودش استفاده می‌کند. ارسال با نشانی IP همچنان کار می‌کند.';

  @override
  String get diagMdnsUnavailableFix =>
      'از «جست‌وجوی دوبارهٔ شبکه» یا «افزودن با IP» استفاده کنید.';

  @override
  String get diagMdnsUnavailableDetailBoth =>
      'LanDrop نتوانست mDNS / Bonjour را روی این دستگاه راه‌اندازی کند، پس از اعلام‌های خودش استفاده می‌کند. آن‌ها هم کار نکردند، پس دستگاه‌ها خودبه‌خود نمایش داده نمی‌شوند. ارسال با نشانی IP همچنان کار می‌کند.';

  @override
  String get diagAllGoodTitle => 'مشکلی پیدا نشد';

  @override
  String get diagAllGoodDetail =>
      'این دستگاه به شبکهٔ محلی وصل است و برای ارسال و دریافت آماده است.';

  @override
  String get diagAllGoodFix =>
      'اگر دستگاهی هنوز دیده نمی‌شود، مطمئن شوید LanDrop روی آن باز است، سپس از «جست‌وجوی دوبارهٔ شبکه» یا «افزودن با IP» استفاده کنید.';

  @override
  String get diagNetworkTitle => 'شبکهٔ شما';

  @override
  String get diagNetworkDetail => 'نشانی‌های این دستگاه، برای مراجعه.';

  @override
  String get diagSearchFailedTitle => 'جست‌وجو ناموفق بود';
}
