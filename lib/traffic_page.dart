import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'theme.dart';

class TrafficPage extends StatelessWidget {
  const TrafficPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final totalBytes = appState.totalMobileBytes + appState.totalWifiBytes;
        final sorted = List<AppUsageItem>.from(appState.apps)
          ..removeWhere((a) => !appState.includeSystemApps && a.isSystem && a.totalBytes < 1024 * 50)
          ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));

        return SafeArea(
          child: RefreshIndicator(
            color: C.jd,
            backgroundColor: C.s1,
            onRefresh: () => appState.refreshData(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Text(
                  'Трафик и Root-Брандмауэр',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.tx),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Учёт мобильного интернета и Wi-Fi + мгновенная блокировка доступа в сеть через iptables (Root)',
                  style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
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
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: appState.toggleExtendedTraffic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.network_check_rounded, color: C.jd, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Сводка сетевого трафика',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                              ),
                              Text(
                                'Всего: ${fmtBytes(totalBytes)} · Моб: ${fmtBytes(appState.totalMobileBytes)} · Wi-Fi: ${fmtBytes(appState.totalWifiBytes)}',
                                style: const TextStyle(color: C.tx2, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          appState.showExtendedTrafficDetails ? 'Скрыть' : 'Показать',
                          style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          appState.showExtendedTrafficDetails
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: C.tx2,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (appState.showExtendedTrafficDetails) ...[
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.05,
                    children: [
                      StatBox(
                        value: fmtBytes(totalBytes),
                        label: 'Общий трафик',
                        icon: Icons.public_rounded,
                        accent: C.jd,
                      ),
                      StatBox(
                        value: fmtBytes(appState.totalMobileBytes),
                        label: 'Мобильная сеть',
                        icon: Icons.cell_tower_rounded,
                        accent: C.pk,
                      ),
                      StatBox(
                        value: fmtBytes(appState.totalWifiBytes),
                        label: 'Сеть Wi-Fi',
                        icon: Icons.wifi_rounded,
                        accent: C.gd,
                      ),
                      StatBox(
                        value: '${sorted.where((x) => x.isNetBlocked).length}',
                        label: 'Заблокировано в сети',
                        icon: Icons.block_rounded,
                        accent: C.rd,
                      ),
                    ],
                  ),
                ],
                const SectionHeader('Расход трафика и Root-блокировка сети', Icons.security_update_good_rounded),
                if (sorted.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Данные о сетевом трафике обновляются…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.tx2),
                    ),
                  )
                else
                  for (final a in sorted.take(100))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.s1,
                        border: Border.all(color: a.isNetBlocked ? C.rd : C.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: C.tx,
                                      ),
                                    ),
                                    Text(
                                      a.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: C.tx2, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                fmtBytes(a.totalBytes),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: C.gd,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => appState.toggleFirewallForApp(a),
                                icon: Icon(
                                  a.isNetBlocked ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                                  color: a.isNetBlocked ? C.rd : C.jd,
                                  size: 20,
                                ),
                                tooltip: a.isNetBlocked
                                    ? 'Сеть отключена (нажмите чтобы включить)'
                                    : 'Отключить интернет приложению (Root iptables)',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Мобильные: ${fmtBytes(a.mobileBytes)} · Wi-Fi: ${fmtBytes(a.wifiBytes)}',
                                  style: const TextStyle(color: C.tx2, fontSize: 12),
                                ),
                              ),
                              if (a.isNetBlocked)
                                const Text(
                                  'Firewall: БЛОК',
                                  style: TextStyle(
                                    color: C.rd,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
