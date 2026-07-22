import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/widgets/customer_scaffold.dart';

const _foodBase = '/api/v1/commerce/food';

class FoodCartLine {
  FoodCartLine(this.item,
      {this.quantity = 1,
      this.addonIds = const [],
      this.customizations = const {},
      required this.unitPrice});
  final Map<String, dynamic> item;
  final List<String> addonIds;
  final Map<String, dynamic> customizations;
  final double unitPrice;
  int quantity;
}

class FoodCart extends ChangeNotifier {
  String? restaurantId;
  final Map<String, FoodCartLine> lines = {};

  void add(String restaurant, Map<String, dynamic> item,
      {List<String> addonIds = const [],
      Map<String, dynamic> customizations = const {}}) {
    if (restaurantId != null && restaurantId != restaurant) lines.clear();
    restaurantId = restaurant;
    final id = '${item['id']}';
    var unitPrice =
        ((item['discountedPrice'] ?? item['price'] ?? 0) as num).toDouble();
    for (final raw in apiItems(item['addons'])) {
      if (addonIds.contains('${raw['id'] ?? raw['name']}')) {
        unitPrice += (raw['price'] as num? ?? 0).toDouble();
      }
    }
    for (final raw in apiItems(item['customizations'])) {
      final key = '${raw['id'] ?? raw['name']}';
      final chosen = customizations[key];
      for (final option in apiItems(raw['options'])) {
        if ('${option['id'] ?? option['name']}' == '$chosen') {
          unitPrice += (option['price'] as num? ?? 0).toDouble();
        }
      }
    }
    lines.update(id, (line) {
      line.quantity++;
      return line;
    },
        ifAbsent: () => FoodCartLine(item,
            addonIds: addonIds,
            customizations: customizations,
            unitPrice: unitPrice));
    notifyListeners();
  }

  void setQuantity(String id, int value) {
    if (value <= 0) {
      lines.remove(id);
    } else {
      lines[id]?.quantity = value;
    }
    if (lines.isEmpty) restaurantId = null;
    notifyListeners();
  }

  void clear() {
    lines.clear();
    restaurantId = null;
    notifyListeners();
  }

  double get subtotal => lines.values.fold(
        0,
        (sum, line) => sum + line.unitPrice * line.quantity,
      );
}

final foodCart = FoodCart();

class FoodRestaurantsPage extends StatefulWidget {
  const FoodRestaurantsPage({super.key});
  @override
  State<FoodRestaurantsPage> createState() => _FoodRestaurantsPageState();
}

class _FoodRestaurantsPageState extends State<FoodRestaurantsPage> {
  final api = ApiClient();
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      api.getList('$_foodBase/restaurants', query: {'search': search.text});

