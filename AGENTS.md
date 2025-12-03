# AI Agents Guidelines for Elixir Libraries

This is a reusable Elixir library designed for distributed systems.

## Project Structure

Each library follows a standard structure:

- `lib/` - Source code
- `test/` - Test files
- `doc/` - Generated documentation
- `mix.exs` - Project configuration
- `README.md` - Overview (always keep up to date)
- `QUICKSTART.md` - Quick start (always keep up to date)
- `USAGE_GUIDE.md` - Detailed usage documentation (always keep up to date)
- `EXAMPLES.md` - Code examples (always keep up to date)

## Library Preference Policy

**Always prefer using libraries from `libs/` when implementing new functionality:**

| Need | Use This Library |
|------|------------------|
| Distributed processes/supervisors | `Cohort` |
| Distributed job queue (Burrow) | `Burrow` |
| BeanstalkD job queue | `BeanstalkD` |
| Periodic/scheduled tasks | `Periodical` |
| Distributed key-value storage | `MeshKV` |
| RabbitMQ messaging | `RabbitMQ` |
| Redis operations | `Redis` |
| S3/object storage | `S3` |
| HTTP client | `HTTPClient` |
| Database/Ecto wrapper | `Repo` |
| Structured error handling | `ASCO.Error` |
| Telemetry/monitoring | `ASCO.Telemetry` |
| Time parsing/scheduling | `ASCO.Time` |
| String case conversion | `ASCO.String` |
| Logfmt logging | `LoggerLogfmt` |

## Library Quick Reference

### Cohort - Distributed Process Management

Use for distributed GenServers, registries, and supervisors across nodes.

```elixir
defmodule MyApp.Worker do
  use Cohort.GenServer

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Cohort.GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts), do: {:ok, %{name: opts[:name]}}

  # State preservation across node failures
  @impl true
  def handle_takeover(opts) do
    case Cohort.StateStore.get({:worker, opts[:name]}) do
      {:ok, state} -> {:ok, state}
      :error -> {:ok, %{name: opts[:name]}}
    end
  end

  @impl true
  def handle_handoff(state) do
    Cohort.StateStore.put({:worker, state.name}, state, ttl: :timer.minutes(10))
    :ok
  end

  @impl true
  def terminate(_reason, _state), do: :ok
end
```

**Best Practices:**

- Always implement `terminate/2` when using handoff
- Use tuple names for namespacing: `{:worker, :user, user_id}`
- Keep StateStore data under 1MB per entry
- Use appropriate TTLs for saved state

### Burrow - Distributed Job Queue

Use for background job processing with retry logic and distributed consumers.

```elixir
defmodule MyApp.EmailWorker do
  use Burrow.Consumer,
    tubes: [:emails],
    poll_interval: 50

  @impl true
  def handle_job(payload, job_id, stats) do
    case send_email(payload) do
      :ok -> {:delete, job_id}
      {:error, :temporary} -> {:release, job_id, in: "1 minute"}
      {:error, :permanent} -> {:bury, job_id}
    end
  end
end

# Add jobs
Burrow.put(%{to: "user@example.com"}, tube: :emails, priority: 100)
```

**Best Practices:**

- Use named jobs for idempotency: `name: {:email, user_id}`
- Use `Burrow.Consumer.Distributed` for cluster singletons
- Always handle all job return values (`:delete`, `:release`, `:bury`)
- Check `stats.releases` for retry count

### Periodical - Scheduled Tasks

Use for periodic/scheduled task execution as cluster singletons.

```elixir
defmodule MyApp.HealthCheck do
  use Periodical, interval: "30s"

  @impl Periodical
  def handle_init(_opts), do: {:ok, %{}}

  @impl Periodical
  def handle_periodical(state) do
    check_health()
    {:ok, state}
  end
end

defmodule MyApp.DailyReport do
  use Periodical, at: "9:00am"

  @impl Periodical
  def handle_periodical(state) do
    generate_report()
    {:ok, state}
  end
end
```

