import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'tvmaze.dart';
import 'ui_common.dart';
import 'widgets.dart';

class ActorPage extends StatefulWidget {
  final Actor actor;
  const ActorPage({super.key, required this.actor});
  @override
  State<ActorPage> createState() => _ActorPageState();
}

class _ActorPageState extends State<ActorPage> {
  List<Drama>? shows;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final l = await Tvmaze.actorShows(widget.actor.id);
    final out = l.map((d) => store.registerTemp(d)).toList();
    store.translator.ensureMany(out);
    if (mounted) setState(() => shows = out);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actor;
    final ph = Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 40));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, foregroundColor: C.tx),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = shows;
          return LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 150).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 80;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(children: [
                    ClipOval(child: SizedBox(width: 84, height: 84,
                      child: a.photo.isEmpty ? ph
                        : Image.network(a.photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(list == null ? 'Загружаем фильмографию…' : 'Корейских дорам: ${list.length}',
                          style: const TextStyle(color: C.tx2, fontSize: 13)),
                    ])),
                  ]),
                ),
              ),
              if (list == null)
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: C.pk))))
              else if (list.isEmpty)
                const SliverToBoxAdapter(child: EmptyBox(Icons.tv_off_rounded, 'Дорам не найдено',
                  'У этого актёра нет корейских дорам в базе TVmaze.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => DramaCard(list[i], key: ValueKey(list[i].id)),
                      childCount: list.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, mainAxisSpacing: 16, crossAxisSpacing: gap,
                      childAspectRatio: cw / ch),
                  ),
                ),
            ]);
          });
        },
      ),
    );
  }
}
