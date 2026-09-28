import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../routes/app_router.dart';
import '../../theme/app_theme.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('mn');
    const balance = 3400.0; // TODO: bind to user state.

    final history = [
      _Tx(kind: _TxKind.reward, title: 'MobiCom 5G', amount: 700, when: '10 мин'),
      _Tx(kind: _TxKind.reward, title: 'Golomt Bank', amount: 500, when: '2 цаг'),
      _Tx(kind: _TxKind.reward, title: 'UniTel', amount: 600, when: 'Өчигдөр'),
      _Tx(kind: _TxKind.payout, title: 'Данс руу татсан', amount: -2000, when: '3 хоног'),
      _Tx(kind: _TxKind.reward, title: 'Khan Bank', amount: 700, when: '5 хоног'),
    ];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFCE00), Color(0xFFE0A800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Одоогийн үлдэгдэл',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${money.format(balance.toInt())} ₮',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => context.push(Routes.payout),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Мөнгө татах'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Гүйлгээний түүх',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _TxTile(tx: history[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

enum _TxKind { reward, payout }

class _Tx {
  final _TxKind kind;
  final String title;
  final double amount; // positive for reward, negative for payout
  final String when;
  const _Tx({
    required this.kind,
    required this.title,
    required this.amount,
    required this.when,
  });
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final _Tx tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final money = NumberFormat.decimalPattern('mn');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (positive ? AppColors.success : AppColors.danger)
            .withOpacity(0.14),
        child: Icon(
          tx.kind == _TxKind.reward
              ? Icons.play_arrow_rounded
              : Icons.arrow_upward_rounded,
          color: positive ? AppColors.success : AppColors.danger,
        ),
      ),
      title: Text(
        tx.title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        tx.when,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        '${positive ? '+' : '-'} ${money.format(tx.amount.abs().toInt())} ₮',
        style: TextStyle(
          color: positive ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
