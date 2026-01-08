# Controllers: Authentication & Authorization

This document describes how authentication and authorization work in
Ktistec controllers, and provides implementation guidance for
developers.

## Table of Contents

- [Overview](#overview)
- [Authentication Framework](#authentication-framework)
- [Authorization Pattern](#authorization-pattern)
- [Implementation Guide](#implementation-guide)
- [Examples](#examples)
- [Testing Authorization](#testing-authorization)
- [Common Patterns](#common-patterns)
- [Best Practices](#best-practices)

## Overview

In Ktistec:
- **Authentication** is handled by a framework handler (`Ktistec::Auth`)
- **Authorization** is implemented in controller methods using the `get_resource` pattern

## Authentication Framework

### How It Works

The `Ktistec::Auth` handler (`src/framework/auth.cr`) runs before every request:

1. Checks if `env.session.account?` returns an authenticated account
2. If authenticated (or route is excluded via `skip_auth`), allows request to proceed
3. If not authenticated, returns **401 Unauthorized**

### Session Management

Sessions are stored in the database and use JWT tokens.

**Available controller methods:**
- `env.account` - Returns authenticated account (raises exception)
- `env.account?` - Returns authenticated account or `nil`

### Skipping Authentication

Use `skip_auth` for public routes that don't require authentication:

```crystal
class MyController
  include Ktistec::Controller

  skip_auth ["/public/resource"], GET
  skip_auth ["/api/public"], GET, POST

  # ... routes ...
end
```

**Important:** `skip_auth` only bypasses authentication. You may still
need authorization logic if the route accesses resources.

## Authorization Pattern

### The Standard Pattern

All resource-level authorization in Ktistec should follow this pattern:

1. **Define private authorization method(s)** at the top of the controller:
   ```crystal
   private def self.get_resource(env, ...)
     # Find resource, return resource if authorized, `nil` otherwise
   end
   ```

2. **Use in routes** with the `unless` pattern:
   ```crystal
   get "/resources/:id" do |env|
     unless (resource = get_resource(env, id_param(env)))
       not_found
     end

     # Use resource...
   end
   ```

### Method Naming Convention

Authorization methods follow the `get_<resource>` naming pattern:

- `get_account(env)` - For Account resources
- `get_account_with_ownership(env)` - For Account resources with account ownership
- `get_object(env, id)` - For ActivityPub::Object resources
- `get_upload(env, path)` - For file uploads

### Return Value Contract

**Authorization methods MUST return:**
- The resource if authorized
- `nil` if unauthorized

**Routes MUST:**
- Return `not_found` (typically) or other appropriate status on
  authorization failure

## Implementation Guide

### Step 1: Define Authorization Method

Place authorization methods at the **top of the controller**,
immediately after `include Ktistec::Controller` and any `skip_auth`
declarations:

```crystal
class MyController
  include Ktistec::Controller

  skip_auth ["/public"], GET

  # Authorizes resource access.
  #
  # Returns the resource if the authenticated user owns it, `nil`
  # otherwise.
  #
  private def self.get_resource(env, id)
    if (resource = Resource.find?(id))
      if (account = env.account?) && account.actor == resource.owner
        resource
      end
    end
  end

  # ... routes ...
end
```

**Documentation requirements:**
- Brief summary of authorization logic
- Explicit return value contract
- Usage context if needed

### Step 2: Use in Route Handlers

```crystal
get "/resources/:id" do |env|
  unless (resource = get_resource(env, id_param(env)))
    not_found
  end

  ok "resources/show", env: env, resource: resource
end

delete "/resources/:id" do |env|
  unless (resource = get_resource(env, id_param(env)))
    not_found
  end

  resource.destroy

  redirect resources_path
end
```

## Testing Authorization

### Test Structure

Authorization tests have two parts:

1. **Direct authorization method tests** - Test the `get_resource` method in isolation
2. **Integration route tests** - Test complete request/response cycle

### Direct Authorization Tests

Test the authorization method directly by making it public:

```crystal
...

# redefine as public for testing
class FiltersController
  def self.get_filter_term(env, id)
    previous_def(env, id)
  end
end

Spectator.describe FiltersController do
  setup_spec

  let(actor) { register.actor }

  describe ".get_filter_term" do
    let(env) { make_env("GET", "/") }
    let_create!(:filter_term, named: test_term, actor: actor, term: "test")
    let_create!(:filter_term, named: other_term, term: "other")

    it "returns nil" do
      result = FiltersController.get_filter_term(env, test_term.id)
      expect(result).to be_nil
    end

    context "when authenticated" do
      sign_in(as: actor.username)

      it "returns the filter term" do
        result = FiltersController.get_filter_term(env, test_term.id)
        expect(result).to eq(test_term)
      end

      it "returns nil if user does not own the term" do
        result = FiltersController.get_filter_term(env, other_term.id)
        expect(result).to be_nil
      end

      it "returns nil if the term does not exist" do
        result = FiltersController.get_filter_term(env, 999999_i64)
        expect(result).to be_nil
      end
    end
  end
end
```

### Integration Route Tests

Test complete HTTP request/response cycle:

```crystal
describe "DELETE /filters/:id" do
  let(headers) { HTTP::Headers{"Accept" => "text/html"} }

  it "returns 401 if not authorized" do
    delete "/filters/0", headers
    expect(response.status_code).to eq(401)
  end

  context "when authorized" do
    sign_in(as: actor.username)

    let_create!(:filter_term, named: my_term, actor: actor, term: "mine")
    let_create!(:filter_term, named: other_term, term: "other")

    it "returns 404 if term does not exist" do
      delete "/filters/999999", headers
      expect(response.status_code).to eq(404)
    end

    it "returns 404 if term does not belong to actor" do
      delete "/filters/#{other_term.id}", headers
      expect(response.status_code).to eq(404)
    end

    it "redirects if successful" do
      delete "/filters/#{my_term.id}", headers
      expect(response.status_code).to eq(302)
    end

    it "destroys the term" do
      expect { delete "/filters/#{my_term.id}", headers }.
        to change { FilterTerm.count }
    end
  end
end
```

## Common Patterns

### Pattern 1: Simple Ownership

**Use case:** User owns a resource directly.

```crystal
private def self.get_resource(env, id)
  if (resource = Resource.find?(id))
    if (account = env.account?) && account.actor == resource.owner
      resource
    end
  end
end
```

### Pattern 2: Visibility-Based Access

**Use case:** Resource has visibility rules (public/private/unlisted).

```crystal
private def self.get_resource(env, id)
  if (resource = Resource.find?(id))
    if resource.visible?(to: env.account?.try(&.actor))
      resource
    end
  end
end
```

## Summary

**Authentication** (framework-level):
- Handled by `Ktistec::Auth` handler
- Returns 401 if not authenticated
- Use `skip_auth` for public routes

**Authorization** (controller-level):
- Implement `get_resource` methods
- Return resource if authorized, `nil` otherwise
- Use in routes: `unless (resource = get_resource(...)); not_found; end`
- Test both directly and via integration tests

For examples, refer to:
- Framework code: `src/framework/auth.cr`, `src/framework/ext/context.cr`
- Example controllers: `src/controllers/filters.cr`, `src/controllers/relationships.cr`, `src/controllers/uploads.cr`
- Test examples: `spec/controllers/filters_spec.cr`
