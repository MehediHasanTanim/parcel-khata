import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/sync/presentation/sync_status_screen.dart';
import 'package:parcel_khata/features/sync/presentation/activity_screen.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';
import 'package:parcel_khata/shared/permission_gate.dart';

import 'package:parcel_khata/features/orders/application/order_prefill.dart';
import 'package:parcel_khata/features/orders/presentation/paste_order_screen.dart';
import 'package:parcel_khata/features/cod/presentation/statement_import_screen.dart';
import 'package:parcel_khata/features/returns/presentation/exchange_screen.dart';
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
import 'package:parcel_khata/features/profit/presentation/missing_costs_screen.dart';
import 'package:parcel_khata/features/expenses/presentation/campaigns_screen.dart';
import 'package:parcel_khata/features/expenses/presentation/expenses_screen.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/presentation/reports_screens.dart';
import 'package:parcel_khata/features/returns/presentation/returns_screen.dart';
import 'package:parcel_khata/features/backup/presentation/data_screen.dart';
import 'package:parcel_khata/features/backup/presentation/import_screen.dart';
import 'package:parcel_khata/features/reminders/presentation/attention_screen.dart';
import 'package:parcel_khata/features/reminders/presentation/notification_settings_screen.dart';
import 'package:parcel_khata/features/security/presentation/security_screen.dart';
import 'package:parcel_khata/features/settings/presentation/settings_screen.dart';
import 'package:parcel_khata/features/templates/presentation/templates_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    if (DebugMenuScreen.enabled)
      GoRoute(path: '/debug', builder: (_, __) => const DebugMenuScreen()),
    // Static order routes must precede '/orders/:id'.
    GoRoute(
      path: '/orders/new',
      builder: (_, st) => OrderFormScreen(prefill: st.extra is OrderPrefill ? st.extra! as OrderPrefill : null),
    ),
    GoRoute(
      path: '/orders/paste',
      builder: (_, st) => PasteOrderScreen(initialText: st.extra is String ? st.extra! as String : ''),
    ),
    GoRoute(path: '/orders/cost-missing', builder: (_, __) => const MissingCostsScreen()),
    GoRoute(
      path: '/drill',
      builder: (_, st) {
        final q = st.uri.queryParameters;
        return OrdersScreen(
          initialFilter: OrderFilter.decode(q['filter']),
          title: q['title'],
          measure: Measure.values.where((m) => m.name == q['measure']).firstOrNull,
          stuck: q['stuck'] == '1',
        );
      },
    ),
    GoRoute(path: '/reports', builder: (_, __) => const PermissionGate(action: Capability.viewReports, child: ReportsScreen())),
    GoRoute(
      path: '/reports/:kind',
      builder: (_, st) => ReportScreen(
        kind: ReportKind.values.firstWhere(
          (k) => k.name == st.pathParameters['kind'],
          orElse: () => ReportKind.profit,
        ),
      ),
    ),
    GoRoute(path: '/expenses', builder: (_, __) => const PermissionGate(action: Capability.manageExpenses, child: ExpensesScreen())),
    GoRoute(path: '/campaigns', builder: (_, __) => const PermissionGate(action: Capability.manageExpenses, child: CampaignsScreen())),
    GoRoute(path: '/campaigns/new', builder: (_, __) => const CampaignScreen()),
    GoRoute(
      path: '/campaigns/:id',
      builder: (_, st) => CampaignScreen(campaignId: st.pathParameters['id']),
    ),
    GoRoute(path: '/returns', builder: (_, __) => const PermissionGate(action: Capability.manageReturns, child: ReturnsScreen())),
    GoRoute(path: '/orders/cn-entry', builder: (_, __) => const CnEntryScreen()),
    GoRoute(path: '/orders/drafts', builder: (_, __) => const DraftsScreen()),
    GoRoute(path: '/orders/deleted', builder: (_, __) => const DeletedOrdersScreen()),
    GoRoute(
      path: '/orders/:id',
      builder: (_, st) => OrderDetailScreen(orderId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id/exchange',
      builder: (_, st) => ExchangeScreen(orderId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id/edit',
      builder: (_, st) => OrderFormScreen(orderId: st.pathParameters['id']),
    ),
    GoRoute(
      path: '/customers/:id/orders',
      builder: (_, st) => OrdersScreen(customerId: st.pathParameters['id']),
    ),
    GoRoute(path: '/cod/ageing', builder: (_, __) => const PermissionGate(action: Capability.recordPayout, child: AgeingScreen())),
    GoRoute(path: '/cod/disputed', builder: (_, __) => const PermissionGate(action: Capability.recordPayout, child: DisputedScreen())),
    GoRoute(path: '/cod/payouts', builder: (_, __) => const PermissionGate(action: Capability.recordPayout, child: PayoutsScreen())),
    GoRoute(
      path: '/cod/payout/statement',
      builder: (_, st) => StatementImportScreen(courierId: st.uri.queryParameters['courier']),
    ),
    GoRoute(
      path: '/cod/payouts/:id',
      builder: (_, st) => PayoutDetailScreen(payoutId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/cod/payout/new',
      builder: (_, st) => PayoutFlowScreen(courierId: st.uri.queryParameters['courier']),
    ),
    GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
    GoRoute(
      path: '/customers/new',
      builder: (_, st) => CustomerFormScreen(
          prefill: st.extra is CustomerPrefill ? st.extra! as CustomerPrefill : null),
    ),
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
    GoRoute(path: '/settings', builder: (_, __) => const PermissionGate(action: Capability.manageSettings, child: SettingsScreen())),
    GoRoute(path: '/settings/security', builder: (_, __) => const SecurityScreen()),
    GoRoute(path: '/settings/data', builder: (_, __) => const PermissionGate(action: Capability.manageSettings, child: DataScreen())),
    GoRoute(path: '/settings/import', builder: (_, __) => const PermissionGate(action: Capability.manageSettings, child: ImportScreen())),
    GoRoute(path: '/settings/sync', builder: (_, __) => const SyncStatusScreen()),
    GoRoute(path: '/settings/activity', builder: (_, __) => const PermissionGate(action: Capability.viewActivity, child: ActivityScreen())),
    GoRoute(
      path: '/settings/notifications',
      builder: (_, __) => const NotificationSettingsScreen(),
    ),
    GoRoute(path: '/templates', builder: (_, __) => const TemplatesScreen()),
    GoRoute(path: '/attention', builder: (_, __) => const AttentionScreen()),
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
          GoRoute(path: '/cod', builder: (_, __) => const PermissionGate(action: Capability.recordPayout, child: CodScreen())),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
        ]),
      ],
    ),
  ],
);
