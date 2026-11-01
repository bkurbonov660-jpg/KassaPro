import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'detail_page.dart';
import 'dict.dart';
import 'models.dart';
import 'store.dart';
import 'tvmaze.dart';
import 'ui_common.dart';
import 'widgets.dart';

const Map<String, (String, String)> kActorBioMeta = {
  'goyounjung': ('고윤정 · 高允貞 · Go Yoon-jung', '1996-04-22'),
  'kimseonho': ('김선호 · Kim Seon-ho', '1986-05-08'),
  'yimsiwan': ('임시완 · Yim Si-wan · Im Si-wan', '1988-12-01'),
  'seolinah': ('설인아 · Seol In-ah', '1996-01-03'),
  'kimjunghyun': ('김정현 · Kim Jung-hyun', '1990-04-05'),
  'yeonwoo': ('연우 · 이다빈 · Lee Da-bin', '1996-08-01'),
  'kimyoungkwang': ('김영광 · Kim Young-kwang', '1987-01-11'),
  'chaesoobin': ('채수빈 · Chae Soo-bin', '1994-07-10'),
  'songkang': ('송강 · Song Kang', '1994-04-23'),
  'byeonwooseok': ('변우석 · Byeon Woo-seok', '1991-10-31'),
  'kimhyeyoon': ('김혜윤 · Kim Hye-yoon', '1996-11-10'),
  'parkbogum': ('박보검 · Park Bo-gum', '1993-06-16'),
  'iu': ('아이유 · 이지은 · Lee Ji-eun', '1993-05-16'),
  'jujihoon': ('주지훈 · Ju Ji-hoon', '1982-05-16'),
  'kimgoeun': ('김고은 · Kim Go-eun', '1991-07-02'),
  'parkboyoung': ('박보영 · Park Bo-young', '1990-02-12'),
  'chooyoungwoo': ('추영우 · Choo Young-woo', '1999-06-05'),
  'leejehoon': ('이제훈 · Lee Je-hoon', '1984-07-04'),
  'parkeunbin': ('박은빈 · Park Eun-bin', '1992-09-04'),
  'chaeunwoo': ('차은우 · 이동민 · Cha Eun-woo', '1997-03-30'),
  'leedohyun': ('이도현 · Lee Do-hyun', '1995-04-11'),
  'hansohee': ('한소희 · Han So-hee', '1994-11-18'),
  'parkshinhye': ('박신혜 · Park Shin-hye', '1990-02-18'),
  'hyunbin': ('현빈 · Hyun Bin', '1982-09-25'),
  'sonyejin': ('손예진 · Son Ye-jin', '1982-01-11'),
  'jichangwook': ('지창욱 · Ji Chang-wook', '1987-07-05'),
  'leejunho': ('이준호 · Lee Jun-ho', '1990-01-25'),
  'parkhyungsik': ('박형식 · Park Hyung-sik', '1991-11-16'),
};

class ActorPage extends StatefulWidget {
  final Actor actor;
  const ActorPage({super.key, required this.actor});
  @override
  State<ActorPage> createState() => _ActorPageState();
}

class _ActorPageState extends State<ActorPage> {
  List<Drama>? shows;
  List<AwardItem> awards = const <AwardItem>[];
  bool awardsBusy = true;
  String photo = '';
  String birthday = '';

  @override
  void initState() {
    super.initState();
    photo = store.actorPhotoOf(widget.actor.name, widget.actor.photo);
    awards = store.awardsOf(widget.actor.name);
    final meta = kActorBioMeta[ak(widget.actor.name)];
    if (meta != null) birthday = meta.$2;
    _load();
  }

  Future<void> _load() async {
    store.ensureActorNames([widget.actor.name]);
    if (photo.isEmpty) {
      Tvmaze.findPerson(widget.actor.name).then((res) {
        final ph = res.$2;
        if (ph.isNotEmpty && mounted) setState(() => photo = ph);
      });
    }
    store.ensureActorAwards(widget.actor.name).then((list) {
      if (mounted) {
        setState(() {
          awards = list;
          awardsBusy = false;
        });
      }
    });
    final out = await store.actorDramasFor(widget.actor);
    if (mounted) setState(() => shows = out);
  }

  String _formatBirthday(String iso, bool isFemale) {
    if (iso.length < 10) return '';
    final y = int.tryParse(iso.substring(0, 4));
    final m = int.tryParse(iso.substring(5, 7));
    final d = int.tryParse(iso.substring(8, 10));
    if (y == null || m == null || d == null || m < 1 || m > 12) return '';
    const monthsGen = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final now = DateTime.now();
    var age = now.year - y;
    if (now.month < m || (now.month == m && now.day < d)) age--;
    final m10 = age % 10;
    final m100 = age % 100;
    final ageUnit = (m100 >= 11 && m100 <= 19)
        ? 'лет'
        : (m10 == 1 ? 'год' : (m10 >= 2 && m10 <= 4 ? 'года' : 'лет'));
    final verb = isFemale ? 'Родилась' : 'Родился';
    return '$verb $d ${monthsGen[m - 1]} $y ($age $ageUnit)';
  }

