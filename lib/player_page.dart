import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'data2026.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'ui_common.dart';

/// Источники прямого мобильного видео без внешних API и токенов.
enum PlayerSource {
  vkVideo('VK Видео', Icons.play_circle_outline_rounded),
  doramyClub('Doramy.club', Icons.ondemand_video_rounded),
  kodikSearch('Kodik · Поиск', Icons.video_library_outlined),
  youtubeTrailer('Трейлер', Icons.movie_creation_outlined);

  final String label;
  final IconData icon;
  const PlayerSource(this.label, this.icon);
}

/// Открывает встроенный полноэкранный видеоплеер InAppWebView внутри приложения.
void openPlayer(
  BuildContext context,
  Drama drama, {
  int? episode,
  String? dub,
  PlayerSource source = PlayerSource.vkVideo,
  String? customUrl,
}) {
  final watched = store.prog[drama.id] ?? 0;
  final total = store.totals[drama.id] ?? (store.epCache[drama.id]?.length ?? 16);
  final initialEp = episode ?? (watched < total ? watched + 1 : math.max(1, total));
  final initialDub = (dub ?? store.dubOf[drama.id] ?? 'SoftBox').trim();

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DoramaPlayerPage(
        drama: drama,
        initialEpisode: initialEp,
        initialDub: initialDub,
        initialSource: source,
        initialCustomUrl: customUrl,
      ),
    ),
  );
}

class DoramaPlayerPage extends StatefulWidget {
  final Drama drama;
  final int initialEpisode;
  final String initialDub;
  final PlayerSource initialSource;
  final String? initialCustomUrl;

  const DoramaPlayerPage({
    super.key,
    required this.drama,
    this.initialEpisode = 1,
    this.initialDub = 'SoftBox',
    this.initialSource = PlayerSource.vkVideo,
    this.initialCustomUrl,
  });

  @override
  State<DoramaPlayerPage> createState() => _DoramaPlayerPageState();
}

class _DoramaPlayerPageState extends State<DoramaPlayerPage> {
  InAppWebViewController? _webCtrl;
  late int _episode;
  late String _dub;
  late PlayerSource _source;
  String? _customUrl;

  double _progress = 0;
  bool _controlsVisible = true;
  bool _expandVideo100 = true;
  bool _landscape = false;
  int _blockedPopups = 0;
  String _currentUrl = '';

  // Разрешённые домены видеоплееров и CDN (защита от внешних редиректов).
  static const List<String> _allowedHostSuffixes = <String>[
    'vkvideo.ru',
    'vk.com',
    'vk.ru',
    'vkuser.net',
    'vkuservideo.net',
    'vkuseraudio.net',
    'userapi.com',
    'okcdn.ru',
    'mycdn.me',
    'doramy.club',
    'doramalive.ru',
    'dorama.land',
    'kodik.info',
    'kodik.biz',
    'kodik.cc',
    'kodikplayer.com',
    'aniqit.com',
    'sibnet.ru',
    'youtube.com',
    'youtu.be',
    'googlevideo.com',
    'ytimg.com',
    'yandex.ru',
    'yastatic.net',
    'kinopoisk.ru',
    'ivi.ru',
  ];

