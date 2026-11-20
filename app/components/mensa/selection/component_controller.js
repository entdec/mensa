import ApplicationController from "mensa/controllers/application_controller";

// Manages row-level checkbox selection and the batch-action bar.
//
// The controller lives on the .overflow-y-auto.relative wrapper element.
//
// The batch bar is a div.mensa-batch-bar that is a sibling of the <table>,
// absolutely positioned at top:0/left:0 inside that wrapper. Its width is
// set to the <table>'s offsetWidth so it covers the full table — including
// any overflow that causes horizontal scrolling.
//
// A selection is either the checked rows, or — after "Select all" — every row
// matching the table's current search and filters, which the server works out
// again from the table's state.
export default class SelectionController extends ApplicationController {
    static targets = [
        "headerCheckbox", // select-all checkbox in the header <th>
        "rowCheckbox", // per-row checkboxes in <tbody>
        "batchBar", // absolutely-positioned div overlaying the header row
        "selectedCount", // span inside the batch bar showing "N selected"
        "batchAllCheckbox", // checkbox inside the batch bar (clicking deselects all)
        "selectAllButton", // button in the batch bar selecting all matching rows
        "selectAllLabel", // its text, "Select all N" or "Select only this page"
        "selectAllIcon", // its icon when it selects all matching rows
        "selectPageIcon", // its icon when it goes back to this page
    ];

    static values = {
        batchUrl: String, // POST endpoint for batch actions
        newUrl: String, // GET endpoint for a batch action's dialog
        total: Number, // number of rows matching the search and filters
        texts: Object, // translations, with {count} for the number
    };

    connect() {
        super.connect();
        this.allMatching = false;
        this.resizeHandler = () => this.syncBatchBarWidth();
        window.addEventListener("resize", this.resizeHandler);
    }

    disconnect() {
        window.removeEventListener("resize", this.resizeHandler);
    }

    // Sets the batch bar's width to match the <table> element so it covers
    // the full scrollable width, not just the visible viewport portion.
    syncBatchBarWidth() {
        if (!this.hasBatchBarTarget) return;
        const table = this.element.querySelector("table");
        if (!table) return;
        this.batchBarTarget.style.width = `${table.offsetWidth}px`;
    }

    // Called when the select-all checkbox in the header changes.
    toggleAll(event) {
        const checked = event.target.checked;
        this.rowCheckboxTargets.forEach((cb) => {
            cb.checked = checked;
        });
        this.allMatching = false;
        this.updateSelectionState();
    }

    // Called when an individual row checkbox changes.
    toggleRow() {
        this.allMatching = false;
        this.updateSelectionState();
    }

    // Called when the batch bar's checkbox is clicked — always deselects all.
    deselectAll() {
        this.rowCheckboxTargets.forEach((cb) => (cb.checked = false));
        this.allMatching = false;
        this.updateSelectionState();
    }

    // Switches between every row matching the search and filters, and only
    // the rows on this page.
    toggleAllMatching() {
        this.allMatching = !this.allMatching;
        this.updateSelectionState();
    }

    // Stops click events from bubbling up to the row's mensa-link handler,
    // preventing accidental navigation when the user clicks a checkbox cell.
    stopPropagation(event) {
        event.stopPropagation();
    }

    // Runs the chosen batch action: opens its dialog when it has a form,
    // otherwise submits it (after confirming, when it asks to). An action on
    // all matching rows always asks first, as those are more than the user
    // sees: the dialog shows how many, otherwise a confirm does.
    executeBatch(event) {
        event.preventDefault();

        const { batchAction, form, confirm, title } = event.params;
        if (this.selectionCount === 0) return;
        if (!this.batchUrlValue) return;

        if (form) {
            this.openDialog(batchAction);
        } else if (this.allMatching && !confirm) {
            this.submitBatch(
                batchAction,
                this.text("confirm_all", this.totalValue).replace("{action}", title),
            );
        } else {
            this.submitBatch(batchAction, confirm);
        }
    }

    // Builds and submits a hidden form for the batch action, through Turbo so
    // data-turbo-confirm and redirects work as usual.
    submitBatch(actionName, confirm) {
        const form = document.createElement("form");
        form.method = "post";
        form.action = this.batchUrlValue;
        form.hidden = true;
        form.dataset.turbo = "true";
        if (confirm) form.dataset.turboConfirm = confirm;

        const entries = [
            ["authenticity_token", this.csrfToken],
            ["batch_action_name", actionName],
            ...this.selectionEntries(),
        ];
        entries.forEach(([name, value]) => {
            const input = document.createElement("input");
            input.type = "hidden";
            input.name = name;
            input.value = value;
            form.appendChild(input);
        });

        document.body.appendChild(form);
        form.requestSubmit();
    }

