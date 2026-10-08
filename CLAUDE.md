# L&D Playbook - Development Notes

## Architecture
- Single-page app in `web/index.html` (~5800+ lines), backed by Supabase
- `AutoLayout.layout()` — flowchart layout engine (inside IIFE), produces nodes + connections
- `DiagramRender.render()` — renders layout into DOM as SVG arrows + HTML boxes

## Flowchart Arrow Routing Rules

### Fan-in bus
- When multiple edges from the same depth converge on one target, they share a horizontal bus
- The bus routes through a shared trunk (`trunkSX`) with a gap before the target box, then enters horizontally from the side
- Same-lane edges MUST be included in the fan-in bus (do NOT exclude with `a.lane !== b.lane`) — all converging arrows should enter the target from the same side via the shared bus for visual consistency
- The trunkSX gap is calculated as `Math.max(COL_GAP, b.w * 0.35)` to ensure arrows don't run along the box edge

### Back-edge detection
- `findBackEdges()` uses DFS with post-processing to prefer "No" decision edges as back-edge candidates
- This ensures decision "No" branches (reject/retry loops) are rendered as back-edges going upward

### Fan-out stagger
- Only stagger within same-lane groups of 3+ children
- Cross-lane fan-outs should NOT be staggered (they naturally sit in different lanes)

## Key Constants
- `COL_GAP = 34`, `ROW_GAP = 52`, `LANE_PAD = 16`, `CANVAS_PAD = 30`, `BACK_GAP = 30`

## Testing
- Use Playwright for visual testing of diagram rendering
- Chromium: `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`
- Node path: `NODE_PATH=/opt/node22/lib/node_modules`

## Dev Branch
- Feature branch: `claude/github-pages-actions-setup-9vw00o` (reset to origin/main after each squash merge)
