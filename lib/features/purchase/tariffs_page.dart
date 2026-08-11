import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// TOPOR VPN: in-app key renewal. Auth by the subscription URL (token);
/// payment happens on the FreeKassa/CryptoBot hosted page in the browser,
/// this screen only creates the order and polls its status.
class TariffsPage extends StatefulWidget {
  const TariffsPage({super.key, required this.subUrl});

  final String subUrl;

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _me;
  List<dynamic> _tariffs = const [];
  String? _tariff;
  String _method = 'fk_card';
  bool _busy = false;
  bool _waitingPayment = false;
  Timer? _poll;

  String get _base {
    final u = Uri.parse(widget.subUrl);
    final port = u.hasPort ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port/app/api/desktop';
  }

  int get _fkCardMin => (_me?['fk_card_min'] as num?)?.toInt() ?? 50;
  bool get _fkOn => _me?['freekassa'] == true;
  bool get _cryptoOn => _me?['crypto'] == true;

  Map<String, dynamic>? get _selected {
    for (final t in _tariffs) {
      if (t['id'] == _tariff) return Map<String, dynamic>.from(t as Map);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _dio.post('$_base/me', data: {'token': widget.subUrl});
      final me = Map<String, dynamic>.from(r.data as Map);
      final tariffs = (me['tariffs'] as List?) ?? const [];
      String? sel;
      for (final t in tariffs) {
        if (t['popular'] == true) sel = t['id'] as String?;
      }
      sel ??= tariffs.isNotEmpty ? tariffs.first['id'] as String? : null;
      if (!mounted) return;
      setState(() {
        _me = me;
        _tariffs = tariffs;
        _tariff = sel;
        if (!_fkOn && _cryptoOn) _method = 'crypto';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить тарифы. Проверьте, что подписка активна.';
      });
    }
  }

  bool get _cardAllowed {
    final rub = (_selected?['rub'] as num?)?.toInt() ?? 0;
    return _fkOn && rub >= _fkCardMin;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pay() async {
    final t = _tariff;
    if (t == null || _busy) return;
    // client-side gate for the FreeKassa card minimum
    if (_method == 'fk_card' && !_cardAllowed) {
      _snack('Для карты минимум $_fkCardMin₽ — выберите СБП, крипту или тариф подороже.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _dio.post('$_base/pay', data: {'token': widget.subUrl, 'tariff': t, 'method': _method});
      final data = Map<String, dynamic>.from(r.data as Map);
      final link = data['link'] as String?;
      final orderId = data['order_id'] as String?;
      if (link == null) throw StateError('no link');
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      _startPolling(orderId);
    } on DioException catch (e) {
      final err = (e.response?.data is Map) ? e.response!.data['error']?.toString() : null;
      _snack(switch (err) {
        'fk_off' => 'Оплата картой сейчас недоступна.',
        'fk_create' => 'Не удалось создать платёж. Попробуйте другой способ.',
        'crypto_off' => 'Крипто-оплата недоступна.',
        _ => 'Ошибка оплаты. Попробуйте ещё раз.',
      });
      setState(() => _busy = false);
    } catch (_) {
      _snack('Ошибка оплаты. Попробуйте ещё раз.');
      setState(() => _busy = false);
    }
  }

  void _startPolling(String? orderId) {
    if (orderId == null) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _waitingPayment = true);
    var tries = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (tm) async {
      tries++;
      try {
        final r = await _dio.post('$_base/order', data: {'token': widget.subUrl, 'order_id': orderId});
        if (r.data is Map && r.data['paid'] == true) {
          tm.cancel();
          if (mounted) _onPaid();
          return;
        }
      } catch (_) {}
      if (tries >= 60) {
        tm.cancel();
        if (mounted) setState(() { _busy = false; _waitingPayment = false; });
      }
    });
  }

  void _onPaid() {
    setState(() {
      _busy = false;
      _waitingPayment = false;
    });
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF32D583), size: 40),
        title: const Text('Оплачено!'),
        content: const Text('Подписка продлена. Дни добавятся автоматически — если не видно сразу, обновите профиль.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Продлить ключ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _waitingPayment
                  ? _WaitingView(onCancel: () {
                      _poll?.cancel();
                      setState(() { _busy = false; _waitingPayment = false; });
                    })
                  : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _statusCard(theme),
        const SizedBox(height: 16),
        Text('Тарифы', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        ..._tariffs.map((t) => _tariffCard(theme, Map<String, dynamic>.from(t as Map))),
        const SizedBox(height: 18),
        Text('Способ оплаты', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        _methods(theme),
        const SizedBox(height: 22),
        _payButton(theme),
        const SizedBox(height: 12),
        Text(
          'Оплата проходит на защищённой странице платёжной системы в браузере. '
          'Данные карты в приложение не вводятся.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _statusCard(ThemeData theme) {
    final active = _me?['active'] == true;
    final days = _me?['days_left'];
    final usedGb = _me?['used_gb'];
    final totalGb = _me?['total_gb'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (active ? const Color(0xFF32D583) : theme.colorScheme.error).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(active ? Icons.verified_rounded : Icons.error_outline_rounded,
                color: active ? const Color(0xFF32D583) : theme.colorScheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'Подписка активна' : 'Подписка неактивна',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  [
                    if (days != null) 'осталось $days дн.',
                    if (totalGb != null && totalGb != 0) 'трафик ${usedGb ?? 0} / $totalGb ГБ',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tariffCard(ThemeData theme, Map<String, dynamic> t) {
    final selected = t['id'] == _tariff;
    final rub = (t['rub'] as num?)?.toInt() ?? 0;
    final old = (t['old'] as num?)?.toInt() ?? 0;
    final popular = t['popular'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _tariff = t['id'] as String?),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${t['label']}', style: theme.textTheme.titleMedium),
                        if (popular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF7A3D), Color(0xFFFF4D6D)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('ХИТ',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    if (t['desc'] != null && '${t['desc']}'.isNotEmpty)
                      Text('${t['desc']}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFF7A3D), Color(0xFFFF4D6D)])
                        .createShader(r),
                    child: Text('$rub₽',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontFamily: 'Oswald', fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  if (old > 0)
                    Text('$old₽',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methods(ThemeData theme) {
    final items = <(String, String, IconData)>[
      if (_fkOn) ('fk_card', 'Карта', Icons.credit_card_rounded),
      if (_fkOn) ('fk_sbp', 'СБП', Icons.qr_code_rounded),
      if (_cryptoOn) ('crypto', 'Крипта', Icons.currency_bitcoin_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((m) {
        final sel = _method == m.$1;
        final disabled = m.$1 == 'fk_card' && !_cardAllowed;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : () => setState(() => _method = m.$1),
          child: Opacity(
            opacity: disabled ? 0.4 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  width: sel ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.$3, size: 18, color: sel ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(m.$2, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _payButton(ThemeData theme) {
    final rub = (_selected?['rub'] as num?)?.toInt() ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF7A3D), Color(0xFFFF4D6D)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFFF4D6D).withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : _pay,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('Оплатить $rub₽',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.onCancel});
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Ждём подтверждение оплаты…', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Завершите оплату в открывшемся браузере. Как только платёж пройдёт — подписка продлится автоматически.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: onCancel, child: const Text('Отмена')),
          ],
        ),
      ),
    );
  }
}