    // Opens a dialog with the batch action's form, loaded into a turbo-frame.
    // The dialog is added to <body>, so its form isn't nested in a form the
    // table may be in. The selection is added to what the form submits.
    openDialog(actionName) {
        const url = new URL(this.newUrlValue, window.location.origin);
        url.searchParams.set("batch_action_name", actionName);
        url.searchParams.set("count", this.selectionCount);

        const entries = this.selectionEntries();
        const dialog = document.createElement("dialog");
        dialog.className = "mensa-batch-dialog";

        const frame = document.createElement("turbo-frame");
        frame.id = "mensa-batch-dialog";
        frame.setAttribute("src", url.pathname + url.search);
        dialog.appendChild(frame);

        dialog.addEventListener(
            "formdata",
            (event) =>
                entries.forEach(([name, value]) =>
                    event.formData.append(name, value),
                ),
            true,
        );
        // A response without the dialog's frame (a redirect after the action
        // ran) is shown as a page
        dialog.addEventListener("turbo:frame-missing", (event) => {
            event.preventDefault();
            dialog.close();
            event.detail.visit(event.detail.response);
        });
        dialog.addEventListener("click", (event) => {
            if (
                event.target === dialog ||
                event.target.closest("[data-mensa-batch-dialog-close]")
            ) {
                dialog.close();
            }
        });
        dialog.addEventListener("close", () => dialog.remove());

        document.body.appendChild(dialog);
        dialog.showModal();
    }

    // What identifies the selection to the server: the ids, or the table's
    // state to find all matching rows with
    selectionEntries() {
        if (!this.allMatching) {
            return this.checkedIds.map((id) => ["record_ids[]", id]);
        }

        const state = this.tableController?.requestState() || {};
        const entries = [["select_all", "1"]];
        if (state.table_view_id) {
            entries.push(["table_view_id", state.table_view_id]);
        }
        if (state.query) entries.push(["query", state.query]);
        // Blank filters means "explicitly none", not the view's
        const filters = state.filters || {};
        if (Object.keys(filters).length === 0) {
            entries.push(["filters", ""]);
        } else {
            this.appendEntries(entries, "filters", filters);
        }
        return entries;
    }

    // Flattens a nested object into Rails-style form names
    appendEntries(entries, name, value) {
        if (Array.isArray(value)) {
            value.forEach((item) => this.appendEntries(entries, `${name}[]`, item));
        } else if (value !== null && typeof value === "object") {
            Object.entries(value).forEach(([key, item]) =>
                this.appendEntries(entries, `${name}[${key}]`, item),
            );
        } else if (value !== undefined && value !== null) {
            entries.push([name, String(value)]);
        }
    }

    get checkedIds() {
        return this.rowCheckboxTargets
            .filter((cb) => cb.checked)
            .map((cb) => cb.value);
    }

    get selectionCount() {
        return this.allMatching ? this.totalValue : this.checkedIds.length;
    }

    get tableController() {
        const element = this.element.closest("[data-controller~='mensa-table']");
        if (!element) return null;
        return this.application.getControllerForElementAndIdentifier(
            element,
            "mensa-table",
        );
    }

    get csrfToken() {
        return (
            document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") ||
            ""
        );
    }

    text(key, count) {
        const template = this.textsValue[key] || `{count} ${key}`;
        const number = Number(count).toLocaleString(
            document.documentElement.lang || undefined,
        );
        return template.replace("{count}", number);
    }

    // Syncs the header checkbox state and shows/hides the batch bar overlay.
    updateSelectionState() {
        const all = this.rowCheckboxTargets;
        const checked = all.filter((cb) => cb.checked);
        const hasSelection = checked.length > 0;
        const allSelected = all.length > 0 && checked.length === all.length;
        const someSelected = checked.length > 0 && checked.length < all.length;

        // Keep the header select-all checkbox in sync
        if (this.hasHeaderCheckboxTarget) {
            this.headerCheckboxTarget.checked = allSelected;
            this.headerCheckboxTarget.indeterminate = someSelected;
        }

        // Mirror the state on the batch bar's deselect-all checkbox
        if (this.hasBatchAllCheckboxTarget) {
            this.batchAllCheckboxTarget.checked = allSelected;
            this.batchAllCheckboxTarget.indeterminate = someSelected;
        }

        // Show / hide the batch bar overlay
        if (this.hasBatchBarTarget) {
            if (hasSelection) this.syncBatchBarWidth();
            this.batchBarTarget.classList.toggle("hidden", !hasSelection);
        }

        // Update "N selected" label
        if (this.hasSelectedCountTarget) {
            this.selectedCountTarget.textContent = this.allMatching
                ? this.text("all_selected", this.totalValue)
                : this.text("selected", checked.length);
        }

        // Once the whole page is selected, offer to select all matching rows,
        // and then to go back to only this page
        if (this.hasSelectAllButtonTarget) {
            const offer = allSelected && this.totalValue > all.length;
            const key = this.allMatching ? "select_page" : "select_all";
            const count = this.allMatching ? all.length : this.totalValue;
            if (this.hasSelectAllLabelTarget) {
                this.selectAllLabelTarget.textContent = this.text(key, count);
            }
            // Both icons are rendered, as Font Awesome may have replaced them
            // with an <svg>, whose class can't simply be swapped
            if (this.hasSelectAllIconTarget) {
                this.selectAllIconTarget.hidden = this.allMatching;
            }
            if (this.hasSelectPageIconTarget) {
                this.selectPageIconTarget.hidden = !this.allMatching;
            }
            this.selectAllButtonTarget.classList.toggle("hidden", !offer);
        }
    }
}
