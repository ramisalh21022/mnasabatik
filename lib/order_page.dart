import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';

import 'main.dart';

class OrderPage extends StatefulWidget {
  final Map<String, dynamic> catalog;

  final Set<String> selectedItems;

  const OrderPage({
    super.key,
    required this.catalog,
    required this.selectedItems,
  });

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final formKey = GlobalKey<FormState>();
  int? savedOrderId;
  bool isSendingWhatsApp = false;
  final customerName = TextEditingController();

  final phone = TextEditingController();

  final eventDate = TextEditingController();

  final guestCount = TextEditingController();

  final budget = TextEditingController();

  final notes = TextEditingController();

  String eventType = 'مناسبة عامة';

  List<Map<String, dynamic>> get selectedItems {
    final services = (widget.catalog['services'] as List)
        .cast<Map<String, dynamic>>();

    final packages = (widget.catalog['packages'] as List)
        .cast<Map<String, dynamic>>();

    final all = [...services, ...packages];

    return all.where((item) {
      return widget.selectedItems.contains(item['id']);
    }).toList();
  }

  String _buildWhatsAppMessage(int orderId) {
    final buffer = StringBuffer();

    buffer.writeln('🎉 *طلب جديد - مناسبتك*');
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('');

    buffer.writeln('📋 *رقم الطلب:* #$orderId');
    buffer.writeln('');

    buffer.writeln('👤 *اسم الزبون:*');
    buffer.writeln(customerName.text.trim());
    buffer.writeln('');

    buffer.writeln('📞 *رقم الهاتف:*');
    buffer.writeln(phone.text.trim());
    buffer.writeln('');

    buffer.writeln('🎉 *نوع المناسبة:*');
    buffer.writeln(eventType);
    buffer.writeln('');

    if (eventDate.text.trim().isNotEmpty) {
      buffer.writeln('📅 *تاريخ المناسبة:*');
      buffer.writeln(eventDate.text.trim());
      buffer.writeln('');
    }

    if (guestCount.text.trim().isNotEmpty) {
      buffer.writeln('👥 *عدد الأشخاص:*');
      buffer.writeln(guestCount.text.trim());
      buffer.writeln('');
    }

    if (budget.text.trim().isNotEmpty) {
      buffer.writeln('💰 *الميزانية التقريبية:*');
      buffer.writeln(budget.text.trim());
      buffer.writeln('');
    }

    // ============================================================
    // الاختيارات
    // ============================================================

    if (selectedItems.isNotEmpty) {
      buffer.writeln('🛒 *الاختيارات:*');

      for (final item in selectedItems) {
        final emoji = item['emoji'] ?? '✨';

        buffer.writeln('$emoji ${item['name']}');
      }

      buffer.writeln('');
    }

    // ============================================================
    // الملاحظات
    // ============================================================

    if (notes.text.trim().isNotEmpty) {
      buffer.writeln('📝 *الملاحظات:*');
      buffer.writeln(notes.text.trim());
      buffer.writeln('');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('');
    buffer.writeln('🏢 *مناسبتك - جبلة*');
    buffer.writeln('🎉 تنظيم وتنسيق المناسبات');

    return buffer.toString();
  }

  Future<bool> _sendWhatsAppMessage(String message) async {
    // الرقم السوري بدون الصفر الأول
    final phoneNumber = '963933210196';

    final encodedMessage = Uri.encodeComponent(message);

    final uri = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      return launched;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    customerName.dispose();
    phone.dispose();
    eventDate.dispose();
    guestCount.dispose();
    budget.dispose();
    notes.dispose();

    super.dispose();
  }

  Future<void> saveOrder() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final selectedJson = selectedItems.map((item) {
      return {'id': item['id'], 'name': item['name'], 'emoji': item['emoji']};
    }).toList();

    final order = {
      'customer_name': customerName.text.trim(),
      'phone': phone.text.trim(),
      'event_type': eventType,
      'event_date': eventDate.text.trim(),
      'guest_count': int.tryParse(guestCount.text.trim()),
      'budget': budget.text.trim(),
      'notes': notes.text.trim(),
      'selected_items': jsonEncode(selectedJson),
      'created_at': DateTime.now().toIso8601String(),
    };

    final orderId = await LocalDatabase.insertOrder(order);

    if (!mounted) {
      return;
    }

    setState(() {
      savedOrderId = orderId;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ تم حفظ الطلب رقم #$orderId')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب المناسبة')),

      body: Form(
        key: formKey,

        child: ListView(
          padding: const EdgeInsets.all(18),

          children: [
            // ==================================================
            // عنوان الاختيارات
            // ==================================================
            const Text(
              'اختيارات الزبون',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // لا توجد اختيارات
            // ==================================================
            if (selectedItems.isEmpty) const Text('لم يتم اختيار خدمات بعد.'),

            // ==================================================
            // العناصر المختارة
            // ==================================================
            ...selectedItems.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),

                clipBehavior: Clip.antiAlias,

                elevation: 2,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  // ----------------------------------------
                  // صورة الخدمة
                  // ----------------------------------------
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),

                    child: Image.asset(
                      item['image'] ?? '',

                      width: 60,

                      height: 60,

                      fit: BoxFit.cover,

                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,

                          height: 60,

                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8EE),

                            borderRadius: BorderRadius.circular(12),
                          ),

                          alignment: Alignment.center,

                          child: Text(
                            item['emoji'] ?? '✨',

                            style: const TextStyle(fontSize: 28),
                          ),
                        );
                      },
                    ),
                  ),

