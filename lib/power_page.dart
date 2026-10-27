import 'package:flutter/material.dart';
import 'app_state.dart';
import 'theme.dart';

class PowerPage extends StatelessWidget {
  const PowerPage({super.key});

  Widget _kvRow(String label, String val, {Color valColor = C.tx}) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: C.tx2, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(
            val,
            style: TextStyle(
              color: valColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final p = appState.power;
        final lastOff = p.history.isNotEmpty ? p.history.first : null;

        return SafeArea(
          child: RefreshIndicator(
            color: C.jd,
            backgroundColor: C.s1,
            onRefresh: () => appState.refreshData(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Text(
                  'Питание и непрерывный таймер',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.tx),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Таймер сохраняется в энергонезависимой памяти (/data/local/tmp) и продолжает отсчёт даже после полной разрядки батареи',
                  style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.jd),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer_rounded, color: C.jd, size: 19),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Непрерывный накопительный таймер работы',
                              style: TextStyle(
                                color: C.tx2,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmtDurationMs(appState.liveContinuousActiveMs, showSeconds: true),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: C.jd,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Текущая сессия после включения: ${fmtDurationMs(appState.liveCurrentUptimeMs, showSeconds: true)}',
                        style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: appState.toggleExtendedPower,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.power_settings_new_rounded, color: C.pk, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Детали включения и выключения',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                              ),
                              Text(
                                'Батарея: ${p.batteryPct}% · Записей в журнале: ${p.history.length}',
                                style: const TextStyle(color: C.tx2, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          appState.showExtendedPowerDetails ? 'Скрыть' : 'Показать',
                          style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          appState.showExtendedPowerDetails
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: C.tx2,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (appState.showExtendedPowerDetails) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Состояние питания устройства',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx),
                        ),
                        _kvRow('Телефон включён с', fmtDateTime(p.bootTimeTs), valColor: C.jd),
                        _kvRow('Работает без перезагрузки', fmtDurationMs(appState.liveCurrentUptimeMs)),
                        _kvRow('Накоплено до последней перезагрузки', fmtDurationMs(p.accumulatedActiveMs)),
                        _kvRow('Суммарное время в выключенном состоянии', fmtDurationMs(p.accumulatedOffMs), valColor: C.gd),
                        _kvRow('Последний контрольный пульс', fmtDateTime(p.lastHeartbeatTs)),
                        _kvRow(
                          'Уровень заряда',
                          '${p.batteryPct}% (${p.isCharging ? "Заряжается" : "От батареи"})',
                        ),
                        if (lastOff != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: C.line, height: 1),
                          ),
                          const Text(
                            'Последнее отключение / разрядка телефона',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.pk),
                          ),
                          _kvRow('Выключился / сел', fmtDateTime(lastOff.offFromTs)),
                          _kvRow('Включился снова', fmtDateTime(lastOff.onAtTs)),
                          _kvRow('Сколько был выключен', fmtDurationMs(lastOff.offDurationMs), valColor: C.gd),
                        ],
                      ],
                    ),
                  ),
                ],
                const SectionHeader('Журнал выключений и перезагрузок', Icons.history_toggle_off_rounded),
                if (p.history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Фоновый сторожевой сервис записывает пульс каждую минуту. После следующего выключения или разрядки телефона здесь появится точное время отключения и простоев.',
                      style: TextStyle(color: C.tx2, fontSize: 13, height: 1.4),
                    ),
                  )
                else
                  for (final ev in p.history)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.s1,
                        border: Border.all(color: C.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.power_off_rounded, size: 16, color: C.pk),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Был выключен: ${fmtDurationMs(ev.offDurationMs)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx),
                                ),
                              ),
                              if (ev.batteryAtOff >= 0)
                                Text(
                                  'Заряд: ${ev.batteryAtOff}%',
                                  style: const TextStyle(color: C.tx2, fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'С ${fmtDateTime(ev.offFromTs)} по ${fmtDateTime(ev.onAtTs)}',
                            style: const TextStyle(color: C.tx2, fontSize: 12.5),
                          ),
                          if (ev.prevActiveDurationMs > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Проработал до выключения: ${fmtDurationMs(ev.prevActiveDurationMs)}',
                                style: const TextStyle(color: C.jd, fontSize: 12),
                              ),
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