  @override
  Widget build(BuildContext context) => CustomerScaffold(
        title: 'Food delivery',
        actions: [
          IconButton(
            onPressed: () => context.push('/app/food/orders'),
            icon: const Icon(Icons.receipt_long),
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: search,
                onSubmitted: (_) => setState(() => data = _load()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search restaurants or cuisines',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Error('${snapshot.error}',
                        () => setState(() => data = _load()));
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const Center(
                        child: Text('No restaurants accepting orders'));
                  }
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final cuisines =
                          (row['cuisine'] as List?)?.join(', ') ?? '';
                      return Card(
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: ListTile(
                          onTap: () => context
                              .push('/app/food/restaurants/${row['id']}'),
                          leading:
                              const CircleAvatar(child: Icon(Icons.restaurant)),
                          title: Text('${row['name']}'),
                          subtitle: Text(
                              '$cuisines\n${row['rating'] ?? 0} ★ • ${row['avgPrepMinutes'] ?? 30} min'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class FoodMenuPage extends StatefulWidget {
  const FoodMenuPage({required this.restaurantId, super.key});
  final String restaurantId;
  @override
  State<FoodMenuPage> createState() => _FoodMenuPageState();
}

class _FoodMenuPageState extends State<FoodMenuPage> {
  final api = ApiClient();
  late Future<Map<String, dynamic>> data;

  Future<Map<String, dynamic>> _load() async {
    final values = await Future.wait([
      api.getJson('$_foodBase/restaurants/${widget.restaurantId}/menu'),
      api.getList('$_foodBase/restaurants/${widget.restaurantId}/combos')
    ]);
    return {...values[0] as Map<String, dynamic>, 'combos': values[1]};
  }

  Future<void> _configureAndAdd(Map<String, dynamic> item) async {
    final addons = apiItems(item['addons']),
        groups = apiItems(item['customizations']);
    final selectedAddons = <String>{};
    final selected = <String, dynamic>{};
    if (addons.isEmpty && groups.isEmpty) {
      foodCart.add(widget.restaurantId, item);
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: Text('Customise ${item['name']}'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final addon in addons)
                        CheckboxListTile(
                            value: selectedAddons
                                .contains('${addon['id'] ?? addon['name']}'),
                            title: Text(
                                '${addon['name']} (+₹${addon['price'] ?? 0})'),
                            onChanged: (value) => setLocal(() {
                                  final id = '${addon['id'] ?? addon['name']}';
                                  value == true
                                      ? selectedAddons.add(id)
                                      : selectedAddons.remove(id);
                                })),
                      for (final group in groups)
                        DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                                labelText:
                                    '${group['name'] ?? group['id']}${group['required'] == true ? ' *' : ''}'),
                            items: apiItems(group['options'])
                                .map((option) => DropdownMenuItem(
                                    value: '${option['id'] ?? option['name']}',
                                    child: Text(
                                        '${option['name'] ?? option['id']} (+₹${option['price'] ?? 0})')))
                                .toList(),
                            onChanged: (value) =>
                                selected['${group['id'] ?? group['name']}'] =
                                    value),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            final missing = groups.any((group) =>
                                group['required'] == true &&
                                selected['${group['id'] ?? group['name']}'] ==
                                    null);
                            if (!missing) Navigator.pop(context, true);
                          },
                          child: const Text('Add'))
                    ])));
    if (confirmed == true) {
      foodCart.add(widget.restaurantId, item,
          addonIds: selectedAddons.toList(), customizations: selected);
    }
  }

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  @override
  Widget build(BuildContext context) => CustomerScaffold(
        title: 'Restaurant menu',
        showBack: true,
        actions: [
          AnimatedBuilder(
            animation: foodCart,
            builder: (_, __) => IconButton(
              onPressed: foodCart.lines.isEmpty
                  ? null
                  : () => context.push('/app/food/checkout'),
              icon: Badge(
                label: Text('${foodCart.lines.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
            ),
          ),
        ],
        child: FutureBuilder<Map<String, dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Error(
                  '${snapshot.error}',
                  () => setState(() {
                        data = _load();
                      }));
            }
            final payload = snapshot.data ?? {};
            final restaurant = apiObject(payload['restaurant']) ?? {};
            final items = [
              ...apiItems(payload['items']),
              ...apiItems(payload['combos']).map((combo) => {
                    ...combo,
                    'isCombo': true,
                    'inStock': combo['in_stock'],
                    'imageUrl': combo['image_url'],
                    'addons': const [],
                    'customizations': const []
                  })
            ];
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('${restaurant['name'] ?? ''}',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(
                    '${restaurant['description'] ?? restaurant['tagline'] ?? ''}'),
                const Divider(),
                for (final item in items)
                  Card(
                    child: ListTile(
                      title: Text('${item['name']}'),
                      subtitle: Text(
                          '${item['description'] ?? ''}\n₹${item['discountedPrice'] ?? item['price']}'),
                      isThreeLine: true,
                      trailing: item['inStock'] == false
                          ? TextButton(
                              onPressed: () async {
                                await api.postJson(
                                  '$_foodBase/menu/items/${item['id']}/back-in-stock',
                                  auth: true,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('We will notify you')),
                                );
                              },
                              child: const Text('Notify'),
                            )
                          : FilledButton(
                              onPressed: () => _configureAndAdd(item),
                              child: const Text('Add'),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class FoodCheckoutPage extends StatefulWidget {
  const FoodCheckoutPage({super.key});
  @override
  State<FoodCheckoutPage> createState() => _FoodCheckoutPageState();
}

class _FoodCheckoutPageState extends State<FoodCheckoutPage> {
  final api = ApiClient();
  final address = TextEditingController();
  final coupon = TextEditingController();
  String method = 'cod';
  DateTime? scheduled;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (foodCart.lines.isEmpty) return;
    setState(() => busy = true);
    try {
      final order = await api.postJson(
        '$_foodBase/orders',
        auth: true,
        body: {
          'restaurantId': foodCart.restaurantId,
          'items': [
            for (final line in foodCart.lines.values)
              {
                if (line.item['isCombo'] == true)
                  'comboId': line.item['id']
                else
                  'menuItemId': line.item['id'],
                'quantity': line.quantity,
                if (line.item['isCombo'] != true) 'addonIds': line.addonIds,
                if (line.item['isCombo'] != true)
                  'customizations': line.customizations
              },
          ],
          'deliveryAddress': address.text,
          'paymentMethod': method,
          'couponCode': coupon.text.trim().isEmpty ? null : coupon.text.trim(),
          'scheduledFor': scheduled?.toUtc().toIso8601String(),
        },
      );
      if (method != 'cod') {
        await api.postJson(
          '$_foodBase/orders/${order['id']}/payment',
          auth: true,
          body: {'provider': 'razorpay'},
        );
      }
      foodCart.clear();
      if (mounted) context.go('/app/food/orders/${order['id']}');
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CustomerScaffold(
        title: 'Food checkout',
        showBack: true,
        child: AnimatedBuilder(
          animation: foodCart,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in foodCart.lines.entries)
                ListTile(
                  title: Text('${entry.value.item['name']}'),
                  subtitle: Text(
                      '₹${entry.value.item['discountedPrice'] ?? entry.value.item['price']}'),
                  trailing: DropdownButton<int>(
                    value: entry.value.quantity,
                    items: [1, 2, 3, 4, 5]
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text('$value')))
                        .toList(),
                    onChanged: (value) =>
                        foodCart.setQuantity(entry.key, value!),
                  ),
                ),
              Text('Subtotal ₹${foodCart.subtotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge),
              TextField(
                  controller: address,
                  decoration:
                      const InputDecoration(labelText: 'Delivery address')),
              TextField(
                  controller: coupon,
                  decoration: const InputDecoration(labelText: 'Coupon code')),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(
                      value: 'cod', child: Text('Cash on delivery')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                ],
                onChanged: (value) => setState(() => method = value!),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(scheduled == null
                    ? 'Deliver now'
                    : 'Scheduled ${scheduled!.toLocal()}'),
                trailing: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (date != null && mounted) {
                      setState(() =>
                          scheduled = date.add(const Duration(hours: 12)));
                    }
                  },
                  child: const Text('Schedule'),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Placing…' : 'Place order'),
              ),
            ],
          ),
        ),
      );
}

