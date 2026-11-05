# Problem list

Findings from the initial inspection of the codebase before any changes were made.
Decisions and outcomes filled in after implementation.

---

## 1. StockPricesUpdateJob hard-codes AlphaVantageApiClient — FIXED

- **Where:** `app/jobs/stock_prices_update_job.rb` — originally `@api_client = AlphaVantageApiClient.new` on the first line of `perform`.
- **What depends on what:** The job (business policy: update stock prices on a schedule) directly constructed its own external price source (technical detail: the AlphaVantage HTTP API). Business logic depended on an infrastructure class name, with no way to substitute another source.
- **Decision:** Inverted. `perform` now accepts two injectable keyword arguments:
  ```ruby
  def perform(simulated_source: SimulatedPriceSource.new, real_source: AlphaVantageApiClient.new)
  ```
  Each stock picks its source at the top of the loop — `stock.simulated? ? simulated_source : real_source` — before the unchanged private business-logic methods run.
- **Why:** This was the single change required to unlock the simulated market. `SimulatedPriceSource` and `AlphaVantageApiClient` are now interchangeable from the job's perspective because both respond to `fetch_quote(symbol)`. Neither the update rules (yesterday's price, trading-day skip, cents conversion) nor the private methods needed modification.
- **What was also delivered:**
  - `app/services/simulated_price_source.rb` — returns a deterministic ±2% price movement using `SHA2("#{symbol}-#{date}")` as the seed. No API key required.
  - `simulated` boolean column on `stocks` (migration `20261105000001`, `default: false, null: false`).
  - Seed data: all 10 fictional companies marked `simulated: true`.
  - Admin stock form: `simulated` checkbox added alongside `archived`.
  - 11 new tests covering the simulated source, source routing, and the stand-in injection seam.

---

## 2. StockAttributeUpdate makes raw Net::HTTP calls inline

- **Where:** `app/services/stock_attribute_update.rb:74–77` — the private `api_request` method constructs a URL string, calls `Net::HTTP.get(URI.parse(url))`, and parses the JSON response directly. It also reads the global constant `API_KEY`, which is defined in `config/initializers/api_keys.rb` as `ENV.fetch("ALPHA_VANTAGE_API_KEY", "test-api-key")`.
- **What depends on what:** Business logic (fetching and saving stock metadata like company name, exchange, profit margin) directly performs HTTP I/O and reads an initializer-level constant. `AlphaVantageApiClient` exists next door and already abstracts the GLOBAL_QUOTE endpoint but is not used here — this service calls the OVERVIEW endpoint on its own.
- **Decision:** Invert — not yet done.
  Add a `fetch_overview(symbol)` method to `AlphaVantageApiClient` (or a separate client), then inject the client into `StockAttributeUpdate` the same way `real_source:` is now injected into the job.
- **Why:** Two places must change whenever the AlphaVantage URL scheme, API version, or authentication method changes. The global `API_KEY` constant is an invisible dependency: if the initializer is absent or the env var is unset in a non-development environment, the constant fallback `"test-api-key"` silently produces bad API responses rather than a clear error. The existing `StockAttributeUpdateTest` stubs `Net::HTTP.expects(:get)` directly — it is coupled to implementation plumbing rather than behaviour.
- **What it costs to leave it as it is:** Any URL or key change requires editing two services. Tests must reach inside the HTTP layer rather than injecting a collaborator. If a simulated attribute update is ever needed (consistent with the simulated price feature), it cannot be added without modifying the service itself.

---

## 3. OrderExecutorFactory is a fake factory with one path

- **Where:** `app/services/order_executor_factory.rb:6` — `self.build(order)` unconditionally returns `ExecuteOrder.new(order)`. Called from `app/jobs/order_execution_job.rb:37`.
- **What depends on what:** `OrderExecutionJob` calls `OrderExecutorFactory.build(pending_order)` instead of `ExecuteOrder.new(pending_order)` directly. The factory adds one indirection hop but performs no selection, branching, or configuration. It is a class whose only content is `ExecuteOrder.new(order)`.
- **Decision:** Remove — not yet done.
  Delete `order_executor_factory.rb` and replace the call in `OrderExecutionJob#execute_orders` with `ExecuteOrder.new(pending_order).execute`.
- **Why:** A factory's job is to select among implementations or encapsulate complex construction. With a single unconditional path, it provides neither. Every reader who encounters `OrderExecutorFactory.build` must look up the factory to discover it does nothing — that is pure reading overhead. The existing `OrderExecutionJobTest` already bypasses the factory entirely by stubbing `ExecuteOrder.any_instance.expects(:execute)`, so removing the factory requires no test changes.
- **What it costs to leave it as it is:** Minor ongoing confusion for anyone tracing the order execution path. The factory name implies flexibility that does not exist, which is quietly misleading. If a real factory is ever needed, introducing it at that point — with a concrete reason — is straightforward.

---

## 4. TransactionFeeProcessor's injectable fee strategy — leave it

- **Where:** `app/services/transaction_fee_processor.rb:4` — `def initialize(orders, fee_strategy: FlatTransactionFee.new)`.
- **What depends on what:** `TransactionFeeProcessor` depends on `TransactionFeeStrategy` (the abstract base class defined in `app/services/transaction_fee_strategy.rb`), not on a concrete class. The default `FlatTransactionFee.new` is a keyword-argument default, so any caller can substitute a different strategy without touching the processor.
- **Decision:** Leave. This is dependency injection done correctly and needs no change.
- **Why:** The base class `TransactionFeeStrategy` raises `NotImplementedError` on `fee_cents_for`, making the contract explicit. `FlatTransactionFee` overrides it. The processor is fully open to extension (pass a different strategy) and closed to modification. The abstraction is load-bearing even with only one concrete strategy today, because the extension point is in the right place and correctly structured.
- **What it costs to leave it as it is:** Nothing. The pattern is correct as written.

---

## 5. StockRepository is a thin pass-through — leave it

- **Where:** `app/repositories/stock_repository.rb` — three class methods: `find(id)` delegates to `Stock.find`, `find_by_ticker(ticker)` delegates to `Stock.find_by(ticker:)`, and `active` delegates to `Stock.active`. Used in `app/controllers/stocks_controller.rb:24` and `app/controllers/orders_controller.rb:71`.
- **What depends on what:** Controllers call `StockRepository` instead of the `Stock` ActiveRecord class directly. The repository adds no logic, caching, or transformation — it is a naming indirection over the model.
- **Decision:** Leave. The abstraction is thin but harmlessly positioned.
- **Why:** Unlike `OrderExecutorFactory`, this layer is in the right architectural place (controllers should not depend directly on persistence details) even if it currently adds no behaviour. If a lookup ever needs caching, scoping, or a backing-store change, `StockRepository` is the correct place for it, and no controller code would need to change. Removing it would save one file at the cost of making controllers directly dependent on `Stock`, which would be a step in the wrong direction.
- **What it costs to leave it as it is:** One extra file with three trivial methods. No practical downside.
