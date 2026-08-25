import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'order_page.dart';
import 'orders_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const JablehEventsApp());
}

/* =========================================================
   تحميل ملف JSON
   ========================================================= */

class CatalogService {
  static Future<Map<String, dynamic>> loadCatalog() async {
    final jsonString = await rootBundle.loadString('assets/data/catalog.json');

    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
}

/* =========================================================
   قاعدة البيانات المحلية SQLite
   ========================================================= */

class LocalDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();

    final path = p.join(databasePath, 'jableh_events.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,

            customer_name TEXT NOT NULL,

            phone TEXT NOT NULL,

            event_type TEXT NOT NULL,

            event_date TEXT,

            guest_count INTEGER,

            budget TEXT,

            notes TEXT,

            selected_items TEXT NOT NULL,

            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<int> insertOrder(Map<String, dynamic> order) async {
    final db = await database;

    return await db.insert('orders', order);
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;

    return await db.query('orders', orderBy: 'id DESC');
  }
}

/* =========================================================
   التطبيق
   ========================================================= */

class JablehEventsApp extends StatelessWidget {
  const JablehEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'مناسبتك',

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: const Color(0xFF8E5B70),

        scaffoldBackgroundColor: const Color(0xFFFBF8FA),
      ),

      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

/* =========================================================
   الصفحة الرئيسية
   ========================================================= */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> catalogFuture;

  @override
  void initState() {
    super.initState();

    catalogFuture = CatalogService.loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: catalogFuture,

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'حدث خطأ في تحميل البيانات\n'
                '${snapshot.error}',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return MainScreen(catalog: snapshot.data!);
      },
    );
  }
}

