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
  final ScrollController categoriesController = ScrollController();
  final ScrollController servicesController = ScrollController();
  @override
  void dispose() {
    categoriesController.dispose();
    servicesController.dispose();

    super.dispose();
  }

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
    final app = (widget.catalog['app'] as Map).cast<String, dynamic>();

    final categories = (widget.catalog['categories'] as List)
        .cast<Map<String, dynamic>>();

    final services = (widget.catalog['services'] as List)
        .cast<Map<String, dynamic>>();

    final packages = (widget.catalog['packages'] as List)
        .cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HERO
          // ============================================================
          Center(child: buildLogo(app)),

          const SizedBox(height: 22),
          _buildHero(app),

          const SizedBox(height: 22),

          // ============================================================
          // غلاف المكتب
          // ============================================================
          _buildCover(app),

          const SizedBox(height: 28),

          // ============================================================
          // المناسبات
          // ============================================================
          _sectionTitle(
            emoji: '🎉',
            title: 'اختر مناسبتك',
            subtitle: 'نساعدك في تنظيم أجمل تفاصيل مناسبتك',
          ),

          const SizedBox(height: 14),

          Scrollbar(
            controller: categoriesController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,

            child: SizedBox(
              height: 230,

              child: ListView.separated(
                controller: categoriesController,

                scrollDirection: Axis.horizontal,

                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 14),

                itemCount: categories.length,

                separatorBuilder: (_, __) {
                  return const SizedBox(width: 12);
                },

                itemBuilder: (context, index) {
                  final category = categories[index];

                  return _buildCategoryCard(category);
                },
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ============================================================
          // الخدمات
          // ============================================================
          // ============================================================
          // الخدمات
          // ============================================================
          _sectionTitle(
            emoji: '✨',
            title: 'خدماتنا',
            subtitle: 'كل ما تحتاجه مناسبتك في مكان واحد',
          ),

          const SizedBox(height: 14),

          Scrollbar(
            controller: servicesController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,

            child: SizedBox(
              height: 200,

              child: ListView.separated(
                controller: servicesController,

                scrollDirection: Axis.horizontal,

                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 14),

                itemCount: services.length,

                separatorBuilder: (_, __) {
                  return const SizedBox(width: 12);
                },

                itemBuilder: (context, index) {
                  final service = services[index];

                  return _buildServiceCard(service);
                },
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ============================================================
          // الباقات
          // ============================================================
          _sectionTitle(
            emoji: '👑',
            title: 'باقاتنا',
            subtitle: 'اختر الباقة المناسبة أو صمم باقتك بنفسك',
          ),

          const SizedBox(height: 14),

          ...packages.map((package) {
            return _buildHomePackageCard(package, services);
          }),

          const SizedBox(height: 20),

          // ============================================================
          // دعوة للطلب
          // ============================================================
          _buildRequestBanner(app),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,

                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return SizedBox(
      width: 175,

      child: Card(
        margin: EdgeInsets.zero,

        clipBehavior: Clip.antiAlias,

        elevation: 3,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        child: InkWell(
          onTap: () {
            _showCategory(category['id'], category['name']);
          },

          child: Stack(
            fit: StackFit.expand,

            children: [
              Image.asset(
                category['image'] ?? '',
                fit: BoxFit.cover,

                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,

                    child: Center(
                      child: Text(
                        category['emoji'] ?? '🎉',
                        style: const TextStyle(fontSize: 55),
                      ),
                    ),
                  );
                },
              ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,

                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.82),
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 12,
                left: 12,
                bottom: 12,

                child: Column(
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
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return SizedBox(
      width: 155,

      child: Card(
        margin: EdgeInsets.zero,

        clipBehavior: Clip.antiAlias,

        elevation: 2,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

        child: InkWell(
          onTap: () {
            toggleItem(service['id']);
          },

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              SizedBox(
                height: 100,
                width: double.infinity,

                child: Image.asset(
                  service['image'] ?? '',
                  fit: BoxFit.cover,

                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,

                      child: Center(
                        child: Text(
                          service['emoji'] ?? '✨',
                          style: const TextStyle(fontSize: 45),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),

                child: Row(
                  children: [
                    Text(
                      service['emoji'] ?? '✨',
                      style: const TextStyle(fontSize: 21),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        service['name'] ?? '',

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePackageCard(
    Map<String, dynamic> package,
    List<Map<String, dynamic>> services,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),

      clipBehavior: Clip.antiAlias,

      elevation: 3,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            height: 180,
            width: double.infinity,

            child: Image.asset(
              package['image'] ?? '',
              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,

                  child: Center(
                    child: Text(
                      package['emoji'] ?? '👑',
                      style: const TextStyle(fontSize: 65),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Text(
                      package['emoji'] ?? '👑',

                      style: const TextStyle(fontSize: 29),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        package['name'] ?? '',

                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(package['description'] ?? ''),

                const SizedBox(height: 10),

                Text(
                  '💰 ${package['priceLabel'] ?? 'حسب الطلب'}',

                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,

                  children: (package['services'] as List).map((serviceId) {
                    final service = services.firstWhere(
                      (x) => x['id'] == serviceId,
                    );

                    return Chip(
                      avatar: Text(service['emoji'] ?? '✨'),

                      label: Text(service['name'] ?? ''),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,

                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final id in package['services']) {
                          selectedItems.add(id);
                        }
                      });
                    },

                    icon: const Icon(Icons.add_circle_outline),

                    label: const Text('إضافة الباقة'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBanner(Map<String, dynamic> app) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),

      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 42)),

          const SizedBox(height: 8),

          const Text(
            'جاهز نبدأ بتجهيز مناسبتك؟',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'اختر الخدمات التي تريدها ثم أرسل طلبك للمكتب.',

            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),

          const SizedBox(height: 15),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),

            onPressed: () {
              setState(() {
                currentTab = 2;
              });
            },

            icon: const Icon(Icons.arrow_back),

            label: const Text('ابدأ طلبك الآن'),
          ),
        ],
      ),
    );
  }

  Widget buildLogo(Map<String, dynamic> app) {
    final logo = app['logo']?.toString() ?? '';

    return Center(
      child: Image.asset(
        logo,
        width: 180,
        height: 180,
        fit: BoxFit.contain,

        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Logo error: $error');
          debugPrint('❌ Logo path: $logo');

          return const Icon(Icons.celebration, size: 100);
        },
      ),
    );
  }

  Widget _buildCover(Map<String, dynamic> app) {
    final image = app['coverImage']?.toString() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),

      child: SizedBox(
        height: 145,
        width: double.infinity,

        child: Stack(
          fit: StackFit.expand,

          children: [
            Image.asset(
              image,
              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,

                  child: const Center(
                    child: Text(
                      '✨ مناسبتك ✨',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,

                  colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                ),
              ),
            ),

            Positioned(
              right: 18,
              bottom: 14,

              child: Text(
                app['name'] ?? 'مناسبتك',

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> app) {
    final image = app['heroImage']?.toString() ?? '';

    return Container(
      height: 270,
      width: double.infinity,

      clipBehavior: Clip.antiAlias,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Stack(
        fit: StackFit.expand,

        children: [
          Image.asset(
            image,
            fit: BoxFit.cover,

            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.primary,
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 70)),
                ),
              );
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

                colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
              ),
            ),
          ),

          Positioned(
            right: 20,
            left: 20,
            bottom: 20,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  app['welcomeTitle'] ?? 'خلّي مناسبتك علينا 🎉',

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  app['welcomeDescription'] ??
                      'من أول فكرة حتى آخر تفصيل، نحن معك.',

                  maxLines: 3,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
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
