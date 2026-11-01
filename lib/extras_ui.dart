import 'dart:async';
export 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'config.dart';
import 'detail_page.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'taste.dart';
import 'ui_common.dart';

// ── Канал проекта в Telegram (минималистичная иконка соединённых звеньев цепи как на референсе) ──
const String kTgSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <rect width="48" height="48" rx="14" fill="#1F1829" stroke="#38304A" stroke-width="1.5"/>
  <g transform="rotate(-45 24 24)" fill="none" stroke="#F5EEE6" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M21 17H16a7 7 0 0 0 0 14h5"/>
    <path d="M27 17h5a7 7 0 0 1 0 14h-5"/>
    <line x1="18" y1="24" x2="30" y2="24"/>
  </g>
</svg>''';

Future<void> openTelegram(BuildContext context) async {
  final ok = await Native.openUrl(Cfg.tgUrl);
  if (ok || !context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: Cfg.tgUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Не удалось открыть Telegram. Ссылка скопирована: ${Cfg.tgUrl}')));
}

class TgCard extends StatelessWidget {
  const TgCard({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openTelegram(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.s1,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          SvgPicture.string(kTgSvg, width: 38, height: 38),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Канал проекта',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.tx)),
            SizedBox(height: 2),
            Text('Обновления, новые версии APK и новости · @PULSEDORAM',
              style: TextStyle(color: C.tx2, fontSize: 11.5)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: C.bg,
              border: Border.all(color: C.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Перейти', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

Future<void> showAppUpdateDialog(BuildContext context, {bool markDismissed = true}) async {
  final title = store.noticeTitle.isNotEmpty
      ? store.noticeTitle
      : 'Вышло новое обновление 3.2';
  final rawText = store.noticeText.isNotEmpty
      ? store.noticeText
      : 'Вышло новое обновление приложения Дорама Пульс 3.2 — пожалуйста, обновитесь для получения всех новых функций:\n'
        '• Полная база дорам 2025 и 2026 годов + точные русские названия для поиска\n'
        '• Обновлённые фотографии актёров, полные фильмографии и все награды 2025–2026\n'
        '• Оффлайн-кэширование постеров и фотографий актёров без интернета\n'
        '• Автоматическая очистка дублей дорам и история всех уведомлений в Профиле';

  final lines = rawText
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: C.s1,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: C.line, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.string(kTgSvg, width: 36, height: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.bg,
                            border: Border.all(color: C.line),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ВЕРСИЯ 3.2 · ОБНОВЛЕНИЕ',
                            style: TextStyle(color: C.pk, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(color: C.tx, fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (markDismissed) store.dismissUpdatePopup();
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: C.tx2, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.bg,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < lines.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 6),
                            child: Text(
                              lines[i],
                              style: TextStyle(
                                color: i == 0 && !lines[i].startsWith('•') ? C.tx : C.tx2,
                                fontWeight: i == 0 && !lines[i].startsWith('•') ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12.8,
                                height: 1.38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (markDismissed) store.dismissUpdatePopup();
                        Navigator.of(ctx).pop();
                        openTelegram(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                          color: C.pk,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.string(kTgSvg, width: 22, height: 22),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Канал проекта · Обновить',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: C.onPk, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      if (markDismissed) store.dismissUpdatePopup();
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: C.line),
                      backgroundColor: C.bg,
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: const Text('Позже', style: TextStyle(color: C.tx2, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (markDismissed) store.dismissUpdatePopup();
}

Widget extraBtn(String t, IconData i, VoidCallback f) => OutlinedButton.icon(
  onPressed: f,
  icon: Icon(i, color: C.pk),
  label: Text(t, style: const TextStyle(color: C.tx)),
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
    side: const BorderSide(color: C.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));

// ── Рекомендации ──
class RecRail extends StatelessWidget {
  final List<Rec> recs;
  const RecRail(this.recs, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final r = recs[i];
          return SizedBox(
            width: 130,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openDrama(context, r.d),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(fit: StackFit.expand, children: [
                      Poster(r.d),
                      Positioned(left: 8, bottom: 8, child: Pill(Icons.favorite_rounded, '${r.pct}%', C.pk)),
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => store.hide(r.d),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: C.shade, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 16, color: C.tx2),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(store.ruTitle(r.d), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
                const SizedBox(height: 2),
                Text(r.why, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.tx2, fontSize: 11, height: 1.25)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class RecSections extends StatelessWidget {
  const RecSections({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = Taste.rows();
    if (rows.isEmpty) {
      return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Рекомендуем вам'),
        Text('Поставьте 7+ баллов нескольким дорамам — подберём то, что подойдёт именно вам: по жанрам, темам, каналу и году, с учётом того, что вам не зашло.',
          style: TextStyle(color: C.tx2, height: 1.35)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows) ...[
        SectionTitle(r.title),
        RecRail(r.items),
      ],
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Крестик на постере — «не интересно», такая дорама больше не появится в подборках.',
          style: TextStyle(color: C.tx2, fontSize: 11)),
      ),
    ]);
  }
}

class MatchCard extends StatelessWidget {
  final Drama d;
  final int pct;
  const MatchCard(this.d, this.pct, {super.key});
  @override
  Widget build(BuildContext context) {
    final why = Taste.why(d).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.pk), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 56, height: 56,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 56, height: 56,
              child: CircularProgressIndicator(value: pct / 100.0, strokeWidth: 5, color: C.pk, backgroundColor: C.s2)),
            Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Совпадение с вашим вкусом', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final w in why)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(w, style: const TextStyle(color: C.tx2, fontSize: 12, height: 1.3)),
            ),
        ])),
      ]),
    );
  }
}

// ── Случайная дорама ──
Future<void> showRoulette(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.s1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const RouletteSheet(),
  );
}

class RouletteSheet extends StatefulWidget {
  const RouletteSheet({super.key});
  @override
  State<RouletteSheet> createState() => _RouletteSheetState();
}

class _RouletteSheetState extends State<RouletteSheet> {
  bool fromPlan = true;
  bool spinning = false;
  Drama? shown;
  Drama? pick;
  Timer? _t;
  List<Drama> _pool = <Drama>[];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    fromPlan = store.listItems('plan').isNotEmpty;
    _pool = Taste.roulettePool(fromPlan);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _src(bool plan) {
    _t?.cancel();
    setState(() {
      fromPlan = plan;
      spinning = false;
      shown = null;
      pick = null;
      _pool = Taste.roulettePool(plan);
    });
  }

  void _spin() {
    if (_pool.isEmpty) return;
    _t?.cancel();
    final prev = pick?.id;
    final pool = _pool;
    setState(() {
      spinning = true;
      pick = null;
    });
    var ticks = 0;
    _t = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      ticks++;
      var d = pool[_rnd.nextInt(pool.length)];
      if (ticks >= 14) {
        t.cancel();
        if (pool.length > 1 && d.id == prev) {
          d = pool[(pool.indexOf(d) + 1) % pool.length];
        }
        setState(() {
          spinning = false;
          pick = d;
          shown = d;
        });
      } else {
        setState(() => shown = d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = shown;
    final pk = pick;
    final inPlan = pk != null && store.listOf[pk.id] == 'plan';
    final m = (pk != null && store.rate[pk.id] == null) ? Taste.match(pk) : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          const Text('Случайная дорама', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilterPill('Из «В планах»', fromPlan, () => _src(true)),
            FilterPill('Из подборки', !fromPlan, () => _src(false)),
          ]),
          const SizedBox(height: 10),
          if (_pool.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                fromPlan
                  ? 'В «В планах» пока пусто. Добавьте дорамы или выберите «Из подборки».'
                  : 'Подборка пока пуста — дождитесь загрузки каталога.',
                textAlign: TextAlign.center, style: const TextStyle(color: C.tx2)),
            )
          else ...[
            SizedBox(
              width: 140, height: 210,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: d == null
                  ? Container(color: C.s2, child: const Icon(Icons.casino_rounded, size: 56, color: C.pk))
                  : Poster(d),
              ),
            ),
            const SizedBox(height: 12),
            if (pk != null && !spinning) ...[
              Text(store.ruTitle(pk), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                [
                  if (pk.year != null) '${pk.year}',
                  if (pk.rating != null) '★ ${pk.rating!.toStringAsFixed(1)}',
                  if (m != null) 'совпадение $m%',
                ].join(' · '),
                style: const TextStyle(color: C.tx2, fontSize: 13)),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: spinning ? null : _spin,
                icon: const Icon(Icons.casino_rounded),
                label: Text(pk == null ? (spinning ? 'Выбираем…' : 'Крутить') : 'Ещё раз'),
                style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            if (pk != null && !spinning) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: extraBtn('Подробнее', Icons.info_outline_rounded, () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => DetailPage(drama: pk)));
                })),
                const SizedBox(width: 10),
                Expanded(child: extraBtn(inPlan ? 'В планах' : 'В планы', Icons.bookmark_rounded, () {
                  if (!inPlan) {
                    store.setList(pk, 'plan');
                    setState(() {});
                  }
                })),
              ]),
            ],
          ],
        ]),
      ),
    );
  }
}

// ── Сравнение и выбор ──
Future<void> openCompare(BuildContext context, {Drama? first}) async {
  final pool = <Drama>[...store.listItems('plan')];
  if (first != null && !pool.any((d) => d.id == first.id)) pool.insert(0, first);
  if (pool.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Добавьте хотя бы две дорамы в «В планах», чтобы сравнить их.')));
    return;
  }
  final nav = Navigator.of(context);
  final sel = <int>{if (first != null) first.id};
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.s1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 14),
            const Text('Что сравниваем?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            const Text('Выберите 2–3 дорамы', style: TextStyle(color: C.tx2, fontSize: 12)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final d in pool)
                  CheckboxListTile(
                    value: sel.contains(d.id),
                    activeColor: C.pk,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setS(() {
                        if (v == true) {
                          if (sel.length < 3) sel.add(d.id);
                        } else {
                          sel.remove(d.id);
                        }
                      });
                    },
                    title: Text(store.ruTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${d.year ?? ""}${d.rating != null ? " · ★ ${d.rating!.toStringAsFixed(1)}" : ""}',
                      style: const TextStyle(color: C.tx2, fontSize: 12)),
                    secondary: SizedBox(width: 40, height: 60,
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Poster(d))),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: sel.length >= 2
                    ? () {
                        final chosen = pool.where((d) => sel.contains(d.id)).toList();
                        Navigator.of(ctx).pop();
                        nav.push(MaterialPageRoute(builder: (_) => ComparePage(chosen)));
                      }
                    : null,
                  style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(sel.length >= 2 ? 'Сравнить (${sel.length})' : 'Выберите минимум две'),
                ),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}

class _Info {
  final Drama d;
  final int? match;
  final double? rating;
  final int eps;
  final double hours;
  _Info(this.d)
      : match = store.rate[d.id] == null ? Taste.match(d) : null,
        rating = d.rating,
        eps = store.totals[d.id] ?? (store.epCache[d.id]?.length ?? 0),
        hours = (store.totals[d.id] ?? (store.epCache[d.id]?.length ?? 0)) * 65 / 60.0;
}

class ComparePage extends StatefulWidget {
  final List<Drama> items;
  const ComparePage(this.items, {super.key});
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  @override
  void initState() {
    super.initState();
    for (final d in widget.items) {
      store.ensureEpisodes(d).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  int _best(List<num?> v) {
    var bi = -1;
    num? bv;
    var cnt = 0;
    for (var i = 0; i < v.length; i++) {
      final x = v[i];
      if (x == null || x == 0) continue;
      cnt++;
      if (bv == null || x > bv) {
        bv = x;
        bi = i;
      }
    }
    if (cnt < 2) return -1;
    var ties = 0;
    for (final x in v) {
      if (x != null && x == bv) ties++;
    }
    return ties > 1 ? -1 : bi;
  }

  Widget _metric(String label, List<String> vals, {int best = -1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < vals.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == best ? const Color(0x265FD9B4) : C.s1,
                  border: Border.all(color: i == best ? C.jd : C.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(vals[i], textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: i == best ? C.jd : C.tx)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  _Info? _verdict(List<_Info> rows) {
    final today = todayIso();
    final out = rows.where((r) => r.d.date.isEmpty || r.d.date.compareTo(today) <= 0).toList();
    final pool = out.isEmpty ? rows : out;
    _Info? best;
    var bv = -1.0;
    for (final r in pool) {
      final v = (r.match ?? 0) * 0.6 + (r.rating ?? 6.0) * 4.0;
      if (v > bv) {
        bv = v;
        best = r;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0, foregroundColor: C.tx,
        title: const Text('Сравнение и выбор', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rows = widget.items.map((d) => _Info(d)).toList();
          final best = _verdict(rows);
          final hasMatch = rows.any((r) => r.match != null);
          final today = todayIso();
          final reasons = <String>[];
          if (best != null) {
            if (best.match != null) reasons.add('Совпадение с вашим вкусом: ${best.match}%');
            if (best.rating != null) reasons.add('Рейтинг TVmaze: ${best.rating!.toStringAsFixed(1)}');
            final known = rows.where((r) => r.eps > 0).toList();
            if (known.length >= 2) {
              final short = known.reduce((a, b) => a.hours <= b.hours ? a : b);
              if (short.d.id == best.d.id) reasons.add('Самая короткая: ≈ ${best.hours.round()} ч');
            }
            for (final w in Taste.why(best.d).take(2)) {
              reasons.add(w);
            }
          }
          String dash(String s) => s.isEmpty ? '—' : s;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => openDrama(context, rows[i].d),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(aspectRatio: 2 / 3,
                          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Poster(rows[i].d))),
                        const SizedBox(height: 6),
                        Text(store.ruTitle(rows[i].d), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2)),
                      ]),
                    ),
                  ),
                ],
              ]),
              if (best != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.pk), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.emoji_events_rounded, color: C.gd),
                      SizedBox(width: 8),
                      Text('Лучший выбор для вас', style: TextStyle(fontWeight: FontWeight.w800, color: C.gd)),
                    ]),
                    const SizedBox(height: 8),
                    Text(store.ruTitle(best.d), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    for (final r in reasons)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $r', style: const TextStyle(color: C.tx2, fontSize: 13, height: 1.3)),
                      ),
                    if (!hasMatch)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Поставьте оценки 7+ любимым дорамам — и выбор станет точнее.',
                          style: TextStyle(color: C.tx2, fontSize: 12)),
                      ),
                  ]),
                ),
              ],
              if (hasMatch)
                _metric('Совпадение с вашим вкусом',
                  [for (final r in rows) r.match != null ? '${r.match}%' : '—'],
                  best: _best([for (final r in rows) r.match])),
              _metric('Рейтинг TVmaze',
                [for (final r in rows) r.rating != null ? r.rating!.toStringAsFixed(1) : '—'],
                best: _best([for (final r in rows) r.rating])),
              _metric('Серий', [for (final r in rows) r.eps > 0 ? '${r.eps}' : '—']),
              _metric('Время просмотра (≈)', [for (final r in rows) r.eps > 0 ? '≈ ${r.hours.round()} ч' : '—']),
              _metric('Год', [for (final r in rows) r.d.year != null ? '${r.d.year}' : '—']),
              _metric('Статус', [
                for (final r in rows)
                  (r.d.date.isNotEmpty && r.d.date.compareTo(today) > 0)
                    ? 'Выйдет ${fmtDate(r.d.date)}'
                    : dash(ruStatus(r.d.status)),
              ]),
              _metric('Канал', [for (final r in rows) dash(r.d.network)]),
              _metric('Жанры', [for (final r in rows) dash(r.d.genres.take(3).map(ruGenre).join(', '))]),
              _metric('Темы', [for (final r in rows) dash(Taste.tropeLabels(r.d).join(', '))]),
              const SizedBox(height: 16),
              const Text(
                'Время просмотра — оценка по ≈65 минут на серию. Совпадение считается по вашим оценкам, жанрам, темам и каналу.',
                style: TextStyle(color: C.tx2, fontSize: 11, height: 1.3)),
            ],
          );
        },
      ),
    );
  }
}
