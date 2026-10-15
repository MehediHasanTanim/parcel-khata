/// Roles and permissions (F17): ONE table drives client gating, server
/// policies and the tests that compare them.
///
/// Hiding things in the UI is UX only. The server enforces
/// ([RolePolicy]) and never sends fields a role may not see.
library;

import 'package:meta/meta.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

enum Role {
  owner('owner'),
  orderTaker('order_taker'),
  packer('packer');

  const Role(this.wire);
  final String wire;

  static Role? fromWire(String? s) {
    for (final r in Role.values) {
      if (r.wire == s) return r;
    }
    return null;
  }
}

/// A user-level capability. Each one lists the server writes ([probes]) that
/// implement it, so the matrix test can replay them against the server.
enum Capability {
  createOrder,
  editOrder,
  cancelOrder,
  manageCustomers,
  manageProducts,
  enterCn,
  markPacked,
  markHandedOver,
  recordDelivery,
  viewCostAndProfit,
  recordPayout,
  manageReturns,
  manageExpenses,
  viewReports,
  manageSettings,
  manageHelpers,
  viewActivity,
}

@immutable
class Probe {
  const Probe(this.table, this.fields);
  final String table;
  final Map<String, Object?> fields;
}

@immutable
class ActionSpec {
  const ActionSpec(this.roles, this.probes);
  final Set<Role> roles;

  /// Writes that must be accepted exactly for [roles] (empty = client-only
  /// capability such as "view reports", which is enforced by what the server
  /// lets the role read).
  final List<Probe> probes;
}

const _all = {Role.owner, Role.orderTaker, Role.packer};
const _ownerOnly = {Role.owner};
const _entry = {Role.owner, Role.orderTaker};

/// The single permission table.
const Map<Capability, ActionSpec> kActions = {
  Capability.createOrder: ActionSpec(_entry, [
    Probe('orders', {'order_no': 'X-1', 'address': 'a', 'cod_expected': 1000}),
    Probe('order_lines', {'name_snapshot': 'Item', 'qty': 1}),
    Probe('order_status_events', {'to_status': 'confirmed'}),
  ]),
  Capability.editOrder: ActionSpec(_entry, [
    Probe('orders', {'address': 'new address', 'notes': 'n'}),
  ]),
  Capability.cancelOrder: ActionSpec(_entry, [
    Probe('order_status_events', {'to_status': 'cancelled'}),
  ]),
  Capability.manageCustomers: ActionSpec(_entry, [
    Probe('customers', {'name': 'N', 'phone_primary': '01712345678'}),
  ]),
  Capability.manageProducts: ActionSpec(_entry, [
    Probe('products', {'name': 'P', 'default_sell_price': 100}),
  ]),
  Capability.enterCn: ActionSpec(_all, [
    Probe('orders', {'courier_id': 'c1', 'consignment_no': 'CN1'}),
  ]),
  Capability.markPacked: ActionSpec({Role.owner, Role.packer}, [
    Probe('order_status_events', {'to_status': 'packed'}),
  ]),
  Capability.markHandedOver: ActionSpec({Role.owner, Role.packer}, [
    Probe('order_status_events', {'to_status': 'handed_to_courier'}),
  ]),
  Capability.recordDelivery: ActionSpec(_ownerOnly, [
    Probe('order_status_events', {'to_status': 'delivered'}),
    Probe('orders', {'cod_collected': 99900}),
  ]),
  Capability.viewCostAndProfit: ActionSpec(_ownerOnly, []),
  Capability.recordPayout: ActionSpec(_ownerOnly, [
    Probe('payouts', {'status': 'active', 'total_received': 100}),
    Probe('payout_allocations', {'amount_applied': 100}),
  ]),
  Capability.manageReturns: ActionSpec(_ownerOnly, [
    Probe('return_records', {'type': 'full', 'reason': 'customer_refused'}),
  ]),
  Capability.manageExpenses: ActionSpec(_ownerOnly, [
    Probe('expenses', {'category': 'rent', 'amount': 1}),
  ]),
  Capability.viewReports: ActionSpec(_ownerOnly, []),
  Capability.manageSettings: ActionSpec(_ownerOnly, [
    Probe('courier_rate_rules', {'zone': 'inside_dhaka', 'delivery_fee': 60}),
  ]),
  Capability.manageHelpers: ActionSpec(_ownerOnly, []),
  Capability.viewActivity: ActionSpec(_ownerOnly, []),
};

/// Client-side gating (UX). Local-only owners are always [Role.owner].
bool can(Role role, Capability action) => kActions[action]!.roles.contains(role);

// ---------------------------------------------------------- table access

@immutable
class Access {
  const Access({
    this.read = false,
    this.write = false,
    this.hidden = const {},
    this.denyUnlessDefault = const {},
    this.writableOnly,
    this.statuses,
  });

  final bool read;
  final bool write;

  /// Never sent to this role and ignored if it writes them.
  final Set<String> hidden;

  /// Writing these fields is forbidden unless the value is null/0/''/false
  /// (insert defaults).
  final Set<String> denyUnlessDefault;

  /// If set, only these fields may be written.
  final Set<String>? writableOnly;

  /// For `order_status_events`: statuses this role may create.
  final Set<String>? statuses;
}

const _none = Access();
const _rw = Access(read: true, write: true);
const _ro = Access(read: true);

