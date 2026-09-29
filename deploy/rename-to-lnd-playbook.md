# Rename to “lnd-playbook” — admin steps (outside the code)

The app display name stays **“L&D Playbook”**. These are the external things that
still carry the old name; each is renamed by an admin (Claude can't do these).

## 1. GitHub repository
1. Open the repo → **Settings** → **General**.
2. **Repository name** → change `pizza4ps-logistics-handbook` → `lnd-playbook` → **Rename**.
3. GitHub keeps the old URL redirecting, so existing clones/links still work. To be tidy, update any local clone:
   `git remote set-url origin https://github.com/4pslnd/lnd-playbook.git`
4. ⚠️ Note for Claude Code sessions: a new session must be pointed at the **new** repo name (`4pslnd/lnd-playbook`). The current session is still attached under the old name and will keep working until it ends.

## 2. Supabase project (name only)
1. Supabase dashboard → your project → **Project Settings** → **General**.
2. **Project name** → `lnd-playbook` → **Save**.
- This is only a display name. The project **ref** and the API URL (`https://<ref>.supabase.co`) and keys **do not change**, so nothing in the app breaks and no code change is needed.

## 3. Google Apps Script (mailer) project — name only
1. Open the mailer project at **script.google.com**.
2. Click the project title (top-left) → rename to `lnd-playbook mailer` → OK.
- ⚠️ The **deployment `/exec` URL does not change** when you rename the project — it's tied to the deployment ID, not the name. So there is nothing to update in Supabase `app_config.mailer_url`; the mailer keeps working. (There is no way to “rename” the deploy URL itself.)

## 4. In-app document title
1. Open the document **“How to use the EDL Internal Handbook”** (User guide pillar).
2. Click **✎ Edit** → use the **✎ rename** button on the editor bar (next to the title).
3. Change the title (e.g. “How to use the L&D Playbook”) → **Save draft** → **Publish** so viewers see it.
- This is stored data, not code — that's why it's renamed in the app.

## Nothing else in the code needs changing
The residual code/doc references (brand-tokens comment, logo alt text, README) were already updated to L&D Playbook / lnd-playbook. The **EDL** team / role / lane names and `lnd.edl@pizza4ps.com` are intentionally kept (they name the team, not the product).
