import 'dart:convert';

import 'package:flutter/material.dart';

import 'main.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<Map<String, dynamic>>> ordersFuture;

  @override
  void initState() {
    super.initState();

    ordersFuture = LocalDatabase.getOrders();
  }

  void refresh() {
    setState(() {
      ordersFuture = LocalDatabase.getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الزبائن'),

        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ordersFuture,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(Icons.inbox_outlined, size: 60),

                  SizedBox(height: 15),

                  Text('لا توجد طلبات بعد', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),

            itemCount: orders.length,

            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),

                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),

                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),

                  leading: CircleAvatar(
                    radius: 27,
                    child: Text(
                      '${order['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  title: Row(
                    children: [
                      Text(
                        _eventEmoji(order['event_type']),
                        style: const TextStyle(fontSize: 23),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          order['customer_name'] ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),

                    child: Text(
                      '${order['event_type'] ?? 'مناسبة عامة'}'
                      '  •  '
                      '${order['phone'] ?? '-'}',
                    ),
                  ),

                  children: [
                    _infoRow('📅', 'التاريخ', order['event_date'] ?? '-'),

                    _infoRow(
                      '👥',
                      'عدد الأشخاص',
                      '${order['guest_count'] ?? '-'}',
                    ),

                    _infoRow('💰', 'الميزانية', order['budget'] ?? '-'),

                    _infoRow('📝', 'الملاحظات', order['notes'] ?? '-'),

                    _selectedItemsRow(order['selected_items']),

                    _infoRow('🕒', 'تاريخ التسجيل', order['created_at'] ?? '-'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _eventEmoji(String? eventType) {
    switch (eventType) {
      case 'عرس':
        return '💍';

      case 'خطوبة':
        return '💍';

      case 'تخرج':
        return '🎓';

      case 'عيد ميلاد':
        return '🎂';

      case 'استقبال مولود':
        return '👶';

      case 'حفلة أطفال':
        return '🧸';

      case 'مفاجأة':
        return '🎁';

      case 'ذكرى زواج':
        return '❤️';

      case 'Baby Shower':
        return '🍼';

      case 'شركة / افتتاح':
        return '🏢';

      case 'مناسبة منزلية':
        return '🏠';

      default:
        return '🎉';
    }
  }

  Widget _infoRow(String emoji, String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),

          const SizedBox(width: 10),

          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),

          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _selectedItemsRow(dynamic value) {
    List<dynamic> items = [];

    try {
      if (value != null && value.toString().isNotEmpty) {
        items = jsonDecode(value.toString());
      }
    } catch (_) {
      items = [];
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Text('🛒', style: TextStyle(fontSize: 20)),

              SizedBox(width: 10),

              Text(
                'الاختيارات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (items.isEmpty)
            const Text('-')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: items.map((item) {
                return Chip(
                  avatar: const Text('✓'),
                  label: Text(item['name'] ?? '-'),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return ListTile(
      dense: true,

      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

      subtitle: Text(value),
    );
  }
}
