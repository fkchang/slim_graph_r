# Nested containment diagrams

Use `:nested` when the meaning is scope through containment: an organization contains a repository, a repository contains a workspace, and a workspace contains a task. The outer scope is broader; the innermost scope is the most specific. Use `:tree` for branching ownership and `:layers` for parallel stack bands.

## Standalone Ruby

Write one `scope` chain. A scope block may contain one nested `scope`; the innermost scope has no child. The innermost level receives the automatic focal accent, so there is no per-scope `focal` option.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :nested,
  title: 'Instruction cascade',
  style: :editorial,
  theme: :light do
  scope :organization, 'Organization' do
    scope :repository, 'Repository' do
      scope :workspace, 'Workspace' do
        scope :task, 'Task'
      end
    end
  end
end

File.write('instruction-cascade.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

The chain must contain 3–5 scopes. IDs are globally unique and labels are nonblank; omitted labels are humanized from IDs. Nested containment uses fixed `:down` direction, including its default. The model is immutable after construction. `to_svg` produces portable SVG and `to_html` produces a self-contained page.

## Equivalent strict JSON

JSON represents the same chain recursively as `scope: { id, label?, scope? }`. The Ruby and JSON examples use identical title, style, theme, labels, and four levels. The innermost object omits `scope` because it has no child.

```json
{
  "type": "nested",
  "title": "Instruction cascade",
  "style": "editorial",
  "theme": "light",
  "scope": {
    "id": "organization",
    "label": "Organization",
    "scope": {
      "id": "repository",
      "label": "Repository",
      "scope": {
        "id": "workspace",
        "label": "Workspace",
        "scope": {"id": "task", "label": "Task"}
      }
    }
  }
}
```

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('instruction-cascade.json'))
File.write('instruction-cascade.svg', diagram.to_svg)
diagram
```

`File.read` is the intended local UTF-8 file path. The parser validates the data and does not execute it. Explicit nulls, arrays in place of the recursive scope, unknown or cross-type fields, duplicate IDs, missing intermediate scopes, and branching raise `SlimGraphR::Error`. The optional top-level `description` replaces the generated chain description.

## CLI and StreamWeaver

```sh
slimgraph render instruction-cascade.rb -o instruction-cascade.svg
slimgraph render instruction-cascade.json -o instruction-cascade.html --format html
```

JSON is the default for stdin; use `--input-format ruby` for Ruby stdin. `--style` and `--theme` override presentation without mutating the model.

The optional StreamWeaver form uses the same DSL:

```ruby
require 'slim_graph_r/stream_weaver'

diagram :nested, title: 'Instruction cascade', style: :editorial, theme: :light do
  scope :organization, 'Organization' do
    scope :repository, 'Repository' do
      scope :workspace, 'Workspace' do
        scope :task, 'Task'
      end
    end
  end
end
```

No StreamWeaver installation is needed for core rendering. Inspect the complete page at its target and narrow widths because producing an SVG string or pushing a canvas document alone does not prove the page layout works.

## Layout, limits, and parity boundary

The renderer uses regular 28px horizontal and 34px vertical insets between rounded rectangles. Each scope label sits in a paper-colored mask over its ring's top border. Stroke strength progresses inward; only the innermost scope is focal. The innermost content area starts at 240×112px. Scope labels exceeding the bounded 880px outer ring, or labels that cannot fit their regular ring, raise `SlimGraphR::LayoutError` rather than becoming irregular or clipped.

The model requires one uninterrupted chain of 3–5 scopes. A scope cannot contain sibling scopes or arbitrary content, and there are no authored coordinates, icons, annotations, or graph edges. The innermost focal treatment is automatic.

This is partial parity with the pinned [Cathryn Lavery Diagram Design nested-containment reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-nested.md). Full editorial callouts, file glyphs, sibling content, custom colors, and unrestricted-depth containment remain deferred. The independent renderer preserves upstream attribution and the MIT notice under `vendor/diagram-design`; it does not claim complete upstream parity.
