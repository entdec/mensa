import ApplicationController from "mensa/controllers/application_controller";

// Manages row-level checkbox selection and the batch-action bar.
//
// The controller lives on the .overflow-y-auto.relative wrapper element.
//
// The batch bar is a div.mensa-batch-bar that is a sibling of the <table>,
// absolutely positioned at top:0/left:0 inside that wrapper. Its width is
// set to the <table>'s offsetWidth so it covers the full table — including
// any overflow that causes horizontal scrolling.
export default class SelectionController extends ApplicationController {
    static targets = [
        "headerCheckbox", // select-all checkbox in the header <th>
        "rowCheckbox", // per-row checkboxes in <tbody>
        "batchBar", // absolutely-positioned div overlaying the header row
        "selectedCount", // span inside the batch bar showing "N selected"
        "batchAllCheckbox", // checkbox inside the batch bar (clicking deselects all)
    ];

    static values = {
        batchUrl: String, // POST endpoint for batch actions
    };

    connect() {
        super.connect();
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
        this.updateSelectionState();
    }

    // Called when an individual row checkbox changes.
    toggleRow() {
        this.updateSelectionState();
    }

    // Called when the batch bar's checkbox is clicked — always deselects all.
    deselectAll() {
        this.rowCheckboxTargets.forEach((cb) => (cb.checked = false));
        this.updateSelectionState();
    }

    // Stops click events from bubbling up to the row's satis-link handler,
    // preventing accidental navigation when the user clicks a checkbox cell.
    stopPropagation(event) {
        event.stopPropagation();
    }

    // Builds and submits a hidden form for the chosen batch action.
    // Reads selected record IDs from the checked row checkboxes.
    executeBatch(event) {
        event.preventDefault();

        const actionName = event.params.batchAction;
        const selectedIds = this.rowCheckboxTargets
            .filter((cb) => cb.checked)
            .map((cb) => cb.value);

        if (selectedIds.length === 0) return;
        if (!this.batchUrlValue) return;

        const form = document.createElement("form");
        form.method = "post";
        form.action = this.batchUrlValue;

        // Rails CSRF token
        const csrfMeta = document.querySelector('meta[name="csrf-token"]');
        if (csrfMeta) {
            const csrfInput = document.createElement("input");
            csrfInput.type = "hidden";
            csrfInput.name = "authenticity_token";
            csrfInput.value = csrfMeta.getAttribute("content");
            form.appendChild(csrfInput);
        }

        // Batch action name
        const actionInput = document.createElement("input");
        actionInput.type = "hidden";
        actionInput.name = "batch_action_name";
        actionInput.value = actionName;
        form.appendChild(actionInput);

        // One hidden input per selected record ID
        selectedIds.forEach((id) => {
            const input = document.createElement("input");
            input.type = "hidden";
            input.name = "record_ids[]";
            input.value = id;
            form.appendChild(input);
        });

        document.body.appendChild(form);
        form.submit();
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
            this.selectedCountTarget.textContent = `${checked.length} selected`;
        }
    }
}
