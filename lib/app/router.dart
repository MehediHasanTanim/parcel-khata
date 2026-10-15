import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/app/debug_menu.dart';
import 'package:parcel_khata/app/shell_scaffold.dart';
import 'package:parcel_khata/features/cod/presentation/ageing_screen.dart';
import 'package:parcel_khata/features/cod/presentation/cod_screen.dart';
import 'package:parcel_khata/features/cod/presentation/payout_flow_screen.dart';
import 'package:parcel_khata/features/cod/presentation/payouts_screen.dart';
import 'package:parcel_khata/features/couriers/presentation/courier_form_screen.dart';
import 'package:parcel_khata/features/couriers/presentation/couriers_screen.dart';
import 'package:parcel_khata/features/customers/presentation/customer_detail_screen.dart';
import 'package:parcel_khata/features/customers/presentation/customer_form_screen.dart';
import 'package:parcel_khata/features/customers/presentation/customers_screen.dart';
import 'package:parcel_khata/features/home/presentation/home_screen.dart';
import 'package:parcel_khata/features/more/presentation/more_screen.dart';
import 'package:parcel_khata/features/orders/presentation/cn_entry_screen.dart';
import 'package:parcel_khata/features/orders/presentation/deleted_orders_screen.dart';
import 'package:parcel_khata/features/orders/presentation/drafts_screen.dart';
import 'package:parcel_khata/features/orders/presentation/order_detail_screen.dart';
import 'package:parcel_khata/features/orders/presentation/order_form_screen.dart';
import 'package:parcel_khata/features/orders/presentation/orders_screen.dart';
import 'package:parcel_khata/features/products/presentation/product_form_screen.dart';
import 'package:parcel_khata/features/products/presentation/products_screen.dart';
import 'package:parcel_khata/features/settings/presentation/settings_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    if (DebugMenuScreen.enabled)
      GoRoute(path: '/debug', builder: (_, __) => const DebugMenuScreen()),
    // Static order routes must precede '/orders/:id'.
    GoRoute(path: '/orders/new', builder: (_, __) => const OrderFormScreen()),
    GoRoute(path: '/orders/cn-entry', builder: (_, __) => const CnEntryScreen()),
    GoRoute(path: '/orders/drafts', builder: (_, __) => const DraftsScreen()),
    GoRoute(path: '/orders/deleted', builder: (_, __) => const DeletedOrdersScreen()),
    GoRoute(
      path: '/orders/:id',
      builder: (_, st) => OrderDetailScreen(orderId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id/edit',
      builder: (_, st) => OrderFormScreen(orderId: st.pathParameters['id']),
    ),
    GoRoute(
      path: '/customers/:id/orders',
      builder: (_, st) => OrdersScreen(customerId: st.pathParameters['id']),
    ),
    GoRoute(path: '/cod/ageing', builder: (_, __) => const AgeingScreen()),
    GoRoute(path: '/cod/disputed', builder: (_, __) => const DisputedScreen()),
    GoRoute(path: '/cod/payouts', builder: (_, __) => const PayoutsScreen()),
    GoRoute(
      path: '/cod/payouts/:id',
      builder: (_, st) => PayoutDetailScreen(payoutId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/cod/payout/new',
      builder: (_, st) => PayoutFlowScreen(courierId: st.uri.queryParameters['courier']),
    ),
    GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
    GoRoute(path: '/customers/new', builder: (_, __) => const CustomerFormScreen()),
    GoRoute(
      path: '/customers/:id',
      builder: (_, st) => CustomerDetailScreen(customerId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/customers/:id/edit',
      builder: (_, st) => CustomerFormScreen(customerId: st.pathParameters['id']),
    ),
    GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
    GoRoute(path: '/products/new', builder: (_, __) => const ProductFormScreen()),
    GoRoute(
      path: '/products/:id/edit',
      builder: (_, st) => ProductFormScreen(productId: st.pathParameters['id']),
    ),
    GoRoute(path: '/couriers', builder: (_, __) => const CouriersScreen()),
    GoRoute(path: '/couriers/new', builder: (_, __) => const CourierFormScreen()),
    GoRoute(
      path: '/couriers/:id/edit',
      builder: (_, st) => CourierFormScreen(courierId: st.pathParameters['id']),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cod', builder: (_, __) => const CodScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
        ]),
      ],
    ),
  ],
);
