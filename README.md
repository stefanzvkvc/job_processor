# JobProcessor

A lightweight Elixir application that exposes an HTTP endpoint for submitting jobs. A job is a list of tasks, each with a name and a shell command. Tasks can depend on other tasks, and the service returns them in an order where every task comes after the tasks it requires, either as JSON or as a ready-to-run bash script.

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

The server listens on port `4000`.

### Example payload

Save the challenge example as `example.json`:

```json
{
  "tasks": [
    { "name": "task-1", "command": "touch /tmp/file1" },
    { "name": "task-2", "command": "cat /tmp/file1", "requires": ["task-3"] },
    { "name": "task-3", "command": "echo 'Hello World!' > /tmp/file1", "requires": ["task-1"] },
    { "name": "task-4", "command": "rm /tmp/file1", "requires": ["task-2", "task-3"] }
  ]
}
```

### Get the sorted tasks as JSON

```bash
curl -X POST http://localhost:4000/tasks \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d @example.json
```

Response (`200 OK`):

```json
{
  "status": "success",
  "tasks": [
    { "name": "task-1", "command": "touch /tmp/file1" },
    { "name": "task-3", "command": "echo 'Hello World!' > /tmp/file1" },
    { "name": "task-2", "command": "cat /tmp/file1" },
    { "name": "task-4", "command": "rm /tmp/file1" }
  ]
}
```

### Get the sorted tasks as a bash script

```bash
curl -X POST http://localhost:4000/tasks \
  -H "Content-Type: application/json" \
  -H "Accept: text/plain" \
  -d @example.json
```

Response (`200 OK`, `text/plain`):

```bash
#!/usr/bin/env bash
touch /tmp/file1
echo 'Hello World!' > /tmp/file1
cat /tmp/file1
rm /tmp/file1
```

### Run the generated script

To test execution end to end, pipe the script into `bash`:

```bash
curl -s -X POST http://localhost:4000/tasks \
  -H "Content-Type: application/json" \
  -H "Accept: text/plain" \
  -d @example.json | bash
```

