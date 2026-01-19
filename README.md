# zf-template — Zero Frame Script Template (qbox/qbx)

This resource is a **copy/paste starter template** for building new ZF scripts fast.

It standardizes:
- Resource structure
- Event naming conventions
- A clean client UI layer (notify / confirm / input / minigame)
- A simple client↔server example to extend

## Dependencies

### Required
- `zf-core`

### Optional (auto-detected)
- `zf-notify` (used for notifications if running)
- `zf-ui` (used for Confirm/Input if running)
- `zf-minigame` (used for skillchecks if running)

If optional resources are missing, the template will not crash; it will:
- fallback to `zf-ui` notify (if available)
- or fallback to printing in console

## Install

1) Place it in your resources folder:

resources/[zf]/zf-template


2) Ensure it:
```cfg
ensure zf-core
ensure zf-template


(If you want full functionality, also ensure:)

ensure zf-notify
ensure zf-ui
ensure zf-minigame

Test

In-game:

/zftest


This will:

Toast notify

Confirm dialog (zf-ui)

Input dialog (zf-ui)

Run minigame (zf-minigame)

Send an example payload to server and show a result notification

Event Naming Standard (ZF style)

Client events:

zf-<script>:client:<action>

Server events:

zf-<script>:server:<action>

Example included:

Client triggers: zf-template:server:exampleAction

Server replies: zf-template:client:exampleResult

Client API Wrappers

These exist in client/main.lua:

Notify(message, type, duration, title)

Prefers zf-notify, fallback to zf-ui notify.

Notify('Hello', 'success', 2500, 'My Script')

Confirm(title, message, confirmLabel, cancelLabel)

Requires zf-ui.
Returns boolean.

local ok = Confirm('Delete', 'Are you sure?', 'Delete', 'Cancel')

Input(title, fields)

Requires zf-ui.
Returns table array or nil.

local res = Input('Rename', {
  { type='input', label='Name', required=true }
})

Minigame(opts)

Requires zf-minigame.
Returns boolean.

local ok = Minigame({ title='Lockpick', speed=1.1, zoneSize=0.12, roundTime=8000 })

Optional Exports

The template also exports these so other scripts can call them if you want:

exports['zf-template']:Notify(...)

exports['zf-template']:Confirm(...)

exports['zf-template']:Input(...)

exports['zf-template']:Minigame(...)

(You probably won’t use that long-term; your real framework should expose these via zf-core or zf-bridge later.)

What to do next

Copy zf-template/ and rename it:

zf-shops

zf-crafting

zf-doors

zf-robberies

etc.

Then:

rename event prefixes (zf-template:* -> zf-shops:*)

update Config.NotifyTitle

replace the example server logic with your real feature


---

## How to use this template (real workflow)
1) Copy folder → rename to `zf-<feature>`
2) Rename the events in both files
3) Keep the wrappers — use them everywhere
4) Add your real logic

If you tell me what your next script is (shops / crafting / robberies / doors), I’ll generate the first real version of it using this template so it plugs into your ZF stack perfectly.



zf-notify exports (use this for ALL toasts)
✅ Notify
exports['zf-notify']:Notify({
  title = 'Title',
  message = 'Text here',
  type = 'info',       -- info/success/warning/error (inform/primary/warn also mapped)
  duration = 3000
})

zf-ui exports (core dialogs + theme)
✅ Notify (if you kept it in zf-ui; optional)
exports['zf-ui']:Notify({ title='ZF', message='Hello', type='success', duration=3000 })

✅ Confirm
local ok = exports['zf-ui']:Confirm({
  title = 'Confirm',
  message = 'Are you sure?',
  confirmLabel = 'Yes',
  cancelLabel = 'No'
})

✅ Input
local res = exports['zf-ui']:Input({
  title = 'Input',
  fields = {
    { type='input',  label='Name', required=true,  placeholder='Type...' },
    { type='number', label='Amount', required=false, placeholder='Optional' }
  }
})
-- res is table array or nil

✅ SetTheme
exports['zf-ui']:SetTheme({
  accent = '#8b5cf6',
  panel = 'rgba(18,18,26,.96)'
})

zf-minigame exports (skillchecks)
✅ Start
local success = exports['zf-minigame']:Start({
  title = 'Lockpick',
  hint = 'Press SPACE/ENTER in the zone',
  speed = 1.0,      -- higher = faster
  zoneSize = 0.12,  -- 0.06 - 0.30 recommended
  roundTime = 8000  -- ms (0 = infinite)
})
-- returns true/false

zf-bridge exports (optional “one API to rule them all”)

If you use zf-bridge, your scripts can depend on one thing and never care if you swap UI/notify later.

✅ Notify
exports['zf-bridge']:Notify({ title='Bank', message='Paid $500', type='success', duration=2500 })

✅ NotifySimple
exports['zf-bridge']:NotifySimple('Bank', 'Paid $500', 'success', 2500)

✅ Confirm
local ok = exports['zf-bridge']:Confirm({ title='Confirm', message='Proceed?' })

✅ Input
local res = exports['zf-bridge']:Input({
  title='Input',
  fields = { { type='input', label='Reason', required=true } }
})

✅ Server-side helpers (from zf-bridge/server/main.lua)
local staff = exports['zf-bridge']:IsStaff(source)
local pdata = exports['zf-bridge']:GetPlayerData(source)


Gang helpers (staff only, if zf-gangsystem + ox callbacks are running):

local gangs = exports['zf-bridge']:GetGangs(source)

local ok, err = exports['zf-bridge']:StaffSetPlayerGang(source, targetId, gangName, rankName)
local ok2, err2 = exports['zf-bridge']:StaffClearPlayerGang(source, targetId)

zf-template exports (optional — mainly for testing/bootstrapping)

If you keep them:

exports['zf-template']:Notify('Hello', 'success', 2500, 'My Script')
local ok = exports['zf-template']:Confirm('Title', 'Msg', 'Yes', 'No')
local res = exports['zf-template']:Input('Title', { { type='input', label='Name', required=true } })
local win = exports['zf-template']:Minigame({ title='Test', speed=1.0, zoneSize=0.12, roundTime=8000 })

What you should standardize on (recommended)

For ZF scripts long-term:

Toasts: exports['zf-notify']:Notify(...)

Dialogs: exports['zf-ui']:Confirm(...) and exports['zf-ui']:Input(...)

Skillchecks: exports['zf-minigame']:Start(...)

Or if you want maximum future flexibility:

use only zf-bridge exports everywhere (and let it route to notify/ui/minigame).

If you tell me which route you’re choosing (direct vs bridge-only), I’ll write you a tiny “ZF coding standard” snippet you can paste into every new script so you never think about it again.