**Best Practices:**

- Use `interval:` for recurring tasks ("30s", "5m", "2h")
- Use `at:` for scheduled times ("9:00am", "Monday 14:30")
- Keep tasks lightweight; spawn for heavy work
- Use `trigger/0` for manual execution

### MeshKV - Distributed Key-Value Store

Use for distributed in-memory caching with automatic cluster sync.

```elixir
# Keys can be atoms, strings, integers, lists, tuples, or maps
MeshKV.put("users", {:user, 123}, %{name: "Alice"})
MeshKV.put("cache", "page:/home", html, ttl: :timer.minutes(5))

{:ok, user} = MeshKV.get("users", {:user, 123})
value = MeshKV.get("cache", "key", "default")

# Check existence
if MeshKV.exists?("db", "key"), do: ...

# List operations
keys = MeshKV.keys("users")
count = MeshKV.size("users")
```

**Best Practices:**

- Use separate databases for different data types
- Use TTLs for cache data
- Keys can be any term (atoms, tuples, strings, etc.)
- Reads are local (fast), writes broadcast to cluster

### RabbitMQ - Message Queue Integration

Use for event-driven messaging with RabbitMQ.

```elixir
defmodule MyApp.EventConsumer do
  use RabbitMQ.Consumer

  @queue "events-queue"

  def start_link(opts) do
    opts = Keyword.put_new(opts, :queue, RabbitMQ.Config.queue(@queue))
    Rabbit.Consumer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl RabbitMQ.Consumer
  def handle_event("user.created", event, _meta) do
    process_user(event.payload)
    :ack
  end

  @impl RabbitMQ.Consumer
  def handle_event(_type, _event, _meta), do: :ack
end
```

**Best Practices:**

- Always acknowledge messages (`:ack` or `:nack`)
- Handle all event types with a catch-all clause
- Use structured logging with correlation IDs
- Implement idempotency for message processing

### S3 - Object Storage

Use for S3-compatible object storage operations.

```elixir
# Basic operations
S3.exists?("path/to/file.pdf")
S3.upload!("/local/file.pdf", "remote/file.pdf")
S3.download!("remote/file.pdf", "/local/file.pdf")
S3.delete!("old/file.pdf")

# With options
S3.upload!(source, dest, community: :media, content_type: "image/png")
S3.download!(remote, local, community: :media)

# Listing
files = S3.files!("documents/2024/")
all_files = S3.files_all!("documents/")  # handles pagination
```

**Best Practices:**

- Use communities for different buckets/configs
- Use batch delete for multiple files: `S3.delete!(list_of_files)`
- Use `files_all!/1` for complete listings (handles pagination)
- Always validate files before upload

### ASCO.Error - Structured Error Handling

Use for consistent error handling across your application.

```elixir
defmodule MyApp.UserError do
  use ASCO.Error

  defmessage :user_not_found, "User not found"
  defmessage :email_taken, "Email already in use"
  defmessage :invalid_password, "Invalid password"
end

# Create errors
error = MyApp.UserError.user_not_found(%{id: 123})

# Return errors
def get_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, MyApp.UserError.user_not_found(%{id: id})}
    user -> {:ok, user}
  end
end

# Pattern match
case get_user(id) do
  {:ok, user} -> process(user)
  {:error, %MyApp.UserError{code: :user_not_found}} -> create_default()
  {:error, error} -> log_error(error)
end
```

**Best Practices:**

- Use domain-specific error modules (UserError, PaymentError)
- Include relevant details in errors
- Return errors for expected failures, raise for unexpected
- Document error conditions in @doc strings

### ASCO.Telemetry - Telemetry Attachments

Use for simplified telemetry handler attachment.

```elixir
# In application.ex
def start(_type, _args) do
  # Attach to span events (start/stop/exception)
  ASCO.Telemetry.attach_many_span([
    [:my_app, :http, :request],
    [:my_app, :database, :query]
  ])

  # Attach to single events
  ASCO.Telemetry.attach_many([
    [:my_app, :cache, :hit],
    [:my_app, :cache, :miss]
  ])

  # ...
end
```