This prints `Hello World!`. The service itself never runs commands (see [Security](#security)), so only pipe scripts into `bash` when you trust their contents.

### Example error

A circular dependency returns `422 Unprocessable Entity`:

```bash
curl -X POST http://localhost:4000/tasks \
  -H "Content-Type: application/json" \
  -d '{"tasks": [
        {"name": "a", "command": "echo a", "requires": ["b"]},
        {"name": "b", "command": "echo b", "requires": ["a"]}
      ]}'
```

```json
{
  "status": "error",
  "message": "Circular dependency among: a, b",
  "errors": {}
}
```

## Running tests

Run the test suite with:

```bash
mix test
```


## Design decisions

### Minimal HTTP stack

Instead of using the full Phoenix framework, I chose Elixir with Plug and Plug.Cowboy. The project only requires a single HTTP endpoint, so a full web framework would introduce additional complexity without providing much immediate value.

### Single endpoint without a router

The application exposes a single route: `POST /tasks`. I chose to implement the request handling directly with Plug rather than introduce a router. This keeps the routing and request-validation logic straightforward for the current scope.

If the application grows to support more endpoints, `Plug.Router` would become worthwhile.

### Response format negotiation

The response format is chosen from the request's `Accept` header:

- `Accept: text/plain` returns the bash script as plain text.
- Anything else, including a missing header or `*/*` (curl's default), returns JSON.

The bash script is returned without the JSON envelope, so it can be piped directly into `bash`. Errors are always returned as JSON.

### Request validation

Request validation happens in stages, each with its own status code:

1. **Body parsing:** Malformed JSON returns `400`. A non-JSON `Content-Type` returns `415`.
2. **Body structure:** The body must contain a non-empty `tasks` list, and each item must be a JSON object (`400`).
3. **Task fields:** Each task is validated with an embedded Ecto schema and changeset (`400`). Errors are reported for every invalid task, keyed by its position, for example `tasks[1]`.
4. **Dependencies:** The sorter rejects duplicate task names, unknown dependencies and circular dependencies (`422`).

This separation keeps HTTP request handling distinct from task-specific validation and makes each set of rules easier to test and maintain.

I chose Ecto for task validation instead of writing my own checks. Ecto is the standard tool for this in Elixir, and it already handles casting, required fields, type errors and blank values consistently. Writing my own validation would have meant re-implementing that edge-case handling myself, which is error-prone.

### Validation of `requires`

The `requires` field is optional. If it is omitted, `null` or an empty list `[]`, the task has no dependencies. An empty list and a missing key mean the same thing, and many clients serialize empty arrays as `[]`, so both are accepted.

Blank or `null` entries are rejected, for example `[" "]` or `["task-1", null]`. A blank entry usually points to a client bug, such as an empty form field, and silently dropping it could let a task run before something it was meant to wait for. Ecto removes blank array elements during casting, so this check reads the raw request parameters to see exactly what the client sent.

Names are never trimmed or normalized: `" task-1 "` stays as sent and is reported as an unknown dependency. This avoids silently changing task names.

### Sorting algorithm

The sorter repeatedly takes the first remaining task whose dependencies are all done, adds it to the output, and marks it as done. If tasks remain but none of them is ready, they form (or depend on) a cycle, and the request is rejected.

- **Deterministic:** Tasks are scanned in input order, so independent tasks keep their submitted order, and the same input always produces the same output.
- **Simple to verify:** A task is only emitted after all of its dependencies have been emitted.
- **Complexity:** Roughly O(n²) for n tasks, which is instant for realistic job sizes. I kept this version for readability. For very large jobs, there are two faster options:
  - **Kahn's algorithm** with an in-degree map and `:queue`.
  - **Erlang's `:digraph_utils.topsort/1`**, which needs no extra dependency.
- **Trade-off:** The cycle error lists every task that can never run, which can include tasks that only depend on a cycle rather than being part of it. A depth-first search could report the exact loop, at the cost of more complex code.

Duplicate names and unknown dependencies are checked before sorting, so the sorting loop only has to deal with valid tasks.

### Synchronous processing

Sorting runs synchronously within the request:

1. The client sends `POST /tasks`.
2. The server validates and sorts the tasks in memory.
3. The server responds `200 OK` with the sorted JSON or the bash script.

I chose this over an asynchronous design because:

- The work is fast. The service only reorders data in memory, and sorting finishes almost instantly.
- There is no slow dependency, such as a third-party call or heavy computation, that would justify background processing.
- An async version would be over-engineering for this task. It would need:
  - a `202 Accepted` response with a job ID,
  - a second endpoint (for example `GET /jobs/:id`) for the client to poll,
  - storage for job state and results, plus cleanup.

If sorting ever became slow, for example with very large jobs, moving to that async flow would be the natural next step.

### Consistent responses

All JSON responses share the same structure:

- `status` — `"success"` or `"error"`.
- `tasks` — the sorted tasks, on success.
- `message` — a human-readable summary, on error.
- `errors` — field-specific validation errors, or an empty object when there are none.

| Status | Meaning |
| --- | --- |
| `200` | Tasks sorted |
| `400` | Malformed JSON, invalid body structure or invalid task fields |
| `404` | Unknown path |
| `405` | Method other than `POST` |
| `415` | `Content-Type` is not `application/json` |
| `422` | Duplicate names, unknown dependency or circular dependency |

This allows clients to handle errors consistently without having to parse language-specific error representations.

### Security

The service never executes commands. It only orders them and returns them. Running the generated script (for example by piping it into `bash`) is the caller's decision and responsibility.

In production, a service like this would usually sit behind an API gateway that handles rate limiting, blocks abusive clients and drops malicious traffic before it reaches the application. The challenge doesn't include that layer, so within the service itself I would add rate limiting per client IP with the [Hammer](https://hex.pm/packages/hammer) library to protect against request floods.

Two further limits would keep the synchronous design safe with large inputs:

- **Request size limit.** `Plug.Parsers` accepts bodies up to 8 MB by default. Lowering it with the `:length` option keeps one request from tying up the server.
- **Maximum number of tasks.** Capping the task count keeps the sorter's worst case bounded.

### Testing

The test suite covers:

- **The sorter:** ordering of the challenge example, input order for independent tasks, and each error (duplicates, unknown dependency, cycle).
- **Task validation:** required fields, blank values, and invalid or blank `requires` entries.
- **The Plug:** method and path checks, malformed JSON, unsupported content types, body structure, task field validation, the `422` dependency errors, and successful JSON and bash responses.