const Map<String, Map<Role, Access>> kTableAccess = {
  'customers': {Role.owner: _rw, Role.orderTaker: _rw, Role.packer: _ro},
  'customer_addresses': {Role.owner: _rw, Role.orderTaker: _rw, Role.packer: _ro},
  'products': {
    Role.owner: _rw,
    Role.orderTaker: Access(read: true, write: true, hidden: {'default_cost_price'}),
    Role.packer: Access(read: true, hidden: {'default_cost_price'}),
  },
  'product_variants': {
    Role.owner: _rw,
    Role.orderTaker: Access(read: true, write: true, hidden: {'cost_price'}),
    Role.packer: Access(read: true, hidden: {'cost_price'}),
  },
  'couriers': {Role.owner: _rw, Role.orderTaker: _ro, Role.packer: _ro},
  'courier_rate_rules': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'orders': {
    Role.owner: _rw,
    Role.orderTaker: Access(
      read: true,
      write: true,
      denyUnlessDefault: {'cod_collected', 'is_disputed', 'dispute_note'},
    ),
    Role.packer: Access(
      read: true,
      write: true,
      writableOnly: {'courier_id', 'consignment_no', 'zone', 'weight_g', 'updated_at'},
    ),
  },
  'order_lines': {
    Role.owner: _rw,
    Role.orderTaker: Access(read: true, write: true, hidden: {'unit_cost_price'}),
    Role.packer: Access(read: true, hidden: {'unit_cost_price'}),
  },
  'order_charges': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'order_tag_links': {Role.owner: _rw, Role.orderTaker: _rw, Role.packer: _ro},
  'order_attachments': {Role.owner: _rw, Role.orderTaker: _rw, Role.packer: _ro},
  'order_status_events': {
    Role.owner: _rw,
    Role.orderTaker: Access(read: true, write: true, statuses: {'draft', 'confirmed', 'cancelled'}),
    Role.packer: Access(
      read: true,
      write: true,
      statuses: {'packed', 'handed_to_courier', 'in_transit'},
    ),
  },
  // Helpers' edits produce log rows; they cannot read them back (values may
  // be money).
  'order_edit_log': {
    Role.owner: _rw,
    Role.orderTaker: Access(write: true),
    Role.packer: Access(write: true),
  },
  'payouts': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'payout_allocations': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'return_records': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'return_lines': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'campaigns': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
  'expenses': {Role.owner: _rw, Role.orderTaker: _none, Role.packer: _none},
};

/// Fields (per table) whose change is flagged "money-affecting" in the
/// activity log, plus whole tables.
const _moneyTables = {
  'payouts',
  'payout_allocations',
  'order_charges',
  'return_records',
  'return_lines',
  'expenses',
  'campaigns',
};
const _moneyFields = {
  'orders': {'cod_collected', 'cod_expected', 'cod_overridden', 'advance_received', 'items_total', 'discount_total', 'delivery_charge_customer'},
  'order_lines': {'unit_sell_price', 'unit_cost_price', 'qty', 'line_discount'},
  'products': {'default_sell_price', 'default_cost_price'},
};
const _moneyStatuses = {'delivered', 'returned', 'return_in_transit', 'delivery_failed'};

bool isMoneyAffecting(String table, Map<String, Object?> fields) {
  if (_moneyTables.contains(table)) return true;
  if (table == 'order_status_events') return _moneyStatuses.contains(fields['to_status']);
  final f = _moneyFields[table];
  return f != null && fields.keys.any(f.contains);
}

// ------------------------------------------------------------ the policy

/// What a server must apply per role. Implemented once, here, from
/// [kTableAccess]; the reference server uses it and the tests replay
/// [kActions] against it.
class RolePolicy implements Authorizer {
  const RolePolicy();

  Access _access(String role, String table) {
    final r = Role.fromWire(role);
    if (r == null) return _none;
    return kTableAccess[table]?[r] ?? _none;
  }

  @override
  bool knows(String table) => kTableAccess.containsKey(table);

  @override
  String? authorizeWrite(String role, String table, Map<String, Object?> fields,
      {required bool rowExists}) {
    final a = _access(role, table);
    if (!a.write) return 'forbidden_role';
    final writable = a.writableOnly;
    for (final e in fields.entries) {
      if (a.hidden.contains(e.key)) continue; // ignored, not an error
      if (writable != null && !writable.contains(e.key)) return 'forbidden_field:${e.key}';
      if (a.denyUnlessDefault.contains(e.key)) {
        final v = e.value;
        if (!(v == null || v == 0 || v == '' || v == false)) return 'forbidden_field:${e.key}';
      }
    }
    if (a.writableOnly != null && !rowExists) return 'forbidden_role';
    if (a.statuses != null) {
      final to = fields['to_status'];
      if (to != null && !a.statuses!.contains(to)) return 'forbidden_status:$to';
    }
    return null;
  }

  @override
  Map<String, Versioned> filterWrite(String role, String table, Map<String, Versioned> fields) {
    final hidden = _access(role, table).hidden;
    if (hidden.isEmpty) return fields;
    return {for (final e in fields.entries) if (!hidden.contains(e.key)) e.key: e.value};
  }

  @override
  RowState? projectRead(String role, RowState row) {
    final a = _access(role, row.table);
    if (!a.read) return null;
    if (a.hidden.isEmpty) return row;
    return RowState(row.table, row.id, row.shopId,
        {for (final e in row.fields.entries) if (!a.hidden.contains(e.key)) e.key: e.value});
  }

  @override
  bool isMoney(String table, Map<String, Object?> fields) => isMoneyAffecting(table, fields);

  @override
  bool seesCost(String role) => _access(role, 'order_lines').hidden.isEmpty;
}