**Best Practices:**

- Attach in application start
- Use span events for operations with duration
- Include meaningful metadata in telemetry events

### ASCO.Time - Time Parsing

Use for parsing time specifications and intervals.

```elixir
# Parse intervals to milliseconds
{:ok, ms} = ASCO.Time.Duration.parse("30s")   # 30_000
{:ok, ms} = ASCO.Time.Duration.parse("5m")    # 300_000
{:ok, ms} = ASCO.Time.Duration.parse("2h")    # 7_200_000
{:ok, ms} = ASCO.Time.Duration.parse("1d")    # 86_400_000

# Parse schedule times
{:ok, {:time, time}} = ASCO.Time.Schedule.parse("14:30")
{:ok, {:weekday_time, :monday, time}} = ASCO.Time.Schedule.parse("Monday 9:00am")
```

### HTTPClient - HTTP Requests

Use for making HTTP requests with a fluent API.

```elixir
# Simple requests
{:ok, body} = HTTPClient.get("https://api.example.com/users")
{:ok, body} = HTTPClient.post("https://api.example.com/users", %{name: "John"})

# Request builder API
alias HTTPClient.Request

Request.new()
|> Request.set_base_url("https://api.example.com")
|> Request.set_headers(%{"Authorization" => "Bearer token"})
|> Request.set_param(:id, 123)
|> Request.get("/users/:id")

# Enable logging
HTTPClient.Logger.attach(level: :info)
```

**Best Practices:**

- Use the Request builder for complex requests
- Use path parameters (`:id`) instead of string interpolation
- Attach logger in application start for debugging
- Handle all error cases (`{:error, %{status: status}}` and `{:error, reason}`)

### Redis - Redis Operations

Use for Redis key-value operations with warmup support.

```elixir
# Wait for connection before use
:ok = Redis.wait_for_warmup()

# Basic commands
Redis.command(["SET", "key", "value"])
{:ok, "value"} = Redis.command(["GET", "key"])

# Pipeline multiple commands
Redis.pipeline([
  ["SET", "key1", "value1"],
  ["SET", "key2", "value2"],
  ["GET", "key1"]
])

# With custom connection
Redis.command(:my_redis, ["GET", "key"])
```

**Best Practices:**

- Always call `wait_for_warmup/0` before first use
- Use pipelines for multiple commands
- Use `:redix` as default connection name
- Handle connection errors gracefully

### Repo - Database/Ecto Wrapper

Use for database operations with convenience functions.

```elixir
defmodule MyApp.Repo do
  use Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.MyXQL
end

# Wait for warmup
:ok = Repo.wait_for_warmup()

# Convenience functions with tagged tuples
{:ok, user} = MyApp.Repo.fetch(User, 123)
{:ok, user} = MyApp.Repo.fetch_by(User, email: "user@example.com")
{:error, :not_found} = MyApp.Repo.fetch(User, 999)

# Create and save
{:ok, user} = MyApp.Repo.create(%User{name: "John"})
{:ok, user} = MyApp.Repo.save(changeset)

# Query helpers
MyApp.Repo.exists?(from u in User, where: u.active)
MyApp.Repo.count(User)

# Attach logger
Repo.Logger.attach(:my_app)
```

**Best Practices:**

- Use `fetch/2` instead of `get/2` for tagged tuple returns
- Call `wait_for_warmup/0` before starting dependent workers
- Use `Repo.Query` for pagination and conditional queries
- Attach logger in application start

### Cluster - Distributed Infrastructure

Use for automatic node discovery and distributed process management.

