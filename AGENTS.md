# Easy Notes — AI Agent Instructions

Easy Notes is a personal note-taking app. Users sign in, group notes into categories, and edit rich-text notes (formatting, links, and images) in a single main pane. Prefer Hotwire so the UI stays on the page.

This document is the source of truth for agents. `CLAUDE.md` only points here.

---

## Tech Stack

| Layer | Technology | Notes |
| --- | --- | --- |
| **Language** | Ruby 3.3.4 | |
| **Framework** | Rails `~> 8.0.1` | Follow Rails conventions. Schema format is `ActiveRecord::Schema[8.0]`. |
| **Frontend** | Hotwire (Turbo + Stimulus) | Import maps. No JS bundler, React, Vue, or other SPA frameworks. |
| **Rich text** | Action Text | `Note` uses `has_rich_text :content`. Images go through Active Storage. |
| **Styling** | CSS Zero `~> 0.0.89` | Utility classes in ERB. Stay on 0.0.x; 1.0 renamed utilities and breaks the views. Migrate views before bumping the gem. |
| **Database** | SQLite | All environments, including production. |
| **Auth** | Rails 8 authentication generator | `has_secure_password`, `Session`, `Authentication` concern. No Devise. |
| **Background jobs** | Solid Queue | Runs in the Puma process when `SOLID_QUEUE_IN_PUMA` is set. |
| **Caching** | Solid Cache | |
| **WebSockets** | Solid Cable | |
| **Deployment** | Kamal 2 | Docker. Production host is `notes.optimalcadence.com`. |

Seeded local login: `test@example.com` / `password`.

---

## Domain

```
User
 └── has_many :categories
      └── has_many :notes   (ordered by position, counter_cache on category)
           └── has_rich_text :content
```

- Scope every read and write to `Current.user`. `Current` stores the session and delegates `user`.
- Notes belong to a category. Position is set on create and updated by `NotesController#sort`.
- Search lives in `NoteSearchQuery` (`app/queries/note_search_query.rb`): title and rich-text body, limited to the current user's notes.
- Export and import are in `ExportImportController`.

There is no `app/services/` directory yet. Put multi-model work or multi-outcome operations there when a model method would be the wrong place. Put complex filtering in `app/queries/`.

---

## Architecture Patterns

### Controllers

Keep controllers thin. Shared auth behavior belongs in `Authentication`.

Use `before_action` to load records, and always load them through the current user:

```ruby
before_action :set_category, except: [ :show ]
before_action :set_note, only: [ :edit, :update, :sort ]

def set_category
  @category = Current.user.categories.find(params[:category_id])
end
```

The signed-in user is `Current.user` (from `Current.session`). Do not add a separate `current_user` helper unless a call site needs it.

Respond with Turbo Streams for in-page updates and keep an HTML format for full loads. The editor target is `#main_frame`:

```ruby
format.turbo_stream do
  render turbo_stream: turbo_stream.update("main_frame", partial: "form", locals: { note: @note })
end
format.html { render :edit }
```

### Query objects

Location: `app/queries/`. Use one when a controller action has several query conditions. See `NoteSearchQuery`.

### Service objects

Location: `app/services/` (create it when needed). Use for work that spans models or has more than one outcome.

---

## Code Style

### Ruby

Follow RuboCop Omakase (`rubocop-rails-omakase`, plus `rubocop-performance`).

- Use query attributes: `category.name?`, not `category.name.present?`.
- Use endless methods for simple getters: `def resource_name = "note"`.
- Use the Rails 7+ two-argument enum syntax if an enum is added: `enum :status, { pending: 0, completed: 1 }`.
- Preload associations. The home and category lists already do `Current.user.categories.includes(:notes)`.

### Views (ERB + CSS Zero)

