import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  String _search = '';

  String _periodTitle(String p) {
    if (p == 'month') return 'За 30 дней (Месяц)';
    if (p == 'year') return 'За 365 дней (Год)';
    return 'За сегодня (День)';
  }

  Future<void> _showAppControlModal(AppUsageItem item) async {
    int limitMin = item.dailyLimitMinutes;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.appName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${item.packageName} · UID ${item.uid}',
                    style: const TextStyle(color: C.tx2, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Дневной лимит использования (Авто-заморозка при превышении):',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in [0, 15, 30, 60, 120, 180])
                        PeriodPill(
                          m == 0 ? 'Без лимита' : '$m мин/день',
                          limitMin == m,
                          () async {
                            setS(() => limitMin = m);
                            await appState.setDailyLimitForApp(item.packageName, m);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await appState.toggleFirewallForApp(item);
                          },
                          icon: Icon(
                            item.isNetBlocked ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 18,
                            color: item.isNetBlocked ? C.jd : C.rd,
                          ),
                          label: Text(
                            item.isNetBlocked ? 'Разблокировать сеть' : 'Блок интернета (Root)',
                            style: const TextStyle(color: C.tx, fontSize: 12.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: C.line),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await appState.toggleFreezeForApp(item.packageName, !item.isFrozen);
                          },
                          icon: Icon(
                            item.isFrozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded,
                            size: 18,
                            color: item.isFrozen ? C.jd : C.pk,
                          ),
                          label: Text(
                            item.isFrozen ? 'Разморозить' : 'Заморозить (Root)',
                            style: const TextStyle(color: C.tx, fontSize: 12.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: C.line),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final filtered = appState.apps.where((a) {
          if (!appState.includeSystemApps && a.isSystem && a.usageMs < 60000) {
            return false;
          }
          if (_search.trim().isEmpty) return true;
          final q = _search.trim().toLowerCase();
          return a.appName.toLowerCase().contains(q) ||
              a.packageName.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => b.usageMs.compareTo(a.usageMs));

        return SafeArea(
          child: RefreshIndicator(
            color: C.jd,
            backgroundColor: C.s1,
            onRefresh: () => appState.refreshData(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.s1,
                        border: Border.all(color: C.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: C.jd, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AegisRoot · Экранное время',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: C.tx,
                            ),
                          ),
                          Text(
                            _periodTitle(appState.period),
                            style: const TextStyle(color: C.tx2, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: appState.loading ? null : () => appState.refreshData(),
                      icon: appState.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: C.jd),
                            )
                          : const Icon(Icons.refresh_rounded, color: C.tx2),
                      style: IconButton.styleFrom(
                        backgroundColor: C.s1,
                        side: const BorderSide(color: C.line),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      PeriodPill('День', appState.period == 'day',
                          () => appState.setPeriod('day')),
                      PeriodPill('Месяц', appState.period == 'month',
                          () => appState.setPeriod('month')),
                      PeriodPill('Год', appState.period == 'year',
                          () => appState.setPeriod('year')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!appState.power.hasUsagePerm)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.gd),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security_rounded, color: C.gd, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Активация разрешений через Root',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Нажмите «Выдать через Root», чтобы автоматически включить доступ к статистике времени, сети и файловой системе.',
                          style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => appState.grantRootPermissions(),
                                icon: const Icon(Icons.bolt_rounded, size: 18),
                                label: const Text('Выдать через Root'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: C.jd,
                                  foregroundColor: C.bg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => NativeBridge.openUsageSettings(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: C.line),
                                foregroundColor: C.tx,
                              ),
                              child: const Text('Настройки'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.05,
                  children: [
                    StatBox(
                      value: fmtDurationMs(appState.totalScreenMs),
                      label: 'Общее время',
                      icon: Icons.schedule_rounded,
                      accent: C.jd,
                    ),
                    StatBox(
                      value: '${filtered.length}',
                      label: 'Приложений',
                      icon: Icons.apps_rounded,
                      accent: C.pk,
                    ),
                    StatBox(
                      value: fmtBytes(appState.totalMobileBytes + appState.totalWifiBytes),
                      label: 'Расход трафика',
                      icon: Icons.swap_vert_rounded,
                      accent: C.gd,
                    ),
                    StatBox(
                      value: appState.power.hasRoot ? 'Активен (SU)' : 'Стандарт',
                      label: 'Root-доступ',
                      icon: Icons.verified_user_rounded,
                      accent: appState.power.hasRoot ? C.jd : C.tx2,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: C.tx, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск среди всех приложений…',
                    hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: C.tx2, size: 20),
                    filled: true,
                    fillColor: C.s1,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: C.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: C.jd),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  activeColor: C.jd,
                  title: const Text(
                    'Показывать все системные приложения',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.tx),
                  ),
                  value: appState.includeSystemApps,
                  onChanged: (v) => appState.toggleSystemApps(v),
                ),
                const SectionHeader(
                  'Приложения (нажмите для лимита или Root-блокировки)',
                  Icons.bar_chart_rounded,
                ),
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Нет данных за выбранный период. Нажмите «Выдать через Root» или включите показ всех приложений.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.tx2, fontSize: 13),
                    ),
                  )
                else
                  for (final item in filtered.take(120)) _buildAppUsageTile(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppUsageTile(AppUsageItem item) {
    final maxMs = appState.totalScreenMs > 0 ? appState.totalScreenMs : 1;
    final ratio = (item.usageMs / maxMs).clamp(0.02, 1.0);
    final minutes = item.usageMs ~/ 60000;
    final hours = (item.usageMs / 3600000).toStringAsFixed(1);

    return GestureDetector(
      onTap: () => _showAppControlModal(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.s1,
          border: Border.all(
            color: item.isNetBlocked || item.isFrozen ? C.pk : C.line,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.s2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.line),
                  ),
                  child: Text(
                    item.appName.isNotEmpty ? item.appName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: C.jd,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: C.tx,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: C.tx2, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmtDurationMs(item.usageMs),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: C.jd,
                      ),
                    ),
                    Text(
                      '$minutes мин ($hours ч)',
                      style: const TextStyle(color: C.tx2, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                color: C.jd,
                backgroundColor: C.s2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Трафик: ${fmtBytes(item.totalBytes)} (Моб: ${fmtBytes(item.mobileBytes)} · Wi-Fi: ${fmtBytes(item.wifiBytes)})',
                  style: const TextStyle(color: C.tx2, fontSize: 11.5),
                ),
                if (item.dailyLimitMinutes > 0)
                  Text(
                    '· Лимит: ${item.dailyLimitMinutes} мин',
                    style: const TextStyle(color: C.gd, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                if (item.isNetBlocked)
                  const Text(
                    '· Сеть заблокирована (Root)',
                    style: TextStyle(color: C.rd, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                if (item.isFrozen)
                  const Text(
                    '· Заморожено',
                    style: TextStyle(color: C.pk, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