```elixir
# Register a global process
GenServer.start_link(
  MyWorker,
  state,
  name: {:via, Cluster.Registry, {ClusterRegistry, :my_worker}}
)

# Look up a process from any node
[{pid, _}] = Cluster.Registry.lookup(ClusterRegistry, :my_worker)

# Start a distributed supervised process
Cluster.DynamicSupervisor.start_child(
  ClusterSupervisor,
  {MyWorker, [name: :worker_1]}
)

# Process groups for pub/sub
Cluster.PG.join(:my_group, self())
Cluster.PG.get_members(:my_group)
```

**Best Practices:**

- Use `ClusterRegistry` for global process registration
- Use `ClusterSupervisor` for distributed supervision
- Use `Cluster.PG` for lightweight pub/sub messaging
- Configure topology in `config/config.exs`

### BeanstalkD - Beanstalkd Job Queue

Use for background job processing with Beanstalkd.

```elixir
# Wait for connection
:ok = BeanstalkD.wait_for_warmup()

# Put jobs
BeanstalkD.put(%{task: "process", id: 123})
BeanstalkD.put(%{email: "user@example.com"}, tube: "emails", priority: 100)

# Consumer
defmodule MyApp.Worker do
  use BeanstalkD.Consumer, tube: "default"

  @impl true
  def handle_job(payload, job_id, _stats) do
    process(payload)
    {:delete, job_id}
  end
end

# Manual reservation
{:ok, job_id, payload} = BeanstalkD.reserve(:my_consumer, 5)
BeanstalkD.delete(:my_consumer, job_id)
```

**Best Practices:**

- Use `wait_for_warmup/0` before first use
- Use separate tubes for different job types
- Use `BeanstalkD.Consumer` behaviour for workers
- Handle all return values (`:delete`, `:release`, `:bury`)

### ASCO.String - String Case Conversion

Use for converting between different string case formats.

```elixir
# Case detection
ASCO.String.detect_case("my_variable")      #=> :snake_case
ASCO.String.detect_case("myVariable")       #=> :camel_case
ASCO.String.detect_case("MyVariable")       #=> :pascal_case
ASCO.String.detect_case("my-variable")      #=> :kebab_case

# Case checking
ASCO.String.snake_case?("my_variable")      #=> true
ASCO.String.camel_case?("myVariable")       #=> true

# Case conversion
ASCO.String.to_snake_case("myVariable")     #=> "my_variable"
ASCO.String.to_camel_case("my_variable")    #=> "myVariableName"
ASCO.String.to_pascal_case("my_variable")   #=> "MyVariableName"
ASCO.String.to_kebab_case("myVariable")     #=> "my-variable"
```

**Best Practices:**

- Use for API response/request transformations
- Handles acronyms correctly (URL, API, ID, etc.)
- Works with atoms and strings

### LoggerLogfmt - Structured Logging

Use for logfmt-formatted log output.

```elixir
# Configure in config.exs
config :logger, :console,
  format: {LoggerLogfmt, :format},
  metadata: :all

# Logs output in logfmt format:
# level=info msg="User created" user_id=123 email=user@example.com
```

**Best Practices:**

- Use metadata for structured data, not string interpolation
- Enable `:all` metadata for full context
- Pairs well with log aggregation systems

## Development Guidelines

### Before Committing

- Run `mix format` to format code
- Run `mix compile --warnings-as-errors` to ensure no compilation warnings
- Run `mix credo --strict` for static analysis and fix all warnings
- Run `mix dialyzer` for type checking (if available)
- Run `mix test` to ensure all tests pass with no warnings
- Run `mix docs` to verify documentation generates without warnings
- Ensure `README.md`, `QUICKSTART.md`, `USAGE_GUIDE.md`, and `EXAMPLES.md` are updated

### Code Style

- Follow standard Elixir conventions
- Use `@moduledoc` and `@doc` for all public modules and functions
- Use `@spec` type specifications for public functions
- Predicate function names should end in `?` (not start with `is_`)
- Use pattern matching over conditional logic where possible
- Fix all compiler warnings - do not commit code with warnings
- Fix all linter warnings from `mix credo --strict`

### Testing