/* =========================================================
   Main Screen
   ========================================================= */

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> catalog;

  const MainScreen({super.key, required this.catalog});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentTab = 0;

  final Set<String> selectedItems = {};

  List<Map<String, dynamic>> get categories {
    return (widget.catalog['categories'] as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get services {
    return (widget.catalog['services'] as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get packages {
    return (widget.catalog['packages'] as List).cast<Map<String, dynamic>>();
  }

  void toggleItem(String id) {
    setState(() {
      if (selectedItems.contains(id)) {
        selectedItems.remove(id);
      } else {
        selectedItems.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مناسبتك | تنظيم المناسبات'),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip: 'طلب المناسبة',

            icon: Badge(
              isLabelVisible: selectedItems.isNotEmpty,

              label: Text('${selectedItems.length}'),

              child: const Icon(Icons.shopping_bag_outlined),
            ),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderPage(
                    catalog: widget.catalog,
                    selectedItems: selectedItems,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: _buildBody(),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,

        onDestinationSelected: (index) {
          setState(() {
            currentTab = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),

          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'الباقات',
          ),

          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'الطلبات',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (currentTab == 0) {
      return _buildHome();
    }

    if (currentTab == 1) {
      return _buildPackages();
    }

    // ✅ صحيح
    return OrderPage(catalog: widget.catalog, selectedItems: selectedItems);
  }

  /* =======================================================
     Home
     ======================================================= */

  Widget _buildHome() {
    return ListView(
      padding: const EdgeInsets.all(18),

      children: [
        _buildHero(),

        const SizedBox(height: 25),

        const Text(
          'اختر نوع المناسبة',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          itemCount: categories.length,

          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 1.3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),

          itemBuilder: (context, index) {
            final category = categories[index];

            return Card(
              clipBehavior: Clip.antiAlias,
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),

              child: InkWell(
                borderRadius: BorderRadius.circular(18),

                onTap: () {
                  _showCategory(category['id'], category['name']);
                },

                child: Stack(
                  children: [
                    // صورة المناسبة
                    Positioned.fill(
                      child: Image.asset(
                        category['image'] ?? '',
                        fit: BoxFit.cover,

                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF3E8EE),
                            child: Icon(_getIcon(category['icon']), size: 50),
                          );
                        },
                      ),
                    ),

                    // طبقة شفافة فوق الصورة
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // النص والإيموجي
                    Positioned(
                      right: 12,
                      left: 12,
                      bottom: 12,

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,

                        children: [
                          Text(
                            category['emoji'] ?? '🎉',
                            style: const TextStyle(fontSize: 30),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            category['name'] ?? '',
                            textAlign: TextAlign.center,

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
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
        ),

        const SizedBox(height: 25),

        const Text(
          'الخدمات المتاحة',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        ...services.map((service) {
          final id = service['id'] as String;

          final selected = selectedItems.contains(id);
          return Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: CheckboxListTile(
              value: selected,

              onChanged: (_) {
                toggleItem(id);
              },

              contentPadding: const EdgeInsets.all(10),

              title: Row(
                children: [
                  Text(
                    service['emoji'] ?? '✨',
                    style: const TextStyle(fontSize: 25),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      service['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(service['description'] ?? ''),
              ),

              secondary: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  service['image'] ?? '',
                  width: 75,
                  height: 75,
                  fit: BoxFit.cover,

                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          service['emoji'] ?? '✨',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    );
                  },
                ),
              ),

              activeColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }),

        const SizedBox(height: 15),

        FilledButton.icon(
          onPressed: selectedItems.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderPage(
                        catalog: widget.catalog,
                        selectedItems: selectedItems,
                      ),
                    ),
                  );
                },

          icon: const Icon(Icons.send),

          label: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('متابعة وإرسال الطلب'),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,

          colors: [Color(0xFFEBD9E2), Color(0xFFF8EEF2)],
        ),
      ),

      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'أنت احتفل…\nونحن نهتم بالباقي.',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),

          SizedBox(height: 10),

          Text(
            'تنسيق وتنظيم المناسبات '
            'في جبلة من الفكرة '
            'حتى التنفيذ.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /* =======================================================
     Packages
     ======================================================= */

  Widget _buildPackages() {
    return ListView(
      padding: const EdgeInsets.all(18),

      children: [
        const Text(
          'الباقات الجاهزة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 15),

        ...packages.map((package) {
          return Card(
            margin: const EdgeInsets.only(bottom: 18),
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الباقة
                SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: Image.asset(
                    package['image'] ?? '',
                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF3E8EE),
                        child: Center(
                          child: Text(
                            package['emoji'] ?? '🎉',
                            style: const TextStyle(fontSize: 70),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // اسم الباقة + الإيموجي
                      Row(
                        children: [
                          Text(
                            package['emoji'] ?? '🎉',
                            style: const TextStyle(fontSize: 30),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              package['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // الوصف
                      Text(
                        package['description'] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // السعر
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            const Text('💰', style: TextStyle(fontSize: 18)),

                            const SizedBox(width: 6),

                            Text(
                              package['priceLabel'] ?? 'حسب الطلب',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'الخدمات الموجودة في الباقة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // الخدمات
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,

                        children: (package['services'] as List).map((
                          serviceId,
                        ) {
                          final service = services.firstWhere(
                            (x) => x['id'] == serviceId,
                          );

                          final isSelected = selectedItems.contains(serviceId);

                          return FilterChip(
                            selected: isSelected,

                            avatar: Text(service['emoji'] ?? '✨'),

                            label: Text(service['name'] ?? ''),

                            onSelected: (_) {
                              toggleItem(serviceId);
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // زر إضافة الباقة
                      SizedBox(
                        width: double.infinity,
                        height: 50,

                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              for (final id in package['services']) {
                                selectedItems.add(id);
                              }
                            });
                          },

                          icon: const Icon(Icons.add_circle_outline),

                          label: const Text(
                            'إضافة الباقة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /* =======================================================
     Category
     ======================================================= */

  void _showCategory(String categoryId, String title) {
    final categoryPackages = packages.where(
      (package) => package['categoryId'] == categoryId,
    );

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,

          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),

              child: ListView(
                shrinkWrap: true,

                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  if (categoryPackages.isEmpty)
                    const Text(
                      'لا توجد باقات جاهزة '
                      'لهذه المناسبة حالياً.',
                    ),

                  ...categoryPackages.map((package) {
                    return ListTile(
                      leading: const Icon(Icons.auto_awesome),

                      title: Text(package['name']),

                      subtitle: Text(package['description']),

                      onTap: () {
                        setState(() {
                          for (final id in package['services']) {
                            selectedItems.add(id);
                          }
                        });

                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String name) {
    const icons = {
      'favorite': Icons.favorite,
      'favorite_border': Icons.favorite_border,
      'school': Icons.school,
      'cake': Icons.cake,
      'child_friendly': Icons.child_friendly,
      'toys': Icons.toys,
      'card_giftcard': Icons.card_giftcard,
      'business': Icons.business,
      'home': Icons.home,
      'celebration': Icons.celebration,
    };

    return icons[name] ?? Icons.celebration;
  }
}
