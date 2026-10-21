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

  @override
  String get commonTryAgain => 'دوباره امتحان کنید';

  @override
  String get commonDismiss => 'بستن';

  @override
  String get commonClose => 'بستن';

  @override
  String get commonShow => 'نمایش';

  @override
  String get commonStop => 'توقف';

  @override
  String get commonDecline => 'رد کردن';

  @override
  String get commonAccept => 'پذیرفتن';

  @override
  String get commonSave => 'ذخیره';

  @override
  String get deviceKindPhone => 'گوشی';

  @override
  String get deviceKindComputer => 'رایانه';

  @override
  String get deviceKindBrowser => 'مرورگر';

  @override
  String get selfStatusReady => 'برای دستگاه‌های اطراف قابل مشاهده است';

  @override
  String get selfStatusStarting => 'در حال آماده شدن…';

  @override
  String get selfStatusStopped => 'متوقف شده';

  @override
  String get selfStatusError => 'الان امکان دریافت نیست.';

  @override
  String get selfRename => 'تغییر نام دستگاه';

  @override
  String selfAddress(String ip, String port) {
    return '$ip · پورت $port';
  }

  @override
  String selfAddressUnknown(String port) {
    return 'IP نامشخص · پورت $port';
  }

  @override
  String get peerDetails => 'جزئیات';

  @override
  String get detailsAddress => 'نشانی';

  @override
  String get detailsConnection => 'اتصال';

  @override
  String get detailsCableLink => 'اتصال مستقیم با کابل';

  @override
  String get detailsOtherAddresses => 'نشانی‌های دیگر';

  @override
  String get detailsModel => 'مدل';

  @override
  String get securityCode => 'کد امنیتی';

  @override
  String get securityCodeHint =>
      'این کد را با دستگاه دیگر مقایسه کنید تا مطمئن شوید واقعاً همان دستگاه است.';

  @override
  String get emptyTitle => 'هنوز دستگاهی پیدا نشد';

  @override
  String get emptyBody =>
      'مطمئن شوید LanDrop روی دستگاه دیگر باز است و هر دو به یک وای‌فای وصل هستند.';

  @override
  String get emptyWhy => 'چرا دستگاهم را نمی‌بینم؟';

  @override
  String get connectHotspotTitle => 'اتصال بدون وای‌فای یا مودم';

  @override
  String get connectHotspotSub => 'گام‌به‌گام با هات‌اسپات گوشی یا لپ‌تاپ';

  @override
  String get connectCableTitle => 'اتصال با کابل';

  @override
  String get connectCableSub =>
      'کابل شبکه بین دو رایانه، یا اشتراک اینترنت با USB';

  @override
  String get connectWifiDirectTitle => 'اتصال با وای‌فای دایرکت';

  @override
  String get connectWifiDirectSub => 'گوشی به گوشی، بدون مودم (اندروید)';

  @override
  String get connectWifiJoinTitle => 'اتصال به هات‌اسپات با کد QR';

  @override
  String get connectWifiJoinSub =>
      'کد QR هات‌اسپات LanDrop گوشی دیگر را اسکن کنید';

  @override
  String get qrForLanDrop => 'برای برنامهٔ LanDrop روی دستگاه دیگر';

  @override
  String get addressNotAvailable => 'نشانی هنوز آماده نیست';

  @override
  String get qrSelfSemantics => 'کد QR نشانی این دستگاه';

  @override
  String transferSummary(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString از $totalString فایل';
  }

  @override
  String transferDeclined(String name) {
    return '$name نپذیرفت';
  }

  @override
  String transferFailed(String reason) {
    return 'ناموفق: $reason';
  }

  @override
  String get transferFailedPlain => 'ناموفق';

  @override
  String get transferDone => 'انجام شد';

  @override
  String transferWaiting(String name) {
    return 'منتظر تأیید $name…';
  }

  @override
  String get transferRunning => 'در حال انتقال';

  @override
  String transferFrom(String name) {
    return 'از $name';
  }

  @override
  String transferTo(String name) {
    return 'به $name';
  }

  @override
  String transferSavedTo(String path) {
    return 'ذخیره‌شده در $path';
  }

  @override
  String incomingTitle(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return '$name می‌خواهد $_temp0 برای شما بفرستد';
  }

  @override
  String incomingFromBrowser(String ip) {
    return 'مرورگر وب در $ip';
  }

  @override
  String incomingFromBrowserModel(String ip, String model) {
    return 'مرورگر وب در $ip · $model';
  }

  @override
  String fileCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return '$_temp0';
  }

  @override
  String incomingTotal(String size) {
    return 'مجموع: $size';
  }

  @override
  String incomingSavesTo(String folder) {
    return 'ذخیره در $folder';
  }

  @override
  String get pairingTitle => 'به این مرورگر اجازه می‌دهید برایتان فایل بفرستد؟';

  @override
  String get pairingCodeLabel => 'کدی که مرورگر نشان می‌دهد';

  @override
  String pairingCodeSemantics(String digits) {
    return 'کد اتصال $digits';
  }

  @override
  String get pairingBody =>
      'فقط اگر مرورگر همین کد را نشان می‌دهد، تأیید کنید. از آن پس تا یک ساعت می‌تواند برایتان فایل بفرستد؛ پذیرفتن هر انتقال همچنان با شماست.';

  @override
  String get pairingApprove => 'تأیید';

  @override
  String get addByIpTitle => 'افزودن دستگاه با نشانی IP';

  @override
  String get addByIpLabel => 'نشانی IP';

  @override
  String addByIpHint(String example, String exampleWithPort) {
    return '$example یا $exampleWithPort';
  }

  @override
  String addByIpInvalid(String example) {
    return 'یک نشانی IPv4 وارد کنید، مثلاً $example';
  }

  @override
  String get addByIpAdd => 'افزودن';

  @override
  String addByIpAdded(String name) {
    return '$name اضافه شد';
  }

  @override
  String addByIpNoAnswer(String address) {
    return 'هیچ دستگاه LanDrop در $address پاسخ نداد.';
  }

  @override
  String addByIpError(String address, String error) {
    return 'دسترسی به $address ممکن نشد — $error';
  }

  @override
  String get addFailedTitle => 'دستگاه پیدا نشد';

  @override
  String get addFailedDiagnose => 'بررسی این نشانی';

  @override
  String get pickerEmpty => 'هنوز دستگاهی پیدا نشد.';

  @override
  String get pickerHelp => 'کمکم کنید وصل شوم';

  @override
  String sendPickerTitleFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return 'ارسال $_temp0 به…';
  }

  @override
  String sendPickerTitleFolder(String name) {
    return 'ارسال پوشهٔ «$name» به…';
  }

  @override
  String get aliasLabel => 'نامی که دیگران می‌بینند';

  @override
  String get settingsDeviceName => 'نام دستگاه';

  @override
  String get homeSend => 'ارسال';

  @override
  String get homeNearbyDevices => 'دستگاه‌های اطراف';

  @override
  String get homeRescan => 'جست‌وجوی دوباره';

  @override
  String get homeAddByIp => 'افزودن با IP';

  @override
  String get homeDiscoveryOff => 'جست‌وجوی خودکار روی این دستگاه خاموش است.';

  @override
  String get homeHelp => 'راهنما';

  @override
  String homeHotspotBanner(String ssid) {
    return 'هات‌اسپات «$ssid» روشن است';
  }

  @override
  String get homeActivity => 'فعالیت‌ها';

  @override
  String get homeClearFinished => 'پاک کردن تمام‌شده‌ها';

  @override
  String get homeShareLink => 'لینک اشتراک';

  @override
  String homeActiveShares(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString لینک در حال اشتراک',
    );
    return '$_temp0';
  }

  @override
  String homeReceiving(int count, String name) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return 'در حال دریافت $_temp0 از $name';
  }

  @override
  String homeScanFinished(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString دستگاه',
    );
    return 'جست‌وجو تمام شد: $_temp0 پیدا شد';
  }

  @override
  String homeScanFailed(String error) {
    return 'جست‌وجو انجام نشد: $error';
  }

  @override
  String get sendSheetTitle => 'چه چیزی می‌خواهید بفرستید؟';

  @override
  String get sendSheetFiles => 'فایل‌ها';

  @override
  String get sendSheetFolder => 'پوشه';

  @override
  String sendSent(String name) {
    return 'به $name ارسال شد.';
  }

  @override
  String sendDeclined(String name) {
    return '$name نپذیرفت.';
  }

  @override
  String sendFailed(String name) {
    return 'به $name دسترسی نداریم. آیا LanDrop هنوز آنجا باز است؟';
  }

  @override
  String errorFilePicker(String error) {
    return 'باز کردن پنجرهٔ انتخاب فایل ممکن نشد: $error';
  }

  @override
  String errorFolderPicker(String error) {
    return 'باز کردن پنجرهٔ انتخاب پوشه ممکن نشد: $error';
  }

  @override
  String errorPicker(String error) {
    return 'باز کردن پنجرهٔ انتخاب ممکن نشد: $error';
  }

  @override
  String get sharesTitle => 'اشتراک‌ها';

  @override
  String get shareSendLinkTitle => 'ارسال لینک';

  @override
  String get shareSendLinkBody =>
      'هر کس در این وای‌فای لینک را داشته باشد، می‌تواند فایل‌ها را با مرورگر دانلود کند.';

  @override
  String get shareFiles => 'اشتراک فایل‌ها';

  @override
  String get shareFolder => 'اشتراک پوشه';

  @override
  String get shareNothingShared =>
      'چیزی به اشتراک گذاشته نشده است. با اشتراک‌گذاری، یک لینک و کد QR می‌گیرید که در هر مرورگری در این شبکه باز می‌شود، بدون نیاز به نصب برنامه.';

  @override
  String get browserSectionTitle => 'استفاده از مرورگر';

  @override
  String get browserSectionBody =>
      'این نشانی را روی گوشی یا رایانهٔ دیگر باز کنید تا به اینجا فایل بفرستید. نیازی به نصب چیزی نیست.';

  @override
  String get shareLessThanMinute => 'کمتر از یک دقیقه';

  @override
  String get shareTtl1h => '۱ ساعت';

  @override
  String get shareTtl24h => '۲۴ ساعت';

  @override
  String get shareTtlNone => 'تا وقتی متوقفش کنم';

  @override
  String get shareUnlimited => 'نامحدود';

  @override
  String get shareLinkWorksFor => 'اعتبار لینک';

  @override
  String get shareDownloadsAllowed => 'تعداد دانلود مجاز';

  @override
  String get shareOptionsNote =>
      'هر کس در این شبکه لینک را داشته باشد، تا وقتی لینک معتبر است می‌تواند دانلود کند. پخش یک ویدیو یک دانلود حساب می‌شود.';

  @override
  String get shareConfirm => 'اشتراک‌گذاری';

  @override
  String shareOptionsTitleFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return 'اشتراک $_temp0';
  }

  @override
  String shareOptionsTitleFolder(String name) {
    return 'اشتراک پوشهٔ «$name»';
  }

  @override
  String shareCreatedFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return '$_temp0 به اشتراک گذاشته شد. لینک را روی دستگاه دیگر باز کنید.';
  }

  @override
  String shareCreatedFolder(String name) {
    return 'پوشهٔ «$name» به اشتراک گذاشته شد. لینک را روی دستگاه دیگر باز کنید.';
  }

  @override
  String errorShare(String error) {
    return 'اشتراک‌گذاری ممکن نشد: $error';
  }

  @override
  String get shareUntilStopped => 'تا وقتی متوقفش کنید';

  @override
  String get shareExpired => 'منقضی شده';

  @override
  String shareEndsIn(String time) {
    return '$time دیگر تمام می‌شود';
  }

  @override
  String get shareUnlimitedDownloads => 'دانلود نامحدود';

  @override
  String get shareLimitReached => 'سقف دانلود پر شد';

  @override
  String shareDownloadsLeft(int left, int max) {
    final intl.NumberFormat leftNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String leftString = leftNumberFormat.format(left);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$leftString از $maxString دانلود باقی مانده';
  }

  @override
  String shareTitleMore(String first, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$first و $countString مورد دیگر';
  }

  @override
  String get shareQrSemantics => 'کد QR لینک اشتراک';

  @override
  String get shareHttpWarning => 'لینک HTTP ساده: بدون رمزگذاری.';

  @override
  String get shareLinkCopied => 'لینک کپی شد';

  @override
  String get shareCopyLink => 'کپی لینک';

  @override
  String get shareStop => 'توقف اشتراک';

  @override
  String get browsersTitle => 'مرورگرهای متصل';

  @override
  String get browsersNone =>
      'هیچ مرورگری متصل نیست. مرورگر متصل می‌تواند تا وقتی خارج شود، شما اتصالش را قطع کنید یا یک ساعت بگذرد، برایتان فایل بفرستد.';

  @override
  String browserSessionSubtitle(String ip, String time, String ago) {
    return '$ip · متصل از $time · آخرین فعالیت $ago';
  }

  @override
  String get agoJustNow => 'همین الان';

  @override
  String agoMinutes(String minutes) {
    return '$minutes دقیقه پیش';
  }

  @override
  String agoHours(String hours) {
    return '$hours ساعت پیش';
  }

  @override
  String browserDisconnected(String name) {
    return 'اتصال $name قطع شد';
  }

  @override
  String get browserDisconnect => 'قطع اتصال';

  @override
  String get webQrCaption => 'برای دوربین هر گوشی یا هر مرورگر';

  @override
  String get webQrSemantics => 'کد QR نشانی مرورگر';

  @override
  String get webHttpOnNote =>
      'HTTP ساده روشن است (تنظیمات): بدون هشدار، اما بدون رمزگذاری. نشانی امن:';

  @override
  String get webWarningTitle => 'مرورگر هشدار نشان می‌دهد؟';

  @override
  String get webWarningBody =>
      'مرورگر اول هشدار می‌دهد که اتصال خصوصی نیست. این طبیعی است: LanDrop از گواهی امنیتی خودش استفاده می‌کند، نه گواهی خریداری‌شده از یک شرکت. «Advanced» و سپس «Proceed» را بزنید (Chrome، Edge)، یا «Show details» و سپس «visit this website» (Safari). بعد «اتصال این مرورگر» را بزنید و اگر هر دو یک کد را نشان می‌دهند، اینجا تأیید کنید.';

  @override
  String get settingsSectionDevice => 'این دستگاه';

  @override
  String get settingsSaveFolder => 'محل ذخیرهٔ فایل‌های دریافتی';

  @override
  String get settingsNotSet => 'تعیین نشده';

  @override
  String get settingsUseDefaultFolder => 'استفاده از پوشهٔ پیش‌فرض';

  @override
  String get settingsPrivateFolder => 'فقط داخل LanDrop دیده می‌شود.';

  @override
  String get settingsUseDownloads => 'استفاده از Downloads';

  @override
  String get settingsSectionConnect => 'اتصال';

  @override
  String get settingsConnectHelp => 'دستگاه دیگر را پیدا نمی‌کنید؟';

  @override
  String get settingsConnectHelpSub =>
      'اتصال را بررسی کنید و ببینید چه باید کرد';

  @override
  String get settingsShares => 'اشتراک‌ها و مرورگرها';

  @override
  String get settingsSharesSub =>
      'لینک‌هایی که به اشتراک گذاشته‌اید و مرورگرهایی که می‌توانند برایتان فایل بفرستند';

  @override
  String get settingsSectionApp => 'برنامه';

  @override
  String get settingsBackground => 'اجرا در پس‌زمینه';

  @override
  String get settingsBackgroundSub =>
      'با صفحهٔ خاموش هم در دسترس می‌ماند. یک اعلان نشان می‌دهد.';

  @override
  String get settingsQuit => 'خروج از LanDrop';

  @override
  String get settingsQuitSub => 'دریافت را متوقف می‌کند و برنامه را می‌بندد';

  @override
  String get settingsAdvanced => 'پیشرفته';

  @override
  String get settingsAdvancedSub => 'نشانی، کد امنیتی، روش‌های اتصال';

  @override
  String get advancedSectionAddress => 'نشانی';

  @override
  String get advancedRestart => 'راه‌اندازی دوبارهٔ سرویس LanDrop';

  @override
  String get serviceRunning => 'در حال اجرا';

  @override
  String get serviceStarting => 'در حال شروع…';

  @override
  String get serviceStopped => 'متوقف شده';

  @override
  String get serviceError => 'اجرا نمی‌شود';

  @override
  String get advancedSectionBrowsers => 'مرورگرها';

  @override
  String get webHttpTitle => 'اجازه به مرورگرها بدون هشدار (بدون رمزگذاری)';

  @override
  String get webHttpSub =>
      'خاموش امن‌تر است. وقتی روشن باشد، ارتباط مرورگر رمزگذاری نمی‌شود: هر کسی در این شبکه می‌تواند فایل‌ها و کدهای اتصال را ببیند. فقط برای شبکه‌هایی که به آن‌ها اعتماد دارید.';

  @override
  String get webHttpUrlTitle => 'نشانی مرورگر (HTTP ساده)';

  @override
  String get webHttpConfirmTitle => 'HTTP ساده برای مرورگرها روشن شود؟';

  @override
  String get webHttpConfirmBody =>
      'مرورگرها LanDrop را بدون هشدار گواهی باز می‌کنند، اما هیچ چیز رمزگذاری نمی‌شود: هر کسی در این وای‌فای می‌تواند فایل‌ها، لینک‌های اشتراک و کدهای اتصال را بخواند و حتی خود را جای این دستگاه جا بزند. فقط در شبکه‌ای که به آن اعتماد دارید، مثل وای‌فای خانه، از آن استفاده کنید؛ هرگز در شبکه‌های عمومی یا محل کار.';

  @override
  String get webHttpConfirmOn => 'روشن کن';

  @override
  String errorWebHttp(String error) {
    return 'تغییر HTTP ساده ممکن نشد: $error';
  }

  @override
  String get keepSharesTitle => 'نگه داشتن لینک‌ها پس از راه‌اندازی دوباره';

  @override
  String get keepSharesSub =>
      'لینک‌های اشتراک پس از راه‌اندازی دوبارهٔ LanDrop هم کار می‌کنند، به شرطی که منقضی نشده باشند و فایل‌ها تغییر نکرده باشند. فهرست فایل‌های اشتراکی روی این دستگاه ذخیره می‌شود. خاموش کردن، آن را پاک می‌کند.';

  @override
  String get advancedSectionTroubleshoot => 'عیب‌یابی';

  @override
  String get advancedReport => 'گزارش اتصال';

  @override
  String get advancedReportSub => 'بفهمید چرا دستگاه‌ها به هم وصل نمی‌شوند';

  @override
  String get advancedSectionMethods => 'همهٔ روش‌های اتصال';

  @override
  String get diagActionHotspot => 'اتصال با هات‌اسپات';

  @override
  String get diagTitle => 'بررسی اتصال';

  @override
  String diagTitleTarget(String target) {
    return 'بررسی $target';
  }

  @override
  String get diagRunning => 'در حال بررسی شبکه…';

  @override
  String diagError(String error) {
    return 'بررسی انجام نشد: $error';
  }

  @override
  String get diagReportCopied => 'گزارش کپی شد';

  @override
  String get diagCopyReport => 'کپی گزارش';

  @override
  String get diagRunAgain => 'دوباره بررسی کن';

  @override
  String get diagDetails => 'جزئیات';

  @override
  String get diagReportNote =>
      'این گزارش به انگلیسی است تا پشتیبانی بتواند آن را بخواند.';
}