  // Чёрный список рекламных сетей, казино, букмекеров и кликандеров.
  static const List<String> _blockedPatterns = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adfox.ru',
    'an.yandex.ru',
    'yandex.ru/ads',
    'mc.yandex.ru',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'exoclick.com',
    'trafficjunky.com',
    'juicyads.com',
    'clickadu.com',
    'hilltopads.net',
    'adsterra.com',
    'adriver.ru',
    'betwinner',
    '1xbet',
    '1xstavka',
    'melbet',
    'mostbet',
    'fonbet',
    'parimatch',
    'pin-up',
    'pinup',
    'vulkan',
    'joycasino',
    'azino',
    'vavada',
    'olymp',
    'leonbets',
    'popunder',
    'clickunder',
  ];

  // ── 1. Скрипт ранней блокировки popup-окон и редиректов (AT_DOCUMENT_START) ──
  static const String _jsDocumentStart = r'''
(function() {
  try {
    // Полная блокировка любых попыток открыть всплывающее окно через JS
    window.open = function() { return null; };
    window.alert = function() {};
    window.confirm = function() { return false; };
    window.prompt = function() { return null; };

    // Перехват кликов по ссылкам с target="_blank" и рекламным оверлеям
    document.addEventListener('click', function(e) {
      var a = e.target && e.target.closest ? e.target.closest('a') : null;
      if (!a) return;
      var href = (a.getAttribute('href') || '').toLowerCase();
      if (href.indexOf('javascript:window.open') === 0 ||
          href.indexOf('1xbet') !== -1 ||
          href.indexOf('mostbet') !== -1 ||
          href.indexOf('melbet') !== -1 ||
          href.indexOf('fonbet') !== -1 ||
          href.indexOf('betwinner') !== -1 ||
          href.indexOf('vulkan') !== -1) {
        e.preventDefault();
        e.stopPropagation();
        return false;
      }
      if (a.getAttribute('target') === '_blank') {
        a.removeAttribute('target');
      }
    }, true);
  } catch (_) {}
})();
''';

  // ── 2. Инъекция CSS и JS: удаление шапок/футеров/рекламы и разворот видео/iframe на 100vw x 100vh ──
  static const String _jsDomCleanerAndFullscreen = r'''
(function() {
  var STYLE_ID = 'dp-inappwebview-clean-style';

  var baseCss = `
    /* Удаляем шапки сайтов (header), навигацию, футеры, боковые панели и рекламные блоки */
    header, footer, nav, aside,
    .header, .footer, .navbar, .nav, .top-bar, .bottom-bar, .sidebar,
    .site-header, .site-footer, .main-header, .main-footer,
    #header, #footer, #nav, #navbar, #sidebar, #comments, .comments, .comment-list,
    .MobileHeader, .BottomMenu, .AppInstallBanner, .VkVideoAppBanner,
    .vk_head, .mhead, .ip_user_link, .Menu, .LeftMenu, .FloatBtn,
    .Banner, .PromoBanner, .SmartBanner, .app-banner, .install-app,
    .breadcrumbs, .share, .social-share, .related-posts, .cookie-notice,
    .ad, .ads, .ad-box, .ad-banner, .ad-container, .adsbox, .advert, .advertisement,
    .popup, .popunder, .modal-backdrop, .overlay-ad, .preroll-ads,
    [class*="ad-banner"], [id*="ad-banner"],
    [class*="ads-"], [id*="ads-"],
    [class*="advert"], [id*="advert"],
    [class*="popup"], [id*="popup"],
    [class*="rek-"], [id*="rek-"],
    [class*="banner"], [id*="banner"],
    a[href*="1xbet"], a[href*="mostbet"], a[href*="melbet"], a[href*="fonbet"],
    iframe[src*="doubleclick"], iframe[src*="googlesyndication"], iframe[src*="adfox"],
    iframe[src*="an.yandex"], iframe[src*="popads"], iframe[src*="exoclick"] {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      width: 0 !important;
      height: 0 !important;
      max-height: 0 !important;
      overflow: hidden !important;
      pointer-events: none !important;
      position: absolute !important;
      left: -9999px !important;
    }

    html, body {
      background-color: #0D0A12 !important;
      color: #F5EEE6 !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow-x: hidden !important;
      -webkit-tap-highlight-color: transparent !important;
    }

    /* Разворот элемента видео/iframe на 100% ширины и высоты экрана */
    .dp-fullscreen-player,
    video.dp-fullscreen-player,
    iframe.dp-fullscreen-player {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      right: 0 !important;
      bottom: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      max-width: 100vw !important;
      max-height: 100vh !important;
      min-width: 100vw !important;
      min-height: 100vh !important;
      z-index: 999999 !important;
      background: #000000 !important;
      border: none !important;
      margin: 0 !important;
      padding: 0 !important;
      object-fit: contain !important;
      transform: none !important;
    }
  `;

  function ensureStyle() {
    if (!document.head) return;
    if (!document.getElementById(STYLE_ID)) {
      var st = document.createElement('style');
      st.id = STYLE_ID;
      st.type = 'text/css';
      st.appendChild(document.createTextNode(baseCss));
      document.head.appendChild(st);
    }
  }

  function isPlayerIframe(el) {
    if (!el || el.tagName !== 'IFRAME') return false;
    var src = (el.getAttribute('src') || el.getAttribute('data-src') || '').toLowerCase();
    if (src.indexOf('doubleclick') !== -1 || src.indexOf('googlesyndication') !== -1 ||
        src.indexOf('adfox') !== -1 || src.indexOf('yandex.ru/ads') !== -1) {
      return false;
    }
    if (src.indexOf('video_ext.php') !== -1 ||
        src.indexOf('vkvideo.ru') !== -1 ||
        src.indexOf('vk.com/video') !== -1 ||
        src.indexOf('kodik') !== -1 ||
        src.indexOf('aniqit') !== -1 ||
        src.indexOf('sibnet') !== -1 ||
        src.indexOf('ok.ru/videoembed') !== -1 ||
        src.indexOf('youtube.com/embed') !== -1 ||
        src.indexOf('player') !== -1 ||
        src.indexOf('embed') !== -1) {
      return true;
    }
    var rect = el.getBoundingClientRect();
    return rect.width >= 220 && rect.height >= 130;
  }

  function unlockAncestors(el) {
    var cur = el ? el.parentElement : null;
    while (cur && cur !== document.body && cur !== document.documentElement) {
      cur.style.setProperty('transform', 'none', 'important');
      cur.style.setProperty('filter', 'none', 'important');
      cur.style.setProperty('perspective', 'none', 'important');
      cur.style.setProperty('contain', 'none', 'important');
      cur.style.setProperty('overflow', 'visible', 'important');
      cur.style.setProperty('z-index', '999999', 'important');
      cur = cur.parentElement;
    }
  }

  window.__dpExpandMode = true;

  window.__dpApplyFullscreen = function(enable) {
    window.__dpExpandMode = !!enable;
    ensureStyle();

    var oldTargets = document.querySelectorAll('.dp-fullscreen-player');
    for (var i = 0; i < oldTargets.length; i++) {
      oldTargets[i].classList.remove('dp-fullscreen-player');
    }

    if (!window.__dpExpandMode) {
      return false;
    }

    // 1. Ищем активный или основной <video> или плеер <iframe>
    var target = null;
    var videos = document.querySelectorAll('video');
    for (var v = 0; v < videos.length; v++) {
      var vd = videos[v];
      if (!vd.paused || vd.readyState >= 2 || vd.getAttribute('src') || vd.querySelector('source')) {
        target = vd;
        break;
      }
    }
    if (!target && videos.length === 1) {
      target = videos[0];
    }

    if (!target) {
      var iframes = document.querySelectorAll('iframe');
      for (var f = 0; f < iframes.length; f++) {
        if (isPlayerIframe(iframes[f])) {
          target = iframes[f];
          break;
        }
      }
    }

    if (target) {
      var playerWrap = target.closest(
        '.videoplayer, .video_box_wrap, #video_player, .player-box, .player-container, .html5-video-player'
      );
      var box = playerWrap || target;
      box.classList.add('dp-fullscreen-player');
      target.classList.add('dp-fullscreen-player');
      unlockAncestors(box);
      return true;
    }
    return false;
  };

  ensureStyle();
  window.__dpApplyFullscreen(window.__dpExpandMode);

  // Автоматически разворачивать любое видео при старте воспроизведения
  document.addEventListener('play', function(e) {
    if (window.__dpExpandMode && e.target && e.target.tagName === 'VIDEO') {
      e.target.classList.add('dp-fullscreen-player');
      unlockAncestors(e.target);
    }
  }, true);

  // Отслеживаем подгрузку SPA-элементов (VK Видео, Kodik, Doramy)
  if (!window.__dpObserverInstalled && window.MutationObserver) {
    window.__dpObserverInstalled = true;
    var obs = new MutationObserver(function() {
      ensureStyle();
      if (window.__dpExpandMode) {
        window.__dpApplyFullscreen(true);
      }
    });
    obs.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true
    });
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _episode = math.max(1, widget.initialEpisode);
    _dub = widget.initialDub;
    _source = widget.initialSource;
    _customUrl = widget.initialCustomUrl;
    _enterFullscreenMode();
  }

  @override
  void dispose() {
    _restoreSystemUi();
    super.dispose();
  }

  void _enterFullscreenMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    if (_landscape) {
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  /// Формирует прямой мобильный URL для выбранной серии, озвучки и платформы.
  String _buildTargetUrl() {
    if (_customUrl != null && _customUrl!.isNotEmpty) {
      return _customUrl!;
    }
    final ruTitle = store.ruTitle(widget.drama).trim();
    final enTitle = widget.drama.en.trim();
    final dubPart = _dub.isNotEmpty && _dub != 'Любая' ? _dub : '';

    switch (_source) {
      case PlayerSource.vkVideo:
        final q = <String>[
          ruTitle,
          'серия $_episode',
          if (dubPart.isNotEmpty) dubPart,
          'дорама',
        ].join(' ');
        return 'https://m.vkvideo.ru/?q=${Uri.encodeComponent(q)}';

      case PlayerSource.doramyClub:
        return 'https://doramy.club/?s=${Uri.encodeComponent(ruTitle)}';

      case PlayerSource.kodikSearch:
        final q = <String>[
          ruTitle,
          'серия $_episode',
          if (dubPart.isNotEmpty) dubPart,
          'смотреть онлайн',
        ].join(' ');
        return 'https://yandex.ru/video/touch/search/?text=${Uri.encodeComponent(q)}';

      case PlayerSource.youtubeTrailer:
        final q = '$enTitle ${widget.drama.year ?? ""} official trailer korean drama'.trim();
        return 'https://m.youtube.com/results?search_query=${Uri.encodeComponent(q)}';
    }
  }

  bool _isBlockedAdUrl(Uri uri) {
    final full = uri.toString().toLowerCase();
    for (final pat in _blockedPatterns) {
      if (full.contains(pat)) return true;
    }
    return false;
  }

  bool _isAllowedDomain(String host) {
    final h = host.toLowerCase();
    if (h.isEmpty) return false;
    for (final allowed in _allowedHostSuffixes) {
      if (h == allowed || h.endsWith('.$allowed')) return true;
    }
    return false;
  }

  InAppWebViewSettings _buildWebViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: false,
      supportMultipleWindows: true,
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllowFullscreen: true,
      useHybridComposition: true,
      allowsBackForwardNavigationGestures: true,
      transparentBackground: false,
      userAgent:
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
      contentBlockers: <ContentBlocker>[
        // 1. Блокировка загрузки рекламных и трекинговых скриптов на уровне движка
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter:
                r'.*(doubleclick\.net|googlesyndication\.com|adfox\.ru|an\.yandex\.ru|popads\.net|propellerads\.com|exoclick\.com|1xbet|mostbet|melbet|fonbet|betwinner|vulkan|joycasino|clickunder|popunder).*',
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
        // 2. Скрытие шапок, футеров и рекламных контейнеров через CSS движка
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '.*'),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.CSS_DISPLAY_NONE,
            selector:
                'header, footer, nav, aside, .header, .footer, .navbar, .ads, .ad-banner, .popup, .AppInstallBanner, .VkVideoAppBanner, [class*="ad-banner"], [id*="ad-banner"]',
          ),
        ),
      ],
    );
  }

  Future<void> _injectCleanAndFullscreen() async {
    final ctrl = _webCtrl;
    if (ctrl == null) return;
    try {
      await ctrl.evaluateJavascript(source: _jsDomCleanerAndFullscreen);
      await ctrl.evaluateJavascript(
        source: 'if (window.__dpApplyFullscreen) window.__dpApplyFullscreen(${_expandVideo100 ? "true" : "false"});',
      );
    } catch (_) {}
  }

  void _selectEpisode(int ep) {
    if (ep < 1) return;
    setState(() {
      _episode = ep;
      _customUrl = null;
      if (_source == PlayerSource.youtubeTrailer) {
        _source = PlayerSource.vkVideo;
      }
    });
    if (store.listOf[widget.drama.id] == 'watch' && (store.prog[widget.drama.id] ?? 0) < ep) {
      store.setProg(widget.drama, ep);
    }
    _reloadTarget();
  }

  void _selectDub(String studio) {
    final nextDub = (_dub == studio) ? '' : studio;
    setState(() {
      _dub = nextDub;
      _customUrl = null;
    });
    store.setDub(widget.drama, nextDub.isEmpty ? null : nextDub);
    _reloadTarget();
  }

  void _selectSource(PlayerSource src) {
    setState(() {
      _source = src;
      _customUrl = null;
    });
    _reloadTarget();
  }

  void _reloadTarget() {
    final url = _buildTargetUrl();
    _currentUrl = url;
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drama;
    final title = store.ruTitle(d);
    final totalEps = math.max(
      _episode,
      store.totals[d.id] ?? (store.epCache[d.id]?.length ?? 16),
    );
    final initialUrl = _buildTargetUrl();
    final subLabel = _source == PlayerSource.youtubeTrailer
        ? 'Официальный трейлер'
        : 'Серия $_episode${_dub.isNotEmpty ? " · $_dub" : ""} · ${_source.label}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_webCtrl != null && await _webCtrl!.canGoBack()) {
          await _webCtrl!.goBack();
          return;
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: _controlsVisible && !_landscape,
          bottom: false,
          child: Stack(
            children: [
              // ── Встроенный браузер InAppWebView на весь экран ──
              Positioned.fill(
                child: Column(
                  children: [
                    if (_controlsVisible)
                      _buildTopControls(title, subLabel, totalEps),
                    if (_progress > 0 && _progress < 1.0)
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 2,
                        color: C.pk,
                        backgroundColor: C.s2,
                      ),
                    Expanded(
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                        initialSettings: _buildWebViewSettings(),
                        initialUserScripts: UnmodifiableListView<UserScript>([
                          UserScript(
                            source: _jsDocumentStart,
                            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                          ),
                          UserScript(
                            source: _jsDomCleanerAndFullscreen,
                            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                          ),
                        ]),
                        onWebViewCreated: (controller) {
                          _webCtrl = controller;
                          _currentUrl = initialUrl;
                        },
                        onLoadStart: (controller, url) {
                          if (url != null) {
                            setState(() => _currentUrl = url.toString());
                          }
                        },
                        onProgressChanged: (controller, progress) {
                          if (mounted) {
                            setState(() => _progress = progress / 100.0);
                          }
                          if (progress >= 60) {
                            _injectCleanAndFullscreen();
                          }
                        },
                        onLoadStop: (controller, url) async {
                          await _injectCleanAndFullscreen();
                        },
                        onUpdateVisitedHistory: (controller, url, isReload) {
                          if (url != null && mounted) {
                            setState(() => _currentUrl = url.toString());
                          }
                          _injectCleanAndFullscreen();
                        },
                        onPermissionRequest: (controller, request) async {
                          return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.GRANT,
                          );
                        },
                        // Полная блокировка всплывающих окон (popup / window.open / target="_blank")
                        onCreateWindow: (controller, createWindowAction) async {
                          final uri = createWindowAction.request.url;
                          if (uri != null &&
                              (uri.scheme == 'http' || uri.scheme == 'https') &&
                              !_isBlockedAdUrl(uri) &&
                              _isAllowedDomain(uri.host)) {
                            await controller.loadUrl(urlRequest: URLRequest(url: uri));
                          } else if (mounted) {
                            setState(() => _blockedPopups++);
                          }
                          return false;
                        },
                        // Блокировка внешних редиректов, рекламных доменов и чужих схем
                        shouldOverrideUrlLoading: (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          if (uri == null) return NavigationActionPolicy.CANCEL;

                          final scheme = uri.scheme.toLowerCase();
                          if (!const <String>{'http', 'https', 'about', 'blob', 'data'}
                              .contains(scheme)) {
                            if (mounted) setState(() => _blockedPopups++);
                            return NavigationActionPolicy.CANCEL;
                          }

                          if (scheme == 'http' || scheme == 'https') {
                            if (_isBlockedAdUrl(uri)) {
                              if (mounted) setState(() => _blockedPopups++);
                              return NavigationActionPolicy.CANCEL;
                            }
                            if (navigationAction.isForMainFrame &&
                                !_isAllowedDomain(uri.host)) {
                              if (mounted) setState(() => _blockedPopups++);
                              return NavigationActionPolicy.CANCEL;
                            }
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Плавающая минималистичная кнопка возврата панели при полном экране ──
              if (!_controlsVisible)
                Positioned(
                  top: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => setState(() => _controlsVisible = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xCC16111D),
                        border: Border.all(color: C.line),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.tune_rounded, size: 15, color: C.tx),
                        const SizedBox(width: 6),
                        Text(
                          'С.$_episode${_dub.isNotEmpty ? " · $_dub" : ""}',
                          style: const TextStyle(
                            color: C.tx,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(String title, String subLabel, int totalEps) {
    return Container(
      color: C.bg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Закрыть плеер',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: C.tx, size: 22),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: C.tx,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.tx2, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (_blockedPopups > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_outlined, size: 12, color: C.jd),
                  const SizedBox(width: 3),
                  Text(
                    '$_blockedPopups',
                    style: const TextStyle(
                      color: C.jd,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _expandVideo100
                  ? 'Показать список видео на странице'
                  : 'Развернуть видео/iframe на 100% экрана',
              onPressed: () {
                setState(() => _expandVideo100 = !_expandVideo100);
                _injectCleanAndFullscreen();
              },
              icon: Icon(
                _expandVideo100 ? Icons.fit_screen_rounded : Icons.aspect_ratio_rounded,
                color: _expandVideo100 ? C.pk : C.tx2,
                size: 20,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Повернуть экран',
              onPressed: _toggleOrientation,
              icon: Icon(
                Icons.screen_rotation_rounded,
                color: _landscape ? C.pk : C.tx2,
                size: 19,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Скрыть панель',
              onPressed: () => setState(() => _controlsVisible = false),
              icon: const Icon(Icons.keyboard_arrow_up_rounded, color: C.tx2, size: 22),
            ),
          ]),

          // Полоса быстрого выбора серии
          if (_source != PlayerSource.youtubeTrailer) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: totalEps,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final epNum = i + 1;
                  final active = epNum == _episode;
                  return GestureDetector(
                    onTap: () => _selectEpisode(epNum),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? C.pk : C.s1,
                        border: Border.all(color: active ? C.pk : C.line),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Серия $epNum',
                        style: TextStyle(
                          color: active ? C.onPk : C.tx2,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Полоса выбора озвучки и источника
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                for (final src in PlayerSource.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectSource(src),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _source == src ? C.tx : C.s1,
                          border: Border.all(color: _source == src ? C.tx : C.line),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            src.icon,
                            size: 13,
                            color: _source == src ? C.bg : C.tx2,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            src.label,
                            style: TextStyle(
                              color: _source == src ? C.bg : C.tx2,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  color: C.line,
                ),
                for (final studio in kDubStudios)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectDub(studio),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _dub == studio ? C.s2 : C.s1,
                          border: Border.all(color: _dub == studio ? C.pk : C.line),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          studio,
                          style: TextStyle(
                            color: _dub == studio ? C.pk : C.tx2,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tooltip: 'Открыть текущую страницу во внешнем браузере',
                  onPressed: () {
                    final u = _currentUrl.isNotEmpty ? _currentUrl : _buildTargetUrl();
                    Native.openUrl(u);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 15, color: C.tx2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