                  // ----------------------------------------
                  // الاسم
                  // ----------------------------------------
                  title: Row(
                    children: [
                      Text(
                        item['emoji'] ?? '✨',

                        style: const TextStyle(fontSize: 22),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          item['name'] ?? '',

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ----------------------------------------
                  // الوصف
                  // ----------------------------------------
                  subtitle: item['description'] != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 5),

                          child: Text(
                            item['description'],

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : null,

                  // ----------------------------------------
                  // علامة الاختيار
                  // ----------------------------------------
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            }),

            // ==================================================
            // فاصل
            // ==================================================
            const Divider(height: 30),

            // ==================================================
            // نوع المناسبة
            // ==================================================
            _eventType(),

            const SizedBox(height: 12),

            // ==================================================
            // اسم الزبون
            // ==================================================
            _field(
              controller: customerName,

              label: 'اسم الزبون',

              icon: Icons.person,

              required: true,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // الهاتف
            // ==================================================
            _field(
              controller: phone,

              label: 'رقم الهاتف',

              icon: Icons.phone,

              required: true,

              keyboard: TextInputType.phone,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // التاريخ
            // ==================================================
            _field(
              controller: eventDate,

              label: 'تاريخ المناسبة',

              icon: Icons.event,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // عدد الأشخاص
            // ==================================================
            _field(
              controller: guestCount,

              label: 'عدد الأشخاص',

              icon: Icons.groups,

              keyboard: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // الميزانية
            // ==================================================
            _field(
              controller: budget,

              label: 'الميزانية التقريبية',

              icon: Icons.payments,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // الملاحظات
            // ==================================================
            _field(
              controller: notes,

              label: 'ملاحظات وطلبات خاصة',

              icon: Icons.notes,

              maxLines: 5,
            ),

            const SizedBox(height: 20),

            // ==================================================
            // قبل الحفظ
            // ==================================================
            if (savedOrderId == null) ...[
              SizedBox(
                height: 55,
                child: FilledButton.icon(
                  onPressed: isSendingWhatsApp ? null : sendOrderToWhatsApp,
                  icon: isSendingWhatsApp
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat),
                  label: Text(
                    isSendingWhatsApp
                        ? 'جاري فتح WhatsApp...'
                        : 'إرسال الطلب عبر WhatsApp',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],

            // ==================================================
            // بعد الحفظ
            // ==================================================
            if (savedOrderId != null) ...[
              // ----------------------------------------------
              // رسالة نجاح الحفظ
              // ----------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),

                  color: Colors.green.withOpacity(0.10),

                  border: Border.all(color: Colors.green.withOpacity(0.30)),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,

                      color: Colors.green,

                      size: 28,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'تم حفظ الطلب بنجاح\n'
                        'رقم الطلب: #$savedOrderId',

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,

                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ----------------------------------------------
              // زر WhatsApp
              // ----------------------------------------------
              SizedBox(
                width: double.infinity,

                height: 55,

                child: FilledButton.icon(
                  onPressed: isSendingWhatsApp ? null : sendOrderToWhatsApp,

                  icon: isSendingWhatsApp
                      ? const SizedBox(
                          width: 20,

                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat),

                  label: Text(
                    isSendingWhatsApp
                        ? 'جاري فتح WhatsApp...'
                        : 'إرسال عبر WhatsApp',

                    style: const TextStyle(
                      fontSize: 17,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sendOrderToWhatsApp() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSendingWhatsApp = true;
    });

    final selectedText = selectedItems.isEmpty
        ? 'لم يتم اختيار خدمات'
        : selectedItems
              .map((item) {
                final emoji = item['emoji']?.toString() ?? '✨';
                final name = item['name']?.toString() ?? '';

                return '$emoji $name';
              })
              .join('\n');

    final message =
        '''
🌸 طلب جديد من "مناسبتك"

━━━━━━━━━━━━━━━━
👤 بيانات الزبون
━━━━━━━━━━━━━━━━

الاسم: ${customerName.text.trim()}
📞 الهاتف: ${phone.text.trim()}

━━━━━━━━━━━━━━━━
🎉 تفاصيل المناسبة
━━━━━━━━━━━━━━━━

نوع المناسبة: $eventType
📅 التاريخ: ${eventDate.text.trim().isEmpty ? 'غير محدد' : eventDate.text.trim()}
👥 عدد الأشخاص: ${guestCount.text.trim().isEmpty ? 'غير محدد' : guestCount.text.trim()}
💰 الميزانية: ${budget.text.trim().isEmpty ? 'غير محددة' : budget.text.trim()}

━━━━━━━━━━━━━━━━
✨ الاختيارات
━━━━━━━━━━━━━━━━

$selectedText

━━━━━━━━━━━━━━━━
📝 ملاحظات
━━━━━━━━━━━━━━━━

${notes.text.trim().isEmpty ? 'لا توجد ملاحظات' : notes.text.trim()}

━━━━━━━━━━━━━━━━

📍 مناسبتك
جبلة - سوريا

💬 يرجى التواصل مع الزبون لتأكيد التفاصيل والسعر.
''';

    final phoneNumber = '963933210196';

    final uri = Uri.parse(
      'https://wa.me/$phoneNumber'
      '?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) {
        return;
      }

      if (!launched) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('⚠️ تعذر فتح WhatsApp')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💬 تم فتح WhatsApp والرسالة جاهزة للإرسال'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ حدث خطأ أثناء فتح WhatsApp')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingWhatsApp = false;
        });
      }
    }
  }

  Widget _eventType() {
    const types = [
      'مناسبة عامة',
      'عرس',
      'خطوبة',
      'تخرج',
      'عيد ميلاد',
      'استقبال مولود',
      'حفلة أطفال',
      'مفاجأة',
      'ذكرى زواج',
      'Baby Shower',
      'شركة / افتتاح',
      'مناسبة منزلية',
    ];

    return DropdownButtonFormField<String>(
      value: eventType,

      decoration: const InputDecoration(
        labelText: 'نوع المناسبة',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.celebration),
      ),

      items: types.map((type) {
        return DropdownMenuItem<String>(value: type, child: Text(type));
      }).toList(),

      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          eventType = value;
        });
      },
    );
  }

  Widget _field({
    required TextEditingController controller,

    required String label,

    required IconData icon,

    bool required = false,

    TextInputType? keyboard,

    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,

      keyboardType: keyboard,

      maxLines: maxLines,

      decoration: InputDecoration(
        labelText: label,

        prefixIcon: Icon(icon),

        border: const OutlineInputBorder(),
      ),

      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }

              return null;
            }
          : null,
    );
  }
}
