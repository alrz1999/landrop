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
  String get shareShowNearby => 'نمایش به دستگاه‌های نزدیک';

  @override
  String get shareShowNearbyHint =>
      'فقط دستگاه‌های مورد اعتماد و مرورگرهای تأییدشده آن را می‌بینند.';

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

  @override
  String get platformAndroid => 'اندروید';

  @override
  String get platformIos => 'آیفون / آیپد';

  @override
  String get platformMac => 'مک';

  @override
  String get platformWindows => 'ویندوز';

  @override
  String get platformLinux => 'لینوکس';

  @override
  String get platformOther => 'دستگاه‌های دیگر';

  @override
  String get hotspotShareAndroid1 =>
      'دکمهٔ «شروع هات‌اسپات» را در پایین بزنید: LanDrop یک هات‌اسپات خصوصی می‌سازد (اینترنت همراه به اشتراک گذاشته نمی‌شود) و یک کد QR نشان می‌دهد که دستگاه دیگر برای وصل شدن آن را اسکن می‌کند. ممکن است این گوشی تا وقتی هات‌اسپات روشن است از وای‌فای خودش جدا شود.';

  @override
  String get hotspotShareAndroid2 =>
      'یا از هات‌اسپات معمولی گوشی استفاده کنید: تنظیمات > شبکه و اینترنت > نقطه اتصال و اشتراک‌گذاری اینترنت > نقطه اتصال Wi-Fi (نام‌ها بسته به برند گوشی کمی فرق دارد). آن را روشن کنید و نام و رمز آن را یادداشت کنید.';

  @override
  String get hotspotShareIos1 =>
      'به Settings > Personal Hotspot (تنظیمات > هات‌اسپات شخصی) بروید و «Allow Others to Join» را روشن کنید. (طرح اینترنت همراه شما باید اجازهٔ استفاده از هات‌اسپات را بدهد.)';

  @override
  String get hotspotShareIos2 =>
      'این صفحه را تا وقتی دستگاه دیگر وصل شود باز نگه دارید: رمز وای‌فای در آن نمایش داده می‌شود.';

  @override
  String get hotspotShareMac1 =>
      'ساده‌ترین راه: برعکس عمل کنید. بگذارید دستگاه دیگر هات‌اسپات بسازد و از این مک به آن وصل شوید (در بالا «این دستگاه به آن وصل می‌شود» را انتخاب کنید).';

  @override
  String get hotspotShareMac2 =>
      'اگر باز هم می‌خواهید از این مک هات‌اسپات بسازید: System Settings > General > Sharing را باز کنید، روی (i) کنار Internet Sharing کلیک کنید، اتصال خود (مثلاً Ethernet) را برای رایانه‌هایی که از Wi-Fi استفاده می‌کنند به اشتراک بگذارید، نام و رمز شبکه را تعیین کنید و سپس Internet Sharing را روشن کنید.';

  @override
  String get hotspotShareWindows1 =>
      'به Settings > Network & internet > Mobile hotspot بروید.';

  @override
  String get hotspotShareWindows2 =>
      '«Mobile hotspot» را روشن کنید. نام و رمز شبکه در همان صفحه نمایش داده می‌شود.';

  @override
  String hotspotShareLinux1(String command) {
    return 'به Settings > Wi-Fi بروید، منوی (⋮) را باز کنید و «Turn On Wi-Fi Hotspot…» را انتخاب کنید. در میزکارهای دیگر از NetworkManager استفاده کنید: یک شبکهٔ Wi-Fi جدید با حالت «Hotspot» بسازید، یا این فرمان را اجرا کنید: $command';
  }

  @override
  String get hotspotShareLinux2 => 'نام و رمز شبکه را یادداشت کنید.';

  @override
  String get hotspotShareOther1 =>
      'هات‌اسپات (اشتراک‌گذاری اینترنت) را در تنظیمات شبکهٔ این دستگاه روشن کنید و نام و رمز آن را یادداشت کنید.';

  @override
  String get hotspotJoinAndroid1 =>
      'به تنظیمات > Wi-Fi بروید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید. یا نماد QR کنار «افزودن شبکه» را بزنید و کدی را که روی دستگاه دیگر نمایش داده می‌شود اسکن کنید.';

  @override
  String get hotspotJoinIos1 =>
      'به Settings > Wi-Fi بروید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید. یا دوربین (Camera) را به سمت کد QR روی دستگاه دیگر بگیرید و «Join network» را بزنید.';

  @override
  String get hotspotJoinMac1 =>
      'روی نماد Wi-Fi در نوار منو (یا Control Center) کلیک کنید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید.';

  @override
  String get hotspotJoinWindows1 =>
      'روی نماد شبکه در نوار وظیفه (taskbar) کلیک کنید، فهرست Wi-Fi را باز کنید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید.';

  @override
  String hotspotJoinLinux1(String command) {
    return 'منوی شبکه (بالا سمت راست) > Wi-Fi > Select Network را باز کنید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید. یا این فرمان را اجرا کنید: $command';
  }

  @override
  String get hotspotJoinOther1 =>
      'تنظیمات وای‌فای را باز کنید، هات‌اسپات دستگاه دیگر را انتخاب کنید و رمز آن را وارد کنید.';

  @override
  String get hotspotStepShareOther =>
      'روی دستگاه دیگر، مثل هر شبکهٔ وای‌فای دیگری به این هات‌اسپات وصل شوید (راهنما در پایین).';

  @override
  String get hotspotStepVpn =>
      'اگر VPN (فیلترشکن) روشن است، خاموشش کنید. اینترنت همراه می‌تواند روشن بماند.';

  @override
  String get hotspotStepOpenBoth =>
      'LanDrop را روی هر دو دستگاه باز کنید، سپس «وصل شدم، دستگاه دیگر را پیدا کن» را بزنید.';

  @override
  String get hotspotWizardTitle => 'اتصال بدون وای‌فای';

  @override
  String get hotspotIntro =>
      'به روتر (مودم) نیازی نیست: یک دستگاه هات‌اسپات وای‌فای می‌سازد، دستگاه دیگر به آن وصل می‌شود و LanDrop دستگاه دیگر را در همان شبکه پیدا می‌کند. وقتی وای‌فای دستگاه‌ها را از هم جدا نگه می‌دارد (شبکه‌های مهمان، اداره یا هتل) هم این روش کمک می‌کند. فایل‌ها مستقیم بین دو دستگاه جابه‌جا می‌شوند و از اینترنت همراه استفاده نمی‌کنند.';

  @override
  String get hotspotRoleShare => 'این دستگاه هات‌اسپات می‌سازد';

  @override
  String get hotspotRoleJoin => 'این دستگاه به آن وصل می‌شود';

  @override
  String wizardOnThisDevice(String platform) {
    return 'روی این دستگاه ($platform)';
  }

  @override
  String get hotspotScanQr => 'اسکن کد QR هات‌اسپات';

  @override
  String get hotspotOtherJoin => 'روی دستگاه دیگر: به هات‌اسپات وصل شوید';

  @override
  String get hotspotOtherShare => 'روی دستگاه دیگر: هات‌اسپات بسازید';

  @override
  String get hotspotFindLabel => 'وصل شدم، دستگاه دیگر را پیدا کن';

  @override
  String get hotspotCableInstead => 'از کابل استفاده می‌کنید؟ اترنت یا USB';

  @override
  String get hotspotStart => 'شروع هات‌اسپات';

  @override
  String get hotspotOn => 'هات‌اسپات روشن است';

  @override
  String hotspotName(String ssid) {
    return 'نام: $ssid';
  }

  @override
  String get hotspotNoPassword => 'بدون رمز';

  @override
  String hotspotPassword(String password) {
    return 'رمز: $password';
  }

  @override
  String get hotspotScanHint =>
      'برای وصل شدن، کد را با دوربین دستگاه دیگر اسکن کنید (اندروید ۱۰ به بالا، آیفون). هات‌اسپات با زدن «توقف هات‌اسپات» یا بستن LanDrop خاموش می‌شود.';

  @override
  String get hotspotStop => 'توقف هات‌اسپات';

  @override
  String get hotspotQrSemantics => 'کد QR برای وصل شدن به این هات‌اسپات';

  @override
  String get findPhaseNetwork => 'در حال بررسی شبکهٔ جدید…';

  @override
  String get findPhaseProbeHotspot => 'در حال بررسی نشانی‌های معمول هات‌اسپات…';

  @override
  String get findPhaseScan => 'در حال جست‌وجوی شبکه…';

  @override
  String get findPhaseWhy => 'چیزی پیدا نشد. در حال بررسی علت…';

  @override
  String get findNothingHintHotspot =>
      'بررسی کنید هر دو دستگاه به یک هات‌اسپات وصل باشند و LanDrop روی هر دو باز باشد. سپس دوباره امتحان کنید، یا با «افزودن با IP» نشانی‌ای را که روی دستگاه دیگر نمایش داده می‌شود وارد کنید.';

  @override
  String findFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString دستگاه پیدا شد',
    );
    return '$_temp0';
  }

  @override
  String get findBackToDevices => 'بازگشت به دستگاه‌ها';

  @override
  String get findNothingTitle => 'هنوز دستگاهی پیدا نشد';

  @override
  String get cableEthMac1 =>
      'کابل اترنت را به هر دو رایانه وصل کنید (مبدل اترنت USB یا Thunderbolt هم کار می‌کند). با کابل مستقیم یا با روتر، مراحل یکی است.';

  @override
  String get cableEthMac2 =>
      'به System Settings > Network بروید. اگر مبدل در فهرست نیست، روی «…» > «Add Service…» (یا دکمهٔ +) کلیک کنید، مبدل اترنت را انتخاب کنید و Create را بزنید.';

  @override
  String cableEthMac3(String prefix) {
    return 'آن را انتخاب کنید و «Configure IPv4» را روی «Using DHCP» بگذارید. بدون روتر، مک به خودش نشانی‌ای می‌دهد که با $prefix شروع می‌شود. این طبیعی است.';
  }

  @override
  String get cableEthPlugBoth => 'کابل اترنت را به هر دو رایانه وصل کنید.';

  @override
  String cableEthWindows2(String prefix) {
    return 'به Settings > Network & internet > Ethernet بروید. احتمالاً «No Internet» یا «Unidentified network» نوشته شده است: اشکالی ندارد، ویندوز به خودش نشانی‌ای می‌دهد که با $prefix شروع می‌شود.';
  }

  @override
  String get cableEthWindows3 =>
      'در بخش «IP assignment» گزینهٔ «Automatic (DHCP)» را نگه دارید. وقتی Windows Firewall پرسید، به LanDrop در شبکه‌های Private اجازه دهید. اگر شبکه «Public» علامت خورده است، آن را Private کنید.';

  @override
  String cableEthLinux2(String command) {
    return 'به Settings > Network بروید، اتصال سیمی را انتخاب کنید و تنظیمات آن > IPv4 را باز کنید. روش «Link-Local Only» را انتخاب و اعمال کنید. یا این فرمان را اجرا کنید: $command';
  }

  @override
  String get cableEthLinux3 =>
      'اتصال را یک بار خاموش و روشن کنید تا نشانی بگیرد.';

  @override
  String get cableEthOther1 =>
      'یک کابل اترنت (در صورت نیاز با مبدل) به هر دو رایانه وصل کنید و مطمئن شوید شبکهٔ سیمی نشانی را خودکار می‌گیرد (DHCP یا «link-local»).';

  @override
  String get cableUsbAndroid1 =>
      'اتصال را همین گوشی به اشتراک می‌گذارد: آن را با کابل USB به رایانه وصل کنید.';

  @override
  String get cableUsbAndroid2 =>
      'به تنظیمات > شبکه و اینترنت > نقطه اتصال و اشتراک‌گذاری اینترنت بروید (نام‌ها بسته به برند گوشی کمی فرق دارد) و «اشتراک‌گذاری اینترنت با USB» را روشن کنید. این گزینه فقط وقتی رایانه وصل است روشن می‌شود.';

  @override
  String get cableUsbIos1 =>
      'آیفون را با کابل USB به رایانه وصل کنید و اگر پرسید، «Trust» را بزنید.';

  @override
  String get cableUsbIos2 =>
      'به Settings > Personal Hotspot بروید و «Allow Others to Join» را روشن کنید. روی رایانهٔ ویندوزی باید iTunes یا برنامهٔ Apple Devices نصب باشد.';

  @override
  String get cableUsbMac1 =>
      'گوشی را با کابل USB به این مک وصل کنید. روی گوشی Personal Hotspot (آیفون) یا «اشتراک‌گذاری اینترنت با USB» (اندروید) را روشن کنید.';

  @override
  String get cableUsbMac2 =>
      'مک یک مبدل شبکهٔ جدید در System Settings > Network نشان می‌دهد (مثلاً «iPhone USB» یا «RNDIS/Ethernet Gadget»). اشتراک اینترنت با USB در اندروید روی مک به درایوری نیاز دارد که همراه سیستم نیست؛ آیفون بدون تنظیم اضافه کار می‌کند.';

  @override
  String get cableUsbWindows1 =>
      'گوشی را با کابل USB به این رایانه وصل کنید. روی گوشی «اشتراک‌گذاری اینترنت با USB» (اندروید) یا Personal Hotspot (آیفون) را روشن کنید.';

  @override
  String get cableUsbWindows2 =>
      'ویندوز یک مبدل جدید اضافه می‌کند (در Settings > Network & internet > Advanced network settings دیده می‌شود). صبر کنید تا Connected نوشته شود.';

  @override
  String get cableUsbLinux1 =>
      'گوشی را با کابل USB به این رایانه وصل کنید. روی گوشی «اشتراک‌گذاری اینترنت با USB» (اندروید) یا Personal Hotspot (آیفون) را روشن کنید.';

  @override
  String get cableUsbLinux2 =>
      'یک اتصال سیمی جدید ظاهر می‌شود (با نامی مثل usb0، enx… یا eth1). معمولاً خودش وصل می‌شود.';

  @override
  String get cableUsbOther1 =>
      'گوشی را با کابل USB وصل کنید و «اشتراک‌گذاری اینترنت با USB» یا Personal Hotspot را روشن کنید؛ سپس رایانه یک مبدل شبکهٔ جدید خواهد داشت.';

  @override
  String get cableStepWait =>
      'چند ثانیه صبر کنید: بدون روتر، ممکن است تا یک دقیقه طول بکشد تا هر دو رایانه نشانی بگیرند.';

  @override
  String get cableStepVpn =>
      'اگر VPN (فیلترشکن) روشن است، خاموشش کنید. اکنون دستگاه دیگر اتصالش را با این دستگاه به اشتراک می‌گذارد.';

  @override
  String get cableStepOpenBoth =>
      'LanDrop را روی هر دو دستگاه باز کنید، سپس «کابل وصل است، دستگاه دیگر را پیدا کن» را بزنید.';

  @override
  String get cableIntro =>
      'به وای‌فای یا روتر نیازی نیست: دو دستگاه را با کابل به هم وصل کنید تا LanDrop دستگاه دیگر را از همین راه پیدا کند. فایل‌ها مستقیم از طریق کابل جابه‌جا می‌شوند.';

  @override
  String get cableKindEthernet => 'کابل اترنت';

  @override
  String get cableKindUsb => 'اشتراک اینترنت با USB';

  @override
  String get cableTetherHint =>
      'روی گوشی: اندروید > تنظیمات > شبکه و اینترنت > نقطه اتصال و اشتراک‌گذاری اینترنت > اشتراک‌گذاری اینترنت با USB. آیفون > Settings > Personal Hotspot.';

  @override
  String get cableFindLabel => 'کابل وصل است، دستگاه دیگر را پیدا کن';

  @override
  String get cablePhaseProbe => 'در حال بررسی نشانی‌های معمول کابل و USB…';

  @override
  String get cableNothingHint =>
      'کابل را بررسی کنید، مطمئن شوید مبدل «وصل» نشان داده می‌شود و LanDrop روی هر دو دستگاه باز است. گرفتن نشانی با کابل مستقیم ممکن است تا یک دقیقه طول بکشد. سپس دوباره امتحان کنید، یا با «افزودن با IP» نشانی‌ای را که روی دستگاه دیگر نمایش داده می‌شود وارد کنید.';

  @override
  String get wifiDirectTitle => 'وای‌فای دایرکت';

  @override
  String get wifiDirectIntro =>
      'دو دستگاه را بدون روتر مستقیم به هم وصل کنید. پس از اتصال، مثل همیشه فایل بفرستید.';

  @override
  String get wifiDirectTry =>
      'این‌ها را امتحان کنید: وای‌فای را روشن کنید، دعوت را روی دستگاه دیگر بپذیرید، صفحهٔ هر دو را روشن و آن‌ها را نزدیک هم نگه دارید.';

  @override
  String get wifiDirectRoleOwner => 'این دستگاه میزبان گروه است.';

  @override
  String get wifiDirectRoleClient => 'به گروه دستگاه دیگر پیوستید.';

  @override
  String get wifiDirectConnected => 'با وای‌فای دایرکت وصل است';

  @override
  String wifiDirectNetwork(String ssid) {
    return 'شبکه: $ssid';
  }

  @override
  String wifiDirectHost(String address) {
    return 'نشانی میزبان: $address';
  }

  @override
  String get wifiDirectLooking => 'در حال جست‌وجوی دستگاه‌های LanDrop…';

  @override
  String get wifiDirectNone =>
      'هنوز هیچ دستگاه LanDrop پاسخ نداده است. مطمئن شوید LanDrop روی دستگاه دیگر باز است، سپس دوباره جست‌وجو کنید.';

  @override
  String get wifiDirectSearchAgain => 'جست‌وجوی دوباره';

  @override
  String get wifiDirectDisconnect => 'قطع اتصال';

  @override
  String get wifiDirectTapHint =>
      'برای اتصال، روی یک دستگاه بزنید. روی دستگاه دیگر پنجرهٔ دعوت اندروید باز می‌شود و باید آن را بپذیرد.';

  @override
  String get wifiDirectLookingShort => 'در حال جست‌وجو…';

  @override
  String get wifiDirectEmpty =>
      'هنوز دستگاهی پیدا نشد. وای‌فای دایرکت را روی دستگاه دیگر هم باز کنید.';

  @override
  String get wifiDirectInvited =>
      'دعوت فرستاده شد. آن را روی دستگاه دیگر بپذیرید.';

  @override
  String get wifiDirectStatusConnected => 'وصل';

  @override
  String get wifiDirectStatusFailed => 'ناموفق';

  @override
  String get wifiDirectStatusAvailable => 'در دسترس';

  @override
  String get wifiDirectStatusUnavailable => 'در دسترس نیست';

  @override
  String get wifiDirectCreateGroup => 'ساختن گروه در اینجا';

  @override
  String get wifiDirectCreateHint =>
      '«ساختن گروه در اینجا» این دستگاه را میزبان می‌کند تا دستگاه دیگر بتواند از صفحهٔ وای‌فای دایرکت خودش آن را پیدا کند و به آن بپیوندد. صفحهٔ هر دو را روشن نگه دارید.';

  @override
  String get wifiJoinNotWifiQr =>
      'این کد QR، کد وای‌فای نیست. کدی را اسکن کنید که هات‌اسپات LanDrop روی گوشی دیگر نشان می‌دهد.';

  @override
  String get wifiJoinManualInvalid =>
      'نام شبکه (حداکثر ۳۲ نویسه) و رمز آن (۸ تا ۶۳ نویسه، یا خالی برای شبکهٔ باز) را وارد کنید.';

  @override
  String get wifiJoinScanIntro =>
      'روی گوشی دیگر، LanDrop را باز کنید و به «اتصال بدون وای‌فای» > «این دستگاه هات‌اسپات می‌سازد» > «شروع هات‌اسپات» بروید. سپس دوربین این گوشی را به سمت کد QR آن بگیرید.';

  @override
  String get wifiJoinAllowCamera => 'اجازهٔ دسترسی به دوربین';

  @override
  String get wifiJoinManualToggle => 'وارد کردن نام و رمز';

  @override
  String get wifiJoinNetworkName => 'نام شبکه';

  @override
  String get wifiJoinPasswordLabel => 'رمز (برای شبکهٔ باز خالی بگذارید)';

  @override
  String get wifiJoinHidden => 'شبکهٔ پنهان';

  @override
  String get wifiJoinContinue => 'ادامه';

  @override
  String wifiJoinConfirmTitle(String ssid) {
    return 'به $ssid وصل شوید؟';
  }

  @override
  String get wifiJoinExplain =>
      'LanDrop از اندروید می‌خواهد به این شبکهٔ وای‌فای وصل شود و اندروید از شما تأیید می‌خواهد. تا وقتی وصل هستید، ممکن است اینترنت این گوشی قطع شود. فقط LanDrop از این شبکه استفاده می‌کند؛ برنامه‌های دیگر تا جایی که اندروید اجازه دهد از اتصال معمول شما استفاده می‌کنند.';

  @override
  String get wifiJoinJoin => 'وصل شو';

  @override
  String wifiJoinJoining(String ssid) {
    return 'در حال وصل شدن به $ssid… وقتی پیام اندروید ظاهر شد، آن را تأیید کنید.';
  }

  @override
  String get wifiJoinScanAgain => 'اسکن دوباره';

  @override
  String wifiJoinJoined(String ssid) {
    return 'به $ssid وصل شد';
  }

  @override
  String get wifiJoinFindTitle => 'پیدا کردن دستگاه دیگر';

  @override
  String get wifiJoinLeave => 'خروج از شبکه';

  @override
  String get errHotspotUnsupportedPlatform =>
      'فقط در اندروید می‌توان از داخل LanDrop هات‌اسپات ساخت.';

  @override
  String get errHotspotUnsupportedSdk =>
      'این نسخهٔ اندروید اجازه نمی‌دهد برنامه‌ها هات‌اسپات بسازند. به‌جای آن از تنظیمات > نقطه اتصال استفاده کنید.';

  @override
  String get errHotspotPermissionNearby =>
      'LanDrop برای ساختن هات‌اسپات به اجازهٔ «دستگاه‌های اطراف» نیاز دارد.';

  @override
  String get errHotspotPermissionLocation =>
      'LanDrop برای ساختن هات‌اسپات به اجازهٔ دسترسی به موقعیت مکانی نیاز دارد (اندروید آن را برای قابلیت‌های وای‌فای لازم می‌داند؛ LanDrop از موقعیت مکانی شما استفاده نمی‌کند).';

  @override
  String get errHotspotNoName =>
      'هات‌اسپات روشن شد، اما اندروید نام آن را اعلام نکرد.';

  @override
  String get errHotspotUnavailable => 'ساختن هات‌اسپات در اینجا ممکن نیست.';

  @override
  String errHotspotRefused(String detail) {
    return 'اندروید اجازه نداد: $detail. در اندروید ۱۲ و قدیمی‌تر، «موقعیت مکانی» هم باید روشن باشد.';
  }

  @override
  String get errHotspotPermissionMissing => 'اجازه داده نشده است';

  @override
  String get errHotspotIncompatible =>
      'اندروید الان نمی‌تواند آن را روشن کند؛ معمولاً چون هات‌اسپات معمولی یا اشتراک‌گذاری اینترنت روشن است. آن را خاموش کنید، یا به‌جای این روش از همان استفاده کنید.';

  @override
  String get errHotspotDisallowed =>
      'ساختن هات‌اسپات روی این دستگاه مجاز نیست (مثلاً به دلیل نمایهٔ کاری یا محدودیت اپراتور).';

  @override
  String get errHotspotNoChannel =>
      'کانال وای‌فای آزادی نیست. کمی بعد دوباره امتحان کنید.';

  @override
  String get errHotspotBusy => 'یک هات‌اسپات در حال روشن شدن است.';

  @override
  String get errHotspotCancelled => 'هات‌اسپات متوقف شد.';

  @override
  String get errHotspotFailed => 'هات‌اسپات روشن نشد.';

  @override
  String errHotspotFailedDetail(String detail) {
    return 'هات‌اسپات روشن نشد: $detail.';
  }

  @override
  String errHotspotStartError(String error) {
    return 'هات‌اسپات روشن نشد: $error';
  }

  @override
  String get errWifiDirectUnsupported =>
      'وای‌فای دایرکت روی این دستگاه در دسترس نیست.';

  @override
  String get errWifiDirectWifiOff =>
      'وای‌فای خاموش است. وای‌فای را روشن کنید (به روتر نیازی نیست)، سپس دوباره امتحان کنید.';

  @override
  String get errWifiDirectPermission =>
      'LanDrop برای پیدا کردن دستگاه‌های اطراف به اجازه نیاز دارد. اجازه دهید، و در اندروید ۱۲ و قدیمی‌تر «موقعیت مکانی» را هم روشن کنید.';

  @override
  String get errWifiDirectBusy =>
      'وای‌فای دایرکت مشغول است. کمی صبر کنید و دوباره امتحان کنید، یا اول «قطع اتصال» را بزنید.';

  @override
  String get errWifiDirectNotReady =>
      'وای‌فای دایرکت هنوز آماده نیست. دوباره امتحان کنید.';

  @override
  String get errWifiDirectFailed =>
      'وای‌فای دایرکت کار نکرد. وای‌فای را خاموش و روشن کنید و دوباره امتحان کنید.';

  @override
  String errWifiDirectFailedDetail(String detail) {
    return 'وای‌فای دایرکت کار نکرد ($detail). وای‌فای را خاموش و روشن کنید و دوباره امتحان کنید.';
  }

  @override
  String get errWifiJoinUnsupported =>
      'برای وصل شدن به شبکهٔ وای‌فای از داخل LanDrop، اندروید ۷ یا جدیدتر لازم است. به‌جای آن از تنظیمات وای‌فای وصل شوید.';

  @override
  String get errWifiJoinCamera =>
      'LanDrop برای اسکن کد QR به دوربین نیاز دارد. در تنظیمات برنامه اجازه دهید، یا نام و رمز را دستی وارد کنید.';

  @override
  String get errWifiJoinTimeout =>
      'اندروید به شبکه وصل نشد. بررسی کنید هات‌اسپات گوشی دیگر روشن و نزدیک باشد، رمز درست باشد و پیام اندروید را رد نکرده باشید. سپس دوباره امتحان کنید.';

  @override
  String get errWifiJoinLost =>
      'شبکه قطع شد. بررسی کنید هات‌اسپات هنوز روشن باشد، سپس دوباره اسکن کنید.';

  @override
  String get errWifiJoinUnsupportedSecurity =>
      'این شبکه از نوع امنیتی قدیمی (WEP) استفاده می‌کند که اندروید دیگر اجازهٔ اتصال برنامه‌ها به آن را نمی‌دهد. به‌جای آن از تنظیمات وای‌فای وصل شوید.';

  @override
  String get errWifiJoinPermission =>
      'اندروید به LanDrop اجازهٔ تغییر شبکه را نداد. به‌جای آن از تنظیمات وای‌فای وصل شوید.';

  @override
  String get errWifiJoinFailed =>
      'اتصال به شبکه ممکن نشد. دوباره امتحان کنید، یا از تنظیمات وای‌فای وصل شوید.';

  @override
  String errWifiJoinFailedDetail(String detail) {
    return 'اتصال به شبکه ممکن نشد ($detail). دوباره امتحان کنید، یا از تنظیمات وای‌فای وصل شوید.';
  }

  @override
  String errorWebHttpStart(String error) {
    return 'HTTP ساده برای مرورگرها شروع نشد: $error';
  }

  @override
  String get pickFilesTitle => 'انتخاب فایل برای ارسال';

  @override
  String get pickFolderTitle => 'انتخاب پوشه برای ارسال';

  @override
  String get helperTitle => 'کمک برای اتصال';

  @override
  String get helperChecking => 'در حال بررسی اتصال شما…';

  @override
  String helperFound(String name) {
    return '$name پیدا شد!';
  }

  @override
  String get helperCheckFine => 'روی این دستگاه مشکلی دیده نمی‌شود.';

  @override
  String get helperQ1 => 'آیا هر دو دستگاه به یک وای‌فای وصل هستند؟';

  @override
  String get helperQ1Same => 'بله، یک وای‌فای';

  @override
  String get helperQ1Different => 'نه، یا وای‌فای نداریم';

  @override
  String get helperQ1Cable => 'با کابل وصل می‌کنم';

  @override
  String get helperChecklist =>
      'LanDrop را روی دستگاه دیگر باز کنید و صفحه‌اش را روشن نگه دارید. اگر VPN (فیلترشکن) روشن است، خاموشش کنید.';

  @override
  String get helperSearchAgain => 'دوباره جست‌وجو کن';

  @override
  String get helperSameWifiNothing =>
      'مطمئن شوید هر دو دستگاه به یک شبکهٔ وای‌فای وصل‌اند (نه شبکهٔ مهمان) و LanDrop روی هر دو باز است، سپس دوباره جست‌وجو کنید.';

  @override
  String get helperBlocked =>
      'ممکن است این وای‌فای اجازهٔ ارتباط دستگاه‌ها با هم را ندهد. بیایید آن‌ها را مستقیم به هم وصل کنیم.';

  @override
  String get helperConnectDirectly => 'اتصال مستقیم';

  @override
  String get helperQ2 => 'دستگاه دیگر چیست؟';

  @override
  String get helperQ2Android => 'گوشی اندروید';

  @override
  String get helperQ2Iphone => 'آیفون';

  @override
  String get helperQ2Computer => 'رایانه';

  @override
  String get helperQ2Browser => 'فقط مرورگر';

  @override
  String get helperRecommended => 'پیشنهادی';

  @override
  String get helperMethodShareQrTitle => 'از این گوشی هات‌اسپات بسازید';

  @override
  String get helperMethodShareQrBody =>
      'از اینترنت استفاده نمی‌شود. گوشی دیگر کد را اسکن می‌کند تا وصل شود.';

  @override
  String get helperMethodShareTitle => 'از این دستگاه هات‌اسپات بسازید';

  @override
  String get helperMethodShareBody =>
      'از اینترنت استفاده نمی‌شود. دستگاه دیگر مثل هر وای‌فای دیگری به این هات‌اسپات وصل می‌شود.';

  @override
  String get helperMethodJoinTitle => 'به هات‌اسپات دستگاه دیگر وصل شوید';

  @override
  String get helperMethodJoinBody =>
      'هات‌اسپات دستگاه دیگر را روشن کنید، سپس از این دستگاه به آن وصل شوید. از اینترنت استفاده نمی‌شود.';

  @override
  String get helperMethodJoinQrTitle => 'کد هات‌اسپات گوشی دیگر را اسکن کنید';

  @override
  String get helperMethodJoinQrBody =>
      'وقتی گوشی دیگر با LanDrop هات‌اسپات می‌سازد، این گوشی کد QR آن را اسکن می‌کند و وصل می‌شود.';

  @override
  String get helperMethodWifiDirectTitle => 'استفاده از وای‌فای دایرکت';

  @override
  String get helperMethodWifiDirectBody =>
      'گوشی به گوشی، بدون روتر. هر دو گوشی باید اندروید باشند.';

  @override
  String get helperOpenWifiDirect => 'باز کردن وای‌فای دایرکت';

  @override
  String get helperMethodBrowserTitle => 'استفاده از مرورگر روی دستگاه دیگر';

  @override
  String get helperMethodBrowserBody =>
      'نیازی به نصب نیست: دستگاه دیگر یک لینک را در مرورگرش باز می‌کند تا فایل بفرستد یا دانلود کند. هر دو دستگاه باید به یک وای‌فای یا هات‌اسپات وصل باشند.';

  @override
  String get helperOpenShares => 'باز کردن صفحهٔ اشتراک';

  @override
  String get helperOnThisDevice => 'روی این دستگاه';

  @override
  String get helperOnOtherDevice => 'روی دستگاه دیگر';

  @override
  String get helperOtherWays => 'راه‌های دیگر';

  @override
  String get helperTryAnother => 'راه دیگری را امتحان کنید';

  @override
  String get helperCopyReport => 'کپی گزارش اتصال';

  @override
  String get wifiJoinCameraFailed =>
      'دوربین روشن نشد. به‌جای آن، نام و رمز را در پایین وارد کنید.';

  @override
  String get transferCancelled => 'لغو شد';

  @override
  String transferSentTo(String name) {
    return 'به $name فرستاده شد';
  }

  @override
  String transferReceivedFrom(String name) {
    return 'از $name دریافت شد';
  }

  @override
  String transferPercent(String percent) {
    return '٪$percent';
  }

  @override
  String transferPercentSpeed(String percent, String speed) {
    return '٪$percent · $speed';
  }

  @override
  String transferTimeLeft(String time) {
    return '$time مانده';
  }

  @override
  String get transferCancelAction => 'لغو';

  @override
  String get transferCancelling => 'در حال لغو…';

  @override
  String get transferOpen => 'باز کردن';

  @override
  String get transferShowInFolder => 'نمایش در پوشه';

  @override
  String get transferCopyPath => 'کپی مسیر';

  @override
  String get transferPathCopied => 'مسیر کپی شد';

  @override
  String transferOpenFailed(String path) {
    return 'باز نشد. فایل‌ها در $path هستند.';
  }

  @override
  String get transferAutoAccepted => 'به‌طور خودکار پذیرفته شد';

  @override
  String get transferFileFailed => 'ناموفق';

  @override
  String get incomingFirstTime => 'اولین بار از این دستگاه';

  @override
  String get incomingTrusted => 'دستگاه مورد اعتماد';

  @override
  String get incomingUnverified => 'هویت تأیید نشده';

  @override
  String get incomingAlwaysAccept => 'همیشه از این دستگاه بپذیر';

  @override
  String incomingAliasWarning(String name) {
    return 'این دستگاه از نام «$name» استفاده می‌کند، اما همان دستگاه نیست.';
  }

  @override
  String get incomingChangeFolder => 'تغییر';

  @override
  String incomingExpired(String name) {
    return 'مهلت درخواست $name تمام شد.';
  }

  @override
  String incomingWithdrawn(String name) {
    return '$name درخواست را لغو کرد.';
  }

  @override
  String get permContinue => 'ادامه';

  @override
  String get permNotNow => 'الان نه';

  @override
  String get permLater =>
      'در مرحلهٔ بعد اندروید از شما می‌پرسد. بعداً هم می‌توانید این را در تنظیمات سیستم تغییر دهید.';

  @override
  String get permNotificationsTitle =>
      'نشان داده شود که LanDrop در حال اجراست؟';

  @override
  String get permNotificationsBody =>
      'LanDrop در پس‌زمینه هم فایل‌ها را دریافت می‌کند. اندروید این را با یک اعلان نشان می‌دهد و در صفحهٔ بعد از شما می‌خواهد اعلان‌های LanDrop را مجاز کنید.';

  @override
  String get permNearbyTitle => 'اجازهٔ «دستگاه‌های اطراف» داده شود؟';

  @override
  String get permNearbyBody =>
      'برای روشن کردن نقطهٔ اتصال یا اتصال Wi-Fi Direct، اندروید به اجازهٔ «دستگاه‌های اطراف» (در گوشی‌های قدیمی‌تر «مکان») نیاز دارد. LanDrop از مکان شما استفاده نمی‌کند.';

  @override
  String get permCameraTitle => 'از دوربین برای اسکن کد استفاده شود؟';

  @override
  String get permCameraBody =>
      'LanDrop فقط برای خواندن کد QR وای‌فای گوشی دیگر از دوربین استفاده می‌کند. هیچ عکسی گرفته یا ذخیره نمی‌شود.';

  @override
  String get permNotificationsOff =>
      'اعلان‌ها خاموش است. LanDrop همچنان در پس‌زمینه دریافت می‌کند، اما نمی‌بینید که در حال اجراست.';

  @override
  String get permNearbyOff =>
      'تا اجازهٔ «دستگاه‌های اطراف» را ندهید، این روش خاموش می‌ماند.';

  @override
  String get permCameraOff =>
      'دوربین خاموش می‌ماند. به‌جای آن می‌توانید نام و رمز شبکه را وارد کنید.';

  @override
  String get permTryAgain => 'دوباره امتحان کنید';

  @override
  String get settingsAllowNotifications => 'اجازهٔ اعلان‌ها';

  @override
  String get transferDetails => 'جزئیات';

  @override
  String get transferDetailsTitle => 'چه اتفاقی افتاد';

  @override
  String get transferDetailsReason => 'علت';

  @override
  String get transferDetailsCode => 'کد خطا';

  @override
  String get transferDetailsUnknown => 'نامشخص';

  @override
  String get transferDetailsReportNote =>
      'گزارش کپی‌شده به انگلیسی است تا هر کسی بتواند کمک کند.';

  @override
  String get incomingKnown => 'قبلاً دیده شده، هنوز مورد اعتماد نیست';

  @override
  String get incomingDetails => 'جزئیات';

  @override
  String autoAcceptedSnack(String name) {
    return 'دریافت از $name به‌طور خودکار پذیرفته شد';
  }

  @override
  String get autoAcceptStop => 'توقف پذیرش خودکار';

  @override
  String get settingsTrustedDevices => 'دستگاه‌های مورد اعتماد';

  @override
  String settingsTrustedDevicesSub(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString دستگاه',
      zero: 'هنوز هیچ دستگاهی',
    );
    return '$_temp0';
  }

  @override
  String get trustedEmpty =>
      'دستگاه‌هایی که از آن‌ها فایل می‌پذیرید، اینجا نمایش داده می‌شوند.';

  @override
  String get trustedIntro =>
      'دستگاه فقط با همان کد امنیتی، همان دستگاه به شمار می‌آید، نه فقط با نامش.';

  @override
  String get trustedAutoAccept => 'پذیرش خودکار';

  @override
  String get trustedAutoAcceptSub =>
      'بدون پرسش ذخیره می‌شود. هر بار یک اعلان می‌بینید.';

  @override
  String get trustedRename => 'تغییر نام';

  @override
  String get trustedRenameLabel => 'نامی که در این دستگاه نشان داده می‌شود';

  @override
  String get trustedRemove => 'حذف';

  @override
  String trustedRemoved(String name) {
    return '$name حذف شد';
  }

  @override
  String trustedDeviceName(String alias) {
    return 'نام دستگاه: $alias';
  }

  @override
  String get trustedLarge => 'انتقال‌های بزرگ هم خودکار پذیرفته شوند';

  @override
  String trustedLargeSub(String size) {
    return 'خاموش: برای انتقال‌های بیش از $size همیشه پرسیده می‌شود.';
  }

  @override
  String get onboardingSemantics => 'به LanDrop خوش آمدید';

  @override
  String get onboardingSkip => 'رد شدن';

  @override
  String get onboardingNext => 'بعدی';

  @override
  String get onboardingStart => 'شروع';

  @override
  String onboardingStep(int step, int total) {
    final intl.NumberFormat stepNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String stepString = stepNumberFormat.format(step);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'مرحلهٔ $stepString از $totalString';
  }

  @override
  String get onboarding1Title => 'فایل‌ها را به دستگاه‌های نزدیک خود بفرستید';

  @override
  String get onboarding1Body =>
      'بدون اینترنت و بدون حساب کاربری. فایل‌ها مستقیم از یک دستگاه به دستگاه دیگر می‌روند.';

  @override
  String get onboarding2Title => 'LanDrop را روی هر دو دستگاه باز کنید';

  @override
  String get onboarding2Body =>
      'آن‌ها را به یک وای‌فای وصل کنید. وای‌فای ندارید؟ LanDrop کمک می‌کند مستقیم وصل شوید.';

  @override
  String get onboarding3Title => 'برای این دستگاه یک نام انتخاب کنید';

  @override
  String get onboarding3Body => 'دیگران این نام را می‌بینند.';

  @override
  String get onboardingPermissions => 'اجازه‌هایی که LanDrop ممکن است بخواهد';

  @override
  String get onboardingLocalNetworkComputer =>
      'مک شما می‌پرسد آیا LanDrop اجازه دارد دستگاه‌های شبکهٔ محلی را پیدا کند. «Allow» را انتخاب کنید، وگرنه دستگاه‌های اطراف نمایش داده نمی‌شوند.';

  @override
  String get onboardingLocalNetworkPhone =>
      'آیفون یا آیپد شما می‌پرسد آیا LanDrop اجازه دارد دستگاه‌های شبکهٔ محلی را پیدا کند. «Allow» را انتخاب کنید، وگرنه دستگاه‌های اطراف نمایش داده نمی‌شوند.';

  @override
  String get onboardingFirewallWindows =>
      'ممکن است ویندوز بپرسد آیا LanDrop اجازهٔ استفاده از شبکه را دارد. آن را برای شبکه‌های خصوصی (Private networks) مجاز کنید.';

  @override
  String get onboardingStorageAndroid =>
      'فایل‌ها: برای ذخیرهٔ فایل‌های دریافتی در پوشهٔ Downloads تا برنامه‌های دیگر هم آن‌ها را ببینند. اولین باری که فایلی دریافت کنید، LanDrop پیش از آن توضیح می‌دهد.';

  @override
  String get onboardingNothingToAllow =>
      'فعلاً لازم نیست اجازه‌ای بدهید. LanDrop فقط وقتی چیزی لازم باشد می‌پرسد.';

  @override
  String get storageTitle => 'فایل‌های دریافتی در پوشهٔ Downloads ذخیره شوند؟';

  @override
  String get storageBody =>
      'برای اینکه فایل‌ها در پوشهٔ دانلودها و در دسترس برنامه‌های دیگر باشند، اندروید در صفحهٔ بعد از شما می‌خواهد «دسترسی به همهٔ فایل‌ها» را برای LanDrop روشن کنید. بدون آن، فایل‌ها در پوشهٔ خود LanDrop می‌مانند.';

  @override
  String get storageLater => 'بعداً می‌توانید این را در تنظیمات تغییر دهید.';

  @override
  String get storageAllow => 'اجازه می‌دهم';

  @override
  String get storageNotNow => 'الان نه';

  @override
  String storageGranted(String folder) {
    return 'از این به بعد فایل‌های دریافتی در $folder ذخیره می‌شوند.';
  }

  @override
  String get storageKeptPrivate =>
      'فایل‌ها در پوشهٔ خود LanDrop می‌مانند. بعداً می‌توانید در تنظیمات دوباره امتحان کنید.';

  @override
  String get sendSheetText => 'متن';

  @override
  String get sendTextTitle => 'ارسال متن';

  @override
  String get sendTextLabel => 'متن یا لینک';

  @override
  String get sendTextPaste => 'جای‌گذاری';

  @override
  String get sendTextNext => 'انتخاب دستگاه';

  @override
  String sendTextTooLong(String max) {
    return 'خیلی طولانی است: حداکثر $max.';
  }

  @override
  String get sendPickerTitleText => 'ارسال متن به…';

  @override
  String textFromTitle(String name) {
    return 'متن از $name';
  }

  @override
  String get textCopy => 'کپی';

  @override
  String get textCopied => 'متن کپی شد';

  @override
  String get textOpenLink => 'باز کردن لینک';

  @override
  String get textLinkFailed => 'لینک باز نشد.';

  @override
  String get textSaveFile => 'ذخیره به‌صورت فایل';

  @override
  String get textSaveFailed => 'فایل ذخیره نشد.';

  @override
  String get textAutoNotice =>
      'به‌طور خودکار از یک دستگاه مورد اعتماد دریافت شد.';

  @override
  String get textMessage => 'پیام متنی';

  @override
  String get historyTitle => 'تاریخچه';

  @override
  String get historySettingsSub => 'انتقال‌های قبلی روی این دستگاه';

  @override
  String get historyPrivacy =>
      'تاریخچه فقط روی همین دستگاه می‌ماند. می‌توانید آن را در تنظیمات خاموش کنید.';

  @override
  String get historyEmpty => 'هنوز انتقالی انجام نشده است.';

  @override
  String get historyOff => 'تاریخچه خاموش است.';

  @override
  String get historyClear => 'پاک کردن تاریخچه';

  @override
  String get historyClearBody =>
      'همهٔ موارد حذف شوند؟ فایل‌های دریافتی پاک نمی‌شوند.';

  @override
  String get historyClearConfirm => 'پاک کردن';

  @override
  String get historyCleared => 'تاریخچه پاک شد';

  @override
  String get historyToday => 'امروز';

  @override
  String get historyYesterday => 'دیروز';

  @override
  String historyFilesMore(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مورد دیگر',
    );
    return '$name و $_temp0';
  }

  @override
  String get historyWhen => 'زمان';

  @override
  String get historyResult => 'نتیجه';

  @override
  String get historySize => 'حجم';

  @override
  String get historyFiles => 'فایل‌ها';

  @override
  String get historySavedIn => 'محل ذخیره';

  @override
  String historyMoreFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل دیگر',
    );
    return 'و $_temp0';
  }

  @override
  String get historyGone => 'این فایل‌ها دیگر آنجا نیستند.';

  @override
  String historyDateTime(String date, String time) {
    return '$date، ساعت $time';
  }

  @override
  String get historyDetailsSemantics => 'جزئیات انتقال';

  @override
  String get settingsSectionPrivacy => 'تاریخچه و حریم خصوصی';

  @override
  String get settingsKeepHistory => 'نگه داشتن تاریخچه';

  @override
  String get settingsKeepHistorySub =>
      'فقط روی همین دستگاه می‌ماند. با خاموش کردن، پاک می‌شود.';

  @override
  String get transferRetryMissing => 'برخی از فایل‌ها دیگر وجود ندارند.';

  @override
  String get peerTrusted => 'مورد اعتماد';

  @override
  String get homeRecent => 'دستگاه‌های اخیر';

  @override
  String get recentNotNearby => 'در اطراف نیست';

  @override
  String recentLastSeen(String when) {
    return 'آخرین بار: $when';
  }

  @override
  String recentSemantics(String name) {
    return '$name، در اطراف نیست';
  }

  @override
  String get settingsAppearance => 'ظاهر';

  @override
  String get themeSystem => 'مطابق سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String shareSendingFiles(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فایل',
    );
    return 'در حال ارسال $_temp0';
  }

  @override
  String get shareSendingText => 'در حال ارسال متن';

  @override
  String get shareErrTooMany =>
      'تعداد مورد‌ها برای یک‌باره به‌اشتراک‌گذاری زیاد است. تعداد کمتری انتخاب کنید.';

  @override
  String get shareErrTooBig =>
      'حجم این مورد‌ها برای این روش زیاد است. به‌جای آن از دکمه ارسال داخل LanDrop استفاده کنید.';

  @override
  String get shareErrUnreadable => 'بعضی مورد‌ها خوانده نشدند و رد شدند.';

  @override
  String get shareErrFailed => 'مورد‌های اشتراکی دریافت نشد.';

  @override
  String get nearbySharesTitle => 'اشتراک‌های نزدیک';

  @override
  String get nearbyLoading => 'در حال جست‌وجوی فایل‌های اشتراکی…';

  @override
  String get nearbyEmpty => 'چیزی با شما به اشتراک گذاشته نشده';

  @override
  String get nearbyEmptyHint =>
      'اگر انتظار فایلی داشتید، شاید صاحب دستگاه باید این دستگاه را مجاز کند.';

  @override
  String get nearbySelectAll => 'انتخاب همه';

  @override
  String nearbyDownloadSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'دانلود موارد انتخاب‌شده ($countString)';
  }

  @override
  String get nearbyRefresh => 'تازه‌سازی';

  @override
  String get nearbyTruncated => 'برخی فایل‌ها نمایش داده نشده‌اند';

  @override
  String nearbyAccessTitle(String alias) {
    return '$alias می‌خواهد اشتراک‌های نزدیک شما را ببیند';
  }

  @override
  String get nearbyAccessDeny => 'رد';

  @override
  String get nearbyAccessOnce => 'اجازه برای ۱ ساعت';

  @override
  String get nearbyAccessAlways => 'همیشه اجازه بده (اعتماد)';
}
