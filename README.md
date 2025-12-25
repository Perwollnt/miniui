# miniui — tiny UI + templating for CC:Tweaked

A minimal, fast layout/templating engine for CC:Tweaked monitors and terminals. Write simple markup, bind data with `{{mustache}}`, and render responsive UIs with padding, gaps, colors, rows/columns, click handlers, and a tiny VDOM.


I do not know how to make an installer, if you can help me with this id appreaciate a message
---

## Highlights

- String templates with `{{var}}`, lists/conditionals `{{#list}}…{{/list}}`, and partials `{{import "path"}}`
- Lightweight markup: `<col>`, `<row>`, `<box>`, `<text>`, `<spacer>`, `<click on="...">`
- Inline styles: width/height, `%` or absolute units, padding/margin, gap, `color`/`bg`
- Word-wrapping text and simple progress “bars” with boxes
- Event system for clickable regions
- One-shot render or managed loop with ticking and state
- Render to any terminal or monitor; auto-scales monitors to textScale 0.5
- Optional HTML → mini markup shim
- Programmatic VDOM builder API

---

## Install

1. Copy the `miniui/` folder to your computer (e.g., `/miniui`).
2. In your program:

```lua
local UI = require("miniui/ui")
```

> `ui.lua` adjusts `package.path` so `require("miniui/...")` works even if your script isn’t in the same folder.

---

## Quick start

**Template (screen_1.tpl):**
```html
<col style="padding:1; gap:1; bg:gray">
  <row style="gap:1">
    <box style="width:33%; bg:black; padding:1">
      <text style="color:white">{{left_list}}</text>
    </box>
    <box style="width:33%; bg:black; padding:1">
      <text style="color:white">{{middle_list}}</text>
    </box>
    <click on="inc" style="width:33%; bg:black; padding:1">
      <text style="color:yellow">Energy {{energy.used}}/{{energy.cap}} ({{energy.pct}}%)</text>
      <box style="height:1; bg:lightGray">
        <box style="width:{{energy.pct}}%; height:1; bg:orange"></box>
      </box>
    </click>
  </row>
</col>
```

**Code:**
```lua
local UI = require("miniui/ui")
local mon = "monitor_8"             -- or leave nil to use current term

local function buildData(state)
  return {
    left_list = "Iron x2.1k\\nCopper x5.2k",
    middle_list = "Gold x640\\nCoal x12.4k",
    energy = { used="12.3m", cap="64m", pct=34 },
  }
end

local handlers = {
  inc = function(evt, state, rerender)
    state.clicks = (state.clicks or 0) + 1
    rerender()
  end
}

-- You have to parse your own templates for now
-- I might add a render that just accepts file and monitor name with some data
local function view(state)
  local ctx = buildData(state)
  local f = fs.open("screen_1.tpl","r"); local tpl = f.readAll(); f.close()
  return UI.tpl(tpl, ctx, { base = "." })
end

UI.run(view, mon, handlers, { clicks=0 }, {
  tick = 1,                                 -- optional: repaint every second
  onTick = function(s) s.time = (s.time or 0)+1 end,
  afterRender = function(s, frame) end
})
```

---

## Markup

Elements:

- `<col>` vertical stack  
- `<row>` horizontal stack  
- `<box>` generic block container  
- `<text>` word-wrapped text  
- `<spacer>` empty block (defaults `height:1`)  
- `<click on="handlerName">` clickable container

Children nest naturally. Unknown tags are ignored.

### Inline styles

All via `style="..."`:

- `width`, `height`: `auto` (default), absolute (`3`), or percent (`50%`)
- `padding`, `margin`: `N` (all sides), `X Y` (left/right, top/bottom), or `L T R B` (four-side)
- `gap`: spacing between children in rows/cols
- `color`, `bg`: any CC color name (`white, orange, ... black`)  
  Hex and rgb may be parsed when supported; prefer CC names.

> Layout computes absolute positions, then renderer paints backgrounds and text. Text wraps to the inner width of the box.

---

## Templating

`UI.tpl(str, ctx, { base })` supports:

- Variables: `{{var}}` (nested: `user.name`)
- Current item: `{{.}}`
- Lists/conditionals:
  ```mustache
  {{#items}}
    <text>{{.}}</text>
  {{/items}}

  {{#cond}}Shown when truthy{{/cond}}
  ```
- Partials: `{{import "relative/or/absolute/path"}}`  
  `base` sets the resolution root for imports.

---

## Rendering APIs

### One-shot

```lua
local frame = UI.render(markup_or_vdom, target)
-- frame.window : the created window
-- frame.root   : the computed VDOM tree (with layout)
-- frame.hits   : click hitboxes [{rect,..., on="handler"}]
```

- `markup_or_vdom`: a string with mini markup or a Node built with `UI.h`.
- `target`: a monitor name, a terminal-like object, or `nil` for `term.current()`.

Also:

```lua
UI.renderFile("path.tpl", target)
```

### Managed loop

```lua
UI.run(viewFn, target, handlers?, initState?, opts?)
```

- `viewFn(state) -> markupStringOrNode`
- `handlers = { name = function(evt, state, rerender) ... end }`  
  Bound via `<click on="name">...</click>`
- `opts.tick = seconds` (repains on a timer; optional)
- `opts.onTick(state)` called before each tick repaint
- `opts.afterRender(state, frame)` called after each render
- `UI.requestRerender()` queues an immediate repaint from anywhere

`evt` passed to handlers includes `{ x, y, node }`.  
Call `rerender()` to repaint after mutating `state`.

---

## VDOM builder (optional)

Build nodes programmatically:

```lua
local n = UI.h("row", { style = { gap = "1" } }, {
  UI.h("box", { style = { width = "50%", padding = "1" } }, {
    UI.h("text", { _text = "Hello" })
  })
})

UI.render(n, "monitor_1")
```

> `UI.h(tag, props, children)` merges `props.style` with tag defaults.

---

## HTML shim (optional)

```lua
local mini = UI.htmlToMini("<div style=\\"padding:1\\"><p>Hello</p></div>")
UI.render(mini, "monitor_2")
```

The shim translates a small subset:
- `div → box`, `p/span → text`, `<br>` → newline, wraps in `<col>`

---

## Color names

Use CC constants by name:
`white, orange, magenta, lightBlue, yellow, lime, pink, gray, lightGray, cyan, purple, blue, brown, green, red, black`.

---

## Tips

- Prefer `%` widths inside rows/cols to split space.
- Progress bars: nest a child box with `width:{{pct}}%` inside a 1-row parent.
- For big lists, render once and only rerender when data changes.
- Use `UI.attach(target)` to coerce targets (`"monitor_2"`, term) when needed.

---

## API Reference

```lua
UI.attach(targetLike) -> terminal
UI.tpl(str, ctx, { base? }) -> string
UI.render(markupOrNode, target?) -> { window, root, hits }
UI.renderFile(path, target?) -> same as render
UI.htmlToMini(html) -> markupString
UI.h(tag, props?, children?) -> Node
UI.run(view, target?, handlers?, state?, {
  tick?, onTick?(state), afterRender?(state, frame)
})
UI.requestRerender()
```

---

## Requirements

- CC:Tweaked (ComputerCraft) environment
- For monitors: `peripheral.wrap("monitor_x")` must exist
