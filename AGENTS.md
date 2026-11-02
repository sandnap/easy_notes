# Rails 8.N, Hotwire, Tailwind AI Agent Instructions

This document provides context and guidelines for AI agents working on a Rails codebase.

---

## Tech Stack

| Layer               | Technology                 | Notes                                  |
| ------------------- | -------------------------- | -------------------------------------- |
| **Framework**       | Rails 8.1                  | Use Rails conventions                  |
| **Frontend**        | Hotwire (Turbo + Stimulus) | NO React, Vue, or SPA frameworks       |
| **Styling**         | Tailwind CSS 4             | Use utility classes directly           |
| **Database**        | SQLite                     | All environments, including production |
| **Background Jobs** | Solid Queue                | Runs in Puma process                   |
| **Caching**         | Solid Cache                |                                        |
| **Deployment**      | Kamal 2                    | Docker-based deployment                |
| **PDF Generation**  | Prawn                      | For invoice PDFs                       |

---

## Architecture Patterns

### Controllers

**Follow these patterns:**

1. **Thin controllers** — Move complex logic to services or models
2. **Use concerns for shared behavior:**
3. **Memoize Current.user:**

   ```ruby
   def current_user
     @current_user ||= Current.user
   end
   ```

4. **Extract before_action callbacks:**
   ```ruby
   before_action :set_invoice, only: %i[show edit update destroy]
   before_action :set_customers, only: %i[new create edit update]
   ```

### Query Objects

Location: `app/queries/`

Use for complex filtering or when a controller action has multiple query conditions:

### Service Objects

Location: `app/services/`

Use for:

- Complex business operations
- Actions that span multiple models
- Operations with multiple outcomes (success/failure)

---

## Code Style

### Ruby

- **Use query attributes:** `customer.email?` not `customer.email.present?`
- **Use endless methods for simple getters:** `def resource_name = "customer"`
- **Prefer `tap` for object building:**
  ```ruby
  current_user.invoices.build(defaults).tap do |invoice|
    invoice.amount = project.fee_rate if invoice.project&.fixed?
  end
  ```
- **Use the 2 argument syntax introduced in Rails 7 when creating ENUMS**
  ```ruby
  enum :status, { pending: 0, in_progress: 1, completed: 2 }
  ```

### Views (ERB + Tailwind)

- **Use Tailwind utility classes directly** — no custom CSS unless absolutely necessary
- **Use Hotwire patterns:**
  - Turbo Drive for page navigation
  - `turbo_frame_tag` for inline editing
  - `turbo_stream` for real-time updates
  - Stimulus controllers in `app/javascript/controllers/` for JavaScript behavior
  - Automatic controller registration via `application.js`, IGNORE LINT ERRORS FOR UNREGISTERED CONTROLLERS, THESE ARE FALSE NEGATIVES
- **Prefer hotwire (turbo frames/streams & stimulus) over full page refreshes/loads in order to make it a reactive experience**
- **Use partials** for reusable components (e.g., `_invoice.html.erb`)

### Testing

- **Create tests for new features**
- **Run tests after changes:** `bin/rails test`
- **Run specific test files:** `bin/rails test test/controllers/my_controller_test.rb`
- **All tests should pass**

---

## Linting Standards

### Required Tools

| Tool                    | Purpose             | Command              |
| ----------------------- | ------------------- | -------------------- |
| **Rubocop**             | Style enforcement   | `bin/lint`           |
| **rubocop-performance** | Performance checks  | Included in bin/lint |
| **Brakeman**            | Security scanner    | `bin/lint -s`        |
| **bundler-audit**       | Gem vulnerabilities | `bin/lint -s`        |
| **RubyCritic**          | Complexity analysis | `bin/lint -f`        |

### Lint Commands

```bash
bin/lint        # Standard check (Rubocop)
bin/lint -a     # Auto-fix issues
bin/lint -s     # Include security scans
bin/lint -f     # Include RubyCritic analysis
```

### Expected Results

- **Rubocop:** 0 offenses
- **Brakeman:** 0 security warnings
- **bundler-audit:** No vulnerabilities
- **RubyCritic:** Score > 80

---

## Database Conventions

### Scopes

Define scopes for common queries:

```ruby
scope :ordered, -> { order(issued_date: :desc) }
scope :for_customer, ->(id) { where(customer_id: id) if id.present? }
scope :for_status, ->(status) { where(status: status) if status.present? }
```

### Avoid N+1 Queries

Always use `includes` or `preload`:

```ruby
# Good
@invoices = current_user.invoices.includes(project: :customer).ordered

# Bad
@invoices = current_user.invoices.ordered
# Then in view: invoice.project.customer.name (N+1!)
```

---

## Deployment

### Kamal Commands

```bash
bin/kamal deploy      # Deploy to production
bin/kamal logs        # Tail logs
bin/kamal console     # Rails console
bin/kamal shell       # Bash shell
bin/kamal dbc         # Database console
```

### Database Backups

```bash
bin/backup-production  # Creates backup in .backups/production/
```

---

## Patterns to Avoid

| Don't                         | Do Instead                        |
| ----------------------------- | --------------------------------- |
| React, Vue, or SPA frameworks | Hotwire (Turbo + Stimulus)        |
| Devise for authentication     | Rails 8 authentication generator  |
| Custom CSS files              | Tailwind utility classes          |
| Fat controllers               | Services, query objects, concerns |
| `x.present?` for attributes   | `x?` (query attribute)            |
| Magic strings for colors      | Constants                         |

---

## File Organization

```
app/
├── controllers/
│   ├── concerns/
│   │   ├── authentication.rb
│   └── [resource]_controller.rb
├── models/
│   └── [model].rb
├── queries/
│   └── [model]_query.rb
├── services/
│   └── my_service.rb
└── views/
    └── [resource]/
        ├── index.html.erb
        ├── show.html.erb
        ├── _[resource].html.erb  (partial for turbo_frame)
        └── _form.html.erb
```

---

## Commit Guidelines

- **Run tests before committing:** `bin/rails test`
- **Run linter before committing:** `bin/lint`
- **Use descriptive commit messages:**
  - `Refactored my_controller with my_service`
  - `Fixed N+1 query in dashboard`

---

## Questions to Ask

When unsure, ask about:

- Whether to use a service vs. model method
- Trade-offs between approaches
- If a change requires a migration
- Whether the change affects production data