- Write tests for all public functions
- Use ExUnit and standard Elixir testing patterns
- Run specific test files with `mix test test/path_test.exs`
- Run failed tests with `mix test --failed`
- Use `mix test --cover` for coverage reports
- Tests must run without warnings

### Documentation

- Keep `README.md` concise with quick start examples
- Put detailed documentation in `USAGE_GUIDE.md`
- Put code examples in `EXAMPLES.md`
- Use proper Markdown formatting
- Include `## Example` sections in `@doc` strings
- **Always update documentation when changing functionality**

### Telemetry and Logging

Libraries should follow these patterns for observability:

**Telemetry Module (`lib/my_lib/telemetry.ex`):**

- All telemetry events must be documented in a dedicated `Telemetry` module
- The module must export an `events/0` function listing all events
- Follow naming convention: `[:library_name, :action, :status]`
- Use `:telemetry.execute/3` for emitting events
- Include relevant metadata in events

**Logger Module (`lib/my_lib/logger.ex`):**

- Implement logging in a dedicated `Logger` module
- Base all logging on telemetry events (attach to telemetry handlers)
- Use simple string messages with variable data as metadata
- Never use string interpolation for variable data in log messages

```elixir
# CORRECT: Simple message with metadata
Logger.info("User created", user_id: user.id, email: user.email)
Logger.debug("Request completed", duration_ms: duration, path: path)

# INCORRECT: String interpolation
Logger.info("User #{user.id} created with email #{user.email}")
Logger.debug("Request to #{path} completed in #{duration}ms")
```

## Elixir Guidelines

### Variables and Data

- Elixir variables are immutable but can be rebound
- Lists do not support index-based access via `[]` syntax - use `Enum.at/2`
- Never use `String.to_atom/1` on user input (memory leak risk)
- Use `Map.get/3` with default for optional map access

### Block Expressions

For `if`, `case`, `cond`, etc., bind the result to use it:

```elixir
# VALID: bind the result
socket =
  if connected?(socket) do
    assign(socket, :val, val)
  else
    socket
  end

# INVALID: rebinding inside doesn't work
if connected?(socket) do
  socket = assign(socket, :val, val)
end
```

### Structs and Access

Never use map access syntax (`struct[:field]`) on structs - they don't implement the Access behaviour by default. Always use `struct.field` or specific APIs like `Ecto.Changeset.get_field/2`.

### OTP Primitives

When using `DynamicSupervisor`, `Registry`, etc., always provide names in the child spec:

```elixir
{DynamicSupervisor, name: MyApp.MySupervisor}
{Registry, keys: :unique, name: MyApp.MyRegistry}
```

### Concurrency

- Use `Task.async_stream/3` for concurrent enumeration with back-pressure
- Usually pass `timeout: :infinity` option for long-running tasks
- Use `GenServer` for stateful processes
- Use `Supervisor` for fault tolerance

### Dependencies

- Use `:req` (`Req`) for HTTP requests - avoid `:httpoison`, `:tesla`, `:httpc`
- Use standard library for date/time manipulation (`DateTime`, `Date`, `Time`, `Calendar`)
- Minimize external dependencies in libraries

## Mix Guidelines

- Use `mix help task_name` to read task documentation
- Use `mix deps.get` to fetch dependencies
- Use `mix deps.compile` to compile dependencies
- Avoid `mix deps.clean --all` unless absolutely necessary

## Distributed System Best Practices

### General Patterns

- Test with multiple nodes when possible
- Handle network partitions gracefully
- Use Erlang's `:pg` for process groups
- Use Horde for distributed supervisors and registries

### Telemetry Integration

Libraries should emit telemetry events for observability:

- Document all events in a `Telemetry` module with an `events/0` function
- Use `:telemetry.execute/3` for emitting events
- Follow naming convention: `[:library_name, :action, :status]`
- Include relevant metadata in events
- Implement a `Logger` module that attaches to telemetry events
- Use simple log messages with variable data as metadata