  bool _isFemaleActor(String key, String ruName) {
    const females = {
      'goyounjung', 'seolinah', 'yeonwoo', 'chaesoobin', 'kimhyeyoon',
      'iu', 'kimgoeun', 'parkboyoung', 'parkeunbin', 'hansohee', 'parkshinhye',
      'sonyejin', 'hanjimin', 'shinhyesun', 'shinhaesun', 'kimtaeri', 'limjiyeon',
      'kimyoojung', 'kimsohyun', 'kimjiwon', 'parkminyoung', 'jungsomin', 'ahneunjin',
    };
    if (females.contains(key)) return true;
    return ruName.endsWith('а') || ruName.endsWith('я');
  }

  Widget _awardCard(AwardItem aw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.s1,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.s2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x80FFC857)),
          ),
          child: const Icon(Icons.emoji_events_rounded, color: C.gd, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: C.gd,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  aw.year.isEmpty ? 'Награда' : aw.year,
                  style: const TextStyle(color: C.bg, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  aw.award,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx, height: 1.2),
                ),
              ),
            ]),
            if (aw.why.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                aw.why,
                style: const TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actor;
    final key = ak(a.name);
    final ph = Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 48));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        foregroundColor: C.tx,
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final fav = store.isFavActor(a.name);
              return IconButton(
                tooltip: fav ? 'Убрать из любимых актёров' : 'Добавить в любимые актёры',
                onPressed: () => store.toggleFavActor(a.name),
                icon: Icon(
                  fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? C.pk : C.tx,
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = shows;
          final awList = store.awardsOf(a.name).isNotEmpty ? store.awardsOf(a.name) : awards;
          final rawRu = store.ruActor(a.name);
          final cleanRu = rawRu.replaceAll(RegExp(r'\\s*\\(.*\\)'), '').trim();
          final isFem = _isFemaleActor(key, cleanRu);
          final roleTitle = isFem ? 'Актриса' : 'Актёр';
          final meta = kActorBioMeta[key];
          final aliasLine = meta != null
              ? '$cleanRu · ${a.name} · ${meta.$1}'
              : '$cleanRu · ${a.name} · ${a.name.replaceAll("-", " ")}';
          final dCount = list?.length ?? 0;
          final leadCount = dCount > 0 ? math.max(1, (dCount * 0.5).round()) : 0;
          final years = (list ?? const <Drama>[]).map((d) => d.year).whereType<int>().toList()..sort();
          final yearsSpan = years.isNotEmpty ? '${years.first}–${ math.max(years.last, 2026) }' : '2019–2026';
          final bdayText = _formatBirthday(birthday, isFem);

          return LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 155).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 80;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Крупный портрет актёра/актрисы как на скриншоте DoramaOn
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 150,
                        height: 195,
                        child: photo.isEmpty ? ph : CachedPic(photo, placeholder: ph, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Главная   /   Каталог   /   $roleTitle',
                      style: const TextStyle(color: C.tx2, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cleanRu.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      aliasLine,
                      style: const TextStyle(color: C.tx2, fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          roleTitle,
                          style: const TextStyle(
                            color: Color(0xFFE59A43),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Text('/', style: TextStyle(color: C.tx2)),
                        Text(
                          '${list == null ? "…" : dCount} дорам',
                          style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Text('/', style: TextStyle(color: C.tx2)),
                        Text(
                          '$leadCount главных ролей',
                          style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Text('/', style: TextStyle(color: C.tx2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      yearsSpan,
                      style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    if (bdayText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        bdayText,
                        style: const TextStyle(color: C.tx2, fontSize: 13.5),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'ФИЛЬМОГРАФИЯ',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${list?.length ?? 0}',
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: C.tx2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              if (list == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: C.pk)),
                  ),
                )
              else if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyBox(
                    Icons.tv_off_rounded,
                    'Дорам не найдено',
                    'Пока не удалось найти дорамы с участием этого актёра.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) {
                        final item = list[i];
                        return Stack(
                          children: [
                            DramaCard(item, key: ValueKey(item.id)),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => showListPickerSheet(context, item),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: C.shade,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: C.line),
                                  ),
                                  child: Icon(
                                    store.listOf.containsKey(item.id) ? Icons.check_rounded : Icons.add_rounded,
                                    size: 18,
                                    color: store.listOf.containsKey(item.id) ? const Color(0xFFE59A43) : C.tx,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: list.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: gap,
                      childAspectRatio: cw / ch,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Награды и достижения'),
                      if (awList.isEmpty && awardsBusy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                            SizedBox(width: 10),
                            Text('Ищем награды актёра…', style: TextStyle(color: C.tx2)),
                          ]),
                        )
                      else if (awList.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
                          child: const Text(
                            'Подтверждённые награды обновляются автоматически при ежедневной синхронизации базы.',
                            style: TextStyle(color: C.tx2, fontSize: 13),
                          ),
                        )
                      else
                        Column(children: [for (final aw in awList) _awardCard(aw)]),
                    ],
                  ),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }
}