class FoodOrdersPage extends StatefulWidget {
  const FoodOrdersPage({super.key});
  @override
  State<FoodOrdersPage> createState() => _FoodOrdersPageState();
}

class _FoodOrdersPageState extends State<FoodOrdersPage> {
  final api = ApiClient();
  late Future<List<Map<String, dynamic>>> data;
  @override
  void initState() {
    super.initState();
    data = api.getList('$_foodBase/orders', auth: true);
  }

  @override
  Widget build(BuildContext context) => CustomerScaffold(
        title: 'Food orders',
        showBack: true,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Error(
                  '${snapshot.error}',
                  () => setState(() {
                        data = api.getList('$_foodBase/orders', auth: true);
                      }));
            }
            return ListView(
              children: [
                for (final order in snapshot.data ?? [])
                  ListTile(
                    onTap: () =>
                        context.push('/app/food/orders/${order['id']}'),
                    leading: const Icon(Icons.delivery_dining),
                    title: Text('${order['restaurantName']}'),
                    subtitle: Text('${order['orderRef']} • ${order['status']}'),
                    trailing: Text('₹${order['total']}'),
                  ),
              ],
            );
          },
        ),
      );
}

class FoodOrderDetailPage extends StatefulWidget {
  const FoodOrderDetailPage({required this.orderId, super.key});
  final String orderId;
  @override
  State<FoodOrderDetailPage> createState() => _FoodOrderDetailPageState();
}

