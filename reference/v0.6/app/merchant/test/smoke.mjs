/**
 * Smoke tests for Merchant Dashboard v0
 * Run: node --experimental-vm-modules test/smoke.mjs
 * or import and call runSmokeTests()
 */

import { pathToFileURL } from "url";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Minimal stub client that records all calls
// ---------------------------------------------------------------------------

function createStubClient(options = {}) {
  const calls = [];
  const {
    merchants = [],
    programs = [],
    rewards = [],
    transactions = { rows: [], count: 0 },
    cards = [],
    subscriptions = [],
    plans = [],
    user = { id: "user-owner-001" },
  } = options;

  function record(table, method, args) {
    calls.push({ table, method, args, at: Date.now() });
  }

  function chainable(table, initialData) {
    const state = {
      filters: [],
      selectArgs: null,
      orderArgs: null,
      rangeArgs: null,
      limitVal: null,
      count: null,
      head: false,
      single: false,
    };

    const api = {
      select(cols, opts = {}) {
        state.selectArgs = { cols, opts };
        state.count = opts.count || null;
        state.head = !!opts.head;
        record(table, "select", { cols, opts });
        return api;
      },
      insert(row) {
        record(table, "insert", { row });
        const result = { data: { id: "new-id", ...row }, error: null };
        return {
          select() {
            return {
              single() {
                return Promise.resolve(result);
              },
              then(r, j) {
                return Promise.resolve(result).then(r, j);
              },
            };
          },
          then(r, j) {
            return Promise.resolve(result).then(r, j);
          },
        };
      },
      update(row) {
        record(table, "update", { row });
        const result = { data: { id: "upd-id", ...row }, error: null };
        return {
          eq(col, val) {
            record(table, "update.eq", { col, val });
            return {
              select() {
                return {
                  single() {
                    return Promise.resolve(result);
                  },
                };
              },
              then(r, j) {
                return Promise.resolve(result).then(r, j);
              },
            };
          },
        };
      },
      eq(col, val) {
        state.filters.push({ op: "eq", col, val });
        record(table, "eq", { col, val });
        return api;
      },
      gte(col, val) {
        state.filters.push({ op: "gte", col, val });
        record(table, "gte", { col, val });
        return api;
      },
      order(col, opts) {
        state.orderArgs = { col, opts };
        record(table, "order", { col, opts });
        return api;
      },
      range(from, to) {
        state.rangeArgs = { from, to };
        record(table, "range", { from, to });
        return api;
      },
      limit(n) {
        state.limitVal = n;
        record(table, "limit", { n });
        return api;
      },
      then(resolve, reject) {
        // Terminal – resolve with appropriate data
        let data = null;
        let count = null;
        if (table === "merchants") data = merchants;
        else if (table === "programs") data = programs;
        else if (table === "rewards") data = rewards;
        else if (table === "transactions") {
          data = state.head ? null : transactions.rows;
          count = transactions.count;
        } else if (table === "cards") {
          data = state.head ? null : cards;
          count = state.count === "exact" ? cards.length : null;
        } else if (table === "subscriptions") data = subscriptions;
        else if (table === "plans") data = plans;

        if (state.head && state.count === "exact") {
          // For cards count
          if (table === "cards") count = cards.length;
          if (table === "transactions") count = transactions.count;
        }

        const result = { data: state.head ? null : data, error: null, count };
        return Promise.resolve(result).then(resolve, reject);
      },
    };
    return api;
  }

  const client = {
    from(table) {
      record(table, "from", {});
      return chainable(table);
    },
    auth: {
      getUser() {
        record("_auth", "getUser", {});
        return Promise.resolve({ data: { user }, error: null });
      },
    },
    _calls: calls,
    _reset() {
      calls.length = 0;
    },
  };

  return client;
}

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;
const failures = [];

function assert(cond, msg) {
  if (cond) {
    passed++;
  } else {
    failed++;
    failures.push(msg);
    console.error("  ✗", msg);
  }
}

function assertEqual(a, b, msg) {
  assert(a === b, `${msg} (got ${JSON.stringify(a)}, expected ${JSON.stringify(b)})`);
}