- Use CSS Zero utility classes in the templates. Avoid new custom stylesheets.
- Do not introduce Tailwind class names. This app is not on Tailwind.
- Hotwire:
  - Turbo Drive for ordinary navigation.
  - `turbo_stream` to update `#main_frame`, the sidebar, and the flash partial.
  - Stimulus controllers in `app/javascript/controllers/`. App-specific ones include autosave, sortable, keyboard, vim editor, search, and URL sync. Controllers register through `application.js`. Ignore lint warnings about unregistered Stimulus controllers; those are false negatives.
- Prefer Turbo and Stimulus over full-page reloads.
- Use partials for repeated markup (`categories/_note`, `notes/_form`, `shared/_flash`).

### Testing

- Add tests for new behavior.
- Run the suite with `bin/rails test`.
- Run one file with `bin/rails test test/controllers/notes_controller_test.rb`.
- All tests should pass.

---

## Linting Standards

| Tool | Purpose | Command |
| --- | --- | --- |
| **RuboCop** | Style | `bin/lint` |
| **rubocop-performance** | Performance | Included in `bin/lint` |
| **Brakeman** | Security | `bin/lint -s` |
| **bundler-audit** | Gem vulnerabilities | `bin/lint -s` |
| **RubyCritic** | Complexity | `bin/lint -f` |

```bash
bin/lint        # RuboCop
bin/lint -a     # Auto-fix
bin/lint -s     # Brakeman + bundler-audit
bin/lint -f     # RuboCop + RubyCritic
```

Expected: RuboCop with 0 offenses, Brakeman with 0 warnings, no known gem vulnerabilities, RubyCritic score above 80.

---

## Database Conventions

SQLite everywhere. Add scopes for repeated filters, and guard optional filters:

```ruby
scope :ordered, -> { order(position: :asc) }
scope :for_category, ->(id) { where(category_id: id) if id.present? }
```

Avoid N+1 queries with `includes` or `preload`:

```ruby
@categories = Current.user.categories.includes(:notes).order("notes.position ASC")
```

Category `notes_count` is a counter cache. Do not maintain that column by hand.

---

## Deployment

```bash
bin/kamal deploy      # Deploy to production
bin/kamal logs        # Tail logs
bin/kamal console     # Rails console
bin/kamal shell       # Bash shell
bin/kamal dbc         # Database console
```

```bash
bin/backup-production  # Writes a backup under .backups/production/
```

Local app: `bin/rails db:migrate`, `bin/rails db:seed`, then `bin/dev` at `http://localhost:3000`.

---

## Patterns to Avoid

| Don't | Do instead |
| --- | --- |
| React, Vue, or a JS bundler | Hotwire, import maps, Stimulus |
| Devise | The existing `Authentication` concern and `Session` model |
| Tailwind or a CSS Zero 1.0 upgrade | CSS Zero `~> 0.0.89` utility classes |
| Fat controllers | Models, `app/queries/`, concerns, or a service when the work spans models |
| `x.present?` on attributes | `x?` |
| Unscoped `Note.find` / `Category.find` | `Current.user.categories.find` and notes reached through those categories |

---

## File Organization

```
app/
├── controllers/
│   ├── concerns/
│   │   └── authentication.rb
│   ├── categories_controller.rb
│   ├── notes_controller.rb
│   ├── search_controller.rb
│   └── export_import_controller.rb
├── models/
│   ├── user.rb
│   ├── category.rb
│   ├── note.rb
│   └── current.rb
├── queries/
│   └── note_search_query.rb
├── javascript/controllers/
└── views/
    ├── categories/
    ├── notes/
    │   └── _form.html.erb
    ├── home/
    └── shared/
```

---

## Commit Guidelines

- Run `bin/rails test` and `bin/lint` before committing.
- Use a descriptive message that says why the change exists, for example `Fixed N+1 when loading the category sidebar`.

---

## Questions to Ask

When unsure, ask about:

- Model method versus a new query or service object
- Whether the change needs a migration
- Whether the change affects production notes or categories
- A CSS Zero major-version bump (views must move first)