class _FoodOrderDetailPageState extends State<FoodOrderDetailPage> {
  final api = ApiClient();
  final message = TextEditingController();
  late Future<List<dynamic>> data;

  Future<List<dynamic>> load() => Future.wait([
        api.getJson('$_foodBase/orders/${widget.orderId}', auth: true),
        api.getJson('$_foodBase/orders/${widget.orderId}/tracking', auth: true),
        api.getList('$_foodBase/orders/${widget.orderId}/chat', auth: true),
      ]);
  @override
  void initState() {
    super.initState();
    data = load();
  }

  void refresh() => setState(() => data = load());

  @override
  Widget build(BuildContext context) => CustomerScaffold(
        title: 'Food order',
        showBack: true,
        child: FutureBuilder<List<dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _Error('${snapshot.error}', refresh);
            final order = snapshot.data![0] as Map<String, dynamic>;
            final tracking = snapshot.data![1] as Map<String, dynamic>;
            final chat = snapshot.data![2] as List<Map<String, dynamic>>;
            final status = '${order['status']}';
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${order['restaurantName']}',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('${order['orderRef']} • $status'),
                LinearProgressIndicator(value: _progress(status)),
                Text('ETA ${tracking['etaMinutes'] ?? '—'} min'),
                if (tracking['rider'] is Map)
                  ListTile(
                    leading: const Icon(Icons.delivery_dining),
                    title: Text('${tracking['rider']['name']}'),
                    subtitle: Text(
                        '${tracking['rider']['vehicleType'] ?? ''} ${tracking['rider']['vehicleNumber'] ?? ''}'),
                  ),
                for (final item in apiItems(order['items']))
                  ListTile(
                    title: Text('${item['name']} × ${item['quantity']}'),
                    trailing: Text('₹${item['lineSubtotal']}'),
                  ),
                Text('Total ₹${order['total']}',
                    style: Theme.of(context).textTheme.titleLarge),
                if (status == 'placed' || status == 'accepted')
                  OutlinedButton(
                    onPressed: () async {
                      await api.postJson(
                        '$_foodBase/orders/${widget.orderId}/cancel',
                        auth: true,
                        body: {'reason': 'Cancelled from customer app'},
                      );
                      refresh();
                    },
                    child: const Text('Cancel order'),
                  ),
                if (status == 'delivered')
                  FilledButton.tonal(
                    onPressed: () async {
                      await api.postJson(
                        '$_foodBase/orders/${widget.orderId}/review',
                        auth: true,
                        body: {
                          'foodRating': 5,
                          'deliveryRating': 5,
                          'comment': 'Reviewed from customer app',
                        },
                      );
                    },
                    child: const Text('Rate 5 stars'),
                  ),
                if (status == 'delivered')
                  TextButton(
                    onPressed: () async {
                      final invoice = await api.getJson(
                        '$_foodBase/orders/${widget.orderId}/invoice',
                        auth: true,
                      );
                      if (!context.mounted) return;
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('${invoice['invoice_no']}'),
                          content: Text('Invoice total ₹${invoice['total']}'),
                        ),
                      );
                    },
                    child: const Text('View invoice'),
                  ),
                const Divider(),
                Text('Order chat',
                    style: Theme.of(context).textTheme.titleMedium),
                for (final row in chat)
                  ListTile(
                      dense: true,
                      title: Text('${row['senderRole']}: ${row['message']}')),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: message,
                        decoration: const InputDecoration(
                            hintText: 'Message restaurant'),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await api.postJson(
                          '$_foodBase/orders/${widget.orderId}/chat',
                          auth: true,
                          body: {'message': message.text},
                        );
                        message.clear();
                        refresh();
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

  double _progress(String status) =>
      <String, double>{
        'placed': .1,
        'accepted': .25,
        'preparing': .45,
        'ready': .6,
        'picked_up': .75,
        'out_for_delivery': .85,
        'delivered': 1,
      }[status] ??
      .1;
}

class _Error extends StatelessWidget {
  const _Error(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      );
}