// ---------------------------------------------------------------------------
// Allowed columns (mirror of merchant.mjs)
// ---------------------------------------------------------------------------

const ALLOWED_WRITES = {
  merchants: {
    insert: ["owner_id", "name", "category", "description", "city", "area"],
    update: ["name", "category", "description", "city", "area"],
  },
  programs: {
    insert: ["merchant_id", "type", "name", "rules", "status"],
    update: ["name", "rules", "status"],
  },
  rewards: {
    insert: ["program_id", "merchant_id", "title", "cost", "is_active"],
    update: ["title", "cost", "is_active"],
  },
};

function assertOnlyAllowedColumns(call, table, op) {
  const allowed = ALLOWED_WRITES[table]?.[op];
  if (!allowed) {
    assert(false, `Unexpected write to ${table}.${op}`);
    return;
  }
  const row = call.args.row || {};
  const keys = Object.keys(row);
  for (const k of keys) {
    assert(
      allowed.includes(k),
      `Forbidden column written: ${table}.${op} → ${k}`
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

async function runSmokeTests() {
  console.log("\n=== Merchant Dashboard Smoke Tests ===\n");

  // Dynamic import of merchant module
  const modPath = pathToFileURL(path.join(__dirname, "../merchant.mjs")).href;
  const mod = await import(modPath);

  // ---- 1. Owner with no store sees register flow ----
  {
    console.log("1. Owner with no store → register flow");
    const stub = createStubClient({ merchants: [], user: { id: "u1" } });
    mod.setClient(stub);

    // Simulate fetchOwnedMerchants
    const list = await mod.fetchOwnedMerchants();
    assertEqual(list.length, 0, "no merchants returned");

    // registerMerchant only uses allowed columns
    stub._reset();
    await mod.registerMerchant({
      name: "مقهى النور",
      category: "المقاهي",
      description: "وصف",
      city: "الرياض",
      area: "العليا",
      // attempt forbidden
      status: "approved",
      secret: "hack",
    });
    const insertCall = stub._calls.find((c) => c.method === "insert");
    assert(!!insertCall, "insert was called");
    assertOnlyAllowedColumns(insertCall, "merchants", "insert");
    assertEqual(insertCall.args.row.owner_id, "u1", "owner_id set from user");
    assert(!("status" in insertCall.args.row), "status not sent (RLS forces pending)");
    assert(!("secret" in insertCall.args.row), "forbidden column stripped");
  }

  // ---- 2. Pending banner logic (status check) ----
  {
    console.log("2. Pending status available for banner");
    const stub = createStubClient({
      merchants: [
        {
          id: "m1",
          name: "متجر قيد المراجعة",
          status: "pending",
          category: "أخرى",
          city: "جدة",
        },
      ],
    });
    mod.setClient(stub);
    const list = await mod.fetchOwnedMerchants();
    assertEqual(list[0].status, "pending", "merchant status is pending");
  }

  // ---- 3. KPI queries use correct filters ----
  {
    console.log("3. KPI queries use right filters");
    const stub = createStubClient({
      merchants: [{ id: "m1", name: "T", status: "approved" }],
      cards: [{ id: "c1" }, { id: "c2" }],
      transactions: { rows: [], count: 5 },
    });
    mod.setClient(stub);
    stub._reset();

    await mod.fetchKPIs("m1");

    // members: cards count with merchant_id
    const cardsFrom = stub._calls.filter((c) => c.table === "cards" && c.method === "from");
    assert(cardsFrom.length >= 1, "cards table queried for members");

    const cardsEq = stub._calls.find(
      (c) => c.table === "cards" && c.method === "eq" && c.args.col === "merchant_id"
    );
    assert(!!cardsEq, "cards filtered by merchant_id");
    assertEqual(cardsEq.args.val, "m1", "correct merchant_id for cards");

    // transactions: type earn / redeem + gte created_at + merchant_id
    const txEqMerchant = stub._calls.filter(
      (c) => c.table === "transactions" && c.method === "eq" && c.args.col === "merchant_id"
    );
    assert(txEqMerchant.length >= 3, "transactions filtered by merchant_id multiple times");

    const earnType = stub._calls.find(
      (c) => c.table === "transactions" && c.method === "eq" && c.args.col === "type" && c.args.val === "earn"
    );
    assert(!!earnType, "earn type filter present");

    const redeemType = stub._calls.find(
      (c) => c.table === "transactions" && c.method === "eq" && c.args.col === "type" && c.args.val === "redeem"
    );
    assert(!!redeemType, "redeem type filter present");

    const gteCalls = stub._calls.filter(
      (c) => c.table === "transactions" && c.method === "gte" && c.args.col === "created_at"
    );
    assert(gteCalls.length >= 3, "created_at >= 30d filter used for KPIs");

    // head + count exact
    const selectWithCount = stub._calls.filter(
      (c) =>
        c.method === "select" &&
        c.args.opts &&
        c.args.opts.count === "exact" &&
        c.args.opts.head === true
    );
    assert(selectWithCount.length >= 3, "select with count:exact, head:true used");
  }

  // ---- 4. Program save blocked without active rewards ----
  {
    console.log("4. Program cannot be activated without active rewards");
    // We test the data layer + the guard is in the UI; here we verify
    // updateProgram only sends allowed columns, and that fetchRewards works
    // for the guard.
    const stub = createStubClient({
      rewards: [
        { id: "r1", program_id: "p1", title: "قهوة", cost: 10, is_active: false },
      ],
    });
    mod.setClient(stub);

    const rewards = await mod.fetchRewards("p1");
    const active = rewards.filter((r) => r.is_active);
    assertEqual(active.length, 0, "no active rewards → UI must block status=active");

    stub._reset();
    await mod.updateProgram("p1", {
      name: "برنامج",
      rules: { target: 10 },
      status: "draft",
      forbidden_col: "x",
    });
    const upd = stub._calls.find((c) => c.method === "update");
    assert(!!upd, "update called");
    assertOnlyAllowedColumns(upd, "programs", "update");
  }

  // ---- 5. Confirmation message text exists (documented) ----
  {
    console.log("5. Rules-change confirmation text");
    // The UI shows: "تعديل القواعد ينشئ نسخة جديدة من البرنامج وتبقى العمليات السابقة كما هي."
    // We assert the constant is present in source by reading the file.
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(
      src.includes("تعديل القواعد ينشئ نسخة جديدة من البرنامج وتبقى العمليات السابقة كما هي."),
      "confirmation message present in source"
    );
  }

  // ---- 6. Pagination ranges ----
  {
    console.log("6. Pagination uses range() with page size 25");
    const stub = createStubClient({
      transactions: { rows: [], count: 60 },
    });
    mod.setClient(stub);
    stub._reset();

    await mod.fetchTransactions("m1", { page: 0 });
    let rangeCall = stub._calls.find((c) => c.method === "range");
    assert(!!rangeCall, "range() called for page 0");
    assertEqual(rangeCall.args.from, 0, "page 0 from=0");
    assertEqual(rangeCall.args.to, 24, "page 0 to=24");

    stub._reset();
    await mod.fetchTransactions("m1", { page: 2 });
    rangeCall = stub._calls.find((c) => c.method === "range");
    assertEqual(rangeCall.args.from, 50, "page 2 from=50");
    assertEqual(rangeCall.args.to, 74, "page 2 to=74");
  }

  // ---- 7. HTML injection protection ----
  {
    console.log("7. HTML-injection / escape");
    // escapeHtml is internal; we test via behaviour expectation:
    // any user-controlled string rendered must be escaped.
    // We verify the source contains escapeHtml and uses it on name/title/reason.
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(src.includes("function escapeHtml"), "escapeHtml defined");
    assert(src.includes("escapeHtml(m.name)") || src.includes("escapeHtml(p.name)"), "names escaped");
    assert(src.includes("escapeHtml(r.reason") || src.includes("escapeHtml(r.reason ||"), "reason escaped");
    // Also test that dangerous payload columns are stripped on write
    const stub = createStubClient({ user: { id: "u1" } });
    mod.setClient(stub);
    stub._reset();
    await mod.registerMerchant({
      name: `<img src=x onerror=alert(1)>`,
      category: "أخرى",
      city: "الرياض",
      description: `<script>alert(1)</script>`,
    });
    const ins = stub._calls.find((c) => c.method === "insert");
    assert(!!ins, "insert called");
    // Values are passed through (escaping is at render time), but no extra cols
    assertOnlyAllowedColumns(ins, "merchants", "insert");
  }

  // ---- 8. No writes outside allowed lists ----
  {
    console.log("8. No write to forbidden tables/columns");
    const stub = createStubClient({ user: { id: "u1" } });
    mod.setClient(stub);
    stub._reset();

    // Perform a variety of allowed ops
    await mod.registerMerchant({
      name: "A",
      category: "أخرى",
      city: "C",
    });
    await mod.updateMerchant("m1", {
      name: "B",
      category: "المقاهي",
      city: "D",
      description: null,
      area: "E",
    });
    await mod.insertProgram({
      merchant_id: "m1",
      type: "stamps",
      name: "P",
      rules: { target: 5 },
      status: "draft",
    });
    await mod.updateProgram("p1", { name: "P2", rules: { target: 8 }, status: "inactive" });
    await mod.insertReward({
      program_id: "p1",
      merchant_id: "m1",
      title: "R",
      cost: 3,
      is_active: true,
    });
    await mod.updateReward("r1", { title: "R2", cost: 4, is_active: false });

    const writeMethods = ["insert", "update"];
    const writeCalls = stub._calls.filter((c) => writeMethods.includes(c.method));

    for (const c of writeCalls) {
      if (c.method === "insert" || c.method === "update") {
        assert(
          ["merchants", "programs", "rewards"].includes(c.table),
          `write only to allowed tables (got ${c.table})`
        );
        assertOnlyAllowedColumns(c, c.table, c.method);
      }
    }

    // Ensure no delete
    const deletes = stub._calls.filter((c) => c.method === "delete");
    assertEqual(deletes.length, 0, "no delete operations");

    // Staff: no insert attempted by the module exports
    // (viewStaff is pure UI message)
  }

  // ---- 9. Staff message present ----
  {
    console.log("9. Staff section shows unavailable message");
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(
      src.includes("إدارة الموظفين غير متاحة بعد"),
      "staff unavailable message present"
    );
  }

  // ---- 10. Subscription empty message ----
  {
    console.log("10. Subscription empty state text");
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(src.includes("لا توجد باقات مفعّلة بعد."), "empty plans message present");
    assert(src.includes("التجديد يدوي حاليًا. تواصل مع فريق وِثاق."), "manual renewal note present");
  }

  // ---- 11. Operations note ----
  {
    console.log("11. Operations immutable note");
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(
      src.includes("سجل العمليات لا يقبل التعديل أو الحذف."),
      "operations immutable note present"
    );
  }

  // ---- 12. Register success message ----
  {
    console.log("12. Register success message");
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(src.includes("طلبك قيد المراجعة"), "register success message present");
  }

  // ---- 13. Customer masking ----
  {
    console.log("13. Customer id masked to last 4 chars");
    const fs = await import("fs");
    const src = fs.readFileSync(path.join(__dirname, "../merchant.mjs"), "utf8");
    assert(src.includes("maskCustomerId") || src.includes("slice(-4)"), "masking helper present");
  }

  // Summary
  console.log("\n----------------------------------------");
  console.log(`Passed: ${passed}`);
  console.log(`Failed: ${failed}`);
  if (failures.length) {
    console.log("\nFailures:");
    failures.forEach((f) => console.log(" -", f));
  }
  console.log("----------------------------------------\n");

  if (failed > 0) {
    process.exitCode = 1;
  }
  return { passed, failed, failures };
}

// Run if executed directly
const isMain =
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  runSmokeTests().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

export { runSmokeTests, createStubClient };
