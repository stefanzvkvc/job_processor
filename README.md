# JobProcessor

A lightweight Elixir application that exposes an HTTP endpoint for submitting tasks. Tasks can have dependencies, which will be used to determine their execution order.

## Setup

### Requirements

- Elixir
- Erlang/OTP
- Mix

### Install dependencies

```bash
mix deps.get
```

## Running the application

Start the application with:

```bash
mix run --no-halt
```

The server's port is determined by the application configuration. The examples below assume it is listening on port `4000`.

### Example request

Submit tasks to the `/tasks` endpoint:

```bash
curl -X POST http://localhost:4000/tasks \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "tasks": [
      {
        "name": "task-1",
        "command": "touch /tmp/file1"
      },
      {
        "name": "task-2",
        "command": "cat /tmp/file1",
        "requires": ["task-1"]
      }
    ]
  }'
```

## Running tests

Run the test suite with:

```bash
mix test
```

## Design decisions

### Minimal HTTP stack

Instead of using the full Phoenix framework, I chose Elixir with Plug and Plug.Cowboy. The project currently requires only a simple HTTP endpoint, so a full web framework would introduce additional complexity without providing much immediate value.

### Single endpoint without a router

The application currently exposes a single route: `POST /tasks`. I chose to implement the request handling directly with Plug rather than introduce a router dependency. This keeps the routing and request-validation logic straightforward for the current scope.

If the application grows to support more endpoints, introducing a router could become worthwhile.

### Response format negotiation

The application is intended to support both JSON and Bash script responses. I plan to use the request's `Accept` header to determine the preferred response format.

If the client does not provide an `Accept` header, the application will default to JSON.

### Request validation

Request validation is separated into two stages:

1. **Body structure validation:** Ensure the request contains a non-empty `tasks` list and that each item is a JSON object.
2. **Task validation:** Validate individual task fields using an embedded Ecto schema and changesets.

This separation keeps HTTP request handling distinct from task-specific validation and makes the validation rules easier to test and maintain.

### Validation of `requires`

The `requires` field is optional. If omitted, the request is considered valid without dependencies.

Ecto casting handles blank values in arrays. An array containing only blank strings, such as `[" ", "  "]`, may be cast to an empty list (`[]`). In this case, custom changeset validation rejects the request with an error indicating that `requires` cannot be an empty list.

If the array contains at least one non-blank value, blank elements may be discarded during casting. For example, `["task-1", " "]` may be cast to `["task-1"]` and accepted.

I chose this approach to keep validation simple and avoid introducing custom trimming or normalization that could unintentionally modify task names.

### Consistent error responses

Error responses use a consistent JSON structure containing:

- `status` — indicates success or failure.
- `message` — provides a human-readable summary.
- `errors` — contains field-specific validation errors, or an empty object when there are none.

This allows clients to handle errors consistently without having to parse language-specific error representations.

### Testing

The Plug and request validation are covered by ExUnit tests. The tests exercise HTTP method and path checks, request body structure, task field validation, and successful requests.

This provides a foundation for adding dependency validation and task-ordering tests as the topology-sorting logic is implemented.
