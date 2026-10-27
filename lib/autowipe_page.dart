import 'package:flutter/material.dart';
import 'app_state.dart';
import 'file_explorer_sheet.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class AutoWipePage extends StatefulWidget {
  const AutoWipePage({super.key});

  @override
  State<AutoWipePage> createState() => _AutoWipePageState();
}

class _AutoWipePageState extends State<AutoWipePage> {
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showPickAllAppsSheet() async {
    final installed = await NativeBridge.listAllInstalledApps();
    if (!mounted) return;
    String q = '';
    String filterTab = 'all'; // 'all', 'user', 'system'
    String actionMode = 'delete'; // 'delete' or 'freeze'

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final list = installed.where((a) {
            if (filterTab == 'user' && a.isSystem) return false;
            if (filterTab == 'system' && !a.isSystem) return false;
            if (q.trim().isEmpty) return true;
            final qq = q.trim().toLowerCase();
            return a.appName.toLowerCase().contains(qq) ||
                a.packageName.toLowerCase().contains(qq);
          }).toList()
            ..sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.84),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apps_rounded, color: C.pk, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Все приложения (${list.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: C.tx2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          PeriodPill('Все (${installed.length})', filterTab == 'all',
                              () => setS(() => filterTab = 'all')),
                          PeriodPill('Пользовательские', filterTab == 'user',
                              () => setS(() => filterTab = 'user')),
                          PeriodPill('Системные', filterTab == 'system',
                              () => setS(() => filterTab = 'system')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Действие по таймеру:',
                          style: TextStyle(color: C.tx2, fontSize: 12.5),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Удалить (uninstall)'),
                          selected: actionMode == 'delete',
                          selectedColor: C.pk,
                          labelStyle: TextStyle(
                            color: actionMode == 'delete' ? C.onPk : C.tx,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setS(() => actionMode = 'delete'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Заморозить (pm hide)'),
                          selected: actionMode == 'freeze',
                          selectedColor: C.jd,
                          labelStyle: TextStyle(
                            color: actionMode == 'freeze' ? C.bg : C.tx,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setS(() => actionMode = 'freeze'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setS(() => q = v),
                      style: const TextStyle(color: C.tx),
                      decoration: InputDecoration(
                        hintText: 'Поиск по названию или пакету…',
                        hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.tx2),
                        filled: true,
                        fillColor: C.s2,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final a = list[i];
                          final already = appState.wipeTargets.any(
                              (x) => x.kind == 'app' && x.target == a.packageName);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              a.isSystem ? Icons.settings_applications_rounded : Icons.android_rounded,
                              color: a.isSystem ? C.tx2 : C.pk,
                            ),
                            title: Text(
                              a.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${a.packageName}${a.isSystem ? " · системное" : ""}${a.isFrozen ? " · заморожено" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.tx2, fontSize: 11.5),
                            ),
                            trailing: IconButton(
                              onPressed: () {
                                if (already) {
                                  appState.removeWipeTarget('app:${a.packageName}');
                                } else {
                                  appState.addWipeTarget(
                                    WipeTargetItem(
                                      id: 'app:${a.packageName}',
                                      kind: 'app',
                                      mode: actionMode,
                                      label: a.appName,
                                      target: a.packageName,
                                    ),
                                  );
                                }
                                setS(() {});
                              },
                              icon: Icon(
                                already
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: already ? C.jd : C.pk,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFileExplorer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FileExplorerSheet(
        onSelectPath: (path, label, isDir) {
          appState.addWipeTarget(
            WipeTargetItem(
              id: 'file:$path',
              kind: 'file',
              mode: 'delete',
              label: label,
              target: path,
            ),
          );
          _snack('Добавлено в автоудаление: $label');
        },
      ),
    );
  }

  Future<void> _showPinCheckDialog() async {
    final ctl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.s1,
        title: const Text('Подтверждение владельца'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Введите ваш обычный PIN (${appState.ownerPin}) для сброса таймера или Код принуждения (${appState.duressPin}) для мгновенного скрытого удаления выбранных целей:',
              style: const TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: C.tx, fontSize: 16, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'PIN-код',
                hintStyle: const TextStyle(color: C.tx2, letterSpacing: 0),
                filled: true,
                fillColor: C.s2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctl.text.trim();
              Navigator.of(ctx).pop();
              final isDuress = await appState.verifyPinOrTriggerDuress(text);
              if (isDuress) {
                _snack('Активирован протокол безопасности: цели очищены');
              } else {
                _snack('Подтверждено! Таймер сброшен на ${appState.wipeIntervalHours} ч.');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: C.jd, foregroundColor: C.bg),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  Future<void> _configurePinsDialog() async {
    final ownerCtl = TextEditingController(text: appState.ownerPin);
    final duressCtl = TextEditingController(text: appState.duressPin);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.s1,
        title: const Text('Настройка PIN и Кода принуждения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ownerCtl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: C.tx),
              decoration: const InputDecoration(
                labelText: 'Обычный PIN владельца (сброс таймера)',
                labelStyle: TextStyle(color: C.tx2),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: duressCtl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: C.tx),
              decoration: const InputDecoration(
                labelText: 'Код принуждения (Duress PIN — мгновенное удаление)',
                labelStyle: TextStyle(color: C.pk),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await appState.updateSecurityPins(
                owner: ownerCtl.text,
                duress: duressCtl.text,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              _snack('PIN-коды сохранены');
            },
            style: FilledButton.styleFrom(backgroundColor: C.jd, foregroundColor: C.bg),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExecuteNow() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.s1,
        title: const Text('Выполнить автоудаление сейчас?'),
        content: Text(
          'Будут немедленно обработаны выбранные цели (${appState.wipeTargets.length} шт.) с использованием Root-прав.',
          style: const TextStyle(color: C.tx2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: C.rd, foregroundColor: C.tx),
            child: const Text('Выполнить'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await appState.triggerWipeNow();
      _snack('Задачи автоудаления выполнены');
    }
  }

  @override
  Widget build(BuildContext context) {
    const intervals = <int>[1, 6, 12, 24, 48, 72];
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final remMs = appState.remainingUntilWipeMs;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Умное автоудаление (Root)',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.tx),
                    ),
                  ),
                  IconButton(
                    onPressed: _configurePinsDialog,
                    icon: const Icon(Icons.password_rounded, color: C.jd),
                    tooltip: 'Настроить PIN и Код принуждения',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Автоматическое удаление или заморозка выбранных приложений и файлов при отсутствии ежедневного подтверждения владельца.',
                style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: appState.wipeEnabled ? C.pk : C.line),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: C.pk,
                      title: const Text(
                        'Активировать таймер автоудаления',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.tx),
                      ),
                      subtitle: Text(
                        appState.wipeEnabled
                            ? 'Активно · Обычный PIN: ${appState.ownerPin} · Duress PIN: ${appState.duressPin}'
                            : 'Выключено · Ничего не удаляется без вашего разрешения',
                        style: const TextStyle(color: C.tx2, fontSize: 12),
                      ),
                      value: appState.wipeEnabled,
                      onChanged: (v) => appState.setWipeEnabled(v),
                    ),
                    const Divider(color: C.line, height: 16),
                    Row(
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded, color: C.gd, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Осталось до автоудаления:',
                            style: TextStyle(color: C.tx2, fontSize: 13),
                          ),
                        ),
                        Text(
                          appState.wipeEnabled
                              ? fmtDurationMs(remMs, showSeconds: true)
                              : 'На паузе',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: appState.wipeEnabled ? C.gd : C.tx2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Последнее подтверждение: ${fmtDateTime(appState.lastOwnerConfirmTs)}',
                      style: const TextStyle(color: C.tx2, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await appState.confirmOwnerPresent();
                              _snack('Подтверждено! Таймер сброшен на ${appState.wipeIntervalHours} ч.');
                            },
                            icon: const Icon(Icons.verified_rounded, size: 19),
                            label: const Text(
                              'Подтвердить в 1 клик',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: C.jd,
                              foregroundColor: C.bg,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showPinCheckDialog,
                          icon: const Icon(Icons.dialpad_rounded, size: 18, color: C.pk),
                          label: const Text(
                            'PIN / Duress',
                            style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: C.line),
                            backgroundColor: C.s2,
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Интервал подтверждения владельца', Icons.update_rounded),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final h in intervals)
                      PeriodPill(
                        h == 24 ? '24 ч (Каждый день)' : '$h ч',
                        appState.wipeIntervalHours == h,
                        () => appState.setWipeIntervalHours(h),
                      ),
                  ],
                ),
              ),
              const SectionHeader('Выбор приложений и файлов для автоудаления', Icons.delete_sweep_rounded),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showPickAllAppsSheet,
                      icon: const Icon(Icons.apps_rounded, size: 18, color: C.pk),
                      label: const Text(
                        'Все приложения',
                        style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.line),
                        backgroundColor: C.s1,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openFileExplorer,
                      icon: const Icon(Icons.folder_open_rounded, size: 18, color: C.jd),
                      label: const Text(
                        'Файловый менеджер',
                        style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.line),
                        backgroundColor: C.s1,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (appState.wipeTargets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Цели ещё не выбраны. Нажмите «Все приложения» (чтобы выбрать любые установленные программы) или «Файловый менеджер» (чтобы выбрать любые файлы или папки).',
                    style: TextStyle(color: C.tx2, fontSize: 13, height: 1.35),
                  ),
                )
              else ...[
                for (final t in appState.wipeTargets)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          t.kind == 'app' ? Icons.android_rounded : Icons.folder_zip_rounded,
                          color: t.kind == 'app' ? C.pk : C.jd,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.label,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Text(
                                '${t.kind == "app" ? (t.mode == "freeze" ? "Заморозка (pm disable-user)" : "Удаление (pm uninstall)") : "Удаление файла/папки (rm -rf)"} · ${t.target}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: C.tx2, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => appState.removeWipeTarget(t.id),
                          icon: const Icon(Icons.close_rounded, color: C.tx2, size: 18),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmExecuteNow,
                    icon: const Icon(Icons.warning_amber_rounded, color: C.rd, size: 18),
                    label: const Text(
                      'Проверить выполнение выбранных целей сейчас',
                      style: TextStyle(color: C.rd, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: C.rd),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
              if (appState.wipeLogs.isNotEmpty) ...[
                const SectionHeader('Журнал срабатываний защиты', Icons.receipt_long_rounded),
                for (final log in appState.wipeLogs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          log.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: log.ok ? C.jd : C.rd,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.target,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              Text(
                                '${fmtDateTime(log.ts)} · ${log.details}',
                                style: const TextStyle(color: C.tx2, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
